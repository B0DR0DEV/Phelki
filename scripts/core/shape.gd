class_name Shape
extends RefCounted
## Формы, материалы и склейка мешей.
##
## Стиль — «дачная игрушка»: всё скруглённое, точёное, с тёмно-коричневым контуром.
## make() создаёт деталь сразу нужного размера (без растяжения, чтобы скругления
## и контур не искажались). Размеры как раньше: BOX — полный размер,
## SPHERE — диаметры, CYLINDER/CAPSULE/CONE — (диаметр X, ПОЛОВИНА высоты, диаметр Z),
## PRISM — двускатная крыша (длина X, высота Y, ширина Z).
## compact() склеивает неподвижные детали каждого узла в один меш,
## bake_static() — всю неподвижную часть карты в несколько больших кусков.
## Настоящие модели подключаются через папку res://art (см. art()).

enum { BOX, SPHERE, CYLINDER, CAPSULE, CONE, PRISM }

const INK := Color(0.17, 0.11, 0.08)
const OUTLINE := 0.022

static var _toon: Shader
static var _outline_shader: Shader
static var _mats := {}
static var _outlines := {}
static var _geo := {}


# ── Материалы ──────────────────────────────────────────────

static func toon_shader() -> Shader:
	if _toon == null:
		_toon = load("res://shaders/toon.gdshader")
	return _toon


