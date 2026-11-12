class_name Autotest
extends Node
## Автопрохождение всех режимов без экрана:
##   godot --headless --path . -- --autotest
## С --shots=/папка (на виртуальном экране) сохраняет скриншоты.
## В конце печатает «AUTOTEST OK» или «AUTOTEST FAIL: …» и выходит с кодом 0/1.

const SPEEDUP := 4.0

var _game: Game
var _fails: PackedStringArray = []
var _shots_dir := ""


func _ready() -> void:
	_game = get_parent() as Game
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	Engine.time_scale = 2.0 if _shots_dir != "" else SPEEDUP
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	if _shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))
	print("  📷 " + shot_name)


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


func _back_to_hub() -> void:
	if _game.state == Game.State.RESULTS:
		_game.show_hub()
	await _wait(0.3)


func _run() -> void:
	if "--preview" in OS.get_cmdline_user_args():
		await _preview()
		get_tree().quit(0)
		return
	await _test_question()
	await _test_sortie()
	await _test_race()
	await _test_bear()
	await _test_flappy()
	await _test_hunt()
	await _test_maps()
	await _test_fpv()
	await _test_human_side()

	Profile.reset()
	if _fails.is_empty():
		print("AUTOTEST OK")
		get_tree().quit(0)
	else:
		print("AUTOTEST FAIL: " + ", ".join(_fails))
		get_tree().quit(1)


func _test_question() -> void:
	print("== Вопрос деда ==")
	await _wait(1.0)
	_check(_game.state == Game.State.QUESTION, "первый запуск показывает вопрос")
	await _wait(6.0)
	await _shot("01_vopros")
	_game.answer(Profile.Side.BEE)
	await _wait(1.5)
	_check(_game.state == Game.State.HUB and Profile.current().side == Profile.Side.BEE, "ответ «Уважаю» — пасека")
	await _shot("02_menu_pchely")


func _test_sortie() -> void:
	print("== Вылет ==")
	_game.start("sortie")
	await _wait(0.5)
	var bee := _game.bee
	_check(_game.state == Game.State.SORTIE and is_instance_valid(bee), "вылет начался")
	_check(_game.get_node_or_null(Tutorial.NODE_NAME) != null, "обучение показано")
	var flower: Flower = null
	var best := INF
	for f in _game.world.flowers:
		if f.has_pollen() and f.head_pos().distance_to(bee.global_position) < best:
			best = f.head_pos().distance_to(bee.global_position)
			flower = f
	bee.debug_steer(flower.head_pos())
	await _wait_until(func(): return Vector2(bee.global_position.x - flower.head_pos().x, bee.global_position.z - flower.head_pos().z).length() < 0.6, 15.0)
	bee.debug_steer(null)
	await _wait(3.0)
	_check(bee.pollen > 0, "собрала пыльцу (%d)" % bee.pollen)
	await _shot("03_vylet")
	bee.debug_steer(_game.world.hive_position + Vector3(0, 0, -1))
	_check(await _wait_until(func(): return _game.stats.honey_made > 0, 20.0), "мёд в улье")
	bee.debug_steer(Vector3(-15, 2, 8))
	await _wait(1.5)
	bee.dash((Vector3(-15, 2, 9) - bee.global_position).normalized())
	_check(await _wait_until(func(): return _game.stats.crashes > 0, 8.0), "удар о стену")
	bee.add_pollen(10, false)
	bee.debug_steer(Vector3(20, 2, 16))
	_check(await _wait_until(func(): return _game.stats.pollen_stolen > 0, 15.0), "осы отжали пыльцу")
	_game.end_sortie()
	await _wait(0.3)
	_check(_game.state == Game.State.RESULTS and Profile.current().honey > 0, "итоги вылета, мёд сохранён")
	await _back_to_hub()


func _test_race() -> void:
	print("== Перегонки ==")
	_game.start("race")
	await _wait(0.5)
	var m := _game.mode as RaceMode
	_check(m != null and m.rings.size() == 8, "кольца на месте")
	await _wait(RaceMode.COUNTDOWN + 0.2)
	var shot := false
	var until := Game.clock + 150.0
	while _game.state == Game.State.MODE and Game.clock < until and is_instance_valid(m):
		var me: Dictionary = m.racers[0]
		m.bee.debug_steer(_game.world.race_rings[me["ring"]])
		if not shot and m.elapsed > 6.0:
			shot = true
			await _shot("04_peregonki")
		await _wait(0.2)
	_check(_game.state == Game.State.RESULTS, "гонка закончилась")
	await _shot("05_itogi_gonki")
	await _back_to_hub()


