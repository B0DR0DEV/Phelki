class_name EscapeMatch
extends Node3D
## Матч «Побег» за людей против пчёл-ботов (часть 1, без сети).
## Цель: утащить 3 банки мёда, добежать до машины и продержаться
## у двери, пока она заводится. Пчёлы жалят — отёк растёт.

const LENGTH := 180.0
const CAR_START_SECONDS := 3.5
const CAR_RADIUS := 2.6
const BOT_COUNT := 12
const MAX_ATTACKERS := 3  # одновременно жалят не больше стольких пчёл


class Stats:
	var jars := 0
	var jars_needed := 3
	var stings := 0
	var swats := 0
	var smokes := 0
	var dodges := 0
	var time := 0.0
	var escaped := false
	var ending := ""  # escaped / ambulance / timeout / gaveup


var human: Human
var bots: Array[BeeBot] = []
var stats := Stats.new()
var time_left := LENGTH
var car_progress := 0.0

var _world: World
var _jars: Array[HoneyJar] = []
var _end_at := -1.0
var _sting_say_at := 0.0
var _car_said := false


static func begin(world: World, parent: Node) -> EscapeMatch:
	var m := EscapeMatch.new()
	m.name = "Побег"
	parent.add_child(m)
	m._setup(world)
	return m


func all_jars() -> bool:
	return stats.jars >= stats.jars_needed


func ending() -> bool:
	return _end_at >= 0.0


func _setup(world: World) -> void:
	_world = world
	human = Human.spawn(self, world.escape_spawn)

	# Банки — в 3 случайных местах из списка
	var spots := world.jar_spots.duplicate()
	spots.shuffle()
	for i in mini(stats.jars_needed, spots.size()):
		_jars.append(HoneyJar.spawn(self, spots[i]))
	stats.jars_needed = _jars.size()

	# Рой вылетает из улья не сразу — у дачника пара секунд форы
	for i in BOT_COUNT:
		var a := i * 360.0 / BOT_COUNT
		var pos := world.hive_position + Basis(Vector3.UP, deg_to_rad(a)) * Vector3(0, 0, 2) + Vector3(0, 2, 0)
		bots.append(BeeBot.spawn(self, pos, a, randf_range(3.0, 6.0)))


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

	# Машина: стоишь у двери со всеми банками — заводится
	var at_car := false
	if all_jars():
		var d := human.global_position - _world.car_door.global_position
		d.y = 0.0
		at_car = d.length() < CAR_RADIUS
	if at_car:
		if not _car_said:
			_car_said = true
			game.say(Lines.pick(Lines.CAR_STARTING))
		car_progress = move_toward(car_progress, 1.0, delta / CAR_START_SECONDS)
		if car_progress >= 1.0:
			_finish("escaped")
	else:
		car_progress = move_toward(car_progress, 0.0, delta * 0.5)


## Раздаём «право атаки» самым близким бодрым пчёлам, остальные ждут вокруг.
func _physics_process(_delta: float) -> void:
	if human == null:
		return
	var candidates: Array[BeeBot] = []
	for bot in bots:
		if is_instance_valid(bot) and not bot.disabled() and bot.awake():
			candidates.append(bot)
			bot.attacking = false
	var hp := human.global_position
	candidates.sort_custom(func(x: BeeBot, y: BeeBot): return x.global_position.distance_squared_to(hp) < y.global_position.distance_squared_to(hp))
	for i in mini(MAX_ATTACKERS, candidates.size()):
		candidates[i].attacking = true


func on_stung(h: Human) -> void:
	if ending():
		return
	stats.stings += 1
	if Game.clock > _sting_say_at and randf() < 0.4:
		_sting_say_at = Game.clock + 4.0
		Game.I.say(Lines.pick(Lines.STUNG), 2.0)
	if h.swelling >= 1.0:
		_finish("ambulance")


func on_jar_taken(jar: HoneyJar) -> void:
	if ending():
		return
	_jars.erase(jar)
	stats.jars += 1
	Game.I.toast("Банка %d/%d" % [stats.jars, stats.jars_needed])
	Game.I.say(Lines.pick(Lines.ALL_JARS if all_jars() else Lines.JAR_TAKEN))


## Куда бежать: ближайшая банка, а когда все собраны — к машине. {pos, label} или пусто.
func target() -> Dictionary:
	if human == null:
		return {}
	if all_jars():
		return {"pos": _world.car_door.global_position, "label": "Машина"}
	var best := INF
	var result := {}
	for j in _jars:
		if not is_instance_valid(j):
			continue
		var d := j.global_position.distance_squared_to(human.global_position)
		if d < best:
			best = d
			result = {"pos": j.global_position, "label": "Банка"}
	return result


func _finish(how: String) -> void:
	if ending():
		return
	stats.ending = how
	stats.escaped = how == "escaped"
	human.frozen = true
	var game := Game.I
	match how:
		"escaped":
			human.visible = false  # сел в машину
			game.say(Lines.pick(Lines.ESCAPED), 3.0)
			_end_at = Game.clock + 2.4
		"ambulance":
			human.faint()
			game.say(Lines.pick(Lines.AMBULANCE), 3.0)
			_end_at = Game.clock + 2.0
		_:
			game.say(Lines.pick(Lines.ESCAPE_TIMEOUT), 3.0)
			_end_at = Game.clock + 1.5
