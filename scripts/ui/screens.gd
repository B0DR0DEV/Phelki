class_name Screens
extends CanvasLayer
## Все экраны: вопрос деда, пасека (меню), вылет и побег (HUD), итоги.
## Стиль — этикетки с банки мёда: бумага, контур дёгтем, жёсткая тень.
## Поверх экранов — дед с репликой, всплывающие «+мёд» и обучение.

var _root: Control
var _safe: Control
var _screen: Control

var _say_box: Control
var _say_bubble: Panel
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
var _tutorial_dots: Label

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

	# Дед с репликой: портрет в медовом кружке и пузырь
	_say_box = UiKit.area(_safe, 0.03, 0.5, 0.97, 0.59, "Дед говорит")
	var face := UiKit.sticker(_say_box, 0.0, 0.0, 0.2, 1.0, UiKit.HONEY_BG, 80, -4.0, "Портрет", 5)
	UiKit.image(face, UiKit.icon("ded"), 0.04, 0.04, 0.96, 0.96)
	_say_bubble = UiKit.sticker(_say_box, 0.23, 0.08, 1.0, 0.92, UiKit.PAPER, 26, 0.0, "Пузырь", 5)
	_say_text = UiKit.label(_say_bubble, "", 38, 0.05, 0.05, 0.95, 0.95, HORIZONTAL_ALIGNMENT_LEFT)
	_say_box.modulate.a = 0.0

	# «+12 мёда» и прочие всплывашки: крупно, медом, с обводкой
	_toast = UiKit.label(_safe, "", 62, 0.04, 0.44, 0.96, 0.52, HORIZONTAL_ALIGNMENT_CENTER, UiKit.HONEY_BG, false, true, true)
	_toast.modulate.a = 0.0

	# Обучение: медовая наклейка с книжкой и точками шагов
	_tutorial = UiKit.sticker(_safe, 0.04, 0.6, 0.96, 0.7, UiKit.HONEY_BG, 22, 1.0, "Обучение", 6)
	UiKit.image(_tutorial, UiKit.icon("book"), 0.02, 0.15, 0.15, 0.85)
	_tutorial_text = UiKit.label(_tutorial, "", 36, 0.17, 0.22, 0.97, 0.95, HORIZONTAL_ALIGNMENT_LEFT)
	_tutorial_dots = UiKit.label(_tutorial, "", 30, 0.17, 0.0, 0.97, 0.28, HORIZONTAL_ALIGNMENT_RIGHT, UiKit.INK, true)
	_tutorial.get_meta("holder").visible = false

	Sfx.setup(self)


func new_screen(screen_name: String) -> Control:
	if _screen:
		_screen.queue_free()
	_screen = UiKit.area(_safe, 0, 0, 1, 1, screen_name)
	_safe.move_child(_screen, 0)  # под дедом, всплывашками и обучением
	_question_active = false
	_hud_active = false
	_escape_active = false
	_change_btn = null
	_toast_at = -100.0
	return _screen


func place_say(y0: float, y1: float) -> void:
	UiKit.place(_say_box, 0.03, y0, 0.97, y1)


func current_screen() -> Control:
	return _screen


# ── Вопрос ─────────────────────────────────────────────────

func show_question() -> void:
	var s := new_screen("Вопрос")
	Sfx.music("menu")
	place_say(0.255, 0.345)
	# Дед смотрит прямо на тебя
	var ded := UiKit.sticker(s, 0.26, 0.62, 0.74, 0.92, UiKit.HONEY_BG, 140, -3.0, "Дед", 8)
	UiKit.image(ded, UiKit.icon("ded"), 0.05, 0.03, 0.95, 0.97)
	# Сам вопрос — главная этикетка игры
	var label := UiKit.sticker(s, 0.05, 0.37, 0.95, 0.6, UiKit.PAPER, 40, -1.5, "Этикетка", 9)
	UiKit.label(label, "Ты пчёлок\nуважаешь?", 84, 0.04, 0.08, 0.96, 0.92, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false, true)
	UiKit.pop(label, 0.7)
	UiKit.button(s, "Уважаю", 0.05, 0.12, 0.49, 0.235, UiKit.HONEY_BG, UiKit.INK,
		func(): Game.I.answer(Profile.Side.BEE), 52, false, "bee", -1.0)
	UiKit.button(s, "Нет", 0.53, 0.12, 0.95, 0.235, UiKit.BERRY, UiKit.PAPER,
		func(): Game.I.answer(Profile.Side.HUMAN), 52, false, "swatter", 1.0)
	var note := UiKit.chip(s, 0.08, 0.025, 0.92, 0.085)
	UiKit.label(note, "Ответ останется с тобой. Передумать можно один раз в первые 10 минут.", 26, 0.04, 0.05, 0.96, 0.95)
	_question_active = true
	_question_at = Game.clock
	_silence = 0


