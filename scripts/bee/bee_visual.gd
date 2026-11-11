class_name BeeVisual
extends Node3D
## Как пчела выглядит в движении: поворот по курсу, крен в виражах,
## кувырок при ударе, толстеет от пыльцы, вытягивается в рывке, машет крыльями.

const TUMBLE_TIME := 0.6

var _bee: Bee
var _wings: Array[Node3D] = []
var _last_horiz := Vector3.ZERO
var _yaw := 0.0
var _roll := 0.0
var _tumble_until := 0.0
var _dash_pulse := 0.0


func bind(bee: Bee) -> void:
	_bee = bee
	_wings = find_wings(self)


static func find_wings(root: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for n in root.find_children("Крыло*", "Node3D", true, false):
		result.append(n as Node3D)
	return result


static func flap_wings(wings: Array[Node3D], speed: float, t: float) -> void:
	var flap := sin(t * speed) * 50.0
	for w in wings:
		var side := 1.0 if w.position.x >= 0.0 else -1.0
		w.rotation_degrees = Vector3(0.0, side * -15.0, side * flap)


func tumble() -> void:
	_tumble_until = Game.clock + TUMBLE_TIME


func dash() -> void:
	_dash_pulse = 1.0


func _process(delta: float) -> void:
	if _bee == null:
		return
	var dt := maxf(delta, 0.0001)
	var v := _bee.velocity
	var h := Vector3(v.x, 0.0, v.z)
	if h.length_squared() > 0.3:
		_yaw = lerp_angle(_yaw, atan2(h.x, h.z), 10.0 * dt)

	var accel := (h - _last_horiz) / dt
	_last_horiz = h
	var right := Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	var lateral := accel.dot(right)
	_roll = lerpf(_roll, clampf(-lateral * 1.5, -35.0, 35.0), 6.0 * dt)
	var pitch := clampf(h.length() * 2.2, 0.0, 22.0)

	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), _yaw, deg_to_rad(_roll)))
	if Game.clock < _tumble_until:
		var k := 1.0 - (_tumble_until - Game.clock) / TUMBLE_TIME
		b = b * Basis.from_euler(Vector3(deg_to_rad(k * 360.0), 0.0, deg_to_rad(k * 200.0)))
	if _bee.is_stuck():
		b = b * Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(sin(Game.clock * 25.0) * 12.0)))

	_dash_pulse = move_toward(_dash_pulse, 0.0, dt * 3.0)
	var fat := 1.0 + _bee.load_fraction() * 0.35
	var squeeze := 1.0 - _dash_pulse * 0.2
	var s := Vector3(fat * squeeze, fat * squeeze, 1.0 + _dash_pulse * 0.35)
	global_basis = b * Basis.from_scale(s)

	flap_wings(_wings, 12.0 if _bee.is_stuck() else 55.0, Game.clock)


## Временная пчела (или оса-гопник) из простых форм. Смотрит вперёд по +Z.
## Заменяется моделью res://art/bee.glb (или wasp.glb).
static func build_placeholder(root: Node3D, wasp: bool) -> void:
	var body_color := Color(0.98, 0.76, 0.08) if wasp else Palette.BEE_YELLOW
	var dark := Palette.BLACK
	var thorax_color := dark if wasp else Color(0.30, 0.20, 0.10)

	# Брюшко с полосками
	var ab := Vector3(0.38, 0.36, 0.62) if wasp else Vector3(0.5, 0.46, 0.68)
	Shape.make(Shape.SPHERE, root, Vector3(0, 0, -0.12), ab, body_color, false, "Брюшко")
	Shape.make(Shape.CYLINDER, root, Vector3(0, 0, -0.04), Vector3(ab.x, 0.035, ab.y), dark, false, "Полоска", Vector3(90, 0, 0))
	Shape.make(Shape.CYLINDER, root, Vector3(0, 0, -0.20), Vector3(ab.x * 0.93, 0.035, ab.y * 0.93), dark, false, "Полоска", Vector3(90, 0, 0))
	Shape.make(Shape.CYLINDER, root, Vector3(0, 0, -0.33), Vector3(ab.x * 0.72, 0.03, ab.y * 0.72), dark, false, "Полоска", Vector3(90, 0, 0))

	# Грудь, голова, жало
	Shape.make(Shape.SPHERE, root, Vector3(0, 0.02, 0.2), Vector3(0.36, 0.34, 0.34), thorax_color, false, "Грудь")
	Shape.make(Shape.SPHERE, root, Vector3(0, 0.05, 0.42), Vector3(0.3, 0.28, 0.26), dark, false, "Голова")
	Shape.make(Shape.CAPSULE, root, Vector3(0, -0.02, -0.5), Vector3(0.05, 0.07, 0.05), dark, false, "Жало", Vector3(90, 0, 0))

	# Глаза
	var pupil := Palette.RED if wasp else dark
	var eye := 0.09 if wasp else 0.12
	for side in [-1.0, 1.0]:
		Shape.make(Shape.SPHERE, root, Vector3(0.08 * side, 0.1, 0.53), Vector3.ONE * eye, Palette.WHITE, false, "Глаз")
		Shape.make(Shape.SPHERE, root, Vector3(0.085 * side, 0.1, 0.585), Vector3.ONE * 0.055, pupil, false, "Зрачок")
		Shape.make(Shape.CYLINDER, root, Vector3(0.06 * side, 0.22, 0.47), Vector3(0.02, 0.1, 0.02), dark, false, "Усик",
			Vector3(-30, 0, -20 * side))

	# Крылья на шарнирах (машут вокруг плеча)
	for side in [-1.0, 1.0]:
		var pivot := Shape.node("Крыло_Л" if side < 0 else "Крыло_П", root, Vector3(0.12 * side, 0.2, 0.15))
		Shape.make(Shape.SPHERE, pivot, Vector3(0.22 * side, 0.02, -0.05), Vector3(0.42, 0.02, 0.24), Palette.WING, false, "Перепонка")

	if not wasp:
		return

	# Оса-гопник: кепка и злые брови
	var cap := Color(0.22, 0.22, 0.25)
	Shape.make(Shape.CYLINDER, root, Vector3(0, 0.2, 0.42), Vector3(0.26, 0.03, 0.26), cap, false, "Кепка")
	Shape.make(Shape.BOX, root, Vector3(0, 0.19, 0.56), Vector3(0.2, 0.02, 0.12), cap, false, "Козырёк")
	for side in [-1.0, 1.0]:
		Shape.make(Shape.BOX, root, Vector3(0.08 * side, 0.165, 0.57), Vector3(0.1, 0.02, 0.02), dark, false, "Бровь",
			Vector3(0, 0, 20 * side))
