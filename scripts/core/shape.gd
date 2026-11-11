class_name Shape
extends RefCounted
## Временные модели-заглушки, материалы и коллизии.
## Размеры как у привычных примитивов: куб 1×1×1, шар диаметром 1,
## цилиндр и капсула диаметром 1 и высотой 2 — масштаб задаёт итоговый размер.
## Настоящие модели подключаются через папку res://art (см. art()).

enum { BOX, SPHERE, CYLINDER, CAPSULE }

static var _mats := {}
static var _meshes := {}


static func mat(color: Color, rough: float = 0.85) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	_mats[key] = m
	return m


static func _mesh(kind: int) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		BOX:
			m = BoxMesh.new()
		SPHERE:
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 24
			s.rings = 12
			m = s
		CYLINDER:
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 2.0
			c.radial_segments = 20
			m = c
		_:
			var cap := CapsuleMesh.new()
			cap.radius = 0.5
			cap.height = 2.0
			m = cap
	_meshes[kind] = m
	return m


## Создаёт форму. solid = true — в неё можно врезаться.
static func make(kind: int, parent: Node3D, pos: Vector3, size: Vector3, color: Color,
		solid := false, node_name := "", rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	mi.mesh = _mesh(kind)
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = size
	parent.add_child(mi)
	if solid:
		add_body(kind, parent, pos, size, rot)
	return mi


## Твёрдое тело той же формы (отдельным узлом — физике вредно неравномерное растяжение).
static func add_body(kind: int, parent: Node3D, pos: Vector3, size: Vector3, rot := Vector3.ZERO,
		bounce := 0.5) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("bounce", bounce)
	var cs := CollisionShape3D.new()
	match kind:
		BOX:
			var b := BoxShape3D.new()
			b.size = size
			cs.shape = b
		SPHERE:
			var sp := SphereShape3D.new()
			sp.radius = maxf(maxf(size.x, size.y), size.z) * 0.5
			cs.shape = sp
		CYLINDER:
			var cy := CylinderShape3D.new()
			cy.radius = maxf(size.x, size.z) * 0.5
			cy.height = size.y * 2.0
			cs.shape = cy
		_:
			var ca := CapsuleShape3D.new()
			ca.radius = maxf(size.x, size.z) * 0.5
			ca.height = maxf(size.y * 2.0, ca.radius * 2.0)
			cs.shape = ca
	body.add_child(cs)
	parent.add_child(body)
	return body


## Невидимая коробка-стена.
static func box_body(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	return add_body(BOX, parent, pos, size)


static func node(node_name: String, parent: Node, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


## Настоящая модель из res://art/<key>.glb (или .gltf / .tscn), если художник её положил.
static func art(key: String) -> PackedScene:
	for ext in ["glb", "gltf", "tscn"]:
		var p := "res://art/%s.%s" % [key, ext]
		if ResourceLoader.exists(p):
			return load(p) as PackedScene
	return null


## Ставит модель. solid = true и у модели нет своих коллизий — добавляет коробку по её размерам.
static func place_art(scene: PackedScene, parent: Node3D, pos: Vector3, yaw := 0.0, solid := true) -> Node3D:
	var inst := scene.instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = yaw
	parent.add_child(inst)
	if solid and inst.find_children("*", "CollisionObject3D", true, false).is_empty():
		var aabb := _aabb(inst)
		if aabb.size != Vector3.ZERO:
			box_body(parent, pos + Basis.from_euler(Vector3(0, deg_to_rad(yaw), 0)) * aabb.get_center(), aabb.size)
	return inst


static func _aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for vi in root.find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		var local := root.global_transform.affine_inverse() * v.global_transform
		var box: AABB = local * v.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
