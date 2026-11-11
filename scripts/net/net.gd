class_name Net
extends Node
## Онлайн-охота: дачники против пчёл по сети (часть 3).
##
## Сервер считает всю игру сам (те же EscapeMatch, Human, Bee, BeeBot, что офлайн),
## игроки шлют ему только «куда ведёт палец» и нажатия, а он 20 раз в секунду
## рассылает снимок: где кто, отёк, банки, машина. Пустые места занимают боты.
##
## Три способа играть:
##   1) выделенный сервер:  godot --headless --path . -- --server --port=8910
##      (к нему подключаются и телефоны, и браузер; для браузера нужен wss://);
##   2) комната с телефона: «Создать комнату» — друзья в том же Wi-Fi подключаются по адресу;
##   3) проверка без экрана: -- --netclient=ws://127.0.0.1:8910 --side=human --autopilot

const DEFAULT_PORT := 8910
## Адрес общего сервера (wss://…). Пока пусто — сервер ещё не развёрнут.
const DEFAULT_SERVER := ""
const SNAPSHOT_RATE := 20.0
const INPUT_RATE := 20.0
const LOBBY_WAIT := 12.0
const RESULT_WAIT := 8.0
const MAX_HUMANS := 4
const MAX_BEES := 16

enum Kind { HUMAN, BEE, BOT, JAR }

var is_server := false
var hosting := false  # комната на телефоне: сервер и игрок в одном
var connected := false
var status := ""

# ── сервер ──
var _players := {}  # peer → {side, name, autopilot}
var _phase := "lobby"  # lobby / match / results
var _phase_until := 0.0
var _snap_acc := 0.0
var _lobby_acc := 0.0
var _net_ids := {}  # id → узел
var _next_id := 1
var _rotate_maps := false  # сервер: после каждого матча — следующая карта

# ── клиент ──
var _my_id := -1
var _my_side := 0
var _proxies := {}  # id → {node, kind, pos, yaw, vel}
var _proxy_root: Node3D
var _header := PackedFloat32Array()
var _jar_ids := PackedInt32Array()
var _finger: FingerTracker
var _send_acc := 0.0
var _autopilot := false
var _test_client := false
var _ui := {}
var _match_running := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Не удалось подключиться"))
	multiplayer.server_disconnected.connect(func(): _fail("Сервер отключился"))
	_finger = FingerTracker.new()
	add_child(_finger)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--netclient="):
			_test_client = true
			_autopilot = "--autopilot" in args
			Profile.current().side = Profile.Side.BEE if "--side=bee" in args else Profile.Side.HUMAN
			connect_to.call_deferred(a.substr(12))


static func _arg(args: PackedStringArray, key: String, def: String) -> String:
	for a in args:
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


# ════════════════════════ СЕРВЕР ════════════════════════

func start_server(args := PackedStringArray()) -> bool:
	var port := int(_arg(args, "--port", str(DEFAULT_PORT)))
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("[server] не удалось открыть порт %d: %s" % [port, error_string(err)])
		return false
	multiplayer.multiplayer_peer = peer
	is_server = true
	var map := _arg(args, "--map", "")
	if map != "" and map != Game.I.world.map_id:
		Game.I._build_world(map)
	_rotate_maps = "--rotate-maps" in args
	_phase = "lobby"
	_phase_until = 0.0
	print("[server] онлайн-охота слушает порт %d, карта %s" % [port, Game.I.world.map_id])
	return true


## Комната на телефоне: этот телефон — сервер и игрок одновременно.
func host_lan() -> void:
	if not start_server(PackedStringArray()):
		status = "Не удалось создать комнату"
		show_menu()
		return
	hosting = true
	var p := Profile.current()
	_players[1] = {"side": p.side, "name": p.display_name(), "autopilot": false}
	show_lobby()


static func lan_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			result.append(a)
	return result


