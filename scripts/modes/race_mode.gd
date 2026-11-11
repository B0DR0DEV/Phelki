class_name RaceMode
extends Node3D
## Перегонки: ты и 5 пчёл-ботов пролетаете золотые кольца по порядку, 2 круга.
## Кто первый — тому почёт и мёд.

const LAPS := 2
const BOTS := 5
const RING_RADIUS := 1.8
const COUNTDOWN := 3.0
const TIME_LIMIT := 180.0
const BOT_NAMES := ["Жужа", "Шмелёк", "Полосатик", "Медуница", "Бзык"]

var bee: Bee
var racers: Array[Dictionary] = []  # {name, node, lap, ring, done_at, player}
var rings: Array[MeshInstance3D] = []
var elapsed := -COUNTDOWN
var finish_order: Array[String] = []

var _world: World
var _game: Game
var _ui: Dictionary = {}
var _ended := false


static func begin(game: Game, world: World) -> RaceMode:
	var m := RaceMode.new()
	m.name = "Перегонки"
	m._game = game
	m._world = world
	game.add_child(m)
	m._setup()
	return m


func _setup() -> void:
	var pts := _world.race_rings
	for i in pts.size():
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = RING_RADIUS - 0.18
		torus.outer_radius = RING_RADIUS
		ring.mesh = torus
		ring.name = "Кольцо %d" % (i + 1)
		add_child(ring)
		ring.global_position = pts[i]
		var nxt := pts[(i + 1) % pts.size()]
		var dir := nxt - pts[i]
		dir.y = 0.0
		ring.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
		rings.append(ring)

	# Старт — позади первого кольца
	var first := pts[0]
	var back := (pts[0] - pts[pts.size() - 1])
	back.y = 0.0
	back = back.normalized()
	var side := back.cross(Vector3.UP).normalized()
	var start := first - back * 7.0

	bee = Bee.spawn(_world, start + Vector3(0, 0, 0))
	bee.cruise_height = first.y
	bee.position.y = first.y
	bee.heading = atan2(back.x, back.z)
	bee.knock(Vector3.ZERO, COUNTDOWN)  # до старта стоим
	racers.append({"name": "Ты", "node": bee, "lap": 0, "ring": 0, "done_at": -1.0, "player": true})
	for i in BOTS:
		var bot := RaceBot.spawn(self, start + side * ((i % 3) - 1) * 1.6 - back * (1.5 + (i / 3) * 1.5) + Vector3(0, first.y, 0))
		racers.append({"name": BOT_NAMES[i], "node": bot, "lap": 0, "ring": 0, "done_at": -1.0, "player": false})
	_game.cam.follow(bee, first.y - 0.6)
	_build_hud()
	_paint_rings()


