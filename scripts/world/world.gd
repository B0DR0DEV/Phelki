class_name World
extends Node3D
## Дачный участок: строится кодом из временных моделей. Любой объект
## можно заменить настоящей моделью, положив её в res://art (см. art/README.md).
## Ориентация: камера смотрит вдоль +Z, улей в центре, вход улья к камере.

const HALF := 32.0
const PETALS := [
	Color(0.96, 0.45, 0.65), Color(0.98, 0.98, 0.96), Color(0.62, 0.42, 0.88),
	Color(0.95, 0.30, 0.25), Color(1.00, 0.60, 0.20), Color(0.40, 0.62, 0.98),
]

var dynamic: Node3D
var bee_spawn := Vector3(0.0, 2.1, -2.4)
var hive_position := Vector3.ZERO
var wind := Vector3.ZERO
var flowers: Array[Flower] = []
var wasps: Array[Wasp] = []

# Побег за людей
var escape_spawn := Vector3(2.5, 0.05, -23.5)
var car_door: Node3D
var jar_spots: Array[Vector3] = []

var _swarm: Swarm
var _rng := RandomNumberGenerator.new()
var _car: Node3D
var _car_home := Vector3.ZERO
var _car_speed := 0.0
var _gust_dir := Vector3.ZERO
var _gust_start := 0.0
var _gust_end := 0.0
var _next_gust := 0.0


## Карты: id → название.
const MAPS := {"dacha": "Дача", "yard": "Двор", "field": "Поле подсолнухов"}
const MAP_ORDER := ["dacha", "yard", "field"]

var map_id := "dacha"
var race_rings: Array[Vector3] = []  # кольца перегонок (по порядку, круг замкнут)
var bear_path: Array[Vector3] = []  # путь медведя к улью
var open_points: Array[Vector3] = []  # свободные места (для ботов)


func build(id := "dacha") -> void:
	map_id = id if MAPS.has(id) else "dacha"
	_rng.seed = 2026
	dynamic = Shape.node("Динамика", self)
	match map_id:
		"yard":
			_map_yard()
		"field":
			_map_field()
		_:
			_map_dacha()
	_build_bounds()
	open_points.clear()
	for p in jar_spots:
		open_points.append(p)
	for r in race_rings:
		open_points.append(Vector3(r.x, 0, r.z))
	_swarm = Swarm.build(self, hive_position, 14)
	_swarm.angry = Profile.current().side == Profile.Side.HUMAN


func map_name() -> String:
	return MAPS[map_id]


func random_open_point() -> Vector3:
	return open_points[randi() % open_points.size()] if not open_points.is_empty() else Vector3.ZERO


# ── Карта 1: Дача ──────────────────────────────────────────

func _map_dacha() -> void:
	_setup_environment(Vector3(-48, 145, 0), Color(1.0, 0.95, 0.85), 1.0, Color(0.38, 0.62, 0.92), Color(0.78, 0.88, 0.96))
	_build_ground(Palette.GRASS, Palette.GRASS_DARK)
	Shape.make(Shape.BOX, self, Vector3(0, 0.01, -12), Vector3(2.2, 0.02, 24), Palette.PATH, false, "Дорожка")
	Shape.make(Shape.BOX, self, Vector3(-8, 0.012, 9), Vector3(16, 0.02, 2), Palette.PATH, false, "Дорожка")
	_build_fence()

	_build_hive(hive_position)
	_build_house(Vector3(-15, 0, 13))
	_build_greenhouse(Vector3(13, 0, 10))

	_build_flower_bed(Vector3(8, 0, -4), 4.5, 10, false)
	_build_flower_bed(Vector3(-8, 0, -7), 4.0, 9, false)
	_build_flower_bed(Vector3(-9, 0, 4), 3.2, 7, true)  # бабкины клумбы
	_build_flower_bed(Vector3(4, 0, 16), 4.0, 9, false)
	_build_flower_bed(Vector3(18, 0, -14), 4.5, 10, false)
	_build_flower_bed(Vector3(-20, 0, -14), 4.0, 9, false)
	_build_flower_bed(Vector3(22, 0, 2), 3.5, 7, false)

	_build_jam_table(Vector3(5, 0, -12))
	_build_fan(Vector3(-3, 0, 9), 90.0)
	_build_trash_can(Vector3(20, 0, 18), 2)
	_build_trash_can(Vector3(-24, 0, -2), 1)
	_build_clothesline(Vector3(-14, 0, -22), Vector3(0, 0, -22))

	_build_car(Vector3(0, 0, -27))
	escape_spawn = Vector3(2.5, 0.05, -23.5)
	jar_spots = [
		Vector3(2, 0, 1.4), Vector3(-12.5, 0, 8.2), Vector3(13, 0, 7.2), Vector3(5, 0, -13.4),
		Vector3(-7, 0, -20.6), Vector3(18.3, 0, 16.6), Vector3(-16, 0, -3.5), Vector3(-9, 0, 0.6),
		Vector3(22, 0, -2), Vector3(-24, 0, -20),
	]
	for t in [Vector3(-26, 0, 25), Vector3(-6, 0, 26), Vector3(14, 0, 26), Vector3(27, 0, 9),
			Vector3(27, 0, -24), Vector3(-27, 0, -26), Vector3(-28, 0, 9), Vector3(10, 0, -25),
			Vector3(12, 0, 2), Vector3(-4, 0, -16), Vector3(-16, 0, -5)]:
		_build_tree(t)

	race_rings = [Vector3(0, 3, -8), Vector3(10, 3, -10), Vector3(17, 3, -2), Vector3(7, 3.2, 6),
		Vector3(0, 3, 13), Vector3(-7, 3, 4), Vector3(-11, 3, -10), Vector3(-8, 3, -18)]
	bear_path = [Vector3(22, 0, -30), Vector3(14, 0, -8), Vector3(4, 0, -3), Vector3(0, 0, -1.6)]


# ── Карта 2: Двор (хрущёвки, гаражи, площадка) ─────────────

func _map_yard() -> void:
	_setup_environment(Vector3(-22, 120, 0), Color(1.0, 0.72, 0.5), 1.05, Color(0.42, 0.45, 0.75), Color(0.98, 0.72, 0.6))
	_build_ground(Color(0.42, 0.42, 0.44), Color(0.36, 0.55, 0.3), true)
	_build_hive(hive_position)

	_build_khrushchevka(Vector3(0, 0, 27), 48.0, 0.0)
	_build_khrushchevka(Vector3(-27, 0, 2), 34.0, 90.0)
	_build_garages(Vector3(26, 0, -6), 7)
	_build_playground(Vector3(-10, 0, -8))
	_build_bench_with_babushka(Vector3(-4, 0, 15))
	_build_fan(Vector3(10, 2.6, 21.8), 180.0, "ac")  # кондиционер на стене дует во двор

	for c in [Vector3(9, 0, -4), Vector3(-12, 0, 8), Vector3(6, 0, 11), Vector3(-2, 0, -16), Vector3(16, 0, 6)]:
		_build_tire_bed(c)
	_build_trash_can(Vector3(16, 0, 17), 2, "dumpster")
	_build_trash_can(Vector3(-18, 0, -20), 1, "dumpster")
	for t in [Vector3(-16, 0, 18), Vector3(12, 0, -14), Vector3(20, 0, 12), Vector3(-20, 0, -8), Vector3(4, 0, -22), Vector3(-6, 0, 22)]:
		_build_tree(t, true)

	_build_car(Vector3(10, 0, -27))
	escape_spawn = Vector3(12.5, 0.05, -23.5)
	jar_spots = [
		Vector3(2, 0, 1.6), Vector3(-6, 0, 13.5), Vector3(-14, 0, -4), Vector3(21, 0, -12), Vector3(14, 0, 14.5),
		Vector3(-20, 0, -16), Vector3(6, 0, 18), Vector3(-2, 0, -12), Vector3(18, 0, 2), Vector3(-15, 0, 14),
	]
	race_rings = [Vector3(0, 3, -9), Vector3(12, 3, -10), Vector3(18, 3.5, 0), Vector3(12, 3, 12),
		Vector3(0, 3.2, 8), Vector3(-10, 3, 12), Vector3(-17, 3, 0), Vector3(-10, 3.5, -16)]
	bear_path = [Vector3(-26, 0, -30), Vector3(-6, 0, -20), Vector3(-1, 0, -6), Vector3(0, 0, -1.6)]


# ── Карта 3: Поле подсолнухов ──────────────────────────────

func _map_field() -> void:
	_setup_environment(Vector3(-62, 160, 0), Color(1.0, 0.98, 0.9), 1.1, Color(0.3, 0.58, 0.95), Color(0.85, 0.92, 0.98))
	_build_ground(Color(0.62, 0.72, 0.3), Color(0.55, 0.62, 0.25))
	_build_fence()
	_build_hive(hive_position)
	Shape.make(Shape.BOX, self, Vector3(0, 0.01, -14), Vector3(3, 0.02, 28), Color(0.7, 0.6, 0.45), false, "Колея")

	for row in 4:
		for col in 2:
			var c := Vector3(-22 + col * 44, 0, -18 + row * 11)
			_build_flower_bed(c, 4.0, 9, row == 1 and col == 0, true)
	_build_flower_bed(Vector3(9, 0, 4), 3.5, 7, false, true)
	_build_flower_bed(Vector3(-9, 0, -6), 3.5, 7, false, true)

	_build_windmill(Vector3(-14, 0, 18))
	_build_barn(Vector3(16, 0, 19))
	_build_scarecrow(Vector3(12, 0, -10))
	_build_trash_can(Vector3(22, 0, 12), 1)
	_build_picnic(Vector3(6, 0, -8))
	for h in [Vector3(-6, 0, 8), Vector3(4, 0, 12), Vector3(-2, 0, -16), Vector3(14, 0, 2), Vector3(-14, 0, -2)]:
		_build_haystack(h)
	for t in [Vector3(-28, 0, 28), Vector3(-20, 0, 28), Vector3(28, 0, 26), Vector3(28, 0, -28), Vector3(-28, 0, -28)]:
		_build_tree(t, false, true)

	_build_car(Vector3(-4, 0, -27), "tractor")
	escape_spawn = Vector3(-1.5, 0.05, -23.5)
	jar_spots = [
		Vector3(2, 0, 1.6), Vector3(6, 0, -6.5), Vector3(-12, 0, 15), Vector3(14, 0, 15.5), Vector3(12, 0, -12.5),
		Vector3(-6, 0, 5.5), Vector3(18, 0, 2), Vector3(-17, 0, -2), Vector3(0, 0, -18), Vector3(-24, 0, 10),
	]
	race_rings = [Vector3(0, 3, -9), Vector3(10, 3, -16), Vector3(19, 3.5, -4), Vector3(10, 3, 8),
		Vector3(2, 4, 18), Vector3(-8, 3, 10), Vector3(-18, 3.5, 4), Vector3(-10, 3, -12)]
	bear_path = [Vector3(28, 0, -30), Vector3(18, 0, -16), Vector3(6, 0, -4), Vector3(0, 0, -1.6)]


