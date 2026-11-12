class_name UiKit
extends RefCounted
## Интерфейс-«этикетка с банки мёда»: плотная бумага, толстый контур дёгтем,
## жёсткая тень как у наклейки. Кнопка при нажатии вдавливается в тень.
## Позиции — доли экрана: (0,0) левый НИЗ, (1,1) правый ВЕРХ.
## Размеры шрифтов — для экрана шириной 1080 и пересчитываются сами.

const INK := Color("2b1d14")
const PAPER := Color("ffefc2")
const PAPER_DARK := Color("efd99e")
const HONEY_BG := Color("f2b21b")
const BERRY := Color("d9473b")
const LEAF := Color("4f8a3c")
const SKY := Color("8fc9e8")
const MUTED := Color("d8c49a")

# Старые имена (на них опираются режимы)
const SHADE := PAPER
const CARD_BG := PAPER
const DEEP_HONEY := Color("c9850c")
const DANGER_BG := BERRY

const SCALE := 720.0 / 1080.0
const BORDER := 5
const SHADOW := 7

static var _regular: Font
static var _bold: FontVariation
static var _display: FontVariation
static var _icons := {}


static func px(size: float) -> int:
	return maxi(8, roundi(size * SCALE))


# ── Шрифты ─────────────────────────────────────────────────

static func regular() -> Font:
	if _regular == null:
		_regular = load("res://fonts/Rubik.ttf") as Font
	return _regular


static func _weighted(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path) as Font
	var ts := TextServerManager.get_primary_interface()
	if ts:
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
	return f


static func bold() -> Font:
	if _bold == null:
		_bold = _weighted("res://fonts/Rubik.ttf", 600)
	return _bold


## Заголовки, цифры, кнопки.
static func display() -> Font:
	if _display == null:
		_display = _weighted("res://fonts/Unbounded.ttf", 800)
	return _display


static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var p := "res://ui/icons/%s.svg" % icon_name
		_icons[icon_name] = load(p) if ResourceLoader.exists(p) else null
	return _icons[icon_name]


# ── Раскладка ──────────────────────────────────────────────

static func place(c: Control, x0: float, y0: float, x1: float, y1: float) -> void:
	c.anchor_left = x0
	c.anchor_right = x1
	c.anchor_top = 1.0 - y1
	c.anchor_bottom = 1.0 - y0
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0


## Переставить наклейку или кнопку целиком (вместе с тенью).
static func move(c: Control, x0: float, y0: float, x1: float, y1: float) -> void:
	var holder: Control = c.get_meta("holder", c)
	place(holder, x0, y0, x1, y1)


static func area(parent: Control, x0: float, y0: float, x1: float, y1: float, node_name := "Область") -> Control:
	var c := Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(c, x0, y0, x1, y1)
	parent.add_child(c)
	return c