# ── Пасека (меню) ──────────────────────────────────────────

func show_hub() -> void:
	var p := Profile.current()
	var bee := p.side == Profile.Side.BEE
	var game := Game.I
	var s := new_screen("Пасека")
	Sfx.music("menu")
	Sfx.stop_loops()
	place_say(0.595, 0.685)

	# Мёд и сторона
	var honey := UiKit.chip(s, 0.03, 0.915, 0.42, 0.975)
	UiKit.image(honey, UiKit.icon("honey"), 0.03, 0.08, 0.27, 0.92)
	UiKit.label(honey, str(p.honey), 46, 0.3, 0.0, 0.95, 1.0, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false, true)
	var stamp := UiKit.sticker(s, 0.56, 0.915, 0.97, 0.975, UiKit.HONEY_BG if bee else UiKit.BERRY, 18, 3.0, "Сторона", 5)
	UiKit.label(stamp, "Пасечник" if bee else "Неуважающий", 34, 0.04, 0.0, 0.96, 1.0, HORIZONTAL_ALIGNMENT_CENTER,
		UiKit.INK if bee else UiKit.PAPER, true)

	# Логотип-этикетка
	var logo := UiKit.sticker(s, 0.08, 0.775, 0.92, 0.87, UiKit.PAPER, 60, -2.0, "Логотип", 8)
	UiKit.label(logo, "Пчёлок уважаешь?", 52, 0.04, 0.05, 0.96, 0.95, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false, true)
	UiKit.image(s, UiKit.icon("bee"), 0.8, 0.83, 0.97, 0.925, 14.0)

	# Карта
	var maps: Array = World.MAP_ORDER
	var idx := maps.find(game.world.map_id)
	UiKit.button(s, "‹", 0.08, 0.7, 0.2, 0.755, UiKit.PAPER, UiKit.INK,
		func(): game.set_map(maps[(idx - 1 + maps.size()) % maps.size()]), 56)
	var map_chip := UiKit.chip(s, 0.23, 0.7, 0.77, 0.755)
	UiKit.label(map_chip, game.world.map_name(), 34, 0.04, 0.0, 0.96, 1.0, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false, true)
	UiKit.button(s, "›", 0.8, 0.7, 0.92, 0.755, UiKit.PAPER, UiKit.INK,
		func(): game.set_map(maps[(idx + 1) % maps.size()]), 56)

	# Режимы: главный — крупно, остальные — наклейки по две в ряд
	var modes: Array
	if bee:
		modes = [
			["sortie", "Вылет", "bee", "рекорд %d мёда" % p.best_sortie_honey],
			["race", "Перегонки", "rings", "побед %d" % p.race_wins],
			["hunt", "Охота", "hunt", "побед %d" % p.hunt_wins],
			["bear", "Медведь", "bear", "побед %d" % p.bear_wins],
			["flappy", "Флаппи", "flappy", "рекорд %d" % p.flappy_best],
		]
	else:
		modes = [
			["escape", "Побег", "car", "лучшее время %s" % _fmt_time(p.best_escape_time) if p.best_escape_time > 0.0 else "3 банки и к машине"],
			["team", "Втроём", "team", "побед %d" % p.team_wins],
			["survival", "Выживание", "swarm", "рекорд %s" % _fmt_time(p.survival_best)],
			["flappy", "Флаппи", "flappy", "рекорд %d" % p.flappy_best],
		]
	modes.append(["online", "Онлайн-охота", "online", "живые игроки по сети"])

	var main: Array = modes[0]
	var mb := UiKit.button(s, main[1], 0.05, 0.455, 0.95, 0.57, UiKit.HONEY_BG if bee else UiKit.BERRY,
		UiKit.INK if bee else UiKit.PAPER, func(): game.start(main[0]), 64, false, main[2], -1.0)
	mb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mb.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.label(mb, main[3], 30, 0.4, 0.08, 0.95, 0.42, HORIZONTAL_ALIGNMENT_RIGHT, UiKit.INK if bee else UiKit.PAPER, true)

	var rest := modes.slice(1)
	var row_h := 0.085
	for i in rest.size():
		var m: Array = rest[i]
		var col := i % 2
		var row := i / 2
		var last_alone := i == rest.size() - 1 and rest.size() % 2 == 1
		var x0 := 0.05 if (col == 0 or last_alone) else 0.52
		var x1 := 0.95 if last_alone else (0.48 if col == 0 else 0.95)
		var y1 := 0.425 - row * (row_h + 0.022)
		var id: String = m[0]
		var b := UiKit.button(s, m[1], x0, y1 - row_h, x1, y1, UiKit.PAPER, UiKit.INK,
			func(): game.ui.show_online() if id == "online" else game.start(id), 36, false, m[2], [1.2, -1.0, 0.8, -0.6, 0.5][i % 5])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.label(b, m[3], 26, 0.3 if not last_alone else 0.5, 0.06, 0.94, 0.38, HORIZONTAL_ALIGNMENT_RIGHT, UiKit.INK)

	# Настройки
	UiKit.button(s, "Сверху" if not game.fpv else "Глазами", 0.04, 0.015, 0.33, 0.07, UiKit.PAPER, UiKit.INK,
		func(): game.toggle_fpv(); show_hub(), 26, false, "eye")
	UiKit.button(s, "Вибро" if p.vibration else "Без вибро", 0.355, 0.015, 0.645, 0.07, UiKit.PAPER, UiKit.INK,
		func(): p.vibration = not p.vibration; p.save(); show_hub(), 26, false, "vibro")
	UiKit.button(s, "Обучение", 0.67, 0.015, 0.96, 0.07, UiKit.PAPER, UiKit.INK,
		func(): Tutorial.reset_all(); toast("Обучение покажется снова"), 26, false, "book")

	if p.can_change():
		var other := Profile.Side.HUMAN if bee else Profile.Side.BEE
		_change_btn = UiKit.button(s, "", 0.56, 0.875, 0.97, 0.905, UiKit.PAPER, UiKit.INK, func(): game.answer(other), 24)

	if Game.clock > _say_until:
		say(Lines.pick(Lines.HUB_BEE if bee else Lines.HUB_HUMAN), 3.0)


