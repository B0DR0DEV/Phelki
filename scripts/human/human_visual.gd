class_name HumanVisual
extends Node3D
## Вид дачника: майка, шорты, шлёпанцы, панамка, усы и мухобойка.
## Бег, перекат, замах мухобойкой, вздрагивание от укуса, обморок.
## С каждым укусом голова и руки раздуваются и краснеют.

const SKIN := Color("d4845a")  # дачный загар
const TANK := Color("f7f4ec")
const SHORTS := Color("3f6fb5")
const SANDALS := Color("6b4a2e")
const SOCKS := Color("fbfbf7")
const PANAMA := Color("eadfc4")
const MOUSTACHE := Color("5a3b22")

var _human: Human
var _placeholder := false
var _mat: ShaderMaterial
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _run_phase := 0.0
var _roll_start := 0.0
var _roll_end := 0.0
var _swing_start := -10.0
var _flinch_start := -10.0
var _faint_start := -1.0
var _dust_at := 0.0


func build(human: Human) -> void:
	_human = human
	var scene := Shape.art("human")
	if scene:
		Shape.place_art(scene, self, Vector3.ZERO, 0.0, false)
		return
	_placeholder = true
	const S := Shape.SPHERE
	const B := Shape.BOX
	const C := Shape.CAPSULE

	# Ноги: голень, белые носки, сандалии — классика дачи
	_leg_l = Shape.node("Нога_Л", self, Vector3(-0.15, 0.88, 0))
	_leg_r = Shape.node("Нога_П", self, Vector3(0.15, 0.88, 0))
	for leg in [_leg_l, _leg_r]:
		Shape.make(C, leg, Vector3(0, -0.36, 0), Vector3(0.15, 0.34, 0.15), SKIN, false, "Нога", Vector3.ZERO, true)
		Shape.make(C, leg, Vector3(0, -0.72, 0.01), Vector3(0.155, 0.12, 0.155), SOCKS, false, "Носок")
		Shape.make(B, leg, Vector3(0, -0.85, 0.06), Vector3(0.17, 0.06, 0.32), SANDALS, false, "Сандалия")
		Shape.make(B, leg, Vector3(0, -0.78, 0.05), Vector3(0.18, 0.03, 0.05), SANDALS, false, "Ремешок")

	# Семейные шорты и майка-алкоголичка поверх пуза
	Shape.make(B, self, Vector3(0, 0.96, 0), Vector3(0.58, 0.32, 0.4), SHORTS, false, "Шорты")
	for k in 3:
		Shape.make(B, self, Vector3(-0.2 + k * 0.2, 0.96, 0.205), Vector3(0.06, 0.28, 0.01), Color("e8d36a"), false, "Узор")
	# Пузо вперёд — точёная майка-алкоголичка
	Shape.lathe(self, Vector3(0, 1.02, 0.06), [
		Vector2(0.0, 0.0), Vector2(0.3, 0.02), Vector2(0.38, 0.16), Vector2(0.39, 0.3),
		Vector2(0.33, 0.48), Vector2(0.28, 0.58), Vector2(0.0, 0.62)],
		[TANK, TANK, TANK, TANK, TANK, TANK, TANK], "Майка", Vector3.ZERO, 16, Vector2(1.0, 0.92))
	Shape.make(S, self, Vector3(0, 1.62, 0.02), Vector3(0.62, 0.24, 0.42), SKIN, false, "Плечи", Vector3.ZERO, true)
	Shape.make(S, self, Vector3(0, 1.5, 0.21), Vector3(0.28, 0.14, 0.06), SKIN, false, "Грудь", Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		Shape.make(B, self, Vector3(0.15 * side, 1.6, 0.2), Vector3(0.07, 0.24, 0.03), TANK, false, "Лямка")

	# Руки (шарнир в плече)
	_arm_l = Shape.node("Рука_Л", self, Vector3(-0.4, 1.62, 0))
	_arm_r = Shape.node("Рука_П", self, Vector3(0.4, 1.62, 0))
	for arm in [_arm_l, _arm_r]:
		Shape.make(C, arm, Vector3(0, -0.27, 0), Vector3(0.16, 0.3, 0.16), SKIN, false, "Рука", Vector3.ZERO, true)
		Shape.make(S, arm, Vector3(0, -0.6, 0.02), Vector3(0.19, 0.19, 0.19), SKIN, false, "Кисть", Vector3.ZERO, true)
	# Мухобойка в правой руке
	Shape.make(Shape.CYLINDER, _arm_r, Vector3(0, -0.62, 0.22), Vector3(0.035, 0.22, 0.035), Color("3c7fd1"), false, "Ручка", Vector3(90, 0, 0))
	Shape.make(B, _arm_r, Vector3(0, -0.62, 0.55), Vector3(0.26, 0.025, 0.24), Color("e53d3d"), false, "Хлопушка")

	# Голова: лицо, нос картошкой, усы, брови, уши, панамка
	_head = Shape.node("Голова", self, Vector3(0, 2.0, 0.04))
	Shape.make(S, _head, Vector3.ZERO, Vector3(0.56, 0.56, 0.52), SKIN, false, "Лицо", Vector3.ZERO, true)
	Shape.make(S, _head, Vector3(0, -0.02, 0.27), Vector3(0.17, 0.15, 0.15), Color("d9805a"), false, "Нос", Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		Shape.make(S, _head, Vector3(0.28 * side, 0.0, 0), Vector3(0.1, 0.15, 0.1), SKIN, false, "Ухо", Vector3.ZERO, true)
		Shape.make(S, _head, Vector3(0.11 * side, 0.08, 0.235), Vector3(0.07, 0.09, 0.04), Palette.INK, false, "Глаз")
		Shape.make(B, _head, Vector3(0.11 * side, 0.17, 0.23), Vector3(0.14, 0.035, 0.04), MOUSTACHE, false, "Бровь", Vector3(0, 0, 10 * side))
		Shape.make(C, _head, Vector3(0.09 * side, -0.11, 0.24), Vector3(0.07, 0.12, 0.07), MOUSTACHE, false, "Ус", Vector3(0, 0, 70 * side))
	Shape.lathe(_head, Vector3(0, 0.15, 0), [
		Vector2(0.0, 0.0), Vector2(0.44, 0.0), Vector2(0.45, 0.025), Vector2(0.3, 0.06), Vector2(0.28, 0.2), Vector2(0.19, 0.26), Vector2(0.0, 0.27)],
		[PANAMA, PANAMA, PANAMA, PANAMA, PANAMA, PANAMA, PANAMA], "Панамка", Vector3(-6, 0, 0), 16)

	# Свой материал на дачника: от укусов краснеет только кожа
	_mat = Shape.unique_mat()
	Shape.compact(self, _mat)


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

	# Отёк: голова и руки раздуваются, кожа краснеет
	var sw := _human.swelling
	_head.scale = Vector3.ONE * (1.0 + sw * 0.75)
	var fat := 1.0 + sw * 0.7
	_arm_l.scale = Vector3(fat, 1, fat)
	_arm_r.scale = Vector3(fat, 1, fat)
	if _mat:
		_mat.set_shader_parameter("flush", sw)

	# Пыль из-под сандалий
	if speed > 3.0 and Game.clock > _dust_at and _human.is_on_floor():
		_dust_at = Game.clock + 0.22
		Fx.dust(_human.global_position)