func _build_hud() -> void:
	var ui := _game.ui
	var s := ui.new_screen("Перегонки")
	ui.place_say(0.73, 0.82)
	var top := UiKit.panel(s, 0.03, 0.9, 0.97, 0.975, UiKit.SHADE)
	_ui["place"] = UiKit.label(top, "", 46, 0.03, 0, 0.32, 1, HORIZONTAL_ALIGNMENT_LEFT, UiKit.HONEY_BG, true)
	_ui["time"] = UiKit.label(top, "0:00", 60, 0.34, 0, 0.66, 1, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	_ui["lap"] = UiKit.label(top, "", 38, 0.66, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_RIGHT, Color.WHITE, true)
	var tag := UiKit.panel(s, 0.03, 0.845, 0.42, 0.89, UiKit.SHADE)
	_ui["arrow"] = UiKit.arrow(tag, 0.03, 0.1, 0.17, 0.9, UiKit.HONEY_BG)
	_ui["next"] = UiKit.label(tag, "", 32, 0.2, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)
	ui.view_button(s)
	UiKit.button(s, "Сдаться", 0.72, 0.845, 0.97, 0.89, UiKit.SHADE, Color.WHITE, func(): give_up(), 34)
	_ui["count"] = UiKit.label(s, "3", 220, 0.2, 0.45, 0.8, 0.65, HORIZONTAL_ALIGNMENT_CENTER, UiKit.HONEY_BG, true)
	_ui["board"] = UiKit.label(s, "", 30, 0.04, 0.03, 0.6, 0.2, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, false)


func _paint_rings() -> void:
	var me := racers[0]
	for i in rings.size():
		var is_next: bool = i == me["ring"]
		rings[i].material_override = Shape.mat(Palette.GOLD if is_next else Color(1, 1, 1), 0.3)
		rings[i].scale = Vector3.ONE * (1.15 if is_next else 0.9)


func _process(delta: float) -> void:
	if _ended:
		return
	elapsed += delta
	var pts := _world.race_rings
	var count_label: Label = _ui["count"]
	if elapsed < 0.0:
		count_label.text = str(ceili(-elapsed))
		return
	count_label.text = "Лети!" if elapsed < 1.0 else ""

	for r in racers:
		if r["done_at"] >= 0.0:
			continue
		var node: Node3D = r["node"]
		if not is_instance_valid(node):
			continue
		var target := pts[r["ring"]]
		if r["player"] == false:
			(node as RaceBot).target = target
		if node.global_position.distance_to(target) < RING_RADIUS + 0.2:
			r["ring"] += 1
			if r["ring"] >= pts.size():
				r["ring"] = 0
				r["lap"] += 1
				if r["lap"] >= LAPS:
					r["done_at"] = elapsed
					finish_order.append(r["name"])
			if r["player"]:
				_paint_rings()
				Game.vibrate(25)
				if r["lap"] == 1 and r["ring"] == 0:
					_game.say("Второй круг! Жми!", 2.0)

	_update_hud()
	var me := racers[0]
	if me["done_at"] >= 0.0 or elapsed > TIME_LIMIT:
		_finish()


func _progress(r: Dictionary) -> float:
	if r["done_at"] >= 0.0:
		return 1000.0 - r["done_at"]
	var pts := _world.race_rings
	var node: Node3D = r["node"]
	var d := node.global_position.distance_to(pts[r["ring"]]) if is_instance_valid(node) else 99.0
	return r["lap"] * 100.0 + r["ring"] * 10.0 - d * 0.1


func _standings() -> Array[Dictionary]:
	var arr := racers.duplicate()
	arr.sort_custom(func(a, b): return _progress(a) > _progress(b))
	var result: Array[Dictionary] = []
	result.assign(arr)
	return result


func _update_hud() -> void:
	var table := _standings()
	var place := 1
	for i in table.size():
		if table[i]["player"]:
			place = i + 1
	var me := racers[0]
	(_ui["place"] as Label).text = "Место %d/%d" % [place, racers.size()]
	(_ui["lap"] as Label).text = "Круг %d/%d" % [mini(me["lap"] + 1, LAPS), LAPS]
	var t := maxf(0.0, elapsed)
	(_ui["time"] as Label).text = "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
	var target := _world.race_rings[me["ring"]]
	var d := target - bee.global_position
	(_ui["next"] as Label).text = "Кольцо %d · %d м" % [me["ring"] + 1, roundi(Vector2(d.x, d.z).length())]
	_game.ui.point_arrow(_ui["arrow"], d)
	var lines := PackedStringArray()
	for i in table.size():
		lines.append("%d. %s" % [i + 1, table[i]["name"]])
	(_ui["board"] as Label).text = "\n".join(lines)


func give_up() -> void:
	_finish(true)


func _finish(gave_up := false) -> void:
	if _ended:
		return
	_ended = true
	var table := _standings()
	var place := table.size()
	for i in table.size():
		if table[i]["player"]:
			place = i + 1
	var me := racers[0]
	var finished: bool = me["done_at"] >= 0.0 and not gave_up
	var p := Profile.current()
	var record := false
	var honey := 0
	if finished:
		var best := float(p.race_best.get(_world.map_id, 0.0))
		record = best <= 0.0 or me["done_at"] < best
		if record:
			p.race_best[_world.map_id] = me["done_at"]
		if place == 1:
			p.race_wins += 1
		honey = [30, 20, 10, 5, 5, 5][place - 1]
	var titles := ["Первое место!", "Второе место", "Третье место", "Четвёртое место", "Пятое место", "Последнее место"]
	_game.say("Вот это скорость! Уважаю." if place == 1 else "Ничего, в следующий раз обгонишь.", 3.0)
	var body := "Карта: %s\nКругов: %d\nТвоё время: %s" % [_world.map_name(), LAPS,
		("%.1f с" % me["done_at"]) if finished else "не финишировал"]
	_game.end_mode({
		"title": titles[place - 1] if finished else "Гонка брошена",
		"big": "%d из %d" % [place, racers.size()] if finished else "—",
		"color": UiKit.DEEP_HONEY if place == 1 else UiKit.INK,
		"body": body,
		"record": "Рекорд карты!" if record else "",
		"honey": honey,
		"footer": "+%d мёда · побед: %d" % [honey, p.race_wins],
	})
	if is_instance_valid(bee):
		bee.queue_free()
