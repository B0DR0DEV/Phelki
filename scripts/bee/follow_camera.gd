class_name FollowCamera
extends Camera3D
## Камера. В меню медленно облетает пасеку (живое 3D-меню),
## в игре смотрит сверху под углом и не поворачивается —
## чтобы управление пальцем всегда было одинаковым.

const OFFSET := Vector3(0.0, 11.5, -8.5)
const SMOOTH := 0.18

var _world: World
var _target: Node3D
var _hub := true
var _orbit := -20.0
var _base_height := 1.5
var _shake := 0.0
var _vel := Vector3.ZERO


func setup(world: World) -> void:
	_world = world
	fov = 50.0
	near = 0.2
	far = 220.0
	current = true
	position = world.hive_position + Vector3(0, 4.2, -9.0)
	show_hub()


func show_hub() -> void:
	_hub = true
	_target = null


## base_height — обычная высота цели над землёй (пчела ~1.5, человек ~0.9).
func follow(target: Node3D, base_height := 1.5) -> void:
	_hub = false
	_target = target
	_base_height = base_height
	_vel = Vector3.ZERO
	global_position = _goal()
	_look_fixed()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _goal() -> Vector3:
	var g := _target.global_position + OFFSET
	g.y = OFFSET.y + _base_height  # не прыгаем по высоте, когда пчела ныряет к цветку
	return g


func _look_fixed() -> void:
	# Смотрим вдоль +Z под постоянным углом
	look_at(global_position + Vector3(0.0, -OFFSET.y, -OFFSET.z), Vector3.UP)


func _process(delta: float) -> void:
	if _hub or not is_instance_valid(_target):
		var center := _world.hive_position if _world else Vector3.ZERO
		_orbit += 6.0 * delta
		var desired := center + Basis(Vector3.UP, deg_to_rad(_orbit)) * Vector3(0.0, 4.2, -9.0)
		global_position = global_position.lerp(desired, clampf(2.0 * delta, 0.0, 1.0))
		var look := center + Vector3.UP * 1.6
		if global_position.distance_to(look) > 0.1:
			var want := global_transform.looking_at(look, Vector3.UP)
			global_basis = global_basis.slerp(want.basis, clampf(3.0 * delta, 0.0, 1.0))
		return

	if Game.I and Game.I.fpv:
		_first_person(delta)
		return

	# Плавное следование (критически затухающая пружина)
	var goal := _goal()
	var omega := 2.0 / SMOOTH
	var x := omega * delta
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := global_position - goal
	var temp := (_vel + change * omega) * delta
	_vel = (_vel - temp * omega) * e
	global_position = goal + (change + temp) * e

	if _shake > 0.0:
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.3
		_shake = move_toward(_shake, 0.0, delta * 1.5)
	_look_fixed()


## Вид от первого лица: камера в голове персонажа, смотрит по его курсу.
func _first_person(delta: float) -> void:
	var yaw := 0.0
	var eye := Vector3.ZERO
	var ahead := 0.45
	if _target is Bee:
		yaw = (_target as Bee).heading
		eye = Vector3(0, 0.3, 0)
		ahead = 1.1  # впереди головы, чтобы не смотреть изнутри глаза
	elif _target is Human:
		yaw = (_target as Human).facing
		eye = Vector3(0, 1.85, 0)
		ahead = 0.55
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	var want := _target.global_position + eye + dir * ahead
	global_position = global_position.lerp(want, clampf(18.0 * delta, 0.0, 1.0))
	var want_basis := Basis.looking_at(dir + Vector3(0, -0.12, 0), Vector3.UP)
	global_basis = global_basis.slerp(want_basis, clampf(10.0 * delta, 0.0, 1.0))
	if _shake > 0.0:
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.1
		_shake = move_toward(_shake, 0.0, delta * 1.5)