func _test_bear() -> void:
	print("== Медведь ==")
	_game.start("bear")
	await _wait(0.5)
	var m := _game.mode as BearRaid
	_check(m != null, "медведь пришёл")
	var shot := false
	var until := Game.clock + 120.0
	while _game.state == Game.State.MODE and Game.clock < until and is_instance_valid(m):
		var bee := m.bee
		if is_instance_valid(bee):
			var target := m.bear_position() + Vector3(0, 1.4, 0)
			bee.debug_steer(target)
			if bee.global_position.distance_to(target) < 5.0:
				bee.dash((target - bee.global_position).normalized())
			if not shot and bee.global_position.distance_to(target) < 6.0:
				shot = true
				await _shot("06_medved")
		await _wait(0.4)
	_check(_game.state == Game.State.RESULTS, "битва с медведем закончилась")
	_check(Profile.current().bear_games == 1, "игра с медведем засчитана (побед %d)" % Profile.current().bear_wins)
	await _back_to_hub()


func _test_flappy() -> void:
	print("== Флаппи-пчела ==")
	_game.start("flappy")
	await _wait(0.5)
	var m := _game.mode as FlappyMode
	_check(m != null, "Флаппи запустилась")
	m.flap()
	var shot := false
	var until := Game.clock + 40.0
	while is_instance_valid(m) and not m.dead and Game.clock < until and m.score < 6:
		var target := 4.5
		for o in m._obstacles:
			if o["x"] > m._x - 0.5:
				target = (o["lo"] + o["hi"]) / 2.0
				break
		if m._y < target - 0.2 and m._vy < 1.0:
			m.flap()
		if not shot and m.score >= 2:
			shot = true
			await _shot("07_flappi")
		await get_tree().process_frame
	_check(is_instance_valid(m) and m.score > 0, "пролетела препятствия (%d)" % (m.score if is_instance_valid(m) else -1))
	if is_instance_valid(m):
		m.give_up()
	await _wait(0.3)
	_check(_game.state == Game.State.RESULTS and Profile.current().flappy_best > 0, "рекорд Флаппи сохранён")
	await _back_to_hub()


func _test_hunt() -> void:
	print("== Охота на дачников (за пчелу) ==")
	_game.start("hunt")
	await _wait(0.5)
	var m := _game.escape
	_check(m != null and m.player_bee != null and m.humans.size() == 3, "рой и три дачника-бота")
	var shot := false
	var until := Game.clock + 190.0
	while _game.state == Game.State.ESCAPE and Game.clock < until and is_instance_valid(m) and not m.ending():
		var bee := m.player_bee
		var h := m.nearest_human(bee.global_position)
		if h:
			var chest := h.global_position + Vector3(0, 1.3, 0)
			bee.debug_steer(chest)
			if bee.global_position.distance_to(chest) < 3.0:
				bee.dash((chest - bee.global_position).normalized())
		if not shot and m.stats.time > 10.0:
			shot = true
			await _shot("08_ohota")
		await _wait(0.3)
	if is_instance_valid(m):
		print("  итог охоты: %s, моих укусов %d, на скорой %d из %d, уехали %d" % [
			m.stats.ending, m.stats.stings_dealt, m.stats.humans_fainted, m.stats.humans_total, m.stats.humans_escaped])
		_check(m.stats.stings_dealt > 0, "пчела-игрок жалила")
	await _wait_until(func(): return _game.state == Game.State.RESULTS, 10.0)
	_check(Profile.current().hunt_games == 1, "охота засчитана")
	await _back_to_hub()


func _test_maps() -> void:
	print("== Карты ==")
	for id in World.MAP_ORDER:
		_game.set_map(id)
		await _wait(1.5)
		var w := _game.world
		_check(w.map_id == id and w.flowers.size() > 20 and w.race_rings.size() == 8 and w.bear_path.size() >= 2 and w.jar_spots.size() >= 6,
			"карта «%s»: цветов %d, колец %d" % [w.map_name(), w.flowers.size(), w.race_rings.size()])
		await _shot("09_karta_" + id)
	_game.set_map("dacha")
	await _wait(0.5)


func _test_fpv() -> void:
	print("== Вид от первого лица ==")
	_game.toggle_fpv()
	_check(_game.fpv and Profile.current().fpv, "вид переключён и запомнен")
	_game.start("sortie")
	await _wait(0.3)
	var bee := _game.bee
	var start := bee.global_position
	bee.debug_steer(start + Vector3(8, 0, 8))
	await _wait(2.5)
	_check(bee.global_position.distance_to(start) > 4.0, "пчела летит в виде от первого лица")
	await _shot("10_ot_pervogo_lica")
	_game.end_sortie()
	_game.toggle_fpv()
	await _back_to_hub()


