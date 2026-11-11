class_name UiKit
extends RefCounted
## Помощники для интерфейса, собранного кодом.
## Позиции — доли экрана, как на миллиметровке: (0,0) левый НИЗ, (1,1) правый ВЕРХ.
## Размеры шрифтов указаны для экрана 1080 пикселей в ширину и пересчитываются сами.

const HONEY_BG := Color(1.0, 0.76, 0.15)
const INK := Color(0.16, 0.11, 0.05)
const SHADE := Color(0.08, 0.06, 0.03, 0.62)
const MUTED := Color(0.55, 0.52, 0.48)
const DANGER_BG := Color(0.72, 0.24, 0.2)
const CARD_BG := Color(1.0, 0.98, 0.93, 0.97)
const DEEP_HONEY := Color(0.85, 0.52, 0.04)
const SCALE := 720.0 / 1080.0

static var _regular: Font
static var _bold: FontVariation


static func px(size: float) -> int:
	return maxi(8, roundi(size * SCALE))


static func regular() -> Font:
	if _regular == null:
		_regular = load("res://fonts/Rubik.ttf") as Font
	return _regular


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = regular()
		var ts := TextServerManager.get_primary_interface()
		if ts:
			_bold.variation_opentype = {ts.name_to_tag("wght"): 700}
	return _bold


static func place(c: Control, x0: float, y0: float, x1: float, y1: float) -> void:
	c.anchor_left = x0
	c.anchor_right = x1
	c.anchor_top = 1.0 - y1
	c.anchor_bottom = 1.0 - y0
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0


static func area(parent: Control, x0: float, y0: float, x1: float, y1: float, node_name := "Область") -> Control:
	var c := Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(c, x0, y0, x1, y1)
	parent.add_child(c)
	return c


static func box_style(color: Color, radius := 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(px(radius))
	sb.anti_aliasing = true
	return sb


static func panel(parent: Control, x0: float, y0: float, x1: float, y1: float, color: Color,
		radius := 22, node_name := "Панель") -> Panel:
	var p := Panel.new()
	p.name = node_name
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box_style(color, radius))
	place(p, x0, y0, x1, y1)
	parent.add_child(p)
	return p


static func label(parent: Control, text: String, size: float, x0: float, y0: float, x1: float, y1: float,
		align := HORIZONTAL_ALIGNMENT_CENTER, color := Color.WHITE, is_bold := false, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ls := LabelSettings.new()
	ls.font = bold() if is_bold else regular()
	ls.font_size = px(size)
	ls.font_color = color
	if outline:
		ls.outline_size = px(8)
		ls.outline_color = Color(0, 0, 0, 0.45)
	l.label_settings = ls
	place(l, x0, y0, x1, y1)
	parent.add_child(l)
	return l


static func button(parent: Control, text: String, x0: float, y0: float, x1: float, y1: float, bg: Color, fg: Color,
		on_press: Callable, size := 56, instant := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if instant:
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # для инструментов: срабатывает сразу
	b.add_theme_stylebox_override("normal", box_style(bg, 26))
	b.add_theme_stylebox_override("hover", box_style(bg.lightened(0.08), 26))
	b.add_theme_stylebox_override("pressed", box_style(bg.darkened(0.18), 26))
	b.add_theme_stylebox_override("disabled", box_style(Color(bg, bg.a * 0.55).darkened(0.2), 26))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", px(size))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.6))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	place(b, x0, y0, x1, y1)
	parent.add_child(b)
	return b


## Треугольник-стрелка (остриём вверх) для указателя «куда лететь».
static func arrow(parent: Control, x0: float, y0: float, x1: float, y1: float, color: Color) -> Control:
	var holder := area(parent, x0, y0, x1, y1, "Стрелка")
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([Vector2(0, -1), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)])
	holder.add_child(poly)
	holder.resized.connect(func():
		var s := minf(holder.size.x, holder.size.y) * 0.45
		poly.position = holder.size / 2
		poly.scale = Vector2(s, s))
	return holder
