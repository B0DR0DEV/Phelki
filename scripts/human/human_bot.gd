class_name HumanBot
extends Node
## «Мозг» дачника-бота: бежит за банками и к машине, отмахивается мухобойкой,
## пускает дым, когда окружили, делает перекаты от ближайшей пчелы.
## Нужен для побега втроём, охоты за пчелу и чтобы занимать пустые места в онлайне.

var _h: Human
var _next_think := 0.0
var _wander := Vector3.ZERO
var _wander_until := 0.0


func _ready() -> void:
	_h = get_parent() as Human
	_next_think = Game.clock + randf() * 0.3


func _physics_process(_delta: float) -> void:
	var game := Game.I
	var m := game.escape if game else null
	if m == null or _h == null or _h.frozen or m.ending() or Game.clock < _next_think:
		return
	_next_think = Game.clock + 0.25

	# Угрозы рядом
	var near := 0
	var closest: Node3D = null
	var closest_d := INF
	var threats: Array = []
	threats.append_array(m.bots)
	threats.append_array(m.player_bees)
	for t in threats:
		if not is_instance_valid(t):
			continue
		if t is BeeBot and (t as BeeBot).disabled():
			continue
		var d: float = t.global_position.distance_to(_h.global_position)
		if d < 2.6:
			near += 1
			if d < closest_d:
				closest_d = d
				closest = t

	# Куда бежать
	var tgt := m.target_for(_h)
	var goal: Vector3
	if tgt.is_empty():
		# Выживание: бегаем от пчёл, меняя направление
		if Game.clock > _wander_until or _h.global_position.distance_to(_wander) < 2.0:
			_wander = game.world.random_open_point()
			_wander_until = Game.clock + 5.0
		goal = _wander
	else:
		goal = tgt["pos"]
	_h.debug_steer(goal)

	if closest == null:
		return
	if closest_d < 2.0 and _h.swat_ready_in() <= 0.0:
		_h.facing = atan2(closest.global_position.x - _h.global_position.x, closest.global_position.z - _h.global_position.z)
		_h.swat()
	if near >= 3 and _h.smoke_ready_in() <= 0.0:
		_h.smoke()
	elif randf() < 0.35:
		var away := _h.global_position - closest.global_position
		away.y = 0.0
		var to_goal := goal - _h.global_position
		to_goal.y = 0.0
		_h.dodge((away.normalized() + to_goal.normalized()).normalized())