func _test_human_side() -> void:
	print("== За людей ==")
	_check(Profile.current().can_change(), "можно передумать")
	_game.answer(Profile.Side.HUMAN)
	await _wait(2.0)
	_check(Profile.current().side == Profile.Side.HUMAN, "стал «неуважающим»")
	await _shot("11_menu_lyudey")

	for id in ["escape", "team", "survival"]:
		_game.start(id)
		await _wait(0.5)
		var m := _game.escape
		_check(m != null and m.human != null, "%s: матч начался, ботов-пчёл %d, дачников %d" % [id, m.bots.size(), m.humans.size()])
		m.human.add_child(HumanBot.new())  # за игрока бегает бот
		var shot := false
		var until := Game.clock + (70.0 if id == "survival" else 190.0)
		while _game.state == Game.State.ESCAPE and Game.clock < until and is_instance_valid(m) and not m.ending():
			if not shot and m.stats.time > 9.0:
				shot = true
				await _shot("12_" + id)
			await _wait(0.3)
		if is_instance_valid(m):
			print("  итог «%s»: %s, банок %d/%d, укусов %d, сбито %d, время %.0f с, уехали %d, на скорой %d" % [
				id, m.stats.ending, m.stats.jars, m.stats.jars_needed, m.stats.stings, m.stats.swats, m.stats.time,
				m.stats.humans_escaped, m.stats.humans_fainted])
			if id == "survival":
				_check(m.bots.size() > 6 or m.ending(), "в выживании прилетают волны")
				if not m.ending():
					_game.give_up()
		await _wait_until(func(): return _game.state == Game.State.RESULTS, 10.0)
		_check(_game.state == Game.State.RESULTS, "%s: итоги" % id)
		if id == "team":
			await _shot("13_itogi_vtroem")
		await _back_to_hub()


## Быстрый предпросмотр для проверки внешнего вида: -- --autotest --preview --shots=/папка
func _preview() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if only == "chars":
		_game.answer(Profile.Side.BEE)
		await _wait(0.5)
		var stage := Shape.node("Витрина", _game, Vector3(0, 0, 40))
		var bee_n := Shape.node("п", stage, Vector3(-1.6, 1.2, 0))
		BeeVisual.build_placeholder(bee_n, false)
		bee_n.rotation_degrees.y = 200
		bee_n.scale = Vector3.ONE * 1.6
		var wasp_n := Shape.node("о", stage, Vector3(-0.2, 1.2, 0))
		BeeVisual.build_placeholder(wasp_n, true)
		wasp_n.rotation_degrees.y = 160
		wasp_n.scale = Vector3.ONE * 1.6
		var h := Human.spawn(stage, Vector3(1.4, 0, 0))
		h.facing = PI + 0.4
		h.set_physics_process(false)
		var bear := Shape.node("м", stage, Vector3(4.6, 0, 1.5))
		BearRaid.new()._build_bear(bear)
		bear.rotation_degrees.y = 210
		bear.scale = Vector3.ONE * 0.8
		var cam := Camera3D.new()
		_game.add_child(cam)
		cam.global_position = stage.global_position + Vector3(1.4, 2.0, -6.5)
		cam.look_at(stage.global_position + Vector3(1.4, 1.1, 0))
		cam.fov = 48
		cam.make_current()
		_game.ui.visible = false
		await _wait(1.0)
		await _shot("c_personazhi")
		h.swelling = 0.8
		await _wait(0.5)
		await _shot("c_otek")
		return
	if only == "tris":
		var groups := {}
		for mi in _game.world.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m == null:
				continue
			var tri := 0
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				tri += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var n: Node = mi
			while n.get_parent() != _game.world:
				n = n.get_parent()
			groups[n.name] = groups.get(n.name, 0) + tri
		var keys := groups.keys()
		keys.sort_custom(func(a, b): return groups[a] > groups[b])
		for k in keys.slice(0, 12):
			print("  %s: %d" % [k, groups[k]])
		return
	if only == "game":
		_game.answer(Profile.Side.BEE)
		_game.start("sortie")
		await _wait(0.5)
		_game.bee.debug_steer(_game.bee.global_position + Vector3(4, 0, 6))
		await _wait(3.0)
		await _shot("q_igra")
		_game.end_sortie()
		_game.show_hub()
		await _wait(1.5)
		await _shot("q_menu")
		return
	await _wait(1.0)
	await _shot("p00_vopros")
	_game.answer(Profile.Side.BEE)
	for id in World.MAP_ORDER:
		_game.set_map(id)
		await _wait(2.5)
		await _shot("p1_menu_" + id)
		_game.start("sortie")
		await _wait(0.5)
		var bee := _game.bee
		bee.debug_steer(bee.global_position + Vector3(4, 0, 6))
		await _wait(2.0)
		bee.debug_steer(null)
		await _wait(1.0)
		await _shot("p2_igra_" + id)
		print("  [%s] вызовов отрисовки: %d, треугольников: %d" % [id,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		_game.end_sortie()
		_game.show_hub()
	_game.answer(Profile.Side.HUMAN)
	_game.set_map("dacha")
	await _wait(1.0)
	_game.start("escape")
	await _wait(9.0)
	await _shot("p3_pobeg")
	_game.give_up()
	await _wait(0.5)
	await _shot("p4_itogi")
