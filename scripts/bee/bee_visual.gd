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


## Пчела (или оса-гопник) из точёных форм. Смотрит вперёд по +Z.
## Заменяется моделью res://art/bee.glb (или wasp.glb).
static var _templates := {}


static func free_templates() -> void:
	for t in _templates.values():
		(t as Node).free()
	_templates.clear()


static func build_placeholder(root: Node3D, wasp: bool) -> void:
	# Модель собирается один раз, дальше копируется (меши общие — это быстро)
	if not _templates.has(wasp):
		var t := Node3D.new()
		_build(t, wasp)
		_templates[wasp] = t
	for c in (_templates[wasp] as Node3D).get_children():
		root.add_child(c.duplicate())


static func _build(root: Node3D, wasp: bool) -> void:
	var dark := Color("2b1d14")
	var yellow := Color("f4b81c") if wasp else Palette.BEE_YELLOW
	if wasp:
		_wasp_body(root, yellow, dark)
	else:
		_bee_body(root, yellow, dark)
	# Крылья на шарнирах (машут вокруг плеча)
	for side in [-1.0, 1.0]:
		var pivot := Shape.node("Крыло_Л" if side < 0 else "Крыло_П", root, Vector3(0.1 * side, 0.2, 0.08))
		Shape.make(Shape.SPHERE, pivot, Vector3(0.2 * side, 0.03, -0.06), Vector3(0.38, 0.025, 0.24), Palette.WING, false, "Перепонка", Vector3(0, 20 * side, 0))
		Shape.make(Shape.SPHERE, pivot, Vector3(0.14 * side, 0.02, -0.16), Vector3(0.22, 0.02, 0.14), Palette.WING, false, "Перепонка", Vector3(0, -15 * side, 0))
	Shape.compact(root)


## Полоски по длине тела: профиль вращения с чёткими границами цветов.
static func _striped(root: Node3D, pos: Vector3, length: float, radius_at: Callable, bands: Array, colors: Array) -> void:
	var prof := []
	var cols := []
	var steps := 9
	var edges: Array = bands.duplicate()
	var band := 0
	for i in steps + 1:
		var t := float(i) / steps
		while band < edges.size() and float(edges[band]) <= t:
			# дублируем точку на границе — полоска получается резкой
			var te: float = edges[band]
			prof.append(Vector2(radius_at.call(te), (te - 0.5) * length))
			cols.append(colors[band % colors.size()])
			band += 1
			prof.append(Vector2(radius_at.call(te), (te - 0.5) * length))
			cols.append(colors[band % colors.size()])
		prof.append(Vector2(radius_at.call(t), (t - 0.5) * length))
		cols.append(colors[band % colors.size()])
	# Лежит вдоль Z: верх профиля смотрит вперёд
	Shape.lathe(root, pos, prof, cols, "Тело", Vector3(90, 0, 0), 10)


static func _bee_body(root: Node3D, yellow: Color, dark: Color) -> void:
	# Пухлое тельце: от жала (сзади) к шее (спереди)
	var r := func(t: float) -> float: return 0.27 * pow(sin(clampf(t, 0.0, 1.0) * PI), 0.75) * (0.88 + 0.12 * t)
	_striped(root, Vector3(0, 0, -0.08), 0.62, r, [0.16, 0.3, 0.44, 0.58], [dark, yellow])
	Shape.make(Shape.CONE, root, Vector3(0, 0, -0.42), Vector3(0.06, 0.06, 0.06), dark, false, "Жало", Vector3(-90, 0, 0))
	# Пушистый воротник
	Shape.make(Shape.SPHERE, root, Vector3(0, 0.02, 0.2), Vector3(0.4, 0.36, 0.2), Color("fff1c7"), false, "Пушок")
	# Голова, глаза с бликом, румянец, улыбка
	Shape.make(Shape.SPHERE, root, Vector3(0, 0.06, 0.36), Vector3(0.34, 0.32, 0.3), dark, false, "Голова")
	for side in [-1.0, 1.0]:
		Shape.make(Shape.SPHERE, root, Vector3(0.085 * side, 0.1, 0.49), Vector3(0.13, 0.15, 0.06), Palette.WHITE, false, "Глаз")
		Shape.make(Shape.SPHERE, root, Vector3(0.08 * side, 0.09, 0.52), Vector3(0.075, 0.09, 0.03), dark, false, "Зрачок")
		Shape.make(Shape.SPHERE, root, Vector3(0.065 * side, 0.12, 0.535), Vector3(0.028, 0.028, 0.01), Palette.WHITE, false, "Блик")
		Shape.make(Shape.SPHERE, root, Vector3(0.13 * side, 0.0, 0.47), Vector3(0.07, 0.04, 0.02), Color("ff8f86"), false, "Румянец")
		Shape.make(Shape.CAPSULE, root, Vector3(0.07 * side, 0.27, 0.4), Vector3(0.025, 0.09, 0.025), dark, false, "Усик", Vector3(-35, 0, -18 * side))
		Shape.make(Shape.SPHERE, root, Vector3(0.11 * side, 0.35, 0.46), Vector3.ONE * 0.06, dark, false, "Шарик усика")
		# Лапки
		for k in 3:
			Shape.make(Shape.CAPSULE, root, Vector3(0.12 * side, -0.2, 0.08 - k * 0.12), Vector3(0.03, 0.08, 0.03), dark, false, "Лапка", Vector3(15, 0, 25 * side))
	Shape.make(Shape.CAPSULE, root, Vector3(0, -0.01, 0.505), Vector3(0.012, 0.045, 0.012), Color("ff8f86"), false, "Улыбка", Vector3(0, 0, 90))


