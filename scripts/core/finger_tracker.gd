class_name FingerTracker
extends Node
## Одно касание (или мышь на компьютере). Касание, начатое на кнопке
## интерфейса, сюда не попадает — кнопки забирают его себе.
## poll() раз в кадр возвращает направление быстрого свайпа (или ноль).

var active := true
var pressed := false
var position := Vector2.ZERO

## Для автотеста: если задано — «палец» держит эту точку мира.
var debug_world_target = null

var _samples: Array = []  # [время, позиция]
var _swipe_used := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active:
			pressed = true
			position = event.position
			_samples.clear()
			_swipe_used = false
		elif not event.pressed:
			pressed = false


func poll() -> Vector2:
	if not active or (pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		pressed = false
	if not pressed:
		_samples.clear()
		_swipe_used = false
		return Vector2.ZERO

	position = get_viewport().get_mouse_position()
	var t := Game.clock
	_samples.append([t, position])
	while _samples.size() > 0 and t - float(_samples[0][0]) > 0.12:
		_samples.pop_front()
	if _swipe_used or _samples.size() < 2:
		return Vector2.ZERO
	var dt := t - float(_samples[0][0])
	if dt <= 0.02:
		return Vector2.ZERO
	var v: Vector2 = (position - (_samples[0][1] as Vector2)) / dt
	if v.length() < get_viewport().get_visible_rect().size.y * 2.4:
		return Vector2.ZERO
	_swipe_used = true
	return v.normalized()


## Палец удерживается (или автотест ведёт к точке).
func is_held() -> bool:
	return pressed or debug_world_target != null


## Точка под пальцем на горизонтальной плоскости высоты height.
func world_point(height: float):
	if debug_world_target != null:
		return debug_world_target
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from := cam.project_ray_origin(position)
	var dir := cam.project_ray_normal(position)
	return Plane(Vector3.UP, height).intersects_ray(from, dir)


## Направление свайпа на экране → направление по земле (экранный Y смотрит вниз).
static func screen_dir_to_world(cam: Camera3D, dir: Vector2) -> Vector3:
	if cam == null:
		return Vector3.ZERO
	var right := cam.global_basis.x
	right.y = 0.0
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var d := right.normalized() * dir.x + fwd.normalized() * (-dir.y)
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO
