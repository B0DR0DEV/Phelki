class_name FlappyMode
extends Node3D
## Флаппи-пчела: пчела сама летит вперёд, тап — взмах вверх.
## Пролетай между досками забора и водосточными трубами. Задел — всё.
## Играют обе стороны: даже неуважающим иногда хочется побыть пчелой.

const ORIGIN := Vector3(0, 0, 1000)  # далеко от дачи, туман её скрывает
const GRAVITY := 22.0
const FLAP := 7.6
const SPEED_START := 5.0
const SPACING := 6.5
const CEILING := 9.0
const FLOOR := 0.5
const RADIUS := 0.3

var score := 0
var started := false
var dead := false

var _game: Game
var _cam: Camera3D
var _bee: Node3D
var _y := 4.0
var _vy := 0.0
var _x := 0.0
var _speed := SPEED_START
var _obstacles: Array[Dictionary] = []  # {x, gap_lo, gap_hi, node, passed}
var _next_x := 12.0
var _dead_at := 0.0
var _ui := {}


static func begin(game: Game) -> FlappyMode:
	var m := FlappyMode.new()
	m.name = "Флаппи-пчела"
	m._game = game
	game.add_child(m)
	m.global_position = ORIGIN
	m._setup()
	return m


func _setup() -> void:
	# Небо, земля, дальние кусты
	Shape.make(Shape.BOX, self, Vector3(200, -0.5 + FLOOR, 0), Vector3(500, 1, 12), Palette.GRASS)
	for i in 60:
		Shape.make(Shape.SPHERE, self, Vector3(i * 7.0 - 10, FLOOR + 0.6, 4 + randf() * 2), Vector3(3, 2, 2) * randf_range(0.8, 1.3),
			Palette.LEAF.lerp(Palette.GRASS_DARK, randf()), false, "Куст")
	var wf := WingFlap.new()
	wf.name = "Пчела"
	wf.speed = 55.0
	var scene := Shape.art("bee")
	if scene:
		Shape.place_art(scene, wf, Vector3.ZERO, 0.0, false)
	else:
		BeeVisual.build_placeholder(wf, false)
	add_child(wf)
	_bee = wf

	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.make_current()
	for i in 8:
		_spawn_obstacle()
	_build_hud()


