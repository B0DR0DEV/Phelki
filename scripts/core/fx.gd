class_name Fx
extends RefCounted
## Частицы: искры золотого цветка, облачко пыльцы, брызги мёда у улья,
## звёздочки от удара, пыль из-под шлёпанцев, пух дыма.
## Всё на CPUParticles3D — работает и на слабых телефонах, и в браузере.

static var _mats := {}


static func _dot_mat(unshaded := true) -> StandardMaterial3D:
	var key := unshaded
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


static func _base(parent: Node, pos: Vector3, amount: int, life: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	var q := SphereMesh.new()
	q.radius = 0.5
	q.height = 1.0
	q.radial_segments = 6
	q.rings = 3
	p.mesh = q
	p.material_override = _dot_mat()
	p.local_coords = false
	parent.add_child(p)
	if p.is_inside_tree():
		p.global_position = pos
	else:
		p.position = pos
	if one_shot:
		p.emitting = true
		p.finished.connect(p.queue_free)
	return p


static func _parent() -> Node:
	return Game.I.world.dynamic if Game.I and Game.I.world else null


## Мерцающие искры вокруг узла (золотой цветок).
static func sparkle(on: Node3D) -> CPUParticles3D:
	var p := _base(on, Vector3(0, 0.15, 0), 10, 1.2, false)
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.color = Color(1.0, 0.95, 0.6)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.8, 1))
	g.set_color(1, Color(1, 0.85, 0.3, 0))
	p.color_ramp = g
	return p


## Короткий взрыв точек: пыльца, мёд, пыль.
static func burst(pos: Vector3, color: Color, count := 12, speed := 2.5, size := 0.12, gravity := -6.0) -> void:
	var parent := _parent()
	if parent == null or Game.server_mode:
		return
	var p := _base(parent, pos, count, 0.7, true)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g


## Звёздочки над головой после удара.
static func stars(pos: Vector3) -> void:
	var parent := _parent()
	if parent == null or Game.server_mode:
		return
	var p := _base(parent, pos + Vector3(0, 0.4, 0), 6, 0.6, true)
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.flatness = 0.9
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 1.8
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.18
	var q := PrismMesh.new()
	q.size = Vector3(1, 1, 0.3)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color("fff3a0"))
	g.set_color(1, Color(1, 0.9, 0.3, 0))
	p.color_ramp = g


## Пыль из-под ног бегущего дачника.
static func dust(pos: Vector3) -> void:
	burst(pos + Vector3(0, 0.08, 0), Color("d9c7a6"), 4, 0.8, 0.22, 0.6)
