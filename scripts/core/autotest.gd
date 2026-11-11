class_name Autotest
extends Node
## Автопрохождение для проверки без экрана:
##   godot --headless --path . -- --autotest
## Отвечает деду, летает пчелой (цветок → улей → удары → оса),
## переходит за людей и бежит за банками к машине. В конце печатает
## «AUTOTEST OK» или «AUTOTEST FAIL: …» и выходит с кодом 0 или 1.

const SPEEDUP := 4.0

var _game: Game
var _fails: PackedStringArray = []
var _shots_dir := ""  # --shots=/путь — сохранять скриншоты ключевых моментов


func _ready() -> void:
	_game = get_parent() as Game
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	Engine.time_scale = 1.0 if _shots_dir != "" else SPEEDUP
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	if _shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _shots_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("  📷 " + path)


func _wait(seconds: float) -> void:
	var until := Game.clock + seconds
	while Game.clock < until:
		await get_tree().process_frame


func _wait_until(cond: Callable, timeout: float) -> bool:
	var until := Game.clock + timeout
	while Game.clock < until:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ✔ " if ok else "  ✘ ") + what)
	if not ok:
		_fails.append(what)


func _run() -> void:
	print("== Автотест: вопрос деда ==")
	await _wait(1.0)
	_check(_game.state == Game.State.QUESTION, "первый запуск показывает вопрос")
	await _wait(6.0)  # дед успевает сказать «Ну? Я жду.»
	await _shot("01_vopros")
	_game.answer(Profile.Side.BEE)
	await _wait(0.5)
	_check(_game.state == Game.State.HUB and Profile.current().side == Profile.Side.BEE, "ответ «Уважаю» — пасека")
	await _wait(2.0)
	await _shot("02_paseka")

	print("== Автотест: вылет пчелы ==")
	_game.start_sortie()
	await _wait(0.5)
	_check(_game.state == Game.State.SORTIE and is_instance_valid(_game.bee), "вылет начался, пчела есть")
	var bee := _game.bee

	# К ближайшему цветущему цветку
	var flower: Flower = null
	var best := INF
	for f in _game.world.flowers:
		if f.has_pollen():
			var d := f.head_pos().distance_to(bee.global_position)
			if d < best:
				best = d
				flower = f
	_check(flower != null, "есть цветущие цветы")
	if flower:
		bee.debug_steer(flower.head_pos())
		var arrived := await _wait_until(func(): return Vector2(bee.global_position.x - flower.head_pos().x,
			bee.global_position.z - flower.head_pos().z).length() < 0.6, 15.0)
		_check(arrived, "долетела до цветка")
		bee.debug_steer(null)
		await _wait(3.0)
		_check(bee.pollen > 0, "собрала пыльцу (%d)" % bee.pollen)
		await _shot("03_cvetok")

	# Обратно в улей
	bee.debug_steer(_game.world.hive_position + Vector3(0, 0, -1))
	var delivered := await _wait_until(func(): return _game.stats.honey_made > 0, 20.0)
	_check(delivered, "донесла пыльцу в улей, мёд +%d" % _game.stats.honey_made)
	await _shot("04_uley")

	# Рывок в стену дома — удар
	bee.debug_steer(Vector3(-15, 2, 8))
	await _wait(1.5)
	bee.dash((Vector3(-15, 2, 9) - bee.global_position).normalized())
	await _wait_until(func(): return _game.stats.crashes > 0, 8.0)
	_check(_game.stats.crashes > 0, "удар о стену засчитан (%d)" % _game.stats.crashes)

	# Набрать пыльцы и пролететь мимо ос у мусорки
	bee.add_pollen(10, false)
	bee.debug_steer(Vector3(20, 2, 16))
	var robbed := await _wait_until(func(): return _game.stats.pollen_stolen > 0, 15.0)
	_check(robbed, "осы отжали пыльцу (%d)" % _game.stats.pollen_stolen)

	# Варенье
	bee.debug_steer(Vector3(5.2, 2, -12))
	var stuck := await _wait_until(func(): return bee.is_stuck(), 15.0)
	_check(stuck, "прилипла в варенье")

	bee.debug_steer(null)
	_game.end_sortie()
	await _wait(0.5)
	_check(_game.state == Game.State.RESULTS, "итоги вылета")
	await _shot("05_itogi")
	_check(Profile.current().honey > 0, "мёд сохранён в профиле (%d)" % Profile.current().honey)
	_game.show_hub()
	await _wait(0.5)

	print("== Автотест: побег за людей ==")
	_check(Profile.current().can_change(), "можно передумать в первые 10 минут")
	_game.answer(Profile.Side.HUMAN)
	await _wait(1.0)
	_check(Profile.current().side == Profile.Side.HUMAN, "стал «неуважающим»")
	await _wait(2.5)
	await _shot("06_neuvazhayushchiy")
	_game.start_escape()
	await _wait(0.5)
	_check(_game.state == Game.State.ESCAPE and _game.escape != null, "побег начался")
	var m := _game.escape
	var human := m.human
	_check(m.bots.size() == EscapeMatch.BOT_COUNT, "пчёл-ботов: %d" % m.bots.size())

	var stung_before := m.stats.stings
	var shots_done := 0
	var swats_tried := 0
	while _game.state == Game.State.ESCAPE and not m.ending():
		var tgt := m.target()
		if tgt.is_empty():
			break
		human.debug_steer(tgt["pos"])
		await _wait(0.5)
		human.swat()
		swats_tried += 1
		if shots_done == 0 and m.stats.time > 8.0:
			shots_done = 1
			await _shot("07_pobeg")
		elif shots_done == 1 and human.swelling > 0.5:
			shots_done = 2
			await _shot("08_otek")
		if human.smoke_ready_in() <= 0.0 and m.stats.stings > stung_before + 2:
			human.smoke()
		var near := 0
		var closest: BeeBot = null
		for b in m.bots:
			if is_instance_valid(b) and not b.disabled() and b.global_position.distance_to(human.global_position) < 2.5:
				near += 1
				if closest == null or b.global_position.distance_to(human.global_position) < closest.global_position.distance_to(human.global_position):
					closest = b
		if near >= 3 and human.smoke_ready_in() <= 0.0:
			human.smoke()
		elif closest and randf() < 0.5:
			var away := human.global_position - closest.global_position
			away.y = 0.0
			var to_goal: Vector3 = tgt["pos"] - human.global_position
			to_goal.y = 0.0
			human.dodge((away.normalized() + to_goal.normalized()).normalized())

	print("  итог побега: %s, банок %d/%d, укусов %d, сбито %d, дымов %d, время %.0f с" % [
		m.stats.ending, m.stats.jars, m.stats.jars_needed, m.stats.stings, m.stats.swats, m.stats.smokes, m.stats.time])
	# Баланс — только для сведения: автобот глупый, настоящий баланс проверяют живые игроки
	print("  (баланс) банок у автобота: %d" % m.stats.jars)
	_check(m.stats.stings > 0, "пчёлы жалили")
	_check(m.ending(), "побег закончился концовкой")
	await _wait_until(func(): return _game.state == Game.State.RESULTS, 10.0)
	_check(_game.state == Game.State.RESULTS, "итоги побега")
	await _shot("09_itogi_pobega")
	_check(Profile.current().escape_attempts == 1, "попытка побега сохранена")

	_game.show_hub()
	await _wait(0.5)
	Profile.reset()

	if _fails.is_empty():
		print("AUTOTEST OK")
		get_tree().quit(0)
	else:
		print("AUTOTEST FAIL: " + ", ".join(_fails))
		get_tree().quit(1)