static func _wasp_body(root: Node3D, yellow: Color, dark: Color) -> void:
	# Осиная талия: острое брюшко, тонкая перетяжка, грудь
	var r := func(t: float) -> float: return 0.2 * pow(sin(clampf(t, 0.0, 1.0) * PI), 1.1) * (0.6 + 0.4 * t)
	_striped(root, Vector3(0, 0, -0.18), 0.5, r, [0.2, 0.34, 0.5, 0.66, 0.8], [dark, yellow])
	Shape.make(Shape.CONE, root, Vector3(0, 0, -0.47), Vector3(0.05, 0.07, 0.05), dark, false, "Жало", Vector3(-90, 0, 0))
	Shape.make(Shape.SPHERE, root, Vector3(0, 0.02, 0.15), Vector3(0.24, 0.22, 0.26), dark, false, "Грудь")
	Shape.make(Shape.SPHERE, root, Vector3(0, 0.07, 0.33), Vector3(0.26, 0.24, 0.24), yellow, false, "Голова")
	for side in [-1.0, 1.0]:
		Shape.make(Shape.SPHERE, root, Vector3(0.07 * side, 0.09, 0.44), Vector3(0.09, 0.07, 0.04), Palette.WHITE, false, "Глаз")
		Shape.make(Shape.SPHERE, root, Vector3(0.07 * side, 0.08, 0.46), Vector3(0.05, 0.05, 0.02), Color("c0282d"), false, "Зрачок")
		Shape.make(Shape.BOX, root, Vector3(0.075 * side, 0.135, 0.455), Vector3(0.1, 0.022, 0.02), dark, false, "Бровь", Vector3(0, 0, 22 * side))
		for k in 3:
			Shape.make(Shape.CAPSULE, root, Vector3(0.1 * side, -0.14, 0.1 - k * 0.08), Vector3(0.025, 0.07, 0.025), dark, false, "Лапка", Vector3(15, 0, 25 * side))
	# Кепка козырьком набок и цепь — гопник с мусорки
	Shape.lathe(root, Vector3(0, 0.17, 0.32), [Vector2(0, 0), Vector2(0.135, 0), Vector2(0.135, 0.03), Vector2(0.1, 0.09), Vector2(0, 0.1)],
		[Color("3a3a40"), Color("3a3a40"), Color("3a3a40"), Color("2e2e33"), Color("2e2e33")], "Кепка", Vector3.ZERO, 12)
	Shape.make(Shape.BOX, root, Vector3(0.1, 0.18, 0.43), Vector3(0.14, 0.02, 0.13), Color("2e2e33"), false, "Козырёк", Vector3(0, 35, 0))
	for k in 9:
		var a := PI * 0.15 + k * PI * 0.7 / 8
		Shape.make(Shape.SPHERE, root, Vector3(cos(a) * 0.12, -0.04 - sin(a) * 0.04, 0.24 + sin(a) * 0.06), Vector3.ONE * 0.035, Palette.GOLD, false, "Цепь")
