class_name Game
extends Node3D
## Главный дирижёр: вопрос деда → пасека (меню) → вылет пчелы или побег дачника → итоги.
## Всё собирается кодом при запуске, сцена main.tscn почти пустая.

enum State { QUESTION, HUB, SORTIE, ESCAPE, RESULTS }

const SORTIE_LENGTH := 180.0

static var I: Game
## Игровые часы (учитывают ускорение времени в автотесте).
static var clock := 0.0

var state: int = State.QUESTION
var world: World
var cam: FollowCamera
var ui: Screens
var bee: Bee
var stats: SortieStats
var time_left := 0.0
var escape: EscapeMatch

var _time_low_said := false


func _ready() -> void:
	I = self
	clock = 0.0
	var autotest := "--autotest" in OS.get_cmdline_user_args()
	if autotest:
		Profile.use_test_storage()

	world = World.new()
	world.name = "Дача"
	add_child(world)
	world.build()

	cam = FollowCamera.new()
	cam.name = "Камера"
	add_child(cam)
	cam.setup(world)

	ui = Screens.new()
	ui.name = "Интерфейс"
	add_child(ui)
	ui.build()

	if Profile.current().side == Profile.Side.NONE:
		show_question()
	else:
		show_hub()

	if autotest:
		var t := Autotest.new()
		t.name = "Автотест"
		add_child(t)


func _process(delta: float) -> void:
	clock += delta
	if state != State.SORTIE:
		return
	time_left -= delta
	if not _time_low_said and time_left < 20.0:
		_time_low_said = true
		say(Lines.pick(Lines.TIME_LOW))
	if time_left <= 0.0:
		end_sortie()


# ── Вопрос и меню ──────────────────────────────────────────

func show_question() -> void:
	state = State.QUESTION
	cam.show_hub()
	ui.show_question()


func answer(side: int) -> void:
	Profile.current().answer(side)
	say(Lines.pick(Lines.ANSWERED_BEE if side == Profile.Side.BEE else Lines.ANSWERED_HUMAN), 3.0)
	if side == Profile.Side.HUMAN:
		world.anger_bees()
	show_hub()


func show_hub() -> void:
	state = State.HUB
	cam.show_hub()
	ui.show_hub()


# ── Вылет пчелы ────────────────────────────────────────────

func start_sortie() -> void:
	if Profile.current().side != Profile.Side.BEE:
		return
	stats = SortieStats.new()
	time_left = SORTIE_LENGTH
	_time_low_said = false
	world.prepare_sortie()
	bee = Bee.spawn(world, world.bee_spawn)
	cam.follow(bee, 1.5)
	state = State.SORTIE
	ui.show_hud()


func end_sortie() -> void:
	if state != State.SORTIE:
		return
	if is_instance_valid(bee):
		stats.pollen_lost += bee.pollen  # не донесённая до улья пыльца пропадает
		bee.queue_free()
	bee = null
	world.end_sortie()

	var p := Profile.current()
	p.honey += stats.honey_made
	p.sorties += 1
	var record := stats.honey_made > p.best_sortie_honey
	if record:
		p.best_sortie_honey = stats.honey_made
	p.save()

	state = State.RESULTS
	cam.show_hub()
	ui.show_results(stats, record)


# ── Побег за людей ─────────────────────────────────────────

func start_escape() -> void:
	if Profile.current().side != Profile.Side.HUMAN:
		return
	world.prepare_escape()
	escape = EscapeMatch.begin(world, self)
	cam.follow(escape.human, 0.9)
	state = State.ESCAPE
	ui.show_escape_hud()
	say(Lines.pick(Lines.ESCAPE_START), 3.0)


## Матч зовёт, когда концовка доиграна; кнопка «Сдаться» — досрочно.
func end_escape() -> void:
	if state != State.ESCAPE or escape == null:
		return
	var s := escape.stats
	if s.ending == "":
		s.ending = "gaveup"
	escape.queue_free()
	escape = null
	world.end_escape()

	var p := Profile.current()
	p.escape_attempts += 1
	var record := false
	if s.escaped:
		p.escape_wins += 1
		record = p.best_escape_time <= 0.0 or s.time < p.best_escape_time
		if record:
			p.best_escape_time = s.time
	p.save()

	state = State.RESULTS
	cam.show_hub()
	ui.show_escape_results(s, record)


# ── Реплики ────────────────────────────────────────────────

func say(line: String, seconds := 2.5) -> void:
	if ui:
		ui.say(line, seconds)


func toast(text: String) -> void:
	if ui:
		ui.toast(text)
