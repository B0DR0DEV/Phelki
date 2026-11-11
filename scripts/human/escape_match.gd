class_name EscapeMatch
extends Node3D
## Матч «дачники против пчёл» для любых составов:
##   ESCAPE   — ты дачник один против роя: 3 банки и к машине;
##   TEAM     — побег втроём: ты и два дачника-бота, 5 банок, пчёл больше;
##   SURVIVAL — выживание: банок нет, пчёлы прибывают волнами, держись сколько сможешь;
##   HUNT     — ты пчела: вместе с роем ловишь трёх дачников-ботов;
##   ONLINE   — сетевая охота: дачники и пчёлы — живые игроки, пустые места занимают боты.

enum Kind { ESCAPE, TEAM, SURVIVAL, HUNT, ONLINE }

const LENGTH := 180.0
const CAR_START_SECONDS := 3.5
const CAR_RADIUS := 2.6
const ESCAPE_RADIUS := 7.0  # дачники рядом с машиной уезжают вместе
const ATTACKERS_PER_HUMAN := 3
const BEE_STING_COOLDOWN := 1.2


class Stats:
	var kind := 0
	var jars := 0
	var jars_needed := 3
	var stings := 0
	var swats := 0
	var smokes := 0
	var dodges := 0
	var time := 0.0
	var escaped := false
	var ending := ""  # escaped / ambulance / timeout / gaveup
	var player_is_bee := false
	var stings_dealt := 0
	var humans_total := 1
	var humans_fainted := 0
	var humans_escaped := 0


var kind: int = Kind.ESCAPE
var human: Human  # дачник этого игрока (если он за людей)
var humans: Array[Human] = []
var player_bee: Bee  # пчела этого игрока (если он за пчёл)
var player_bees: Array[Bee] = []  # все пчёлы-игроки
var bots: Array[BeeBot] = []
var stats := Stats.new()
var time_left := LENGTH
var car_progress := 0.0
var peer_entities := {}  # онлайн: id игрока → его дачник или пчела

var _world: World
var _jars: Array[HoneyJar] = []
var _end_at := -1.0
var _sting_say_at := 0.0
var _car_said := false
var _next_wave := 0.0
var _wave := 0


## roster (только для ONLINE): {"humans": [id...], "bees": [id...], "fill_humans": N}
static func begin(world: World, parent: Node, match_kind := Kind.ESCAPE, roster := {}) -> EscapeMatch:
	var m := EscapeMatch.new()
	m.name = "Побег"
	m.kind = match_kind
	parent.add_child(m)
	m._setup(world, roster)
	return m


func all_jars() -> bool:
	return stats.jars >= stats.jars_needed


func ending() -> bool:
	return _end_at >= 0.0


func is_local(h: Human) -> bool:
	return h != null and h == human


func active_humans() -> Array[Human]:
	var result: Array[Human] = []
	for h in humans:
		if is_instance_valid(h) and not h.frozen and h.visible:
			result.append(h)
	return result


func nearest_human(pos: Vector3) -> Human:
	var best: Human = null
	var best_d := INF
	for h in active_humans():
		var d := h.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = h
	return best


