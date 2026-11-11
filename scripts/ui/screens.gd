class_name Screens
extends CanvasLayer
## Все экраны: вопрос деда, пасека (меню), вылет (HUD), побег (HUD), итоги.
## Поверх экранов — реплики деда и всплывающие сообщения.

var _root: Control
var _safe: Control
var _screen: Control

var _say: Panel
var _say_text: Label
var _say_until := 0.0

var _toast: Label
var _toast_at := -100.0

var _question_active := false
var _question_at := 0.0
var _silence := 0

var _change_btn: Button
var _tutorial: Panel
var _tutorial_text: Label
var _tutorial_step: Label

# HUD вылета
var _hud_active := false
var _pollen_text: Label
var _pollen_fill: Panel
var _timer_text: Label
var _honey_text: Label
var _hive_text: Label
var _arrow: Control
var _hint: Control
var _hint_at := 0.0

# HUD побега
var _escape_active := false
var _jars_text: Label
var _swell_text: Label
var _swell_fill: Panel
var _target_text: Label
var _car_box: Control
var _car_fill: Panel
var _swat_btn: Button
var _smoke_btn: Button


func build() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Корень"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_safe = UiKit.area(_root, 0, 0, 1, 1, "Безопасная зона")

	# Реплика деда
	_say = UiKit.panel(_safe, 0.05, 0.5, 0.95, 0.59, UiKit.CARD_BG, 22, "Дед говорит")
	UiKit.label(_say, "ДЕД-ПАСЕЧНИК", 28, 0.04, 0.64, 0.7, 0.94, HORIZONTAL_ALIGNMENT_LEFT, UiKit.DEEP_HONEY, true, false)
	_say_text = UiKit.label(_say, "", 42, 0.04, 0.06, 0.96, 0.68, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false)
	_say.modulate.a = 0.0

	# Всплывающее сообщение (+мёд и т.п.)
	_toast = UiKit.label(_safe, "", 58, 0.06, 0.5, 0.94, 0.56, HORIZONTAL_ALIGNMENT_CENTER, UiKit.HONEY_BG, true)
	_toast.modulate.a = 0.0

	# Баннер обучения
	_tutorial = UiKit.panel(_safe, 0.05, 0.6, 0.95, 0.7, Color(1.0, 0.82, 0.3, 0.97), 22, "Обучение")
	_tutorial_step = UiKit.label(_tutorial, "", 26, 0.04, 0.66, 0.96, 0.95, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, true, false)
	_tutorial_text = UiKit.label(_tutorial, "", 38, 0.04, 0.05, 0.96, 0.7, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false)
	_tutorial.visible = false


func new_screen(screen_name: String) -> Control:
	if _screen:
		_screen.queue_free()
	_screen = UiKit.area(_safe, 0, 0, 1, 1, screen_name)
	_safe.move_child(_screen, 0)  # под репликой деда и всплывашками
	_question_active = false
	_hud_active = false
	_escape_active = false
	_change_btn = null
	_toast_at = -100.0  # старая всплывашка не переезжает на новый экран
	return _screen


func place_say(y0: float, y1: float) -> void:
	UiKit.place(_say, 0.05, y0, 0.95, y1)


# ── Вопрос ─────────────────────────────────────────────────

func show_question() -> void:
	var s := new_screen("Вопрос")
	place_say(0.5, 0.59)
	UiKit.panel(s, 0, 0, 1, 0.46, UiKit.SHADE, 0)
	UiKit.label(s, "Дед-пасечник смотрит на тебя очень внимательно", 40, 0.08, 0.37, 0.92, 0.43,
		HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1, 0.85))
	UiKit.label(s, "Ты пчёлок уважаешь?", 92, 0.04, 0.24, 0.96, 0.37, HORIZONTAL_ALIGNMENT_CENTER, UiKit.HONEY_BG, true)
	UiKit.button(s, "Уважаю", 0.07, 0.07, 0.48, 0.19, UiKit.HONEY_BG, UiKit.INK,
		func(): Game.I.answer(Profile.Side.BEE), 64)
	UiKit.button(s, "Нет", 0.52, 0.07, 0.93, 0.19, UiKit.DANGER_BG, Color.WHITE,
		func(): Game.I.answer(Profile.Side.HUMAN), 64)
	UiKit.label(s, "Ответ останется с тобой. Передумать можно один раз в первые 10 минут.", 30,
		0.06, 0.0, 0.94, 0.065, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1, 0.6))
	_question_active = true
	_question_at = Game.clock
	_silence = 0