func _build_hud() -> void:
	var ui := _game.ui
	var s := ui.new_screen("Флаппи")
	ui.place_say(0.73, 0.82)
	_ui["score"] = UiKit.label(s, "0", 140, 0.2, 0.82, 0.8, 0.96, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	_ui["best"] = UiKit.label(s, "Рекорд: %d" % Profile.current().flappy_best, 34, 0.2, 0.78, 0.8, 0.83, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
	_ui["hint"] = UiKit.label(s, "Тапай по экрану — пчела взлетает", 46, 0.08, 0.3, 0.92, 0.4, HORIZONTAL_ALIGNMENT_CENTER, UiKit.HONEY_BG, true)
	UiKit.button(s, "Выйти", 0.72, 0.9, 0.97, 0.95, UiKit.SHADE, Color.WHITE, func(): give_up(), 34)


func _spawn_obstacle() -> void:
	var gap := lerpf(3.2, 2.4, clampf(_obstacles.size() / 40.0, 0.0, 1.0))
	var center := randf_range(FLOOR + 1.6 + gap / 2, CEILING - 1.4 - gap / 2)
	var lo := center - gap / 2
	var hi := center + gap / 2
	var node := Shape.node("Препятствие", self, Vector3(_next_x, 0, 0))
	var pipe := randi() % 2 == 0
	if pipe:
		# Водосточная труба сверху и снизу
		Shape.make(Shape.CYLINDER, node, Vector3(0, (FLOOR + lo) / 2, 0), Vector3(0.9, (lo - FLOOR) / 2, 0.9), Palette.METAL)
		Shape.make(Shape.CYLINDER, node, Vector3(0, (hi + CEILING) / 2, 0), Vector3(0.9, (CEILING - hi) / 2, 0.9), Palette.METAL)
		Shape.make(Shape.CYLINDER, node, Vector3(0, lo - 0.1, 0), Vector3(1.1, 0.12, 1.1), Palette.METAL.darkened(0.2))
		Shape.make(Shape.CYLINDER, node, Vector3(0, hi + 0.1, 0), Vector3(1.1, 0.12, 1.1), Palette.METAL.darkened(0.2))
	else:
		# Доски забора
		Shape.make(Shape.BOX, node, Vector3(0, (FLOOR + lo) / 2, 0), Vector3(0.9, lo - FLOOR, 0.3), Palette.WOOD)
		Shape.make(Shape.BOX, node, Vector3(0, (hi + CEILING) / 2, 0), Vector3(0.9, CEILING - hi, 0.3), Palette.WOOD)
	# Пыльца в проёме — для красоты
	Shape.make(Shape.SPHERE, node, Vector3(0, center, 0), Vector3.ONE * 0.3, Palette.GOLD, false, "Пыльца")
	_obstacles.append({"x": _next_x, "lo": lo, "hi": hi, "node": node, "passed": false})
	_next_x += SPACING


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		flap()


func flap() -> void:
	if dead:
		return
	if not started:
		started = true
		(_ui["hint"] as Label).text = ""
	_vy = FLAP


func _process(delta: float) -> void:
	if dead:
		if Game.clock - _dead_at > 1.2:
			_end()
		_place(delta)
		return
	if started:
		_vy -= GRAVITY * delta
		_y += _vy * delta
		_x += _speed * delta
		_speed = SPEED_START + score * 0.08
	else:
		_y = 4.0 + sin(Game.clock * 3.0) * 0.3

	if _y < FLOOR + RADIUS or _y > CEILING - RADIUS:
		_die()
	for o in _obstacles:
		if absf(o["x"] - _x) < 0.45 + RADIUS and (_y - RADIUS < o["lo"] or _y + RADIUS > o["hi"]):
			_die()
		if not o["passed"] and o["x"] < _x:
			o["passed"] = true
			score += 1
			(_ui["score"] as Label).text = str(score)
			if score % 10 == 0:
				_game.say(["Во даёт!", "Уважаю такую пчелу!", "Ещё чуть-чуть!"][randi() % 3], 1.5)
	# Подкидываем новые препятствия впереди, старые убираем
	while _obstacles.size() > 0 and _obstacles[0]["x"] < _x - 10.0:
		(_obstacles[0]["node"] as Node).queue_free()
		_obstacles.pop_front()
	while _next_x < _x + 50.0:
		_spawn_obstacle()
	_place(delta)


func _place(_delta: float) -> void:
	_bee.position = Vector3(_x, _y, 0)
	var pitch := clampf(-_vy * 6.0, -35.0, 70.0)
	_bee.basis = Basis.from_euler(Vector3(deg_to_rad(pitch), PI / 2, 0.0))
	_cam.position = Vector3(_x + 3.0, 4.6, -11.0)
	_cam.look_at(global_position + Vector3(_x + 3.0, 4.2, 0), Vector3.UP)


func _die() -> void:
	if dead:
		return
	dead = true
	_dead_at = Game.clock
	_vy = -4.0
	Game.vibrate(80)
	_game.say(["Бум! Об забор.", "Эх, трубу не заметила.", "Ну кто так летает..."][randi() % 3], 2.0)


func give_up() -> void:
	dead = true
	_end()


func _end() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var p := Profile.current()
	var record := score > p.flappy_best
	if record:
		p.flappy_best = score
	_game.end_mode({
		"title": "Флаппи-пчела",
		"big": "%d" % score,
		"color": UiKit.DEEP_HONEY,
		"body": "Пролетела препятствий: %d\nРекорд: %d" % [score, p.flappy_best],
		"record": "Новый рекорд!" if record else "",
		"honey": score / 5,
		"footer": "+%d мёда (1 за каждые 5 препятствий)" % (score / 5),
	})