func show_online() -> void:
	Game.I.net.show_menu()


## Кнопка «вид» в игровом экране.
func view_button(parent: Control) -> Button:
	var b := UiKit.button(parent, "", 0.44, 0.845, 0.7, 0.895, UiKit.PAPER, UiKit.INK, Callable(), 26, false, "eye")
	var refresh := func(): b.text = "Глазами" if Game.I.fpv else "Сверху"
	refresh.call()
	b.pressed.connect(func(): Game.I.toggle_fpv(); refresh.call())
	return b


# ── Общие итоги ────────────────────────────────────────────

## Итоги режима: {title, big, color, body, record, footer, again}.
func show_card(r: Dictionary) -> void:
	var s := new_screen("Итоги")
	Sfx.stop_loops()
	place_say(0.82, 0.91)
	UiKit.panel(s, 0, 0, 1, 1, Color(0, 0, 0, 0.35), 0)
	var card := UiKit.sticker(s, 0.06, 0.21, 0.94, 0.79, UiKit.PAPER, 34, -1.0, "Карточка", 10)
	UiKit.pop(card, 0.8)
	UiKit.label(card, r.get("title", ""), 50, 0.05, 0.84, 0.95, 0.96, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false, true)
	var big_color: Color = r.get("color", UiKit.HONEY_BG)
	if big_color == UiKit.DEEP_HONEY:
		big_color = UiKit.HONEY_BG
	UiKit.label(card, r.get("big", ""), 96, 0.04, 0.6, 0.96, 0.82, HORIZONTAL_ALIGNMENT_CENTER, big_color, false, true, true)
	UiKit.label(card, r.get("body", ""), 34, 0.09, 0.25, 0.91, 0.6, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK)
	var foot := UiKit.sticker(card, 0.06, 0.05, 0.94, 0.19, UiKit.PAPER_DARK, 20, 0.0, "Подвал", 0)
	UiKit.label(foot, r.get("footer", ""), 30, 0.04, 0.0, 0.96, 1.0, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true)
	if r.get("record", "") != "":
		var rib := UiKit.sticker(s, 0.56, 0.755, 0.97, 0.815, UiKit.BERRY, 16, 7.0, "Рекорд", 5)
		UiKit.label(rib, r["record"], 30, 0.04, 0.0, 0.96, 1.0, HORIZONTAL_ALIGNMENT_CENTER, UiKit.PAPER, true)
	var won: bool = r.get("won", big_color == UiKit.HONEY_BG)
	Sfx.play("win" if won else "lose", -3.0, 1.0, 0.0)
	var again: String = r.get("again", Game.I.mode_id)
	if again != "":
		UiKit.button(s, "Ещё раз", 0.06, 0.07, 0.6, 0.17, UiKit.HONEY_BG, UiKit.INK, func(): Game.I.start(again), 54)
	UiKit.button(s, "В меню", 0.63, 0.07, 0.94, 0.17, UiKit.PAPER, UiKit.INK, func(): Game.I.show_hub(), 40)