func _setup(world: World, roster: Dictionary) -> void:
	_world = world
	stats.kind = kind
	var jar_count := 3
	var bot_count := 12
	var local_humans := 0
	var bot_humans := 0
	match kind:
		Kind.ESCAPE:
			local_humans = 1
		Kind.TEAM:
			local_humans = 1
			bot_humans = 2
			jar_count = 5
			bot_count = 16
		Kind.SURVIVAL:
			local_humans = 1
			jar_count = 0
			bot_count = 6
			_next_wave = Game.clock + 20.0
		Kind.HUNT:
			bot_humans = 3
			jar_count = 6
			bot_count = 14
		Kind.ONLINE:
			bot_humans = int(roster.get("fill_humans", 0))

	# Дачники
	var slot := 0
	for i in local_humans:
		human = _spawn_human(slot, false)
		slot += 1
	for peer in roster.get("humans", []):
		peer_entities[peer] = _spawn_human(slot, false, false)
		slot += 1
	for i in bot_humans:
		_spawn_human(slot, true)
		slot += 1
	stats.humans_total = humans.size()

	# Пчёлы-игроки
	if kind == Kind.HUNT:
		player_bee = Bee.spawn(self, world.bee_spawn)
		player_bees.append(player_bee)
		stats.player_is_bee = true
	for peer in roster.get("bees", []):
		var b := Bee.spawn(self, world.bee_spawn + Vector3(randf_range(-2, 2), 0, randf_range(-1, 1)))
		b.local_control = false
		player_bees.append(b)
		peer_entities[peer] = b
	if kind == Kind.ONLINE:
		jar_count = clampi(2 + humans.size(), 3, 6)
		bot_count = maxi(6, 16 - player_bees.size())

	# Банки — в случайных местах из списка карты
	var spots := world.jar_spots.duplicate()
	spots.shuffle()
	for i in mini(jar_count, spots.size()):
		_jars.append(HoneyJar.spawn(self, spots[i]))
	stats.jars_needed = _jars.size()

	# Рой вылетает из улья не сразу — у дачников есть фора
	for i in bot_count:
		_spawn_bot(i * 360.0 / bot_count, randf_range(3.0, 6.0))


func _spawn_human(slot: int, as_bot: bool, local := true) -> Human:
	var offset := Vector3((slot % 3 - 1) * 1.4, 0, -(slot / 3) * 1.4)
	var h := Human.spawn(self, _world.escape_spawn + offset)
	h.local_control = local and not as_bot
	if as_bot:
		var brain := HumanBot.new()
		brain.name = "Мозг"
		h.add_child(brain)
	humans.append(h)
	return h


func _spawn_bot(angle_deg: float, wake: float) -> void:
	var pos := _world.hive_position + Basis(Vector3.UP, deg_to_rad(angle_deg)) * Vector3(0, 0, 2) + Vector3(0, 2, 0)
	bots.append(BeeBot.spawn(self, pos, angle_deg, wake))


## Куда бежать этому дачнику: ближайшая банка, а когда все собраны — к машине.
func target_for(h: Human) -> Dictionary:
	if h == null or stats.jars_needed == 0:
		return {}
	if all_jars():
		return {"pos": _world.car_door.global_position, "label": "Машина"}
	var best := INF
	var result := {}
	for j in _jars:
		if not is_instance_valid(j):
			continue
		var d := j.global_position.distance_squared_to(h.global_position)
		if d < best:
			best = d
			result = {"pos": j.global_position, "label": "Банка"}
	return result


## Цель для указателя игрока: за дачника — банка/машина, за пчелу — ближайший дачник.
func target() -> Dictionary:
	if human:
		return target_for(human)
	if is_instance_valid(player_bee):
		var h := nearest_human(player_bee.global_position)
		if h:
			return {"pos": h.global_position, "label": "Дачник"}
	return {}


func _physics_process(_delta: float) -> void:
	if ending():
		return
	var alive := active_humans()
	if alive.is_empty():
		return

	# Право атаки — самым близким бодрым ботам, остальные кружат рядом и ждут
	var limit := ATTACKERS_PER_HUMAN * alive.size() + (_wave if kind == Kind.SURVIVAL else 0)
	var candidates: Array[BeeBot] = []
	for bot in bots:
		if is_instance_valid(bot) and not bot.disabled() and bot.awake():
			candidates.append(bot)
			bot.attacking = false
	candidates.sort_custom(func(x: BeeBot, y: BeeBot):
		return _dist_to_humans(x.global_position) < _dist_to_humans(y.global_position))
	for i in mini(limit, candidates.size()):
		candidates[i].attacking = true

	# Пчёлы-игроки жалят, врезаясь в дачника
	for pb in player_bees:
		if not is_instance_valid(pb) or Game.clock < pb.sting_ready_at:
			continue
		for h in alive:
			var chest := h.global_position + Vector3(0, 1.3, 0)
			if chest.distance_to(pb.global_position) > 1.0:
				continue
			if h.try_sting():
				pb.sting_ready_at = Game.clock + BEE_STING_COOLDOWN
				var away := pb.global_position - h.global_position
				away.y = 0.0
				pb.knock(away.normalized() * 6.0, 0.25)
				if pb == player_bee:
					stats.stings_dealt += 1
					Game.I.toast("Ужалила!")
					Game.vibrate(40)
			break