static func outline_mat(width := OUTLINE) -> ShaderMaterial:
	var key := snappedf(width, 0.001)
	if _outlines.has(key):
		return _outlines[key]
	if _outline_shader == null:
		_outline_shader = load("res://shaders/outline.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("ink", INK)
	_outlines[key] = m
	return m


## Мультяшный материал. rough < 0.5 — с бликом. outline = 0 — без контура.
static func mat(color: Color, rough: float = 0.85, outline := OUTLINE) -> ShaderMaterial:
	var key := "%s|%.2f|%.3f" % [color.to_html(), rough, outline]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = toon_shader()
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("gloss", clampf(1.0 - rough * 1.6, 0.0, 1.0))
	if outline > 0.0:
		m.next_pass = outline_mat(outline)
	_mats[key] = m
	return m


## Свой экземпляр материала (для отёка дачника, золотого цветка и т.п.).
static func unique_mat(color := Color.WHITE, outline := OUTLINE) -> ShaderMaterial:
	var m := mat(color, 0.85, outline).duplicate() as ShaderMaterial
	return m


# ── Детали ─────────────────────────────────────────────────

## Создаёт деталь. solid — в неё можно врезаться. skin — «кожа» (краснеет от отёка).
static func make(kind: int, parent: Node3D, pos: Vector3, size: Vector3, color: Color,
		solid := false, node_name := "", rot := Vector3.ZERO, skin := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	mi.mesh = geometry(kind, size)
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.set_meta("part", true)
	mi.set_meta("color", color)
	mi.set_meta("skin", skin)
	parent.add_child(mi)
	if solid:
		add_body(kind, parent, pos, size, rot)
	return mi


## Деталь из профиля вращения: точки (радиус, высота) снизу вверх, у каждой свой цвет.
static func lathe(parent: Node3D, pos: Vector3, profile: Array, colors: Array, node_name := "",
		rot := Vector3.ZERO, segments := 18, scale_xz := Vector2.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	mi.mesh = _lathe_mesh(profile, colors, segments, scale_xz)
	mi.material_override = mat(Color.WHITE)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.set_meta("part", true)
	mi.set_meta("color", Color.WHITE)
	mi.set_meta("vcolor", true)
	parent.add_child(mi)
	return mi


static func geometry(kind: int, size: Vector3) -> ArrayMesh:
	var key := "%d|%.3f|%.3f|%.3f" % [kind, size.x, size.y, size.z]
	if _geo.has(key):
		return _geo[key]
	var m: ArrayMesh
	match kind:
		BOX:
			m = _rounded_box(size)
		SPHERE:
			var big := maxf(size.x, maxf(size.y, size.z))
			m = _ellipsoid(size * 0.5, 4 if big < 0.3 else (6 if big < 1.2 else 10), 7 if big < 0.3 else (10 if big < 1.2 else 16))
		CYLINDER:
			var r := 1.0
			var h := size.y
			var b := minf(0.06, minf(h * 0.4, minf(size.x, size.z) * 0.18))
			var prof := [Vector2(0, -h), Vector2(r - b / maxf(size.x * 0.5, 0.001), -h)]
			var bx := b / maxf(size.x * 0.5, 0.001)
			for i in range(1, 2):
				var a := i / 2.0 * PI / 2
				prof.append(Vector2(r - bx + sin(a) * bx, -h + b - cos(a) * b))
			prof.append(Vector2(r, h - b))
			for i in range(1, 2):
				var a := i / 2.0 * PI / 2
				prof.append(Vector2(r - bx + cos(a) * bx, h - b + sin(a) * b))
			prof.append(Vector2(r - bx, h))
			prof.append(Vector2(0, h))
			m = _lathe_mesh(prof, [], _segs(size), Vector2(size.x * 0.5, size.z * 0.5))
		CAPSULE:
			var rr := minf(size.x, size.z) * 0.5
			var hh := maxf(size.y, rr)
			var prof := []
			for i in 4:
				var a := -PI / 2 + i / 3.0 * PI / 2
				prof.append(Vector2(cos(a) * rr, -hh + rr + sin(a) * rr))
			for i in 4:
				var a := i / 3.0 * PI / 2
				prof.append(Vector2(cos(a) * rr, hh - rr + sin(a) * rr))
			m = _lathe_mesh(prof, [], _segs(size), Vector2(size.x * 0.5 / rr, size.z * 0.5 / rr))
		CONE:
			var h := size.y
			m = _lathe_mesh([Vector2(0, -h), Vector2(0.92, -h), Vector2(1.0, -h + 0.04), Vector2(0.04, h - 0.02), Vector2(0, h)],
				[], _segs(size), Vector2(size.x * 0.5, size.z * 0.5))
		_:
			m = _prism(size)
	_geo[key] = m
	return m


static func _segs(size: Vector3) -> int:
	var d := maxf(size.x, size.z)
	return 6 if d < 0.15 else (8 if d < 0.6 else (12 if d < 2.0 else 16))


## Совместимость со старым кодом: единичная сфера (для облачков пыльцы).
static func _mesh(kind: int) -> Mesh:
	return geometry(kind, Vector3.ONE)


# ── Генераторы ─────────────────────────────────────────────

static func _commit(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		uv := PackedVector2Array()) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	if not uv.is_empty():
		arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Треугольник, видимый снаружи (в Godot лицевая сторона — по часовой стрелке).
static func _tri(idx: PackedInt32Array, v: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> void:
	if (v[b] - v[a]).cross(v[c] - v[a]).dot(outward) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


static func _rounded_box(size: Vector3) -> ArrayMesh:
	var half := size * 0.5
	var r := minf(minf(half.x, half.y), half.z) * 0.6
	r = minf(r, 0.07)
	var inner := half - Vector3(r, r, r)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var u_axis := (axis + 1) % 3
			var w_axis := (axis + 2) % 3
			var fine := minf(minf(size.x, size.y), size.z) > 0.25
			var us := _samples(half[u_axis], inner[u_axis], r, fine)
			var ws := _samples(half[w_axis], inner[w_axis], r, fine)
			var face_n := Vector3.ZERO
			face_n[axis] = sgn
			var start := v.size()
			for ui in us.size():
				for wi in ws.size():
					var q := Vector3.ZERO
					q[axis] = sgn * half[axis]
					q[u_axis] = us[ui]
					q[w_axis] = ws[wi]
					var core := Vector3(clampf(q.x, -inner.x, inner.x), clampf(q.y, -inner.y, inner.y), clampf(q.z, -inner.z, inner.z))
					var d := q - core
					var nn := d.normalized() if d.length_squared() > 1e-10 else face_n
					v.append(core + nn * r)
					n.append(nn)
					c.append(Color.WHITE)
			var cols := ws.size()
			for ui in us.size() - 1:
				for wi in cols - 1:
					var a := start + ui * cols + wi
					_tri(idx, v, a, a + cols, a + 1, face_n)
					_tri(idx, v, a + 1, a + cols, a + cols + 1, face_n)
	return _commit(v, n, c, idx)


## Сэмплы вдоль ребра: гуще в зоне скругления.
static func _samples(h: float, i: float, r: float, fine: bool) -> PackedFloat32Array:
	var s := PackedFloat32Array([-h])
	if fine:
		s.append(-(i + r * 0.5))
	s.append(-i if i > 0.001 else 0.0)
	if i > 0.001:
		s.append(i)
	if fine:
		s.append(i + r * 0.5)
	s.append(h)
	return s


static func _ellipsoid(rad: Vector3, rings := 10, segs := 18) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for ri in rings + 1:
		var phi := PI * ri / rings
		for si in segs + 1:
			var th := TAU * si / segs
			var p := Vector3(sin(phi) * cos(th), -cos(phi), sin(phi) * sin(th))
			v.append(p * rad)
			n.append(Vector3(p.x / maxf(rad.x, 0.0001), p.y / maxf(rad.y, 0.0001), p.z / maxf(rad.z, 0.0001)).normalized())
			c.append(Color.WHITE)
	var cols := segs + 1
	for ri in rings:
		for si in segs:
			var a := ri * cols + si
			var mid := (v[a] + v[a + cols + 1]) * 0.5
			_tri(idx, v, a, a + cols, a + 1, mid)
			_tri(idx, v, a + 1, a + cols, a + cols + 1, mid)
	return _commit(v, n, c, idx)


## Тело вращения вокруг Y. profile — Vector2(радиус, высота) снизу вверх.
static func _lathe_mesh(profile: Array, colors: Array, segs: int, scale_xz := Vector2.ONE) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var count := profile.size()
	for pi in count:
		var p: Vector2 = profile[pi]
		var prev: Vector2 = profile[maxi(pi - 1, 0)]
		var nxt: Vector2 = profile[mini(pi + 1, count - 1)]
		var t := (nxt - prev).normalized()
		var n2 := Vector2(t.y, -t.x)  # наружу при обходе снизу вверх
		var col: Color = colors[pi] if pi < colors.size() else Color.WHITE
		for si in segs + 1:
			var th := TAU * si / segs
			var dir := Vector3(cos(th), 0, sin(th))
			v.append(Vector3(dir.x * p.x * scale_xz.x, p.y, dir.z * p.x * scale_xz.y))
			n.append(Vector3(dir.x * n2.x / scale_xz.x, n2.y, dir.z * n2.x / scale_xz.y).normalized())
			c.append(col)
	var cols := segs + 1
	for pi in count - 1:
		for si in segs:
			var a := pi * cols + si
			var mid := (v[a] + v[a + cols + 1]) * 0.5
			var out := Vector3(mid.x, 0, mid.z)
			var axis_y: float = (n[a] + n[a + cols + 1]).y
			out = (out.normalized() if out.length_squared() > 1e-8 else Vector3.ZERO) + Vector3(0, axis_y, 0)
			_tri(idx, v, a, a + cols, a + 1, out)
			_tri(idx, v, a + 1, a + cols, a + cols + 1, out)
	return _commit(v, n, c, idx)


## Двускатная крыша: конёк вдоль X.
static func _prism(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var faces := [
		[Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, h, 0), Vector3(-hx, h, 0)],
		[Vector3(-hx, 0, hz), Vector3(-hx, h, 0), Vector3(hx, h, 0), Vector3(hx, 0, hz)],
		[Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz)],
	]
	for f in faces:
		var nn: Vector3 = ((f[1] - f[0]).cross(f[2] - f[0])).normalized()
		var center: Vector3 = (f[0] + f[2]) * 0.5
		if nn.dot(center - Vector3(0, h * 0.3, 0)) < 0:
			nn = -nn
		var s := v.size()
		for p in f:
			v.append(p)
			n.append(nn)
			c.append(Color.WHITE)
		_tri(idx, v, s, s + 1, s + 2, nn)
		_tri(idx, v, s, s + 2, s + 3, nn)
	for sx in [-1.0, 1.0]:
		var s := v.size()
		var nn := Vector3(sx, 0, 0)
		for p in [Vector3(sx * hx, 0, -hz), Vector3(sx * hx, 0, hz), Vector3(sx * hx, h, 0)]:
			v.append(p)
			n.append(nn)
			c.append(Color.WHITE)
		_tri(idx, v, s, s + 1, s + 2, nn)
	return _commit(v, n, c, idx)


# ── Коллизии ───────────────────────────────────────────────

## Твёрдое тело той же формы.
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
		SPHERE:
			var sp := SphereShape3D.new()
			sp.radius = maxf(maxf(size.x, size.y), size.z) * 0.5
			cs.shape = sp
		CYLINDER, CONE:
			var cy := CylinderShape3D.new()
			cy.radius = maxf(size.x, size.z) * 0.5
			cy.height = size.y * 2.0
			cs.shape = cy
		CAPSULE:
			var ca := CapsuleShape3D.new()
			ca.radius = maxf(size.x, size.z) * 0.5
			ca.height = maxf(size.y * 2.0, ca.radius * 2.0)
			cs.shape = ca
		PRISM:
			var b := BoxShape3D.new()
			b.size = size
			cs.shape = b
			cs.position = Vector3(0, size.y * 0.5, 0)
		_:
			var bx := BoxShape3D.new()
			bx.size = size
			cs.shape = bx
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


# ── Склейка ────────────────────────────────────────────────

class Acc:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func add(mi: MeshInstance3D, xf: Transform3D) -> void:
		var arr := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var cols = arr[Mesh.ARRAY_COLOR]
		var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := v.size()
		var nb := xf.basis.inverse().transposed()
		var tint: Color = mi.get_meta("color", Color.WHITE)
		var skin: bool = mi.get_meta("skin", false)
		var use_v: bool = mi.get_meta("vcolor", false) and cols != null
		for k in verts.size():
			v.append(xf * verts[k])
			n.append((nb * norms[k]).normalized())
			var col: Color = (cols[k] if use_v else Color.WHITE) * tint
			col.a = 0.0 if skin else 1.0
			c.append(col)
		for k in ind:
			i.append(base + k)

	func mesh() -> ArrayMesh:
		return Shape._commit(v, n, c, i)


static func _mergeable(mi: MeshInstance3D) -> bool:
	return mi.has_meta("part") and mi.get_child_count() == 0 and mi.mesh is ArrayMesh


## Склеивает неподвижные детали внутри каждого узла (персонажи, предметы).
## Шарниры (крылья, руки, голова) остаются отдельными узлами со своим мешем.
static func compact(root: Node3D, material: Material = null) -> void:
	var parts: Array[MeshInstance3D] = []
	for ch in root.get_children():
		if ch is MeshInstance3D and _mergeable(ch):
			parts.append(ch)
		elif ch is Node3D:
			compact(ch, material)
	if parts.size() < 2 and material == null:
		return
	if parts.is_empty():
		return
	var acc := Acc.new()
	for p in parts:
		acc.add(p, p.transform)
	var mi := MeshInstance3D.new()
	mi.name = "Склеено"
	mi.mesh = acc.mesh()
	mi.material_override = material if material else mat(Color.WHITE)
	root.add_child(mi)
	for p in parts:
		root.remove_child(p)
		p.free()


## Склеивает всё неподвижное в мире в куски 18×18 м (по куску — один вызов отрисовки).
static func bake_static(world: Node3D, cell := 18.0) -> void:
	var chunks := {}
	var victims: Array[MeshInstance3D] = []
	var inv := world.global_transform.affine_inverse()
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		if not _mergeable(mi) or not _static_path(mi, world):
			continue
		var xf: Transform3D = inv * (mi as MeshInstance3D).global_transform
		var key := Vector2i(floori(xf.origin.x / cell), floori(xf.origin.z / cell))
		if not chunks.has(key):
			chunks[key] = Acc.new()
		(chunks[key] as Acc).add(mi, xf)
		victims.append(mi)
	var holder := node("Статика", world)
	for key in chunks:
		var mi := MeshInstance3D.new()
		mi.mesh = (chunks[key] as Acc).mesh()
		mi.material_override = mat(Color.WHITE)
		holder.add_child(mi)
	for v in victims:
		v.get_parent().remove_child(v)
		v.free()


## Неподвижно ли: никто из предков не двигается.
static func _static_path(n: Node, world: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != world:
		if p.has_meta("dynamic"):
			return false
		var s = p.get_script()
		if s != null and not p is Flower:
			return false
		p = p.get_parent()
	return true


# ── Настоящие модели ───────────────────────────────────────

## Модель из res://art/<key>.glb (или .gltf / .tscn), если художник её положил.
static func art(key: String) -> PackedScene:
	for ext in ["glb", "gltf", "tscn"]:
		var p := "res://art/%s.%s" % [key, ext]
		if ResourceLoader.exists(p):
			return load(p) as PackedScene
	return null


## Ставит модель. solid и у модели нет коллизий — добавляет коробку по её размерам.
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
		var vis := vi as VisualInstance3D
		var local := root.global_transform.affine_inverse() * vis.global_transform
		var box: AABB = local * vis.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
