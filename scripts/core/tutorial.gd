class_name Tutorial
extends Node
## Пошаговое обучение при первом заходе в режим. Каждый шаг ждёт,
## пока игрок сделает действие (или 20 секунд), потом показывает следующий.
## Пройденное запоминается в профиле; в меню можно пройти заново.

const STEP_TIMEOUT := 20.0
const NODE_NAME := "Обучение"

var mode_id := ""
var steps: Array = []  # [текст, Callable-проверка]
var _i := 0
var _step_at := 0.0
var _game: Game
var _start_pos := Vector3.ZERO


static func maybe_start(game: Game, id: String) -> void:
	stop(game)
	if Profile.current().tutorials.get(id, false):
		return
	var t := Tutorial.new()
	t.name = NODE_NAME
	t.mode_id = id
	t._game = game
	t.steps = t._steps_for(id)
	if t.steps.is_empty():
		t.free()
		return
	game.add_child(t)
	t._show()


static func stop(game: Game) -> void:
	var old := game.get_node_or_null(NODE_NAME)
	if old:
		old.queue_free()
	if game.ui:
		game.ui.hide_tutorial()


static func reset_all() -> void:
	var p := Profile.current()
	p.tutorials = {}
	p.save()


func _player() -> Node3D:
	var g := _game
	if g.state == Game.State.SORTIE and is_instance_valid(g.bee):
		return g.bee
	if g.escape:
		return g.escape.human if g.escape.human else g.escape.player_bee
	if g.mode and "bee" in g.mode and is_instance_valid(g.mode.bee):
		return g.mode.bee
	return null


func _moved(dist: float) -> bool:
	var p := _player()
	return p != null and p.global_position.distance_to(_start_pos) > dist


func _steps_for(id: String) -> Array:
	var g := _game
	match id:
		"sortie":
			return [
				["Веди пальцем по экрану — пчела летит следом.", func(): return _moved(5.0)],
				["Зависни над цветком — пчела соберёт пыльцу.", func(): return is_instance_valid(g.bee) and g.bee.pollen > 0],
				["Неси пыльцу в улей — стрелка вверху покажет путь.", func(): return g.stats and g.stats.honey_made > 0],
				["Быстро проведи пальцем — это рывок. Им можно таранить ос.", func(): return is_instance_valid(g.bee) and g.bee.is_dashing()],
			]
		"escape", "team", "survival":
			var s := [
				["Веди пальцем — дачник бежит следом.", func(): return _moved(4.0)],
				["Пчёлы рядом? Жми «Мухобойку»!", func(): return g.escape and g.escape.stats.swats > 0],
				["Быстро проведи пальцем — перекат. Пока катишься, не жалят.", func(): return g.escape and g.escape.stats.dodges > 0],
				["Окружили? «Дымарь» усыпит всех вокруг.", func(): return g.escape and g.escape.stats.smokes > 0],
			]
			if id != "survival":
				s.append(["Собирай банки мёда — стрелка покажет ближайшую. Потом к машине!", func(): return g.escape and g.escape.stats.jars > 0])
			return s
		"hunt":
			return [
				["Ты пчела! Веди пальцем — летишь следом.", func(): return _moved(5.0)],
				["Врежься в дачника — это укус. Стрелка покажет ближайшего.", func(): return g.escape and g.escape.stats.stings_dealt > 0],
				["Не давай им дойти до машины с банками!", func(): return false],
			]
		"race":
			return [
				["Пролетай через золотые кольца по порядку. Два круга!", func(): return g.mode is RaceMode and (g.mode as RaceMode).racers[0]["ring"] > 0],
				["Быстрый свайп — рывок вперёд. Обгоняй!", func(): return g.mode is RaceMode and (g.mode as RaceMode).bee.is_dashing()],
			]
		"flappy":
			return [["Тапай по экрану — пчела взлетает. Пролетай между досками!", func(): return g.mode is FlappyMode and (g.mode as FlappyMode).score > 0]]
		"bear":
			return [
				["Лети к медведю — стрелка покажет, где он.", func(): return g.mode is BearRaid and is_instance_valid((g.mode as BearRaid).bee) and (g.mode as BearRaid).bee.global_position.distance_to((g.mode as BearRaid).bear_position()) < 6.0],
				["Быстро проведи пальцем в медведя — сильный укус!", func(): return g.mode is BearRaid and (g.mode as BearRaid).damage_by_player > 0.0],
			]
	return []


func _show() -> void:
	_step_at = Game.clock
	var p := _player()
	_start_pos = p.global_position if p else Vector3.ZERO
	_game.ui.show_tutorial(steps[_i][0], _i + 1, steps.size())


func _process(_delta: float) -> void:
	if _i >= steps.size():
		return
	var check: Callable = steps[_i][1]
	var done: bool = check.call()
	if done or Game.clock - _step_at > STEP_TIMEOUT:
		if done:
			Game.vibrate(20)
		_i += 1
		if _i >= steps.size():
			var prof := Profile.current()
			prof.tutorials[mode_id] = true
			prof.save()
			_game.ui.hide_tutorial()
			_game.toast("Обучение пройдено!")
			queue_free()
		else:
			_show()