func _dist_to_humans(pos: Vector3) -> float:
	var h := nearest_human(pos)
	return h.global_position.distance_squared_to(pos) if h else INF


func _process(delta: float) -> void:
	var game := Game.I
	if ending():
		if stats.escaped:
			_world.drive_car(delta)
		if Game.clock >= _end_at:
			game.end_escape()
		return

	time_left -= delta
	stats.time += delta
	if time_left <= 0.0:
		_finish("timeout")
		return

	# Выживание: каждые 20 секунд прилетает новая волна
	if kind == Kind.SURVIVAL:
		time_left = LENGTH  # в выживании нет таймера — держись сколько сможешь
		if Game.clock >= _next_wave:
			_wave += 1
			_next_wave = Game.clock + 20.0
			for i in 2 + _wave:
				_spawn_bot(randf() * 360.0, 0.5)
			game.toast("Волна %d — пчёл больше!" % _wave)
			game.say("Ещё летят! Держись!", 2.0)

	# Машина: кто-то стоит у двери со всеми банками — заводится
	if stats.jars_needed == 0:
		return
	var at_car := false
	if all_jars():
		for h in active_humans():
			var d := h.global_position - _world.car_door.global_position
			d.y = 0.0
			if d.length() < CAR_RADIUS:
				at_car = true
				break
	if at_car:
		if not _car_said:
			_car_said = true
			game.say(Lines.pick(Lines.CAR_STARTING))
		car_progress = move_toward(car_progress, 1.0, delta / CAR_START_SECONDS)
		if car_progress >= 1.0:
			for h in active_humans():
				if h.global_position.distance_to(_world.car_door.global_position) < ESCAPE_RADIUS:
					h.visible = false  # сел в машину
					stats.humans_escaped += 1
			_finish("escaped")
	else:
		car_progress = move_toward(car_progress, 0.0, delta * 0.5)


func on_stung(h: Human) -> void:
	if ending():
		return
	if is_local(h):
		stats.stings += 1
	if Game.clock > _sting_say_at and randf() < 0.4:
		_sting_say_at = Game.clock + 4.0
		Game.I.say(Lines.pick(Lines.STUNG), 2.0)
	if h.swelling >= 1.0:
		h.frozen = true
		h.faint()
		stats.humans_fainted += 1
		if active_humans().is_empty() or (is_local(h) and kind != Kind.TEAM):
			_finish("ambulance")
		else:
			Game.I.toast("Одного дачника увезла скорая!")


func on_jar_taken(jar: HoneyJar) -> void:
	if ending():
		return
	_jars.erase(jar)
	stats.jars += 1
	Game.I.toast("Банка %d/%d" % [stats.jars, stats.jars_needed])
	Game.I.say(Lines.pick(Lines.ALL_JARS if all_jars() else Lines.JAR_TAKEN))


## Досрочно (кнопка «Сдаться»).
func give_up() -> void:
	_finish("gaveup")


func _finish(how: String) -> void:
	if ending():
		return
	stats.ending = how
	stats.escaped = how == "escaped"
	for h in humans:
		if is_instance_valid(h):
			h.frozen = true
	var game := Game.I
	match how:
		"escaped":
			game.say(Lines.pick(Lines.ESCAPED), 3.0)
			_end_at = Game.clock + 2.4
		"ambulance":
			if is_instance_valid(human) and not human.visible:
				pass
			elif is_instance_valid(human):
				human.faint()
			game.say(Lines.pick(Lines.AMBULANCE), 3.0)
			_end_at = Game.clock + 2.0
		"gaveup":
			_end_at = Game.clock
		_:
			game.say(Lines.pick(Lines.ESCAPE_TIMEOUT), 3.0)
			_end_at = Game.clock + 1.5