func show_tutorial(text: String, step: int, total: int) -> void:
	var h: Control = _tutorial.get_meta("holder")
	if not h.visible:
		UiKit.pop(_tutorial, 0.6)
	h.visible = true
	_tutorial_text.text = text
	var dots := ""
	for i in total:
		dots += "●" if i < step else "○"
	_tutorial_dots.text = dots


func hide_tutorial() -> void:
	if _tutorial:
		_tutorial.get_meta("holder").visible = false


# ── Вылет (HUD) ────────────────────────────────────────────

## Верхняя строка игры: три плашки. Возвращает [левая, центр, правая].
func _top_row(s: Control, left_icon: String, right_icon: String) -> Array:
	var l := UiKit.chip(s, 0.03, 0.915, 0.37, 0.975)
	UiKit.image(l, UiKit.icon(left_icon), 0.02, 0.1, 0.24, 0.9)
	var c := UiKit.chip(s, 0.39, 0.915, 0.61, 0.975)
	var r := UiKit.chip(s, 0.63, 0.915, 0.97, 0.975)
	UiKit.image(r, UiKit.icon(right_icon), 0.02, 0.1, 0.24, 0.9)
	return [l, c, r]


func _target_chip(s: Control) -> Label:
	var tag := UiKit.chip(s, 0.03, 0.845, 0.42, 0.895)
	_arrow = UiKit.arrow(tag, 0.02, 0.06, 0.2, 0.94)
	return UiKit.label(tag, "", 28, 0.22, 0.0, 0.97, 1.0, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, true)