static func box_style(color: Color, radius := 22, border := BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(px(radius))
	sb.anti_aliasing = true
	sb.corner_detail = 6
	if border > 0:
		sb.set_border_width_all(px(border))
		sb.border_color = INK
	return sb


static func _holder(parent: Control, x0: float, y0: float, x1: float, y1: float, node_name: String, tilt: float) -> Control:
	var h := area(parent, x0, y0, x1, y1, node_name)
	if tilt != 0.0:
		h.rotation_degrees = tilt
		h.resized.connect(func(): h.pivot_offset = h.size / 2)
	return h


# ── Наклейки ───────────────────────────────────────────────

## Наклейка: бумага с контуром и жёсткой тенью. Возвращает лицевую панель.
static func sticker(parent: Control, x0: float, y0: float, x1: float, y1: float, color := PAPER,
		radius := 22, tilt := 0.0, node_name := "Наклейка", shadow := SHADOW) -> Panel:
	var h := _holder(parent, x0, y0, x1, y1, node_name, tilt)
	if shadow > 0:
		var sh := Panel.new()
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.add_theme_stylebox_override("panel", box_style(INK, radius, 0))
		sh.set_anchors_preset(Control.PRESET_FULL_RECT)
		sh.offset_top = px(shadow)
		sh.offset_bottom = px(shadow)
		sh.offset_left = px(shadow) * 0.4
		sh.offset_right = px(shadow) * 0.4
		h.add_child(sh)
	var face := Panel.new()
	face.name = "Лицо"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", box_style(color, radius))
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_child(face)
	face.set_meta("holder", h)
	return face


## Небольшая бумажная плашка для HUD.
static func chip(parent: Control, x0: float, y0: float, x1: float, y1: float, node_name := "Плашка") -> Panel:
	return sticker(parent, x0, y0, x1, y1, PAPER, 18, 0.0, node_name, 5)


## Совместимость: цветная панель. Полупрозрачные и бумажные цвета превращаются в наклейку,
## панели без скругления — в затемнение экрана.
static func panel(parent: Control, x0: float, y0: float, x1: float, y1: float, color: Color,
		radius := 22, node_name := "Панель") -> Panel:
	if radius == 0:
		var p := Panel.new()
		p.name = node_name
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", box_style(Color(INK, minf(color.a, 0.5)), 0, 0))
		place(p, x0, y0, x1, y1)
		parent.add_child(p)
		return p
	if radius <= 10:
		# Полоски индикаторов (внутри наклеек)
		var bar := Panel.new()
		bar.name = node_name
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("panel", box_style(color if color.a > 0.5 else PAPER_DARK, radius, 3))
		place(bar, x0, y0, x1, y1)
		parent.add_child(bar)
		return bar
	return sticker(parent, x0, y0, x1, y1, color if color.a > 0.9 else PAPER, radius, 0.0, node_name, 6)


# ── Текст ──────────────────────────────────────────────────

## Подпись. outline — обводка дёгтем (для текста прямо поверх 3D-сцены).
## big — шрифт Unbounded (заголовки, цифры).
static func label(parent: Control, text: String, size: float, x0: float, y0: float, x1: float, y1: float,
		align := HORIZONTAL_ALIGNMENT_CENTER, color := INK, is_bold := false, outline := false, big := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ls := LabelSettings.new()
	ls.font = display() if big else (bold() if is_bold else regular())
	ls.font_size = px(size)
	ls.font_color = _ink_on_paper(color)
	if big:
		ls.line_spacing = -px(size) * 0.12
	if outline:
		ls.outline_size = px(14 if big else 9)
		ls.outline_color = INK
	l.label_settings = ls
	place(l, x0, y0, x1, y1)
	parent.add_child(l)
	return l


## Белый текст старых экранов на бумаге не читается — заменяем на дёготь.
static func _ink_on_paper(c: Color) -> Color:
	if c.is_equal_approx(Color.WHITE) or c.is_equal_approx(Color(1, 1, 1, 0.85)) or c.is_equal_approx(Color(1, 1, 1, 0.6)):
		return INK
	return c


# ── Кнопки ─────────────────────────────────────────────────

## Кнопка-наклейка. При нажатии лицевая часть опускается на тень.
static func button(parent: Control, text: String, x0: float, y0: float, x1: float, y1: float, bg: Color, fg: Color,
		on_press: Callable, size := 56, instant := false, icon_name := "", tilt := 0.0) -> Button:
	if bg.a < 0.9:
		bg = PAPER
	fg = _ink_on_paper(fg) if bg.get_luminance() > 0.55 else fg
	var h := _holder(parent, x0, y0, x1, y1, "Кнопка", tilt)
	var sh := Panel.new()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_theme_stylebox_override("panel", box_style(INK, 26, 0))
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	var d := px(SHADOW)
	sh.offset_top = d
	sh.offset_bottom = d
	h.add_child(sh)

	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	if instant:
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # инструменты срабатывают сразу
	b.add_theme_stylebox_override("normal", box_style(bg, 26))
	b.add_theme_stylebox_override("hover", box_style(bg.lightened(0.06), 26))
	b.add_theme_stylebox_override("pressed", box_style(bg.darkened(0.08), 26))
	b.add_theme_stylebox_override("disabled", box_style(bg.lerp(MUTED, 0.6), 26))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", display() if size >= 40 else bold())
	b.add_theme_font_size_override("font_size", px(size * (0.82 if size >= 40 else 1.0)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = true
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_theme_font_size_override("font_size", px(size * (0.7 if size >= 40 else 0.95)))
		b.add_theme_constant_override("h_separation", px(16))
		# Отступы внутри кнопки: иконка вписывается по высоте
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.content_margin_left = px(22)
			sb.content_margin_right = px(22)
			sb.content_margin_top = px(10)
			sb.content_margin_bottom = px(10)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_child(b)
	b.set_meta("holder", h)
	# Вдавливание
	b.button_down.connect(func(): b.offset_top = d; b.offset_bottom = d; sh.visible = false)
	b.button_up.connect(func(): b.offset_top = 0; b.offset_bottom = 0; sh.visible = true)
	b.pressed.connect(func(): Sfx.play("click"))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Картинка (иконка, портрет).
static func image(parent: Control, tex: Texture2D, x0: float, y0: float, x1: float, y1: float, tilt := 0.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(t, x0, y0, x1, y1)
	parent.add_child(t)
	if tilt != 0.0:
		t.rotation_degrees = tilt
		t.resized.connect(func(): t.pivot_offset = t.size / 2)
	return t


## Стрелка «куда лететь»: медовый указатель, вращается.
static func arrow(parent: Control, x0: float, y0: float, x1: float, y1: float, _color := HONEY_BG) -> Control:
	var holder := area(parent, x0, y0, x1, y1, "Стрелка")
	var t := TextureRect.new()
	t.texture = icon("arrow")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(t)
	holder.resized.connect(func(): t.pivot_offset = holder.size / 2)
	holder.set_meta("needle", t)
	return holder


## Повернуть стрелку (радианы, 0 — вверх по экрану).
static func point(holder: Control, angle: float) -> void:
	var t: Control = holder.get_meta("needle", null)
	if t:
		t.rotation = angle


## «Пружинка» при появлении — ответ на действие игрока.
static func pop(c: Control, from := 0.85) -> void:
	var holder: Control = c.get_meta("holder", c)
	holder.pivot_offset = holder.size / 2
	holder.scale = Vector2.ONE * from
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