# ── Пасека (меню) ──────────────────────────────────────────

func show_hub() -> void:
	var p := Profile.current()
	var bee := p.side == Profile.Side.BEE
	var game := Game.I
	var s := new_screen("Пасека")
	place_say(0.57, 0.66)

	var top := UiKit.panel(s, 0.04, 0.905, 0.96, 0.975, UiKit.SHADE)
	if bee:
		UiKit.label(top, "Мёд: %d" % p.honey, 46, 0.05, 0, 0.5, 1, HORIZONTAL_ALIGNMENT_LEFT, UiKit.HONEY_BG, true)
		UiKit.label(top, "Пасечник", 34, 0.5, 0, 0.95, 1, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		UiKit.label(top, "Неуважающий", 44, 0.05, 0, 0.5, 1, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 0.58, 0.52), true)
		UiKit.label(top, "Мёд: %d" % p.honey, 34, 0.5, 0, 0.95, 1, HORIZONTAL_ALIGNMENT_RIGHT, UiKit.HONEY_BG)
	UiKit.label(s, "Твоя пасека" if bee else "Ты не уважаешь пчёлок", 70, 0.04, 0.84, 0.96, 0.9,
		HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)

	# Выбор карты
	var maps: Array = World.MAP_ORDER
	var idx := maps.find(game.world.map_id)
	UiKit.button(s, "‹", 0.12, 0.775, 0.24, 0.83, UiKit.SHADE, Color.WHITE,
		func(): game.set_map(maps[(idx - 1 + maps.size()) % maps.size()]), 60)
	var map_box := UiKit.panel(s, 0.26, 0.775, 0.74, 0.83, UiKit.SHADE)
	UiKit.label(map_box, "Карта: " + game.world.map_name(), 38, 0.03, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	UiKit.button(s, "›", 0.76, 0.775, 0.88, 0.83, UiKit.SHADE, Color.WHITE,
		func(): game.set_map(maps[(idx + 1) % maps.size()]), 60)

	UiKit.panel(s, 0, 0, 1, 0.56, UiKit.SHADE, 0)

	# Режимы своей стороны
	var modes: Array
	if bee:
		modes = [
			["sortie", "Вылет", "собирай пыльцу · рекорд %d мёда" % p.best_sortie_honey, true],
			["race", "Перегонки", "5 пчёл, кольца, 2 круга · побед %d" % p.race_wins, false],
			["hunt", "Охота на дачников", "ты и рой против трёх дачников · побед %d" % p.hunt_wins, false],
			["bear", "Медведь-рейдер", "отбей улей от медведя · побед %d" % p.bear_wins, false],
			["flappy", "Флаппи-пчела", "тапай и пролетай · рекорд %d" % p.flappy_best, false],
		]
	else:
		var best := " · лучший %s" % _fmt_time(p.best_escape_time) if p.best_escape_time > 0.0 else ""
		modes = [
			["escape", "Побег", "3 банки мёда и к машине%s" % best, true],
			["team", "Побег втроём", "ты и два дачника-бота · побед %d" % p.team_wins, false],
			["survival", "Выживание", "пчёлы волнами · рекорд %s" % _fmt_time(p.survival_best), false],
			["flappy", "Флаппи-пчела", "даже неуважающим можно · рекорд %d" % p.flappy_best, false],
		]
	modes.append(["online", "Онлайн-охота", "живые игроки по сети", false])
	var y := 0.535
	for m in modes:
		var h := 0.07 if m[3] else 0.06
		var id: String = m[0]
		var bg := (UiKit.HONEY_BG if bee else UiKit.DANGER_BG) if m[3] else Color(1, 1, 1, 0.16)
		var fg := UiKit.INK if (m[3] and bee) else Color.WHITE
		var b := UiKit.button(s, m[1], 0.06, y - h, 0.94, y, bg, fg,
			func(): game.ui.show_online() if id == "online" else game.start(id), 50 if m[3] else 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 0)
		var sub := UiKit.label(b, m[2], 26, 0.42, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_RIGHT, fg, false, false)
		sub.modulate.a = 0.85
		y -= h + 0.01

	# Настройки
	UiKit.button(s, "Вид: " + ("глаза" if game.fpv else "сверху"), 0.04, 0.015, 0.34, 0.065, Color(1, 1, 1, 0.2), Color.WHITE,
		func(): game.toggle_fpv(); show_hub(), 30)
	UiKit.button(s, "Вибро: " + ("да" if p.vibration else "нет"), 0.36, 0.015, 0.64, 0.065, Color(1, 1, 1, 0.2), Color.WHITE,
		func(): p.vibration = not p.vibration; p.save(); show_hub(), 30)
	UiKit.button(s, "Обучение заново", 0.66, 0.015, 0.96, 0.065, Color(1, 1, 1, 0.2), Color.WHITE,
		func(): Tutorial.reset_all(); toast("Обучение покажется снова"), 28)

	if p.can_change():
		var other := Profile.Side.HUMAN if bee else Profile.Side.BEE
		_change_btn = UiKit.button(s, "", 0.2, 0.69, 0.8, 0.735, Color(0, 0, 0, 0.35), Color.WHITE,
			func(): game.answer(other), 30)

	if Game.clock > _say_until:
		say(Lines.pick(Lines.HUB_BEE if bee else Lines.HUB_HUMAN), 3.0)


## Кнопка «Вид» в игровом экране.
func show_online() -> void:
	Game.I.net.show_menu()


func current_screen() -> Control:
	return _screen


## Кнопка «Вид» в игровом экране.
func view_button(parent: Control) -> Button:
	var b := UiKit.button(parent, "", 0.44, 0.845, 0.7, 0.89, UiKit.SHADE, Color.WHITE, Callable(), 30)
	var refresh := func(): b.text = "Вид: " + ("глаза" if Game.I.fpv else "сверху")
	refresh.call()
	b.pressed.connect(func(): Game.I.toggle_fpv(); refresh.call())
	return b


## Общие итоги режима: {title, big, color, body, record, footer}.
func show_card(r: Dictionary) -> void:
	var s := new_screen("Итоги")
	place_say(0.81, 0.895)
	UiKit.panel(s, 0, 0, 1, 1, Color(0, 0, 0, 0.45), 0)
	var card := UiKit.panel(s, 0.06, 0.2, 0.94, 0.8, UiKit.CARD_BG, 30)
	UiKit.label(card, r.get("title", ""), 64, 0.05, 0.85, 0.95, 0.97, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true, false)
	if r.get("record", "") != "":
		UiKit.label(card, r["record"], 44, 0.05, 0.77, 0.95, 0.85, HORIZONTAL_ALIGNMENT_CENTER, UiKit.DEEP_HONEY, true, false)
	UiKit.label(card, r.get("big", ""), 88, 0.05, 0.6, 0.95, 0.77, HORIZONTAL_ALIGNMENT_CENTER, r.get("color", UiKit.DEEP_HONEY), true, false)
	UiKit.label(card, r.get("body", ""), 38, 0.08, 0.27, 0.92, 0.6, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false)
	UiKit.label(card, r.get("footer", ""), 34, 0.05, 0.18, 0.95, 0.27, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true, false)
	var again: String = r.get("again", Game.I.mode_id)
	if again != "":
		UiKit.button(s, "Ещё раз", 0.06, 0.07, 0.6, 0.17, UiKit.HONEY_BG, UiKit.INK, func(): Game.I.start(again), 58)
	UiKit.button(s, "В меню", 0.63, 0.07, 0.94, 0.17, UiKit.MUTED, Color.WHITE, func(): Game.I.show_hub(), 42)


func show_tutorial(text: String, step: int, total: int) -> void:
	_tutorial.visible = true
	_tutorial_step.text = "ОБУЧЕНИЕ · ШАГ %d ИЗ %d" % [step, total]
	_tutorial_text.text = text


func hide_tutorial() -> void:
	if _tutorial:
		_tutorial.visible = false


# ── Вылет (HUD) ────────────────────────────────────────────

func show_hud() -> void:
	var s := new_screen("Вылет")
	place_say(0.73, 0.82)

	var top := UiKit.panel(s, 0.03, 0.9, 0.97, 0.975, UiKit.SHADE)
	_pollen_text = UiKit.label(top, "", 36, 0.03, 0.45, 0.36, 0.95, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)
	var bar := UiKit.panel(top, 0.03, 0.14, 0.36, 0.38, Color(1, 1, 1, 0.18), 10)
	_pollen_fill = UiKit.panel(bar, 0, 0, 0.02, 1, UiKit.HONEY_BG, 10)
	_timer_text = UiKit.label(top, "3:00", 62, 0.38, 0, 0.62, 1, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	_honey_text = UiKit.label(top, "", 38, 0.64, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_RIGHT, UiKit.HONEY_BG, true)

	var tag := UiKit.panel(s, 0.03, 0.845, 0.42, 0.89, UiKit.SHADE)
	_arrow = UiKit.arrow(tag, 0.03, 0.1, 0.17, 0.9, UiKit.HONEY_BG)
	_hive_text = UiKit.label(tag, "Улей", 32, 0.2, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)

	view_button(s)
	UiKit.button(s, "Домой", 0.72, 0.845, 0.97, 0.89, UiKit.SHADE, Color.WHITE, func(): Game.I.end_sortie(), 34)

	_hint = UiKit.panel(s, 0.05, 0.03, 0.95, 0.15, UiKit.SHADE)
	UiKit.label(_hint, "Веди пальцем — пчела летит следом.\nЗависни над цветком — соберёшь пыльцу, неси её в улей.\n" +
		"Быстрый свайп — рывок: им можно протаранить осу.", 32, 0.04, 0.06, 0.96, 0.94)
	_hint_at = Game.clock
	_hud_active = true


func _update_hud() -> void:
	var game := Game.I
	if game == null or game.stats == null:
		return
	var bee := game.bee
	if is_instance_valid(bee):
		_pollen_text.text = "Пыльца %d/%d" % [bee.pollen, Bee.CAPACITY]
		_pollen_fill.anchor_right = maxf(0.02, bee.load_fraction())
		var d := game.world.hive_position - bee.global_position
		d.y = 0.0
		_hive_text.text = "Ты у улья" if d.length() < 2.5 else "Улей · %d м" % roundi(d.length())
		point_arrow(_arrow, d)
	var secs := ceili(maxf(0.0, game.time_left))
	_timer_text.text = "%d:%02d" % [secs / 60, secs % 60]
	_timer_text.label_settings.font_color = Color(1, 0.55, 0.5) if secs <= 20 else Color.WHITE
	_honey_text.text = "Мёд +%d" % game.stats.honey_made
	_fade_hint()


## Стрелка на экране указывает направление по земле (камера смотрит вдоль +Z).
func point_arrow(holder: Control, d: Vector3) -> void:
	if holder.get_child_count() == 0:
		return
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := 0.0
	if cam:
		var f := -cam.global_basis.z
		cam_yaw = atan2(f.x, f.z)
	var angle := atan2(d.x, d.z) - cam_yaw
	# На экране вправо — это мировой -X для камеры, смотрящей вдоль +Z
	(holder.get_child(0) as Node2D).rotation = -angle


func _fade_hint() -> void:
	var t := Game.clock - _hint_at
	_hint.modulate.a = 1.0 if t < 8.0 else clampf(1.0 - (t - 8.0) / 1.5, 0.0, 1.0)


# ── Побег (HUD) ────────────────────────────────────────────

func show_escape_hud() -> void:
	var s := new_screen("Побег")
	place_say(0.73, 0.82)
	var game := Game.I
	var as_bee := game.escape != null and game.escape.human == null

	var top := UiKit.panel(s, 0.03, 0.9, 0.97, 0.975, UiKit.SHADE)
	_jars_text = UiKit.label(top, "", 38, 0.03, 0, 0.34, 1, HORIZONTAL_ALIGNMENT_LEFT, UiKit.HONEY_BG, true)
	_timer_text = UiKit.label(top, "3:00", 62, 0.36, 0, 0.6, 1, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	_swell_text = UiKit.label(top, "", 32, 0.62, 0.45, 0.97, 0.95, HORIZONTAL_ALIGNMENT_RIGHT, Color.WHITE, true)
	var bar := UiKit.panel(top, 0.62, 0.14, 0.97, 0.38, Color(1, 1, 1, 0.18), 10)
	_swell_fill = UiKit.panel(bar, 0, 0, 0.02, 1, Color(0.95, 0.38, 0.35), 10)

	var tag := UiKit.panel(s, 0.03, 0.845, 0.42, 0.89, UiKit.SHADE)
	_arrow = UiKit.arrow(tag, 0.03, 0.1, 0.17, 0.9, UiKit.HONEY_BG)
	_target_text = UiKit.label(tag, "", 30, 0.2, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)
	view_button(s)
	UiKit.button(s, "Сдаться", 0.72, 0.845, 0.97, 0.89, UiKit.SHADE, Color.WHITE, func(): game.give_up(), 34)

	# Полоса «заводим машину»
	_car_box = UiKit.panel(s, 0.12, 0.43, 0.88, 0.49, UiKit.SHADE)
	UiKit.label(_car_box, "Дачники уезжают! Жаль их!" if as_bee else "Заводим машину… держись!", 36,
		0.04, 0.45, 0.96, 0.95, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, true)
	var car_bar := UiKit.panel(_car_box, 0.06, 0.12, 0.94, 0.38, Color(1, 1, 1, 0.18), 10)
	_car_fill = UiKit.panel(car_bar, 0, 0, 0.02, 1, UiKit.HONEY_BG, 10)
	_car_box.modulate.a = 0.0

	_swat_btn = null
	_smoke_btn = null
	if not as_bee:
		# Инструменты (срабатывают сразу при нажатии)
		_smoke_btn = UiKit.button(s, "Дымарь", 0.6, 0.15, 0.96, 0.24, Color(0.45, 0.55, 0.65), Color.WHITE,
			func(): _with_human(func(h: Human): h.smoke()), 44, true)
		_swat_btn = UiKit.button(s, "Мухобойка", 0.6, 0.035, 0.96, 0.14, UiKit.HONEY_BG, UiKit.INK,
			func(): _with_human(func(h: Human): h.swat()), 48, true)

	_hint = UiKit.panel(s, 0.04, 0.035, 0.57 if not as_bee else 0.96, 0.24, UiKit.SHADE)
	var hint_text := "Веди пальцем — бежишь следом.\nСвайп — перекат: пока катишься, не жалят.\nСобери банки и стой у машины, пока заводится."
	if as_bee:
		hint_text = "Ты пчела в рою. Веди пальцем — летишь следом.\nВрежься в дачника — это укус. Свайп — рывок.\nНе дай дачникам унести банки и уехать!"
	elif game.escape and game.escape.kind == EscapeMatch.Kind.SURVIVAL:
		hint_text = "Держись как можно дольше!\nКаждые 20 секунд прилетает новая волна.\nБез укусов 4 секунды — отёк спадает."
	UiKit.label(_hint, hint_text, 30, 0.05, 0.05, 0.95, 0.95)
	_hint_at = Game.clock
	_escape_active = true


func _with_human(action: Callable) -> void:
	var game := Game.I
	if game and game.escape and is_instance_valid(game.escape.human):
		action.call(game.escape.human)


func _update_escape_hud() -> void:
	var game := Game.I
	var m := game.escape if game else null
	if m == null:
		return
	var me: Node3D = m.human if m.human else m.player_bee
	if not is_instance_valid(me):
		return
	var alive := m.active_humans().size()
	if m.kind == EscapeMatch.Kind.SURVIVAL:
		_jars_text.text = "Держишься %s" % _fmt_time(m.stats.time)
		_timer_text.text = ""
	else:
		var secs := ceili(maxf(0.0, m.time_left))
		_timer_text.text = "%d:%02d" % [secs / 60, secs % 60]
		_timer_text.label_settings.font_color = Color(1, 0.55, 0.5) if secs <= 20 else Color.WHITE
		if m.human == null:
			_jars_text.text = "Дачников: %d · банок %d/%d" % [alive, m.stats.jars, m.stats.jars_needed]
		else:
			_jars_text.text = "Все банки — к машине!" if m.all_jars() else "Банки %d/%d" % [m.stats.jars, m.stats.jars_needed]
	if m.human:
		_swell_text.text = "Отёк %d%%" % roundi(m.human.swelling * 100.0)
		_swell_fill.anchor_right = maxf(0.02, m.human.swelling)
	else:
		_swell_text.text = "Укусов: %d" % m.stats.stings_dealt
		_swell_fill.anchor_right = clampf(float(m.stats.humans_fainted) / maxf(1.0, m.stats.humans_total), 0.02, 1.0)

	var tgt := m.target()
	if not tgt.is_empty():
		var d: Vector3 = tgt["pos"] - me.global_position
		d.y = 0.0
		_target_text.text = "%s · %d м" % [tgt["label"], roundi(d.length())]
		point_arrow(_arrow, d)

	_car_box.modulate.a = move_toward(_car_box.modulate.a, 1.0 if m.car_progress > 0.01 else 0.0, get_process_delta_time() * 6.0)
	_car_fill.anchor_right = maxf(0.02, m.car_progress)

	if m.human and _swat_btn:
		var smoke_in := m.human.smoke_ready_in()
		_swat_btn.disabled = m.human.swat_ready_in() > 0.0
		_smoke_btn.disabled = smoke_in > 0.0
		_smoke_btn.text = "Дымарь · %d" % ceili(smoke_in) if smoke_in > 0.0 else "Дымарь"
	_fade_hint()


# ── Итоги ──────────────────────────────────────────────────

func show_results(stats: SortieStats, record: bool) -> void:
	var p := Profile.current()
	var s := new_screen("Итоги")
	place_say(0.81, 0.895)
	UiKit.panel(s, 0, 0, 1, 1, Color(0, 0, 0, 0.45), 0)
	var card := UiKit.panel(s, 0.06, 0.2, 0.94, 0.8, UiKit.CARD_BG, 30)

	UiKit.label(card, "Вылет окончен", 68, 0.05, 0.85, 0.95, 0.97, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true, false)
	if record:
		UiKit.label(card, "Новый рекорд!", 44, 0.05, 0.77, 0.95, 0.85, HORIZONTAL_ALIGNMENT_CENTER, UiKit.DEEP_HONEY, true, false)
	UiKit.label(card, "+%d мёда" % stats.honey_made, 90, 0.05, 0.6, 0.95, 0.77, HORIZONTAL_ALIGNMENT_CENTER, UiKit.DEEP_HONEY, true, false)
	var body := "Пыльцы собрано: %d\nДоставок в улей: %d\nРассыпано при ударах: %d\nОтжали осы: %d\nВрезалась: %d раз\nОс протаранено: %d" % [
		stats.pollen_collected, stats.deposits, stats.pollen_lost, stats.pollen_stolen, stats.crashes, stats.wasps_rammed]
	UiKit.label(card, body, 38, 0.08, 0.27, 0.92, 0.6, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false)
	UiKit.label(card, "На пасеке всего: %d мёда" % p.honey, 38, 0.05, 0.18, 0.95, 0.27, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true, false)

	UiKit.button(s, "Ещё вылет", 0.06, 0.07, 0.6, 0.17, UiKit.HONEY_BG, UiKit.INK, func(): Game.I.start("sortie"), 58)
	UiKit.button(s, "На пасеку", 0.63, 0.07, 0.94, 0.17, UiKit.MUTED, Color.WHITE, func(): Game.I.show_hub(), 42)
	say(Lines.pick(Lines.RESULT_GOOD if stats.honey_made >= 40 else Lines.RESULT_BAD), 4.0)


func show_escape_results(stats: EscapeMatch.Stats, record: bool) -> void:
	var p := Profile.current()
	var r := {"record": "", "again": Game.I.mode_id}
	var K := EscapeMatch.Kind
	if stats.player_is_bee:
		var won := not stats.escaped and stats.ending != "gaveup"
		r["title"] = "Пчёлы победили!" if won else ("Сдалась" if stats.ending == "gaveup" else "Дачники уехали")
		r["big"] = "%d укусов" % stats.stings_dealt
		r["color"] = UiKit.DEEP_HONEY if won else UiKit.DANGER_BG
		r["body"] = "Дачников на скорой: %d из %d\nУехали: %d\nБанок утащили: %d/%d\nВремя: %s" % [
			stats.humans_fainted, stats.humans_total, stats.humans_escaped, stats.jars, stats.jars_needed, _fmt_time(stats.time)]
		r["footer"] = ("+%d мёда · " % (10 * stats.humans_fainted) if won else "") + "побед в охоте: %d из %d" % [p.hunt_wins, p.hunt_games]
	elif stats.kind == K.SURVIVAL:
		r["title"] = "Увезли на скорой"
		r["big"] = _fmt_time(stats.time)
		r["color"] = UiKit.DEEP_HONEY
		r["record"] = "Новый рекорд выживания!" if record else ""
		r["body"] = "Продержался: %s\nУжалили: %d раз\nПчёл сбито: %d\nДымарь: %d раз\nПерекатов: %d" % [
			_fmt_time(stats.time), stats.stings, stats.swats, stats.smokes, stats.dodges]
		r["footer"] = "Рекорд: %s" % _fmt_time(p.survival_best)
	else:
		var titles := {"escaped": "Вы сбежали!" if stats.kind == K.TEAM else "Ты сбежал!", "ambulance": "Увезли на скорой",
			"timeout": "Не успели", "gaveup": "Сдался"}
		r["title"] = titles.get(stats.ending, "Конец")
		match stats.ending:
			"escaped":
				r["big"] = "за %s" % _fmt_time(stats.time)
				r["color"] = UiKit.DEEP_HONEY
			"ambulance":
				r["big"] = "%d укусов" % stats.stings
				r["color"] = UiKit.DANGER_BG
			_:
				r["big"] = "пчёлы довольны"
				r["color"] = UiKit.MUTED
		r["record"] = "Лучшее время!" if record else ""
		var team := ""
		if stats.kind == K.TEAM:
			team = "\nУехали: %d из %d · на скорой: %d" % [stats.humans_escaped, stats.humans_total, stats.humans_fainted]
		r["body"] = "Банок утащено: %d/%d\nУжалили тебя: %d раз\nПчёл сбито: %d · дым: %d · перекатов: %d%s" % [
			stats.jars, stats.jars_needed, stats.stings, stats.swats, stats.smokes, stats.dodges, team]
		r["footer"] = "Побегов всего: %d из %d" % [p.escape_wins, p.escape_attempts]
	show_card(r)


static func _fmt_time(seconds: float) -> String:
	var s := maxi(0, roundi(seconds))
	return "%d:%02d" % [s / 60, s % 60]


# ── Реплики, всплывашки, обновление ────────────────────────

func say(line: String, seconds: float) -> void:
	_say_text.text = line
	_say_until = Game.clock + seconds


func toast(text: String) -> void:
	_toast.text = text
	_toast_at = Game.clock


func _process(delta: float) -> void:
	_update_safe_area()
	_say.modulate.a = move_toward(_say.modulate.a, 1.0 if Game.clock < _say_until else 0.0, delta * 5.0)

	var tt := Game.clock - _toast_at
	_toast.modulate.a = 1.0 if tt < 1.6 else clampf(1.0 - (tt - 1.6) / 0.4, 0.0, 1.0)
	var lift := -minf(tt, 2.0) * 40.0
	_toast.offset_top = lift
	_toast.offset_bottom = lift

	if _question_active:
		var qt := Game.clock - _question_at
		if _silence == 0 and qt > 5.0:
			_silence = 1
			say(Lines.SILENCE[0], 3.0)
		elif _silence == 1 and qt > 11.0:
			_silence = 2
			say(Lines.SILENCE[1], 3.0)

	if is_instance_valid(_change_btn):
		var p := Profile.current()
		if p.can_change():
			var sec := p.seconds_to_change()
			_change_btn.text = "Я передумал · %d:%02d" % [sec / 60, sec % 60]
		else:
			_change_btn.queue_free()
			_change_btn = null

	if _hud_active:
		_update_hud()
	if _escape_active:
		_update_escape_hud()


## Держим интерфейс внутри безопасной зоны экрана (вырез камеры, жесты).
func _update_safe_area() -> void:
	var win := get_window().size
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return
	var x0 := clampf(float(safe.position.x) / win.x, 0.0, 0.2)
	var x1 := clampf(float(safe.end.x) / win.x, 0.8, 1.0)
	var top := clampf(float(safe.position.y) / win.y, 0.0, 0.2)
	var bottom := clampf(float(safe.end.y) / win.y, 0.8, 1.0)
	_safe.anchor_left = x0
	_safe.anchor_right = x1
	_safe.anchor_top = top
	_safe.anchor_bottom = bottom
