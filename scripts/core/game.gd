class_name Game
extends Node3D
## Главный дирижёр: вопрос деда → пасека (меню режимов) → режим → итоги.
## Всё собирается кодом при запуске, сцена main.tscn почти пустая.
## С ключом «-- --server» запускается выделенный сервер онлайн-охоты без интерфейса.

enum State { QUESTION, HUB, SORTIE, ESCAPE, MODE, RESULTS, ONLINE }

const SORTIE_LENGTH := 180.0

static var I: Game
## Игровые часы (учитывают ускорение времени в автотесте).
static var clock := 0.0
## Выделенный сервер: без интерфейса и без сохранения профиля.
static var server_mode := false

var state: int = State.QUESTION
var world: World
var cam: FollowCamera
var ui: Screens
var net: Net
var bee: Bee
var stats: SortieStats
var time_left := 0.0
var escape: EscapeMatch
var mode: Node  # перегонки, Флаппи, медведь — текущий особый режим
var fpv := false  # вид от первого лица
var mode_id := ""  # какой режим сейчас (для «Ещё раз» и обучения)

var _time_low_said := false


func _ready() -> void:
	I = self
	clock = 0.0
	var args := OS.get_cmdline_user_args()
	server_mode = "--server" in args
	var autotest := "--autotest" in args
	if autotest:
		Profile.use_test_storage()
	var p := Profile.current()
	fpv = p.fpv

	cam = FollowCamera.new()
	cam.name = "Камера"
	add_child(cam)
	_build_world(p.map_id)

	if not server_mode:
		ui = Screens.new()
		ui.name = "Интерфейс"
		add_child(ui)
		ui.build()

	net = Net.new()
	net.name = "Net"
	add_child(net)

	if server_mode:
		net.start_server(args)
		return

	if p.side == Profile.Side.NONE:
		show_question()
	else:
		show_hub()

	if autotest:
		var t := Autotest.new()
		t.name = "Автотест"
		add_child(t)


func _exit_tree() -> void:
	BeeVisual.free_templates()


func _build_world(id: String) -> void:
	if world:
		remove_child(world)
		world.queue_free()
	world = World.new()
	world.name = "Мир"
	add_child(world)
	move_child(world, 0)
	world.build(id)
	cam.setup(world)


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


static func vibrate(ms: int) -> void:
	if not server_mode and Profile.current().vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func bee_controls_active() -> bool:
	return state in [State.SORTIE, State.MODE, State.ESCAPE]


# ── Вопрос, меню, настройки ────────────────────────────────

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


func set_map(id: String) -> void:
	var p := Profile.current()
	p.map_id = id
	p.save()
	_build_world(id)
	show_hub()


func toggle_fpv() -> void:
	fpv = not fpv
	var p := Profile.current()
	p.fpv = fpv
	p.save()


## Запустить режим по id (из меню, «Ещё раз», автотеста).
func start(id: String) -> void:
	mode_id = id
	match id:
		"sortie":
			start_sortie()
		"escape":
			start_escape(EscapeMatch.Kind.ESCAPE)
		"team":
			start_escape(EscapeMatch.Kind.TEAM)
		"survival":
			start_escape(EscapeMatch.Kind.SURVIVAL)
		"hunt":
			start_escape(EscapeMatch.Kind.HUNT)
		"race", "flappy", "bear":
			_start_mode(id)
	if ui and state != State.HUB:
		Tutorial.maybe_start(self, id)


# ── Вылет пчелы ────────────────────────────────────────────

func start_sortie() -> void:
	mode_id = "sortie"
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
	Tutorial.stop(self)

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


# ── Дачники против пчёл ────────────────────────────────────

func start_escape(kind: int) -> void:
	world.prepare_escape()
	escape = EscapeMatch.begin(world, self, kind)
	if escape.human:
		cam.follow(escape.human, 0.9)
	else:
		cam.follow(escape.player_bee, 1.5)
	state = State.ESCAPE
	ui.show_escape_hud()
	say(Lines.pick(Lines.ESCAPE_START) if escape.human else "Лети, лови неуважающих!", 3.0)


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
	Tutorial.stop(self)
	if net and net.is_server:
		net.server_match_over(s)
		if server_mode:
			state = State.HUB
			return

	var p := Profile.current()
	var record := false
	match s.kind:
		EscapeMatch.Kind.SURVIVAL:
			record = s.time > p.survival_best
			if record:
				p.survival_best = s.time
		EscapeMatch.Kind.HUNT:
			p.hunt_games += 1
			if not s.escaped and s.ending != "gaveup":
				p.hunt_wins += 1
				p.honey += 10 * s.humans_fainted
		_:
			p.escape_attempts += 1
			if s.escaped:
				p.escape_wins += 1
				if s.kind == EscapeMatch.Kind.TEAM:
					p.team_wins += 1
				record = p.best_escape_time <= 0.0 or s.time < p.best_escape_time
				if record:
					p.best_escape_time = s.time
	p.save()

	state = State.RESULTS
	cam.show_hub()
	ui.show_escape_results(s, record)


# ── Перегонки, Флаппи, медведь ─────────────────────────────

func _start_mode(id: String) -> void:
	world.prepare_escape()  # прячем рой и чистим динамику
	match id:
		"race":
			mode = RaceMode.begin(self, world)
		"flappy":
			mode = FlappyMode.begin(self)
		"bear":
			mode = BearRaid.begin(self, world)
	state = State.MODE


## Режим закончился: result — {title, big, color, body, record, honey}.
func end_mode(result: Dictionary) -> void:
	if state != State.MODE:
		return
	if is_instance_valid(mode):
		mode.queue_free()
	mode = null
	world.end_escape()
	Tutorial.stop(self)
	var p := Profile.current()
	p.honey += int(result.get("honey", 0))
	p.save()
	state = State.RESULTS
	cam.make_current()
	cam.show_hub()
	ui.show_card(result)


func give_up() -> void:
	match state:
		State.SORTIE:
			end_sortie()
		State.ESCAPE:
			if escape:
				escape.give_up()
		State.MODE:
			if mode and mode.has_method("give_up"):
				mode.give_up()


# ── Реплики ────────────────────────────────────────────────

func say(line: String, seconds := 2.5) -> void:
	if ui:
		ui.say(line, seconds)
	if net and net.is_server:
		net.server_event("say", line)


func toast(text: String) -> void:
	if ui:
		ui.toast(text)
	if net and net.is_server:
		net.server_event("toast", text)