func _on_peer_connected(id: int) -> void:
	if is_server:
		print("[server] подключился игрок %d" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_server:
		return
	print("[server] отключился игрок %d" % id)
	_players.erase(id)
	var m := Game.I.escape
	if m and m.peer_entities.has(id):
		var e = m.peer_entities[id]
		if e is Human and is_instance_valid(e):
			var brain := HumanBot.new()  # ушедшего дачника подхватывает бот
			(e as Human).add_child(brain)
		m.peer_entities.erase(id)


@rpc("any_peer", "call_remote", "reliable")
func c_hello(side: int, player_name: String, autopilot: bool) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	_players[id] = {"side": side, "name": player_name.left(16), "autopilot": autopilot}
	s_welcome.rpc_id(id, Game.I.world.map_id, _phase)
	print("[server] %s за %s" % [player_name, "пчёл" if side == Profile.Side.BEE else "людей"])


func _process(delta: float) -> void:
	if is_server:
		_server_tick(delta)
	elif connected:
		_client_tick(delta)


func _server_tick(delta: float) -> void:
	var game := Game.I
	match _phase:
		"lobby":
			if _players.is_empty():
				_phase_until = 0.0
				return
			if _phase_until <= 0.0:
				_phase_until = Game.clock + LOBBY_WAIT
			_lobby_acc += delta
			if _lobby_acc >= 1.0:
				_lobby_acc = 0.0
				s_lobby.rpc(_players.size(), maxf(0.0, _phase_until - Game.clock))
				if hosting:
					_update_lobby_ui(_players.size(), _phase_until - Game.clock)
			if Game.clock >= _phase_until:
				_server_start_match()
		"match":
			_snap_acc += delta
			if _snap_acc >= 1.0 / SNAPSHOT_RATE:
				_snap_acc = 0.0
				_send_snapshot()
		"results":
			if Game.clock >= _phase_until:
				_phase = "lobby"
				_phase_until = 0.0
				if _rotate_maps and not hosting:
					var order: Array = World.MAP_ORDER
					game._build_world(order[(order.find(game.world.map_id) + 1) % order.size()])
					print("[server] следующая карта: " + game.world.map_name())
				if hosting:
					show_lobby()


## Хозяин комнаты может начать сразу, не дожидаясь отсчёта.
func start_now() -> void:
	if is_server and _phase == "lobby" and not _players.is_empty():
		_phase_until = Game.clock


func _server_start_match() -> void:
	var game := Game.I
	var humans: Array = []
	var bees: Array = []
	for id in _players:
		var side: int = _players[id]["side"]
		if side == Profile.Side.HUMAN and humans.size() < MAX_HUMANS:
			humans.append(id)
		elif bees.size() < MAX_BEES:
			bees.append(id)
		elif humans.size() < MAX_HUMANS:
			humans.append(id)
	var roster := {"humans": humans, "bees": bees, "fill_humans": maxi(0, 3 - humans.size())}
	game.world.prepare_escape()
	var m := EscapeMatch.begin(game.world, game, EscapeMatch.Kind.ONLINE, roster)
	game.escape = m
	game.state = Game.State.ESCAPE
	_phase = "match"
	print("[server] матч: дачников %d (+%d ботов), пчёл-игроков %d, ботов-пчёл %d" % [
		humans.size(), roster["fill_humans"], bees.size(), m.bots.size()])

	# Сетевые номера всем участникам
	_net_ids.clear()
	_next_id = 1
	var list: Array = []
	for h in m.humans:
		list.append([_register(h), Kind.HUMAN])
	for b in m.player_bees:
		list.append([_register(b), Kind.BEE])
	for b in m.bots:
		list.append([_register(b), Kind.BOT])
	for j in m.get_children():
		if j is HoneyJar:
			list.append([_register(j), Kind.JAR, j.global_position])

	for id in _players:
		var e = m.peer_entities.get(id)
		if _players[id]["autopilot"] and e is Human:
			(e as Human).add_child(HumanBot.new())
		if id == 1 and hosting:
			_host_takes_control(m, e)
			continue
		s_match_start.rpc_id(id, game.world.map_id, list, _id_of(e))


func _host_takes_control(m: EscapeMatch, e) -> void:
	var game := Game.I
	if e is Human:
		m.human = e
		(e as Human).local_control = true
		game.cam.follow(e, 0.9)
	elif e is Bee:
		m.player_bee = e
		(e as Bee).local_control = true
		m.stats.player_is_bee = true
		game.cam.follow(e, 1.5)
	game.mode_id = ""
	game.ui.show_escape_hud()


func _register(node: Node) -> int:
	var id := _next_id
	_next_id += 1
	_net_ids[id] = node
	node.set_meta("net_id", id)
	return id


func _id_of(node) -> int:
	return int(node.get_meta("net_id", -1)) if node is Node and is_instance_valid(node) else -1


func _send_snapshot() -> void:
	var m := Game.I.escape
	if m == null:
		return
	var data := PackedFloat32Array()
	var jars := PackedInt32Array()
	for id in _net_ids:
		var n = _net_ids[id]
		if not is_instance_valid(n):
			continue
		var p: Vector3 = n.global_position
		if n is HoneyJar:
			jars.append(id)
			continue
		var yaw := 0.0
		var f1 := 0.0
		var f2 := 0.0
		var v := Vector3.ZERO
		if n is Human:
			var h := n as Human
			yaw = h.facing
			v = h.velocity
			f1 = h.swelling
			f2 = (1.0 if h.frozen else 0.0) + (2.0 if h.visible else 0.0) + (4.0 if h.is_dodging() else 0.0)
		elif n is Bee:
			var b := n as Bee
			yaw = b.heading
			v = b.velocity
			f2 = 1.0 if b.is_stuck() else 0.0
		elif n is BeeBot:
			var bb := n as BeeBot
			v = bb.velocity
			yaw = atan2(v.x, v.z)
			f1 = 1.0 if bb.stunned() else 0.0
			f2 = 1.0 if bb.asleep() else 0.0
		data.append_array(PackedFloat32Array([id, p.x, p.y, p.z, yaw, v.x, v.z, f1, f2]))
	var header := PackedFloat32Array([m.time_left, m.stats.jars, m.stats.jars_needed, m.car_progress,
		m.active_humans().size(), m.stats.humans_total])
	s_snapshot.rpc(header, data, jars)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_input(has_target: bool, target: Vector3) -> void:
	var e = _entity_of_sender()
	if e is Human or e is Bee:
		e.debug_steer(target if has_target else null)


@rpc("any_peer", "call_remote", "reliable")
func c_action(action: String, dir: Vector3) -> void:
	var e = _entity_of_sender()
	if e is Human:
		match action:
			"swat":
				(e as Human).swat()
			"smoke":
				(e as Human).smoke()
			"dodge":
				(e as Human).dodge(dir)
	elif e is Bee and action == "dash":
		(e as Bee).dash(dir)


func _entity_of_sender():
	if not is_server:
		return null
	var m := Game.I.escape
	if m == null:
		return null
	var e = m.peer_entities.get(multiplayer.get_remote_sender_id())
	return e if is_instance_valid(e) else null


## Реплики деда и всплывашки сервер пересылает игрокам.
func server_event(kind: String, text: String) -> void:
	if is_server and _phase == "match":
		s_event.rpc(kind, text)


## Матч окончен (зовёт Game.end_escape на сервере/у хозяина).
func server_match_over(s: EscapeMatch.Stats) -> void:
	var result := {"ending": s.ending, "escaped": s.escaped, "humans_total": s.humans_total,
		"humans_fainted": s.humans_fainted, "humans_escaped": s.humans_escaped,
		"jars": s.jars, "jars_needed": s.jars_needed, "time": s.time}
	s_match_over.rpc(result)
	print("[server] матч окончен: %s, уехали %d, на скорой %d" % [s.ending, s.humans_escaped, s.humans_fainted])
	_phase = "results"
	_phase_until = Game.clock + RESULT_WAIT
	_net_ids.clear()


# ════════════════════════ КЛИЕНТ ════════════════════════

func connect_to(url: String) -> void:
	if url == "":
		status = "Укажи адрес сервера"
		show_menu()
		return
	if not url.begins_with("ws"):
		url = "ws://" + url
	if url.count(":") < 2:
		url += ":%d" % DEFAULT_PORT
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		_fail("Неверный адрес: " + url)
		return
	multiplayer.multiplayer_peer = peer
	status = "Подключаюсь к %s…" % url
	if Game.I.ui:
		show_lobby()
	print("[client] подключаюсь к " + url)


func _on_connected() -> void:
	connected = true
	var p := Profile.current()
	_my_side = p.side
	c_hello.rpc_id(1, p.side, p.display_name(), _autopilot)
	status = "Подключено! Ждём игроков…"
	print("[client] подключено")


func _fail(why: String) -> void:
	print("[client] " + why)
	disconnect_all()
	status = why
	if _test_client:
		print("NETTEST FAIL: " + why)
		get_tree().quit(1)
		return
	if Game.I.ui:
		show_menu()


func disconnect_all() -> void:
	_clear_proxies()
	connected = false
	is_server = false
	hosting = false
	_players.clear()
	_match_running = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


@rpc("authority", "call_remote", "reliable")
func s_welcome(map_id: String, phase: String) -> void:
	if Game.I.world.map_id != map_id:
		Game.I._build_world(map_id)
	status = "Идёт матч — подождём следующий" if phase == "match" else "Ждём игроков…"
	if Game.I.ui:
		show_lobby()


@rpc("authority", "call_remote", "reliable")
func s_lobby(players: int, wait: float) -> void:
	if _match_running:
		return
	_update_lobby_ui(players, wait)


@rpc("authority", "call_remote", "reliable")
func s_match_start(map_id: String, roster: Array, your_id: int) -> void:
	var game := Game.I
	if game.world.map_id != map_id:
		game._build_world(map_id)
	game.world.prepare_escape()
	_clear_proxies()
	_proxy_root = Shape.node("Сетевые", game)
	for r in roster:
		var id: int = r[0]
		var kind: int = r[1]
		var node: Node3D
		match kind:
			Kind.HUMAN:
				var h := Human.spawn(_proxy_root, game.world.escape_spawn)
				h.local_control = false
				h.set_physics_process(false)
				node = h
			Kind.BEE:
				var b := Bee.spawn(_proxy_root, game.world.bee_spawn)
				b.local_control = false
				b.set_physics_process(false)
				node = b
			Kind.BOT:
				var bb := BeeBot.spawn(_proxy_root, game.world.hive_position + Vector3(0, 2, 0), 0.0, 0.0)
				bb.set_physics_process(false)
				node = bb
			Kind.JAR:
				node = HoneyJar.spawn(_proxy_root, r[2])
		_proxies[id] = {"node": node, "kind": kind, "pos": node.global_position, "yaw": 0.0, "vel": Vector3.ZERO}
	_my_id = your_id
	_match_running = true
	game.state = Game.State.ONLINE
	var me := _me()
	if me:
		game.cam.follow(me, 0.9 if me is Human else 1.5)
	if game.ui:
		_build_hud()
		game.say("Матч начался! " + ("Беги за банками!" if me is Human else "Лови неуважающих!"), 3.0)
	print("[client] матч начался, участников %d, мой номер %d" % [roster.size(), your_id])


func _me() -> Node3D:
	var p = _proxies.get(_my_id)
	return p["node"] if p and is_instance_valid(p["node"]) else null


@rpc("authority", "call_remote", "unreliable_ordered")
func s_snapshot(header: PackedFloat32Array, data: PackedFloat32Array, jars: PackedInt32Array) -> void:
	_header = header
	_jar_ids = jars
	var i := 0
	while i + 8 < data.size():
		var id := int(data[i])
		var p = _proxies.get(id)
		if p and is_instance_valid(p["node"]):
			p["pos"] = Vector3(data[i + 1], data[i + 2], data[i + 3])
			p["yaw"] = data[i + 4]
			p["vel"] = Vector3(data[i + 5], 0, data[i + 6])
			var n: Node3D = p["node"]
			match int(p["kind"]):
				Kind.HUMAN:
					var h := n as Human
					h.swelling = data[i + 7]
					var flags := int(data[i + 8])
					var was_frozen := h.frozen
					h.frozen = flags & 1 != 0
					h.visible = flags & 2 != 0
					if h.frozen and not was_frozen and h.swelling >= 1.0:
						h.faint()
				Kind.BOT:
					(n as BeeBot).net_flags(data[i + 7] > 0.5, data[i + 8] > 0.5)
		i += 9
	# Унесённые банки исчезают
	for id in _proxies.keys():
		var p = _proxies[id]
		if int(p["kind"]) == Kind.JAR and not id in jars and is_instance_valid(p["node"]):
			(p["node"] as Node).queue_free()
	_snapshot_count += 1


var _snapshot_count := 0


@rpc("authority", "call_remote", "reliable")
func s_event(kind: String, text: String) -> void:
	if Game.I.ui == null:
		return
	if kind == "say":
		Game.I.ui.say(text, 2.5)
	else:
		Game.I.ui.toast(text)


@rpc("authority", "call_remote", "reliable")
func s_match_over(result: Dictionary) -> void:
	_match_running = false
	var me_human := _me() is Human
	var humans_won: bool = result.get("escaped", false)
	var i_won := humans_won if me_human else not humans_won
	print("[client] матч окончен: %s, снимков получено %d" % [result.get("ending", ""), _snapshot_count])
	_clear_proxies()
	var game := Game.I
	game.world.end_escape()
	game.state = Game.State.HUB
	if _test_client:
		print("NETTEST OK: снимков %d, концовка %s" % [_snapshot_count, result.get("ending", "")])
		get_tree().quit(0)
		return
	game.cam.show_hub()
	game.mode_id = ""
	game.ui.show_card({
		"title": "Победа!" if i_won else "Поражение",
		"big": ("Дачники уехали" if humans_won else "Пчёлы победили"),
		"color": UiKit.DEEP_HONEY if i_won else UiKit.DANGER_BG,
		"body": "Дачников: %d · уехали %d · на скорой %d\nБанок: %d/%d\nВремя: %d с" % [
			result.get("humans_total", 0), result.get("humans_escaped", 0), result.get("humans_fainted", 0),
			result.get("jars", 0), result.get("jars_needed", 0), roundi(result.get("time", 0.0))],
		"footer": "Следующий матч начнётся сам — останься в комнате",
		"again": "",
	})
	var stay := UiKit.button(game.ui.current_screen(), "В комнату", 0.06, 0.07, 0.6, 0.17, UiKit.HONEY_BG, UiKit.INK,
		func(): show_lobby(), 54)
	stay.name = "В комнату"


func _clear_proxies() -> void:
	if is_instance_valid(_proxy_root):
		_proxy_root.queue_free()
	_proxy_root = null
	_proxies.clear()
	_my_id = -1


func _client_tick(delta: float) -> void:
	# Плавно двигаем копии к позициям из снимков
	for id in _proxies:
		var p = _proxies[id]
		if not is_instance_valid(p["node"]) or int(p["kind"]) == Kind.JAR:
			continue
		var n: Node3D = p["node"]
		n.global_position = n.global_position.lerp(p["pos"], clampf(14.0 * delta, 0.0, 1.0))
		var v: Vector3 = p["vel"]
		match int(p["kind"]):
			Kind.HUMAN:
				(n as Human).facing = p["yaw"]
				(n as Human).velocity = v
			Kind.BEE:
				(n as Bee).heading = p["yaw"]
				(n as Bee).velocity = v
			Kind.BOT:
				(n as BeeBot).velocity = v

	if not _match_running:
		return
	var me := _me()
	if me == null:
		return
	# Палец → серверу
	var frozen := me is Human and (me as Human).frozen
	_finger.active = not frozen and not _autopilot
	_finger.origin = me
	_finger.fpv_yaw = ((me as Human).facing if me is Human else (me as Bee).heading) if Game.I.fpv else null
	var swipe := _finger.poll()
	if swipe != Vector2.ZERO:
		var dir := FingerTracker.screen_dir_to_world(get_viewport().get_camera_3d(), swipe)
		c_action.rpc_id(1, "dodge" if me is Human else "dash", dir)
	_send_acc += delta
	if _send_acc >= 1.0 / INPUT_RATE and not _autopilot:
		_send_acc = 0.0
		var target = _finger.world_point(me.global_position.y) if _finger.pressed else null
		c_input.rpc_id(1, target != null, target if target != null else Vector3.ZERO)
	if Game.I.ui:
		_update_hud()


# ════════════════════════ ЭКРАНЫ ════════════════════════

## Меню онлайна: адрес сервера, подключение, комната по Wi-Fi.
func show_menu() -> void:
	var game := Game.I
	var ui := game.ui
	var s := ui.new_screen("Онлайн")
	ui.place_say(0.81, 0.895)
	UiKit.panel(s, 0, 0, 1, 1, Color(0, 0, 0, 0.5), 0)
	var card := UiKit.panel(s, 0.06, 0.25, 0.94, 0.78, UiKit.CARD_BG, 30)
	UiKit.label(card, "Онлайн-охота", 64, 0.05, 0.86, 0.95, 0.97, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true, false)
	var side := "пчела" if Profile.current().side == Profile.Side.BEE else "дачник"
	UiKit.label(card, "Дачники против пчёл, до 4 + 16 игроков. Пустые места займут боты. Ты — %s." % side, 32,
		0.06, 0.68, 0.94, 0.85, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false)
	UiKit.label(card, "Адрес сервера или комнаты:", 30, 0.06, 0.6, 0.94, 0.67, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false)
	var field := LineEdit.new()
	field.text = DEFAULT_SERVER
	field.placeholder_text = "например 192.168.1.5"
	field.add_theme_font_size_override("font_size", UiKit.px(40))
	UiKit.place(field, 0.06, 0.48, 0.94, 0.6)
	card.add_child(field)
	UiKit.button(card, "Подключиться", 0.06, 0.33, 0.94, 0.46, UiKit.HONEY_BG, UiKit.INK,
		func(): connect_to(field.text.strip_edges()), 48)
	if not OS.has_feature("web"):
		UiKit.button(card, "Создать комнату (Wi-Fi)", 0.06, 0.18, 0.94, 0.31, UiKit.DANGER_BG, Color.WHITE,
			func(): host_lan(), 42)
	UiKit.label(card, status, 28, 0.06, 0.04, 0.94, 0.16, HORIZONTAL_ALIGNMENT_CENTER, UiKit.DANGER_BG, false, false)
	UiKit.button(s, "Назад", 0.3, 0.1, 0.7, 0.18, UiKit.MUTED, Color.WHITE, func(): disconnect_all(); game.show_hub(), 44)


func show_lobby() -> void:
	var ui := Game.I.ui
	var s := ui.new_screen("Комната")
	ui.place_say(0.81, 0.895)
	UiKit.panel(s, 0, 0, 1, 1, Color(0, 0, 0, 0.45), 0)
	var card := UiKit.panel(s, 0.06, 0.3, 0.94, 0.75, UiKit.CARD_BG, 30)
	UiKit.label(card, "Комната", 64, 0.05, 0.82, 0.95, 0.96, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true, false)
	_ui["lobby"] = UiKit.label(card, status, 40, 0.06, 0.45, 0.94, 0.8, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false)
	if hosting:
		var addrs := lan_addresses()
		UiKit.label(card, "Друзьям в том же Wi-Fi ввести:\n" + (", ".join(addrs) if not addrs.is_empty() else "адрес этого телефона"),
			32, 0.06, 0.22, 0.94, 0.45, HORIZONTAL_ALIGNMENT_CENTER, UiKit.DEEP_HONEY, true, false)
		UiKit.button(card, "Начать сейчас", 0.2, 0.05, 0.8, 0.2, UiKit.HONEY_BG, UiKit.INK, func(): start_now(), 44)
	UiKit.button(s, "Выйти", 0.3, 0.12, 0.7, 0.2, UiKit.MUTED, Color.WHITE, func(): disconnect_all(); Game.I.show_hub(), 44)


func _update_lobby_ui(players: int, wait: float) -> void:
	status = "Игроков в комнате: %d\nМатч начнётся через %d с" % [players, ceili(maxf(0.0, wait))]
	var l = _ui.get("lobby")
	if l and is_instance_valid(l):
		(l as Label).text = status


func _build_hud() -> void:
	var ui := Game.I.ui
	var s := ui.new_screen("Онлайн-матч")
	ui.place_say(0.73, 0.82)
	var top := UiKit.panel(s, 0.03, 0.9, 0.97, 0.975, UiKit.SHADE)
	_ui["jars"] = UiKit.label(top, "", 36, 0.03, 0, 0.34, 1, HORIZONTAL_ALIGNMENT_LEFT, UiKit.HONEY_BG, true)
	_ui["time"] = UiKit.label(top, "", 60, 0.36, 0, 0.6, 1, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	_ui["me"] = UiKit.label(top, "", 32, 0.62, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_RIGHT, Color.WHITE, true)
	var tag := UiKit.panel(s, 0.03, 0.845, 0.42, 0.89, UiKit.SHADE)
	_ui["arrow"] = UiKit.arrow(tag, 0.03, 0.1, 0.17, 0.9, UiKit.HONEY_BG)
	_ui["target"] = UiKit.label(tag, "", 30, 0.2, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)
	ui.view_button(s)
	UiKit.button(s, "Выйти", 0.72, 0.845, 0.97, 0.89, UiKit.SHADE, Color.WHITE, func(): disconnect_all(); Game.I.show_hub(), 34)
	if _me() is Human:
		UiKit.button(s, "Дымарь", 0.6, 0.15, 0.96, 0.24, Color(0.45, 0.55, 0.65), Color.WHITE,
			func(): c_action.rpc_id(1, "smoke", Vector3.ZERO), 44, true)
		UiKit.button(s, "Мухобойка", 0.6, 0.035, 0.96, 0.14, UiKit.HONEY_BG, UiKit.INK,
			func(): c_action.rpc_id(1, "swat", Vector3.ZERO), 48, true)


func _update_hud() -> void:
	if _header.size() < 6 or not _ui.has("time") or not is_instance_valid(_ui["time"]):
		return
	var me := _me()
	var secs := ceili(maxf(0.0, _header[0]))
	(_ui["time"] as Label).text = "%d:%02d" % [secs / 60, secs % 60]
	(_ui["jars"] as Label).text = "Банки %d/%d · дачников %d" % [int(_header[1]), int(_header[2]), int(_header[4])]
	if me is Human:
		(_ui["me"] as Label).text = "Отёк %d%%" % roundi((me as Human).swelling * 100.0)
	else:
		(_ui["me"] as Label).text = "Ты пчела"
	# Указатель: за дачника — ближайшая банка (или машина), за пчелу — ближайший дачник
	var best := INF
	var target := Vector3.ZERO
	var label := ""
	for id in _proxies:
		var p = _proxies[id]
		if not is_instance_valid(p["node"]) or p["node"] == me:
			continue
		var n: Node3D = p["node"]
		var want: bool = (me is Human and int(p["kind"]) == Kind.JAR) or (me is Bee and int(p["kind"]) == Kind.HUMAN and n.visible and not (n as Human).frozen)
		if want:
			var d := n.global_position.distance_squared_to(me.global_position)
			if d < best:
				best = d
				target = n.global_position
				label = "Банка" if me is Human else "Дачник"
	if label == "" and me is Human:
		target = Game.I.world.car_door.global_position
		label = "Машина"
	if label != "":
		var d := target - me.global_position
		(_ui["target"] as Label).text = "%s · %d м" % [label, roundi(Vector2(d.x, d.z).length())]
		Game.I.ui.point_arrow(_ui["arrow"], d)