func _hint_chip(s: Control, text: String, x1 := 0.95) -> void:
	_hint = UiKit.chip(s, 0.04, 0.035, x1, 0.15)
	UiKit.label(_hint, text, 28, 0.05, 0.05, 0.95, 0.95, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_at = Game.clock


func show_hud() -> void:
	var s := new_screen("Вылет")
	Sfx.music("game")
	place_say(0.73, 0.82)
	var row := _top_row(s, "pollen", "honey")
	_pollen_text = UiKit.label(row[0], "", 26, 0.26, 0.46, 0.96, 0.96, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, true)
	var bar := UiKit.panel(row[0], 0.27, 0.14, 0.93, 0.44, UiKit.PAPER_DARK, 8)
	_pollen_fill = UiKit.panel(bar, 0, 0, 0.02, 1, UiKit.HONEY_BG, 8)
	_timer_text = UiKit.label(row[1], "3:00", 40, 0.0, 0.0, 1.0, 1.0, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false, true)
	_honey_text = UiKit.label(row[2], "", 38, 0.28, 0.0, 0.96, 1.0, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, false, false, true)
	_hive_text = _target_chip(s)
	view_button(s)
	UiKit.button(s, "Домой", 0.72, 0.845, 0.97, 0.895, UiKit.PAPER, UiKit.INK, func(): Game.I.end_sortie(), 26, false, "home")
	_hint_chip(s, "Веди пальцем — пчела летит следом. Зависни над цветком — соберёшь пыльцу, неси её в улей. Быстрый свайп — рывок.")
	_hud_active = true


func _update_hud() -> void:
	var game := Game.I
	if game == null or game.stats == null:
		return
	var bee := game.bee
	if is_instance_valid(bee):
		_pollen_text.text = "%d из %d" % [bee.pollen, Bee.CAPACITY]
		_pollen_fill.anchor_right = maxf(0.02, bee.load_fraction())
		var d := game.world.hive_position - bee.global_position
		d.y = 0.0
		_hive_text.text = "Ты у улья" if d.length() < 2.5 else "Улей, %d м" % roundi(d.length())
		point_arrow(_arrow, d)
		Sfx.loop("buzz", 0.35 + minf(bee.velocity.length() / 12.0, 0.6), 0.9 + minf(bee.velocity.length() / 25.0, 0.5))
	var secs := ceili(maxf(0.0, game.time_left))
	_timer_text.text = "%d:%02d" % [secs / 60, secs % 60]
	_timer_text.label_settings.font_color = UiKit.BERRY if secs <= 20 else UiKit.INK
	_honey_text.text = "+%d" % game.stats.honey_made
	_fade_hint()


## Стрелка указывает направление по земле относительно камеры.
func point_arrow(holder: Control, d: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := 0.0
	if cam:
		var f := -cam.global_basis.z
		cam_yaw = atan2(f.x, f.z)
	UiKit.point(holder, -(atan2(d.x, d.z) - cam_yaw))


func _fade_hint() -> void:
	if not is_instance_valid(_hint):
		return
	var t := Game.clock - _hint_at
	(_hint.get_meta("holder") as Control).modulate.a = 1.0 if t < 8.0 else clampf(1.0 - (t - 8.0) / 1.5, 0.0, 1.0)


# ── Побег (HUD) ────────────────────────────────────────────

func show_escape_hud() -> void:
	var s := new_screen("Побег")
	Sfx.music("game")
	place_say(0.73, 0.82)
	var game := Game.I
	var as_bee := game.escape != null and game.escape.human == null

	var row := _top_row(s, "honey", "bee" if as_bee else "swatter")
	_jars_text = UiKit.label(row[0], "", 26, 0.26, 0.0, 0.97, 1.0, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, true)
	_timer_text = UiKit.label(row[1], "3:00", 40, 0.0, 0.0, 1.0, 1.0, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, false, false, true)
	_swell_text = UiKit.label(row[2], "", 26, 0.26, 0.46, 0.96, 0.96, HORIZONTAL_ALIGNMENT_LEFT, UiKit.INK, true)
	var bar := UiKit.panel(row[2], 0.27, 0.14, 0.93, 0.44, UiKit.PAPER_DARK, 8)
	_swell_fill = UiKit.panel(bar, 0, 0, 0.02, 1, UiKit.BERRY, 8)

	_target_text = _target_chip(s)
	view_button(s)
	UiKit.button(s, "Сдаться", 0.72, 0.845, 0.97, 0.895, UiKit.PAPER, UiKit.INK, func(): game.give_up(), 26)

	# Полоса «заводим машину»
	_car_box = UiKit.sticker(s, 0.1, 0.405, 0.9, 0.475, UiKit.HONEY_BG, 22, 0.0, "Заводим", 6)
	UiKit.label(_car_box, "Дачники уезжают — жаль их!" if as_bee else "Заводим машину, держись!", 30,
		0.04, 0.45, 0.96, 0.95, HORIZONTAL_ALIGNMENT_CENTER, UiKit.INK, true)
	var car_bar := UiKit.panel(_car_box, 0.06, 0.12, 0.94, 0.4, UiKit.PAPER, 8)
	_car_fill = UiKit.panel(car_bar, 0, 0, 0.02, 1, UiKit.LEAF, 8)
	(_car_box.get_meta("holder") as Control).modulate.a = 0.0

	_swat_btn = null
	_smoke_btn = null
	if not as_bee:
		_smoke_btn = UiKit.button(s, "Дымарь", 0.6, 0.165, 0.96, 0.255, UiKit.SKY, UiKit.INK,
			func(): _with_human(func(h: Human): h.smoke()), 36, true, "smoke", -1.5)
		_swat_btn = UiKit.button(s, "Шлёп", 0.6, 0.035, 0.96, 0.145, UiKit.HONEY_BG, UiKit.INK,
			func(): _with_human(func(h: Human): h.swat()), 44, true, "swatter", 1.5)

	var hint_text := "Веди пальцем — бежишь следом. Свайп — перекат, пока катишься, не жалят. Собери банки и стой у машины, пока заводится."
	if as_bee:
		hint_text = "Ты пчела в рою. Врежься в дачника — это укус, свайп — рывок. Не дай им унести банки и уехать!"
	elif game.escape and game.escape.kind == EscapeMatch.Kind.SURVIVAL:
		hint_text = "Держись как можно дольше. Каждые 20 секунд прилетает новая волна. Без укусов отёк спадает."
	_hint_chip(s, hint_text, 0.95 if as_bee else 0.57)
	if not as_bee:
		UiKit.move(_hint, 0.04, 0.035, 0.57, 0.255)
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
		_jars_text.text = "Волна %d" % (m._wave + 1)
		_timer_text.text = _fmt_time(m.stats.time)
	else:
		var secs := ceili(maxf(0.0, m.time_left))
		_timer_text.text = "%d:%02d" % [secs / 60, secs % 60]
		_timer_text.label_settings.font_color = UiKit.BERRY if secs <= 20 else UiKit.INK
		if m.human == null:
			_jars_text.text = "Дачников %d" % alive
		else:
			_jars_text.text = "К машине!" if m.all_jars() else "Банки %d из %d" % [m.stats.jars, m.stats.jars_needed]
	if m.human:
		_swell_text.text = "Отёк %d%%" % roundi(m.human.swelling * 100.0)
		_swell_fill.anchor_right = maxf(0.02, m.human.swelling)
	else:
		_swell_text.text = "Укусов %d" % m.stats.stings_dealt
		_swell_fill.anchor_right = clampf(float(m.stats.humans_fainted) / maxf(1.0, m.stats.humans_total), 0.02, 1.0)

	var tgt := m.target()
	if not tgt.is_empty():
		var d: Vector3 = tgt["pos"] - me.global_position
		d.y = 0.0
		_target_text.text = "%s, %d м" % [tgt["label"], roundi(d.length())]
		point_arrow(_arrow, d)

	var car_holder: Control = _car_box.get_meta("holder")
	car_holder.modulate.a = move_toward(car_holder.modulate.a, 1.0 if m.car_progress > 0.01 else 0.0, get_process_delta_time() * 6.0)
	_car_fill.anchor_right = maxf(0.02, m.car_progress)

	if m.human and _swat_btn:
		var smoke_in := m.human.smoke_ready_in()
		_swat_btn.disabled = m.human.swat_ready_in() > 0.0
		_smoke_btn.disabled = smoke_in > 0.0
		_smoke_btn.text = "Дымарь %d" % ceili(smoke_in) if smoke_in > 0.0 else "Дымарь"
	# Гул роя тем громче, чем больше пчёл рядом
	var near := 0
	for b in m.bots:
		if is_instance_valid(b) and b.global_position.distance_to(me.global_position) < 8.0:
			near += 1
	Sfx.loop("swarm", clampf(near / 8.0, 0.0, 0.9), 1.0)
	if m.player_bee:
		Sfx.loop("buzz", 0.5, 1.0 + minf(m.player_bee.velocity.length() / 25.0, 0.4))
	_fade_hint()


# ── Итоги ──────────────────────────────────────────────────

func show_results(stats: SortieStats, record: bool) -> void:
	var p := Profile.current()
	show_card({
		"title": "Вылет окончен",
		"big": "+%d мёда" % stats.honey_made,
		"color": UiKit.HONEY_BG,
		"won": stats.honey_made > 0,
		"record": "Рекорд!" if record else "",
		"body": "Пыльцы собрано: %d\nДоставок в улей: %d\nРассыпано при ударах: %d\nОтжали осы: %d\nВрезалась: %d раз\nОс протаранено: %d" % [
			stats.pollen_collected, stats.deposits, stats.pollen_lost, stats.pollen_stolen, stats.crashes, stats.wasps_rammed],
		"footer": "На пасеке всего %d мёда" % p.honey,
		"again": "sortie",
	})
	say(Lines.pick(Lines.RESULT_GOOD if stats.honey_made >= 40 else Lines.RESULT_BAD), 4.0)


func show_escape_results(stats: EscapeMatch.Stats, record: bool) -> void:
	var p := Profile.current()
	var r := {"record": "", "again": Game.I.mode_id}
	var K := EscapeMatch.Kind
	if stats.player_is_bee:
		var won := not stats.escaped and stats.ending != "gaveup"
		r["won"] = won
		r["title"] = "Пчёлы победили!" if won else ("Сдалась" if stats.ending == "gaveup" else "Дачники уехали")
		r["big"] = "%d укусов" % stats.stings_dealt
		r["color"] = UiKit.HONEY_BG if won else UiKit.BERRY
		r["body"] = "Дачников на скорой: %d из %d\nУехали: %d\nБанок утащили: %d из %d\nВремя: %s" % [
			stats.humans_fainted, stats.humans_total, stats.humans_escaped, stats.jars, stats.jars_needed, _fmt_time(stats.time)]
		r["footer"] = ("+%d мёда, " % (10 * stats.humans_fainted) if won else "") + "побед в охоте %d из %d" % [p.hunt_wins, p.hunt_games]
	elif stats.kind == K.SURVIVAL:
		r["won"] = record
		r["title"] = "Увезли на скорой"
		r["big"] = _fmt_time(stats.time)
		r["color"] = UiKit.HONEY_BG
		r["record"] = "Рекорд!" if record else ""
		r["body"] = "Продержался: %s\nУжалили: %d раз\nПчёл сбито: %d\nДымарь: %d раз\nПерекатов: %d" % [
			_fmt_time(stats.time), stats.stings, stats.swats, stats.smokes, stats.dodges]
		r["footer"] = "Рекорд выживания %s" % _fmt_time(p.survival_best)
	else:
		var titles := {"escaped": "Вы сбежали!" if stats.kind == K.TEAM else "Ты сбежал!", "ambulance": "Увезли на скорой",
			"timeout": "Не успели", "gaveup": "Сдался"}
		r["title"] = titles.get(stats.ending, "Конец")
		r["won"] = stats.escaped
		match stats.ending:
			"escaped":
				r["big"] = _fmt_time(stats.time)
				r["color"] = UiKit.HONEY_BG
			"ambulance":
				r["big"] = "%d укусов" % stats.stings
				r["color"] = UiKit.BERRY
			_:
				r["big"] = "Пчёлы рады"
				r["color"] = UiKit.BERRY
		r["record"] = "Лучшее время!" if record else ""
		var team := ""
		if stats.kind == K.TEAM:
			team = "\nУехали: %d из %d, на скорой: %d" % [stats.humans_escaped, stats.humans_total, stats.humans_fainted]
		r["body"] = "Банок утащено: %d из %d\nУжалили тебя: %d раз\nПчёл сбито: %d\nДымарь: %d, перекатов: %d%s" % [
			stats.jars, stats.jars_needed, stats.stings, stats.swats, stats.smokes, stats.dodges, team]
		r["footer"] = "Побегов всего %d из %d" % [p.escape_wins, p.escape_attempts]
	show_card(r)


static func _fmt_time(seconds: float) -> String:
	var s := maxi(0, roundi(seconds))
	return "%d:%02d" % [s / 60, s % 60]


# ── Реплики, всплывашки, обновление ────────────────────────

func say(line: String, seconds: float) -> void:
	if _say_text.text != line or Game.clock >= _say_until:
		Sfx.mumble(line)
		UiKit.pop(_say_bubble, 0.92)
	_say_text.text = line
	_say_until = Game.clock + seconds


func toast(text: String) -> void:
	_toast.text = text
	_toast_at = Game.clock
	_toast.pivot_offset = _toast.size / 2
	_toast.scale = Vector2.ONE * 0.6
	var tw := _toast.create_tween()
	tw.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_update_safe_area()
	_say_box.modulate.a = move_toward(_say_box.modulate.a, 1.0 if Game.clock < _say_until else 0.0, delta * 5.0)

	var tt := Game.clock - _toast_at
	_toast.modulate.a = 1.0 if tt < 1.4 else clampf(1.0 - (tt - 1.4) / 0.4, 0.0, 1.0)
	var lift := -minf(tt, 2.0) * 30.0
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
			_change_btn.text = "Передумать (%d:%02d)" % [sec / 60, sec % 60]
		else:
			(_change_btn.get_meta("holder") as Control).queue_free()
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
	_safe.anchor_left = clampf(float(safe.position.x) / win.x, 0.0, 0.2)
	_safe.anchor_right = clampf(float(safe.end.x) / win.x, 0.8, 1.0)
	_safe.anchor_top = clampf(float(safe.position.y) / win.y, 0.0, 0.2)
	_safe.anchor_bottom = clampf(float(safe.end.y) / win.y, 0.8, 1.0)