func _rand(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


# ── Свет, небо, земля ──────────────────────────────────────

func _setup_environment(sun_rot: Vector3, sun_color: Color, sun_energy: float, sky_top: Color, horizon: Color) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Солнце"
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = Color(0.35, 0.5, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.6
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.003
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85

	var we := WorldEnvironment.new()
	we.name = "Небо"
	we.environment = env
	add_child(we)


func _build_ground(color: Color, patch: Color, asphalt := false) -> void:
	Shape.make(Shape.BOX, self, Vector3(0, -0.5, 0), Vector3(HALF * 2 + 40, 1, HALF * 2 + 40), color, true, "Земля")
	# Пятна потемнее; каждое чуть выше предыдущего, чтобы не мерцали
	for i in 26:
		var p := Vector3(_rand(-HALF, HALF), 0.004 + i * 0.0003, _rand(-HALF, HALF))
		var s := _rand(3, 7)
		Shape.make(Shape.CYLINDER, self, p, Vector3(s, 0.005, s * _rand(0.6, 1.0)), patch, false, "Пятно")
	if asphalt:
		# Разметка парковки и бордюры
		for i in 6:
			Shape.make(Shape.BOX, self, Vector3(-4 + i * 4, 0.02, -27), Vector3(0.12, 0.01, 4), Palette.WHITE, false, "Разметка")
		Shape.make(Shape.BOX, self, Vector3(0, 0.08, -24.5), Vector3(40, 0.16, 0.3), Color(0.7, 0.7, 0.68), false, "Бордюр")


func _build_fence() -> void:
	var fence := Shape.node("Забор", self)
	var x := -HALF
	while x <= HALF + 0.01:
		_fence_post(fence, Vector3(x, 0, -HALF))
		_fence_post(fence, Vector3(x, 0, HALF))
		x += 4.0
	var z := -HALF + 4.0
	while z < HALF:
		_fence_post(fence, Vector3(-HALF, 0, z))
		_fence_post(fence, Vector3(HALF, 0, z))
		z += 4.0
	for y in [0.45, 0.95]:
		Shape.make(Shape.BOX, fence, Vector3(0, y, -HALF), Vector3(HALF * 2, 0.1, 0.08), Palette.WOOD)
		Shape.make(Shape.BOX, fence, Vector3(0, y, HALF), Vector3(HALF * 2, 0.1, 0.08), Palette.WOOD)
		Shape.make(Shape.BOX, fence, Vector3(-HALF, y, 0), Vector3(0.08, 0.1, HALF * 2), Palette.WOOD)
		Shape.make(Shape.BOX, fence, Vector3(HALF, y, 0), Vector3(0.08, 0.1, HALF * 2), Palette.WOOD)


func _fence_post(parent: Node3D, p: Vector3) -> void:
	Shape.make(Shape.BOX, parent, p + Vector3(0, 0.6, 0), Vector3(0.14, 1.2, 0.14), Palette.WOOD)


func _build_bounds() -> void:
	# Невидимые стены и потолок: с участка не улететь
	var b := Shape.node("Границы", self)
	var h := 10.0
	var l := HALF * 2 + 2
	Shape.box_body(b, Vector3(0, h / 2, -HALF - 0.5), Vector3(l, h, 1))
	Shape.box_body(b, Vector3(0, h / 2, HALF + 0.5), Vector3(l, h, 1))
	Shape.box_body(b, Vector3(-HALF - 0.5, h / 2, 0), Vector3(1, h, l))
	Shape.box_body(b, Vector3(HALF + 0.5, h / 2, 0), Vector3(1, h, l))
	Shape.box_body(b, Vector3(0, 6, 0), Vector3(l, 0.5, l))


# ── Пасека ─────────────────────────────────────────────────

func _build_hive(pos: Vector3) -> void:
	var hive := Hive.new()
	hive.name = "Улей"
	hive.position = pos
	add_child(hive)
	var body := Shape.node("Корпус", hive)

	var scene := Shape.art("hive")
	if scene:
		Shape.place_art(scene, body, Vector3.ZERO, 180.0)
	else:
		for lp in [Vector3(-0.5, 0.15, -0.4), Vector3(0.5, 0.15, -0.4), Vector3(-0.5, 0.15, 0.4), Vector3(0.5, 0.15, 0.4)]:
			Shape.make(Shape.BOX, body, lp, Vector3(0.1, 0.3, 0.1), Palette.WOOD, false, "Ножка")
		var tiers := [Palette.WOOD_LIGHT, Color(0.98, 0.82, 0.45), Palette.WOOD_LIGHT]
		for i in 3:
			Shape.make(Shape.BOX, body, Vector3(0, 0.49 + i * 0.38, 0), Vector3(1.2, 0.36, 1.0), tiers[i], false, "Корпус %d" % (i + 1))
		Shape.make(Shape.BOX, body, Vector3(0, 1.5, 0), Vector3(1.4, 0.12, 1.2), Palette.ROOF, false, "Крыша")
		Shape.make(Shape.BOX, body, Vector3(0, 0.38, -0.51), Vector3(0.6, 0.06, 0.04), Palette.BLACK, false, "Леток")
		Shape.make(Shape.BOX, body, Vector3(0, 0.33, -0.62), Vector3(0.7, 0.03, 0.22), Palette.WOOD, false, "Прилётная доска")
		# Твёрдое тело ниже высоты полёта — над ульем можно пролететь
		Shape.box_body(hive, Vector3(0, 0.8, 0), Vector3(1.2, 1.25, 1.0))
	hive.init(body)


func _build_flower_bed(center: Vector3, radius: float, count: int, grandmas: bool, tall := false) -> void:
	var bed := Shape.node("Бабкина клумба" if grandmas else "Клумба", self, center)
	Shape.make(Shape.CYLINDER, bed, Vector3(0, 0.03, 0), Vector3(radius * 2, 0.03, radius * 2),
		Color(0.48, 0.36, 0.22) if tall else Color(0.42, 0.30, 0.20), false, "Земля клумбы")
	if grandmas:
		for i in 14:
			var a := i / 14.0 * TAU
			Shape.make(Shape.BOX, bed, Vector3(cos(a) * radius, 0.1, sin(a) * radius), Vector3(0.5, 0.2, 0.25),
				Color(0.75, 0.35, 0.28), false, "Кирпич", Vector3(0, -rad_to_deg(a) + 90, 0))
	for i in count:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * (radius - 0.5)
		var petal: Color = Color(1.0, 0.82, 0.1) if tall else PETALS[_rng.randi() % PETALS.size()]
		_build_flower(bed, Vector3(cos(a) * r, 0, sin(a) * r), petal, grandmas, tall)


func _build_flower(parent: Node3D, local_pos: Vector3, petal: Color, grandmas: bool, tall := false) -> void:
	var flower := Flower.new()
	flower.name = "Подсолнух" if tall else "Цветок"
	flower.position = local_pos
	parent.add_child(flower)
	var h := _rand(1.5, 1.9) if tall else _rand(0.6, 0.9)
	var k := 1.8 if tall else 1.0  # подсолнух крупнее
	var petals: Array[MeshInstance3D] = []
	var head: Node3D

	var scene := Shape.art("flower")
	if scene:
		Shape.place_art(scene, flower, Vector3.ZERO, _rand(0, 360), false)
		head = Shape.node("Голова", flower, Vector3(0, h, 0))
	else:
		Shape.make(Shape.CYLINDER, flower, Vector3(0, h / 2, 0), Vector3(0.05 * k, h / 2, 0.05 * k), Palette.LEAF, false, "Стебель")
		Shape.make(Shape.SPHERE, flower, Vector3(0.08 * k, h * 0.45, 0), Vector3(0.18, 0.03, 0.08) * k, Palette.LEAF, false, "Листок", Vector3(0, 0, 25))
		head = Shape.node("Голова", flower, Vector3(0, h, 0))
		Shape.make(Shape.SPHERE, head, Vector3.ZERO, Vector3(0.16, 0.1, 0.16) * k,
			Color(0.35, 0.22, 0.1) if tall else Color(1, 0.8, 0.2), false, "Серединка")
		var count := 10 if tall else 6
		for p in count:
			var a := p * 360.0 / count
			var dir := Basis(Vector3.UP, deg_to_rad(a)) * Vector3.BACK
			petals.append(Shape.make(Shape.SPHERE, head, dir * 0.14 * k, Vector3(0.12, 0.04, 0.2) * k, petal, false, "Лепесток", Vector3(-12, a, 0)))
	flower.init(head, petals, grandmas)
	flower.prepare(true, false)
	flowers.append(flower)


# ── Постройки ──────────────────────────────────────────────

func _build_house(pos: Vector3) -> void:
	var root := Shape.node("Дом", self, pos)
	var scene := Shape.art("house")
	if scene:
		Shape.place_art(scene, root, Vector3.ZERO, 180.0)
		return
	Shape.make(Shape.BOX, root, Vector3(0, 2.5, 0), Vector3(10, 5, 8), Palette.WALL, true, "Стены")
	Shape.make(Shape.BOX, root, Vector3(0, 5, 0), Vector3(10.6, 5.8, 5.8), Palette.ROOF, true, "Крыша", Vector3(45, 0, 0))
	Shape.make(Shape.BOX, root, Vector3(2.5, 1.1, -4.02), Vector3(1.2, 2.2, 0.06), Palette.WOOD, false, "Дверь")
	for x in [-3.0, -0.5]:
		Shape.make(Shape.BOX, root, Vector3(x, 2.4, -4.03), Vector3(1.5, 1.3, 0.06), Palette.GLASS, false, "Окно")
		Shape.make(Shape.BOX, root, Vector3(x, 2.4, -4.06), Vector3(0.08, 1.3, 0.04), Palette.WHITE, false, "Рама")
		Shape.make(Shape.BOX, root, Vector3(x, 1.68, -4.15), Vector3(1.7, 0.1, 0.3), Palette.WHITE, false, "Подоконник")
	Shape.make(Shape.BOX, root, Vector3(3, 7.2, 1.5), Vector3(0.7, 2, 0.7), Color(0.6, 0.3, 0.25), true, "Труба")


func _build_greenhouse(pos: Vector3) -> void:
	var root := Shape.node("Теплица", self, pos)
	var scene := Shape.art("greenhouse")
	if scene:
		Shape.place_art(scene, root, Vector3.ZERO)
		return
	var w := 6.0
	var d := 4.0
	var h := 3.0
	var panes := [
		[Vector3(0, h / 2, -d / 2), Vector3(w, h, 0.05), Vector3.ZERO],
		[Vector3(0, h / 2, d / 2), Vector3(w, h, 0.05), Vector3.ZERO],
		[Vector3(-w / 2, h / 2, 0), Vector3(0.05, h, d), Vector3.ZERO],
		[Vector3(w / 2, h / 2, 0), Vector3(0.05, h, d), Vector3.ZERO],
		[Vector3(0, h + 0.55, -d / 4), Vector3(w, 0.05, d / 2 + 0.3), Vector3(-28, 0, 0)],
		[Vector3(0, h + 0.55, d / 4), Vector3(w, 0.05, d / 2 + 0.3), Vector3(28, 0, 0)],
	]
	for p in panes:
		Shape.make(Shape.BOX, root, p[0], p[1], Palette.GLASS, false, "Стекло", p[2])
		Shape.add_body(Shape.BOX, root, p[0], p[1], p[2], 0.8)  # стекло пружинит
	for x in [-w / 2, 0.0, w / 2]:
		for z in [-d / 2, d / 2]:
			Shape.make(Shape.BOX, root, Vector3(x, h / 2, z), Vector3(0.08, h, 0.08), Palette.METAL)
	for i in 6:
		var p := Vector3(-2.2 + i * 0.9, 0.6, 0)
		Shape.make(Shape.CYLINDER, root, p, Vector3(0.05, 0.6, 0.05), Palette.LEAF)
		Shape.make(Shape.SPHERE, root, p + Vector3(0.1, 0.3, 0), Vector3.ONE * 0.18, Palette.RED)


func _build_jam_table(pos: Vector3) -> void:
	var root := Shape.node("Стол с вареньем", self, pos)
	var table := Shape.art("table")
	if table:
		Shape.place_art(table, root, Vector3.ZERO)
	else:
		Shape.make(Shape.BOX, root, Vector3(0, 0.8, 0), Vector3(1.8, 0.08, 1.1), Palette.WOOD, true, "Столешница")
		for lp in [Vector3(-0.8, 0.4, -0.45), Vector3(0.8, 0.4, -0.45), Vector3(-0.8, 0.4, 0.45), Vector3(0.8, 0.4, 0.45)]:
			Shape.make(Shape.BOX, root, lp, Vector3(0.08, 0.8, 0.08), Palette.WOOD, true, "Ножка")
		Shape.make(Shape.BOX, root, Vector3(0, 0.845, 0), Vector3(1.6, 0.01, 0.9), Color(0.95, 0.95, 1), false, "Скатерть")

	var jar := Shape.node("Банка", root, Vector3(0.2, 0.85, 0))
	var jar_scene := Shape.art("jam_jar")
	if jar_scene:
		Shape.place_art(jar_scene, jar, Vector3.ZERO)
	else:
		Shape.make(Shape.CYLINDER, jar, Vector3(0, 0.18, 0), Vector3(0.32, 0.18, 0.32), Palette.JAM, true, "Варенье")
		Shape.make(Shape.CYLINDER, jar, Vector3(0, 0.38, 0), Vector3(0.34, 0.03, 0.34), Color(0.9, 0.85, 0.75), false, "Крышка")
		Shape.make(Shape.BOX, jar, Vector3(-0.55, 0.02, 0.1), Vector3(0.05, 0.02, 0.3), Palette.METAL, false, "Ложка")

	var zone := JamZone.new()
	zone.name = "Липкая зона"
	zone.position = Vector3(0.2, 1.4, 0)
	root.add_child(zone)


func _build_fan(pos: Vector3, yaw := 90.0, style := "") -> void:
	var root := Shape.node("Кондиционер" if style == "ac" else "Вентилятор соседа", self, pos)
	root.rotation_degrees.y = yaw  # дует вдоль своей оси +Z
	var scene := Shape.art("fan")
	if style == "ac":
		Shape.make(Shape.BOX, root, Vector3(0, 0, -0.2), Vector3(1.4, 0.8, 0.5), Palette.WHITE, true, "Блок")
		Shape.make(Shape.BOX, root, Vector3(0, -0.2, 0.06), Vector3(1.2, 0.1, 0.04), Palette.METAL, false, "Решётка")
		var blades_ac := Spinner.new()
		blades_ac.name = "Лопасти"
		blades_ac.position = Vector3(0.3, 0.05, 0.06)
		root.add_child(blades_ac)
		for i in 3:
			Shape.make(Shape.BOX, blades_ac, Basis(Vector3.BACK, deg_to_rad(i * 120.0)) * Vector3(0, 0.12, 0), Vector3(0.08, 0.24, 0.01),
				Palette.METAL, false, "Лопасть", Vector3(0, 0, i * 120.0))
	elif scene:
		Shape.place_art(scene, root, Vector3.ZERO)
	else:
		Shape.make(Shape.CYLINDER, root, Vector3(0, 0.04, 0), Vector3(0.6, 0.04, 0.6), Palette.WHITE, true, "Подставка")
		Shape.make(Shape.CYLINDER, root, Vector3(0, 0.9, 0), Vector3(0.06, 0.9, 0.06), Palette.METAL, true, "Стойка")
		Shape.make(Shape.SPHERE, root, Vector3(0, 1.85, -0.1), Vector3(0.35, 0.35, 0.4), Palette.WHITE, true, "Мотор")
		var blades := Spinner.new()
		blades.name = "Лопасти"
		blades.position = Vector3(0, 1.85, 0.15)
		root.add_child(blades)
		for i in 3:
			var a := i * 120.0
			Shape.make(Shape.BOX, blades, Basis(Vector3.BACK, deg_to_rad(a)) * Vector3(0, 0.32, 0), Vector3(0.18, 0.6, 0.02),
				Color(0.55, 0.75, 0.95), false, "Лопасть", Vector3(0, 12, a))
	var zone := FanZone.new()
	zone.name = "Поток воздуха"
	zone.position = Vector3(0, 0.0 if style == "ac" else 1.9, 0)
	root.add_child(zone)


func _build_trash_can(pos: Vector3, wasp_count: int, style := "") -> void:
	var root := Shape.node("Мусорка", self, pos)
	var scene := Shape.art("trash_can")
	if style == "dumpster":
		Shape.make(Shape.BOX, root, Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.1), Color(0.2, 0.42, 0.62), true, "Контейнер")
		Shape.make(Shape.BOX, root, Vector3(0, 1.24, -0.1), Vector3(1.85, 0.06, 1.0), Color(0.15, 0.3, 0.45), false, "Крышка", Vector3(-14, 0, 0))
		Shape.make(Shape.BOX, root, Vector3(1.1, 0.12, 0.3), Vector3(0.4, 0.24, 0.3), Color(0.85, 0.85, 0.8), false, "Пакет")
	elif scene:
		Shape.place_art(scene, root, Vector3.ZERO)
	else:
		Shape.make(Shape.CYLINDER, root, Vector3(0, 0.6, 0), Vector3(0.9, 0.6, 0.9), Color(0.25, 0.45, 0.3), true, "Бак")
		Shape.make(Shape.CYLINDER, root, Vector3(0.1, 1.25, 0), Vector3(0.95, 0.05, 0.95), Color(0.2, 0.38, 0.25), false, "Крышка", Vector3(0, 0, 12))
		Shape.make(Shape.BOX, root, Vector3(0.7, 0.08, 0.4), Vector3(0.4, 0.16, 0.3), Color(0.85, 0.85, 0.8), false, "Пакет")
	for i in wasp_count:
		wasps.append(Wasp.spawn(self, pos + Vector3(i * 1.2 - 0.6, 2.6, 0)))


func _build_clothesline(a: Vector3, b: Vector3) -> void:
	var root := Shape.node("Бельё", self)
	Shape.make(Shape.CYLINDER, root, a + Vector3(0, 1.4, 0), Vector3(0.1, 1.4, 0.1), Palette.WOOD, true, "Столб")
	Shape.make(Shape.CYLINDER, root, b + Vector3(0, 1.4, 0), Vector3(0.1, 1.4, 0.1), Palette.WOOD, true, "Столб")
	var mid := (a + b) / 2 + Vector3(0, 2.6, 0)
	Shape.make(Shape.CYLINDER, root, mid, Vector3(0.02, a.distance_to(b) / 2, 0.02), Palette.WHITE, false, "Верёвка", Vector3(0, 0, 90))
	var colors := [Palette.WHITE, Color(0.7, 0.85, 1), Color(1, 0.75, 0.8)]
	for i in 3:
		var hinge := Sway.new()
		hinge.name = "Простыня"
		hinge.position = a.lerp(b, (i + 1) / 4.0) + Vector3(0, 2.6, 0)
		root.add_child(hinge)
		Shape.make(Shape.BOX, hinge, Vector3(0, -0.75, 0), Vector3(2.4, 1.5, 0.04), colors[i], false, "Ткань")
		# Твёрдая часть не качается вместе с тканью — так физике проще
		Shape.box_body(root, hinge.position + Vector3(0, -0.75, 0), Vector3(2.4, 1.5, 0.12))


func _build_tree(pos: Vector3, birch := false, poplar := false) -> void:
	var root := Shape.node("Дерево", self, pos)
	var yaw := _rand(0, 360)
	var scene := Shape.art("tree")
	if scene and not birch and not poplar:
		Shape.place_art(scene, root, Vector3.ZERO, yaw)
		return
	var s := _rand(0.85, 1.25)
	if poplar:
		Shape.make(Shape.CYLINDER, root, Vector3(0, 1.2 * s, 0), Vector3(0.4, 1.2 * s, 0.4), Palette.TRUNK, true, "Ствол")
		Shape.make(Shape.SPHERE, root, Vector3(0, 5.0 * s, 0), Vector3(2.2, 7.0, 2.2) * s, Color(0.28, 0.55, 0.22), true, "Крона")
		return
	var trunk := Color(0.92, 0.92, 0.88) if birch else Palette.TRUNK
	Shape.make(Shape.CYLINDER, root, Vector3(0, 1.2 * s, 0), Vector3(0.45, 1.2 * s, 0.45), trunk, true, "Ствол")
	if birch:
		for i in 4:
			Shape.make(Shape.BOX, root, Vector3(0, 0.4 + i * 0.5, 0.2), Vector3(0.18, 0.05, 0.1), Palette.BLACK, false, "Пятно берёзы")
	Shape.make(Shape.SPHERE, root, Vector3(0, 3.6 * s, 0), Vector3(3.2, 2.6, 3.2) * s, Color(0.42, 0.7, 0.3) if birch else Palette.LEAF, true, "Крона")
	Shape.make(Shape.SPHERE, root, Vector3(0.9, 4.3 * s, 0.4), Vector3(2, 1.8, 2) * s, Color(0.3, 0.62, 0.26), false, "Крона")
	Shape.make(Shape.SPHERE, root, Vector3(-0.8, 4.1 * s, -0.5), Vector3(1.8, 1.6, 1.8) * s, Color(0.22, 0.5, 0.2), false, "Крона")


func _build_car(pos: Vector3, style := "") -> void:
	_car = Shape.node("Трактор" if style == "tractor" else "Машина", self, pos)
	_car_home = pos
	car_door = Shape.node("Дверь водителя", _car, Vector3(0.3, 0, 1.4))  # со стороны участка (+Z)
	var scene := Shape.art("tractor" if style == "tractor" else "car")
	if style == "tractor" and scene == null:
		var red := Color(0.8, 0.2, 0.15)
		Shape.make(Shape.BOX, _car, Vector3(0.6, 0.9, 0), Vector3(2.4, 0.8, 1.2), red, false, "Капот")
		Shape.make(Shape.BOX, _car, Vector3(-0.8, 1.6, 0), Vector3(1.4, 1.6, 1.4), red, false, "Кабина")
		Shape.make(Shape.BOX, _car, Vector3(-0.8, 1.9, 0), Vector3(1.3, 0.8, 1.42), Palette.GLASS, false, "Окна")
		Shape.make(Shape.CYLINDER, _car, Vector3(1.3, 1.6, 0.3), Vector3(0.12, 0.4, 0.12), Palette.BLACK, false, "Труба")
		for z in [-0.85, 0.85]:
			Shape.make(Shape.CYLINDER, _car, Vector3(-1.0, 0.75, z), Vector3(1.5, 0.2, 1.5), Palette.BLACK, false, "Большое колесо", Vector3(90, 0, 0))
			Shape.make(Shape.CYLINDER, _car, Vector3(1.4, 0.45, z), Vector3(0.9, 0.15, 0.9), Palette.BLACK, false, "Колесо", Vector3(90, 0, 0))
		Shape.box_body(_car, Vector3(0, 1.1, 0), Vector3(4.0, 2.2, 1.9))
		return
	if scene:
		Shape.place_art(scene, _car, Vector3.ZERO)
		return
	var paint := Color(0.55, 0.72, 0.86)
	Shape.make(Shape.BOX, _car, Vector3(0, 0.72, 0), Vector3(4.2, 0.7, 1.8), paint, false, "Кузов")
	Shape.make(Shape.BOX, _car, Vector3(-0.25, 1.45, 0), Vector3(2.2, 0.75, 1.64), paint, false, "Салон")
	Shape.make(Shape.BOX, _car, Vector3(-0.25, 1.5, 0), Vector3(2.0, 0.5, 1.66), Palette.GLASS, false, "Окна")
	Shape.make(Shape.BOX, _car, Vector3(-0.25, 1.86, 0), Vector3(1.6, 0.06, 1.4), Palette.METAL, false, "Багажник на крыше")
	for z in [-0.6, 0.6]:
		Shape.make(Shape.SPHERE, _car, Vector3(2.1, 0.8, z), Vector3(0.08, 0.22, 0.22), Color(1, 0.97, 0.8), false, "Фара")
	for x in [-2.15, 2.15]:
		Shape.make(Shape.BOX, _car, Vector3(x, 0.45, 0), Vector3(0.12, 0.16, 1.84), Palette.METAL, false, "Бампер")
	for x in [-1.35, 1.35]:
		for z in [-0.92, 0.92]:
			Shape.make(Shape.CYLINDER, _car, Vector3(x, 0.34, z), Vector3(0.68, 0.12, 0.68), Palette.BLACK, false, "Колесо", Vector3(90, 0, 0))
	Shape.box_body(_car, Vector3(0, 0.95, 0), Vector3(4.3, 1.9, 1.85))


# ── Постройки двора ────────────────────────────────────────

func _build_khrushchevka(pos: Vector3, length: float, yaw: float) -> void:
	var root := Shape.node("Хрущёвка", self, pos)
	root.rotation_degrees.y = yaw
	var depth := 10.0
	var height := 15.0
	Shape.make(Shape.BOX, root, Vector3(0, height / 2, 0), Vector3(length, height, depth), Color(0.82, 0.78, 0.7), true, "Стены")
	Shape.make(Shape.BOX, root, Vector3(0, height + 0.15, 0), Vector3(length + 0.4, 0.3, depth + 0.4), Color(0.4, 0.4, 0.42), false, "Крыша")
	var cols := int(length / 3.2)
	for floor_i in 5:
		for c in cols:
			var x := -length / 2 + 1.6 + c * 3.2
			var y := 1.6 + floor_i * 2.8
			Shape.make(Shape.BOX, root, Vector3(x, y, -depth / 2 - 0.02), Vector3(1.4, 1.5, 0.04), Color(0.45, 0.6, 0.72), false, "Окно")
			if (c + floor_i) % 5 == 0:
				Shape.make(Shape.BOX, root, Vector3(x, y - 0.9, -depth / 2 - 0.5), Vector3(2.2, 0.12, 1.0), Color(0.7, 0.68, 0.64), false, "Балкон")
	for e in 3:
		var x := -length / 3 + e * length / 3
		Shape.make(Shape.BOX, root, Vector3(x, 1.1, -depth / 2 - 0.03), Vector3(1.4, 2.2, 0.06), Color(0.35, 0.25, 0.18), false, "Подъезд")
		Shape.make(Shape.BOX, root, Vector3(x, 2.5, -depth / 2 - 0.7), Vector3(2.4, 0.12, 1.4), Color(0.6, 0.6, 0.6), false, "Козырёк")


func _build_garages(pos: Vector3, count: int) -> void:
	var root := Shape.node("Гаражи", self, pos)
	var colors := [Color(0.55, 0.55, 0.6), Color(0.6, 0.42, 0.3), Color(0.35, 0.5, 0.42), Color(0.62, 0.6, 0.45)]
	for i in count:
		var z := -count * 1.8 + i * 3.6
		Shape.make(Shape.BOX, root, Vector3(0, 1.25, z), Vector3(5, 2.5, 3.5), Color(0.66, 0.64, 0.6), true, "Гараж")
		Shape.make(Shape.BOX, root, Vector3(-2.52, 1.0, z), Vector3(0.05, 2.0, 2.8), colors[i % colors.size()], false, "Ворота")
		Shape.make(Shape.BOX, root, Vector3(0, 2.55, z), Vector3(5.2, 0.1, 3.6), Color(0.3, 0.3, 0.32), false, "Рубероид")


func _build_playground(pos: Vector3) -> void:
	var root := Shape.node("Детская площадка", self, pos)
	# Горка
	Shape.make(Shape.BOX, root, Vector3(-2, 1.0, 0), Vector3(1.0, 2.0, 1.0), Color(0.9, 0.3, 0.25), true, "Башенка")
	Shape.make(Shape.BOX, root, Vector3(-0.4, 0.9, 0), Vector3(2.6, 0.08, 0.9), Color(0.95, 0.8, 0.2), true, "Скат", Vector3(0, 0, -35))
	# Качели — перекладина на высоте полёта
	for x in [1.5, 4.5]:
		Shape.make(Shape.CYLINDER, root, Vector3(x, 1.25, -1), Vector3(0.12, 1.25, 0.12), Palette.METAL, true, "Стойка")
		Shape.make(Shape.CYLINDER, root, Vector3(x, 1.25, 1), Vector3(0.12, 1.25, 0.12), Palette.METAL, true, "Стойка")
	Shape.make(Shape.CYLINDER, root, Vector3(3, 2.5, -1), Vector3(0.1, 1.6, 0.1), Palette.METAL, true, "Перекладина", Vector3(0, 0, 90))
	Shape.make(Shape.CYLINDER, root, Vector3(3, 2.5, 1), Vector3(0.1, 1.6, 0.1), Palette.METAL, true, "Перекладина", Vector3(0, 0, 90))
	var swing := Sway.new()
	swing.name = "Качели"
	swing.position = Vector3(3, 2.5, 0)
	swing.angle = 20.0
	root.add_child(swing)
	Shape.make(Shape.BOX, swing, Vector3(0, -1.9, 0), Vector3(0.9, 0.08, 0.5), Color(0.2, 0.5, 0.85), false, "Сиденье")
	# Песочница
	Shape.make(Shape.BOX, root, Vector3(0, 0.15, 4), Vector3(3, 0.3, 3), Palette.WOOD, false, "Песочница")
	Shape.make(Shape.BOX, root, Vector3(0, 0.2, 4), Vector3(2.7, 0.3, 2.7), Color(0.92, 0.82, 0.55), false, "Песок")


func _build_bench_with_babushka(pos: Vector3) -> void:
	var root := Shape.node("Лавка с бабушкой", self, pos)
	Shape.make(Shape.BOX, root, Vector3(0, 0.45, 0), Vector3(2.2, 0.08, 0.5), Palette.WOOD, true, "Лавка")
	Shape.make(Shape.BOX, root, Vector3(0, 0.75, 0.25), Vector3(2.2, 0.5, 0.06), Palette.WOOD, false, "Спинка")
	# Бабушка в платке
	Shape.make(Shape.SPHERE, root, Vector3(0.4, 0.85, 0), Vector3(0.6, 0.8, 0.5), Color(0.55, 0.3, 0.45), false, "Пальто")
	Shape.make(Shape.SPHERE, root, Vector3(0.4, 1.4, -0.02), Vector3(0.32, 0.34, 0.32), Color(0.98, 0.8, 0.68), false, "Лицо")
	Shape.make(Shape.SPHERE, root, Vector3(0.4, 1.47, 0.04), Vector3(0.38, 0.32, 0.38), Color(0.9, 0.2, 0.25), false, "Платок")
	# Банка варенья рядом — липкая зона
	Shape.make(Shape.CYLINDER, root, Vector3(-0.4, 0.66, 0), Vector3(0.3, 0.16, 0.3), Palette.JAM, false, "Варенье")
	var zone := JamZone.new()
	zone.name = "Липкая зона"
	zone.position = Vector3(-0.4, 1.6, 0)
	root.add_child(zone)


func _build_tire_bed(center: Vector3) -> void:
	_build_flower_bed(center, 2.0, 5, false)
	for i in 8:
		var a := i / 8.0 * TAU
		Shape.make(Shape.CYLINDER, self, center + Vector3(cos(a) * 2.0, 0.18, sin(a) * 2.0), Vector3(0.6, 0.12, 0.6),
			[Color(0.9, 0.3, 0.3), Color(0.95, 0.85, 0.2), Color(0.3, 0.6, 0.9)][i % 3], false, "Шина", Vector3(90, rad_to_deg(-a), 0))


# ── Постройки поля ─────────────────────────────────────────

func _build_windmill(pos: Vector3) -> void:
	var root := Shape.node("Мельница", self, pos)
	Shape.make(Shape.CYLINDER, root, Vector3(0, 4, 0), Vector3(3.2, 4, 3.2), Color(0.85, 0.82, 0.75), true, "Башня")
	Shape.make(Shape.SPHERE, root, Vector3(0, 8.4, 0), Vector3(3.6, 2.2, 3.6), Palette.ROOF, false, "Купол")
	var blades := Spinner.new()
	blades.name = "Крылья"
	blades.position = Vector3(0, 7, -1.8)
	blades.speed_deg = 60.0
	root.add_child(blades)
	for i in 4:
		Shape.make(Shape.BOX, blades, Basis(Vector3.BACK, deg_to_rad(i * 90.0)) * Vector3(0, 2.6, 0), Vector3(0.9, 5.2, 0.08),
			Palette.WOOD_LIGHT, false, "Крыло мельницы", Vector3(0, 0, i * 90.0))
	# Ветер от мельницы сдувает пчёл к югу
	var zone := FanZone.new()
	zone.name = "Ветер мельницы"
	zone.position = Vector3(0, 2.2, -2.5)
	zone.rotation_degrees.y = 180.0
	root.add_child(zone)


func _build_barn(pos: Vector3) -> void:
	var root := Shape.node("Сарай", self, pos)
	Shape.make(Shape.BOX, root, Vector3(0, 2.5, 0), Vector3(8, 5, 6), Color(0.68, 0.18, 0.15), true, "Стены")
	Shape.make(Shape.BOX, root, Vector3(0, 5, 0), Vector3(8.4, 4.4, 4.4), Color(0.35, 0.3, 0.28), true, "Крыша", Vector3(45, 0, 0))
	Shape.make(Shape.BOX, root, Vector3(0, 1.6, -3.03), Vector3(3, 3.2, 0.06), Palette.WHITE, false, "Ворота")


func _build_scarecrow(pos: Vector3) -> void:
	var root := Shape.node("Пугало", self, pos)
	Shape.make(Shape.CYLINDER, root, Vector3(0, 1.3, 0), Vector3(0.12, 1.3, 0.12), Palette.WOOD, true, "Шест")
	Shape.make(Shape.CYLINDER, root, Vector3(0, 2.0, 0), Vector3(0.1, 1.0, 0.1), Palette.WOOD, false, "Руки", Vector3(0, 0, 90))
	Shape.make(Shape.BOX, root, Vector3(0, 1.8, 0), Vector3(0.9, 0.9, 0.35), Color(0.3, 0.45, 0.7), false, "Рубаха")
	Shape.make(Shape.SPHERE, root, Vector3(0, 2.6, 0), Vector3(0.5, 0.5, 0.5), Color(0.9, 0.8, 0.5), false, "Голова-мешок")
	Shape.make(Shape.CYLINDER, root, Vector3(0, 2.9, 0), Vector3(0.9, 0.04, 0.9), Color(0.85, 0.7, 0.35), false, "Соломенная шляпа")
	wasps.append(Wasp.spawn(self, pos + Vector3(-0.6, 3.2, 0)))
	wasps.append(Wasp.spawn(self, pos + Vector3(0.6, 3.2, 0)))


func _build_picnic(pos: Vector3) -> void:
	var root := Shape.node("Пикник", self, pos)
	Shape.make(Shape.BOX, root, Vector3(0, 0.02, 0), Vector3(3, 0.02, 2.2), Color(0.9, 0.3, 0.3), false, "Покрывало")
	for i in 4:
		Shape.make(Shape.BOX, root, Vector3(-1.1 + i * 0.75, 0.025, 0), Vector3(0.35, 0.02, 2.2), Palette.WHITE, false, "Клетка")
	Shape.make(Shape.CYLINDER, root, Vector3(0.4, 0.2, 0.2), Vector3(0.32, 0.18, 0.32), Palette.JAM, false, "Варенье")
	Shape.make(Shape.BOX, root, Vector3(-0.6, 0.15, -0.3), Vector3(0.8, 0.3, 0.5), Palette.WOOD_LIGHT, false, "Корзинка")
	var zone := JamZone.new()
	zone.name = "Липкая зона"
	zone.position = Vector3(0.4, 1.6, 0.2)
	root.add_child(zone)


func _build_haystack(pos: Vector3) -> void:
	var s := _rand(0.9, 1.3)
	Shape.make(Shape.SPHERE, self, pos + Vector3(0, 1.2 * s, 0), Vector3(3.0, 2.8, 3.0) * s, Color(0.88, 0.76, 0.38), true, "Стог")


# ── Вылет ──────────────────────────────────────────────────

## Перед вылетом: где сегодня цветёт, где бабкин цветок, осы по местам.
func prepare_sortie() -> void:
	var grandmas: Array[Flower] = []
	for f in flowers:
		f.prepare(randf() < 0.75, false)
		if f.grandmas_bed:
			grandmas.append(f)
	if not grandmas.is_empty():
		grandmas[randi() % grandmas.size()].prepare(true, true)
	for w in wasps:
		w.reset_to_home()
	_clear_dynamic()
	_set_swarm(false)
	wind = Vector3.ZERO
	_gust_end = 0.0
	_next_gust = Game.clock + randf_range(10.0, 16.0)


func end_sortie() -> void:
	_clear_dynamic()
	_set_swarm(true)
	wind = Vector3.ZERO
	for w in wasps:
		w.reset_to_home()


## Декоративный рой у улья: виден в меню, прячется в игре.
func _set_swarm(on: bool) -> void:
	if _swarm:
		_swarm.visible = on
		_swarm.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func anger_bees() -> void:
	if _swarm:
		_swarm.angry = true


func _clear_dynamic() -> void:
	for c in dynamic.get_children():
		c.queue_free()


func nearest_flower(pos: Vector3, max_horizontal: float) -> Flower:
	var best: Flower = null
	var best_sq := max_horizontal * max_horizontal
	for f in flowers:
		if not f.has_pollen():
			continue
		var d := f.head_pos() - pos
		d.y = 0.0
		var sq := d.length_squared()
		if sq < best_sq:
			best_sq = sq
			best = f
	return best


# ── Побег (за людей) ───────────────────────────────────────

func prepare_escape() -> void:
	_clear_dynamic()
	wind = Vector3.ZERO
	for w in wasps:
		w.reset_to_home()
	_set_swarm(false)  # вместо роя — боты матча
	_reset_car()


func end_escape() -> void:
	_clear_dynamic()
	_set_swarm(true)
	_reset_car()


## Машина уезжает за ворота (концовка «сбежал»).
func drive_car(delta: float) -> void:
	_car_speed = minf(_car_speed + 9.0 * delta, 16.0)
	_car.position += Vector3.RIGHT * _car_speed * delta


func _reset_car() -> void:
	_car.position = _car_home
	_car_speed = 0.0


func _process(_delta: float) -> void:
	var game := Game.I
	if game == null or game.state != Game.State.SORTIE:
		wind = Vector3.ZERO
		return
	# Порывы ветра: плавно нарастают и стихают
	var t := Game.clock
	if t >= _next_gust and t > _gust_end:
		_gust_start = t
		_gust_end = t + randf_range(2.0, 3.5)
		_next_gust = _gust_end + randf_range(8.0, 14.0)
		var d := Vector2.from_angle(randf() * TAU)
		_gust_dir = Vector3(d.x, 0, d.y)
		game.say(Lines.pick(Lines.WIND), 2.0)
	if t < _gust_end:
		var k := inverse_lerp(_gust_start, _gust_end, t)
		wind = _gust_dir * sin(k * PI) * 6.0
	else:
		wind = Vector3.ZERO
