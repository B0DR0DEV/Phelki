class_name HumanVisual
extends Node3D
## Вид дачника: майка, шорты, шлёпанцы, панамка, усы и мухобойка.
## Бег, перекат, замах мухобойкой, вздрагивание от укуса, обморок.
## С каждым укусом голова и руки раздуваются и краснеют.

const SKIN := Color(0.98, 0.80, 0.66)
const SWOLLEN := Color(0.95, 0.42, 0.40)
const TANK := Color(0.97, 0.97, 0.95)
const SHORTS := Color(0.20, 0.45, 0.80)
const SLIPPERS := Color(0.15, 0.65, 0.35)
const PANAMA := Color(0.86, 0.80, 0.60)

var _human: Human
var _placeholder := false
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _skin: Array[MeshInstance3D] = []
var _run_phase := 0.0
var _roll_start := 0.0
var _roll_end := 0.0
var _swing_start := -10.0
var _flinch_start := -10.0
var _faint_start := -1.0
var _skin_step := -1


func build(human: Human) -> void:
	_human = human
	var scene := Shape.art("human")
	if scene:
		Shape.place_art(scene, self, Vector3.ZERO, 0.0, false)
		return
	_placeholder = true

	# Ноги (шарнир в бедре)
	_leg_l = Shape.node("Нога_Л", self, Vector3(-0.15, 0.88, 0))
	_leg_r = Shape.node("Нога_П", self, Vector3(0.15, 0.88, 0))
	for leg in [_leg_l, _leg_r]:
		_skin.append(Shape.make(Shape.CYLINDER, leg, Vector3(0, -0.42, 0), Vector3(0.15, 0.4, 0.15), SKIN))
		Shape.make(Shape.BOX, leg, Vector3(0, -0.84, 0.06), Vector3(0.16, 0.05, 0.32), SLIPPERS, false, "Шлёпанец")

	# Шорты, майка, пузо
	Shape.make(Shape.BOX, self, Vector3(0, 0.98, 0), Vector3(0.52, 0.32, 0.34), SHORTS, false, "Шорты")
	Shape.make(Shape.CAPSULE, self, Vector3(0, 1.42, 0), Vector3(0.56, 0.36, 0.38), TANK, false, "Майка")
	Shape.make(Shape.SPHERE, self, Vector3(0, 1.28, 0.08), Vector3(0.52, 0.48, 0.42), TANK, false, "Пузо")

	# Руки (шарнир в плече)
	_arm_l = Shape.node("Рука_Л", self, Vector3(-0.36, 1.68, 0))
	_arm_r = Shape.node("Рука_П", self, Vector3(0.36, 1.68, 0))
	for arm in [_arm_l, _arm_r]:
		_skin.append(Shape.make(Shape.CYLINDER, arm, Vector3(0, -0.3, 0), Vector3(0.12, 0.3, 0.12), SKIN))

	# Мухобойка в правой руке
	Shape.make(Shape.CYLINDER, _arm_r, Vector3(0, -0.62, 0.18), Vector3(0.03, 0.22, 0.03), Palette.METAL, false, "Ручка", Vector3(90, 0, 0))
	Shape.make(Shape.BOX, _arm_r, Vector3(0, -0.62, 0.5), Vector3(0.24, 0.02, 0.24), Palette.RED, false, "Хлопушка")

	# Голова, нос, глаза, усы, панамка
	_head = Shape.node("Голова", self, Vector3(0, 1.98, 0))
	_skin.append(Shape.make(Shape.SPHERE, _head, Vector3.ZERO, Vector3(0.44, 0.46, 0.42), SKIN, false, "Лицо"))
	_skin.append(Shape.make(Shape.SPHERE, _head, Vector3(0, -0.02, 0.22), Vector3(0.11, 0.1, 0.1), SKIN, false, "Нос"))
	for side in [-1.0, 1.0]:
		Shape.make(Shape.SPHERE, _head, Vector3(0.09 * side, 0.06, 0.19), Vector3.ONE * 0.06, Palette.BLACK, false, "Глаз")
	Shape.make(Shape.BOX, _head, Vector3(0, -0.09, 0.2), Vector3(0.18, 0.035, 0.04), Color(0.35, 0.25, 0.15), false, "Усы")
	Shape.make(Shape.CYLINDER, _head, Vector3(0, 0.2, 0), Vector3(0.62, 0.02, 0.62), PANAMA, false, "Поля панамки")
	Shape.make(Shape.CYLINDER, _head, Vector3(0, 0.27, 0), Vector3(0.38, 0.08, 0.38), PANAMA, false, "Панамка")


func roll(duration: float) -> void:
	_roll_start = Game.clock
	_roll_end = Game.clock + duration


func swing() -> void:
	_swing_start = Game.clock


func flinch() -> void:
	_flinch_start = Game.clock


func faint() -> void:
	_faint_start = Game.clock


func _process(delta: float) -> void:
	if _human == null:
		return
	var t := Game.clock

	# Курс, перекат, обморок
	var b := Basis(Vector3.UP, _human.facing)
	if t < _roll_end:
		var k := inverse_lerp(_roll_start, _roll_end, t)
		b = b * Basis(Vector3.RIGHT, k * TAU)
	if _faint_start >= 0.0:
		var k := clampf((t - _faint_start) / 0.5, 0.0, 1.0)
		b = b * Basis(Vector3.RIGHT, deg_to_rad(-90.0 * smoothstep(0.0, 1.0, k)))
	basis = b

	# Вздрагивание от укуса
	var ft := t - _flinch_start
	position.y = sin(ft / 0.25 * PI) * 0.12 if ft < 0.25 else 0.0

	if not _placeholder:
		return

	# Бег
	var v := _human.velocity
	var speed := Vector2(v.x, v.z).length()
	_run_phase += speed * delta * 2.4
	var swing_deg := sin(_run_phase) * clampf(speed / 4.0, 0.0, 1.0) * 40.0
	_leg_l.rotation_degrees = Vector3(swing_deg, 0, 0)
	_leg_r.rotation_degrees = Vector3(-swing_deg, 0, 0)
	_arm_l.rotation_degrees = Vector3(-swing_deg * 0.8, 0, -8)

	# Замах мухобойкой поверх бега
	var st := t - _swing_start
	if st < 0.3:
		var k := st / 0.3
		var a := lerpf(0.0, -150.0, k / 0.35) if k < 0.35 else lerpf(-150.0, 40.0, (k - 0.35) / 0.65)
		_arm_r.rotation_degrees = Vector3(a, 0, 8)
	else:
		_arm_r.rotation_degrees = Vector3(swing_deg * 0.8, 0, 8)

	# Отёк
	var s := _human.swelling
	_head.scale = Vector3.ONE * (1.0 + s * 0.75)
	var fat := 1.0 + s * 0.7
	_arm_l.scale = Vector3(fat, 1, fat)
	_arm_r.scale = Vector3(fat, 1, fat)
	var step := roundi(s * 10.0)
	if step != _skin_step:
		_skin_step = step
		var m := Shape.mat(SKIN.lerp(SWOLLEN, step / 10.0))
		for mi in _skin:
			mi.material_override = m
