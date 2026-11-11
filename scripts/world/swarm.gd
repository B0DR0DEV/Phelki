class_name Swarm
extends Node3D
## Рой вокруг улья для живого меню. Если игрок ответил «Нет»,
## все пчёлы разворачиваются и зависают прямо перед камерой.

var angry := false
var _center := Vector3.ZERO
var _members: Array[Dictionary] = []


static func build(parent: Node3D, center: Vector3, count: int) -> Swarm:
	var s := Swarm.new()
	s.name = "Рой"
	s._center = center
	var scene := Shape.art("bee")
	for i in count:
		var m := WingFlap.new()
		m.name = "Пчела роя"
		m.speed = randf_range(45.0, 60.0)
		if scene:
			Shape.place_art(scene, m, Vector3.ZERO, 0.0, false)
		else:
			BeeVisual.build_placeholder(m, false)
		m.position = center
		s.add_child(m)
		var dir_sign := 1.0 if randf() > 0.5 else -1.0
		s._members.append({
			"node": m,
			"scale": randf_range(0.45, 0.6),
			"phase": randf() * TAU,
			"radius": randf_range(1.6, 3.8),
			"height": randf_range(1.4, 3.2),
			"speed": randf_range(0.5, 1.1) * dir_sign,
			"angry_offset": Vector3(randf_range(-1.6, 1.6), randf_range(-1.2, 1.2), randf_range(-0.4, 0.6)),
		})
	parent.add_child(s)
	return s


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var game := Game.I
	var is_angry := angry and cam != null and Profile.current().side == Profile.Side.HUMAN \
		and game != null and game.state != Game.State.SORTIE
	var t := Game.clock

	for m in _members:
		var n: Node3D = m["node"]
		var target: Vector3
		var look_dir: Vector3
		if is_angry:
			var cb := cam.global_basis
			var off: Vector3 = m["angry_offset"]
			target = cam.global_position - cb.z * (4.5 + off.z) + cb.x * off.x + cb.y * off.y
			target.y += sin(t * 7.0 + float(m["phase"])) * 0.08
			look_dir = cam.global_position - n.global_position
			n.global_position = n.global_position.lerp(target, clampf(3.0 * delta, 0.0, 1.0))
		else:
			var a := t * float(m["speed"]) + float(m["phase"])
			var r: float = m["radius"]
			target = _center + Vector3(cos(a) * r, float(m["height"]) + sin(t * 2.0 + float(m["phase"])) * 0.2, sin(a) * r)
			look_dir = Vector3(-sin(a), 0.0, cos(a)) * signf(float(m["speed"]))
			n.global_position = n.global_position.lerp(target, clampf(4.0 * delta, 0.0, 1.0))
		if look_dir.length_squared() > 0.001:
			var yaw := atan2(look_dir.x, look_dir.z)
			var pitch := -atan2(look_dir.y, Vector2(look_dir.x, look_dir.z).length())
			var want := Basis.from_euler(Vector3(pitch, yaw, 0.0)).get_rotation_quaternion()
			var have := n.basis.get_rotation_quaternion()
			var q := have.slerp(want, clampf(6.0 * delta, 0.0, 1.0))
			n.basis = Basis(q) * Basis.from_scale(Vector3.ONE * float(m["scale"]))
