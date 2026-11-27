## Shared look for every HUD element (Phase 8): one theme, one set of colours,
## helpers for panels, labels and bars. Amber and signal cyan are reserved for
## instruments and warnings (docs/VISUALS.md §3.2).
class_name UiStyle
extends RefCounted

const BG: Color = Color(0.07, 0.08, 0.075, 0.86)
const BG_SOFT: Color = Color(0.07, 0.08, 0.075, 0.62)
const LINE: Color = Color(1.0, 1.0, 1.0, 0.09)
const TEXT: Color = Color(0.9, 0.9, 0.86)
const DIM: Color = Color(0.62, 0.64, 0.6)
const AMBER: Color = Color("#E0B54A")
const CYAN: Color = Color("#5FC7D1")
const GOOD: Color = Color(0.55, 0.85, 0.5)
const BAD: Color = Color(0.95, 0.42, 0.33)
const OWN: Color = Color(0.24, 0.55, 0.88)
const FONT_S: int = 12
const FONT_M: int = 14
const FONT_L: int = 18

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font_size = FONT_M
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	var normal: StyleBoxFlat = _box(Color(0.16, 0.17, 0.16, 0.95), Color(1, 1, 1, 0.1))
	var hover: StyleBoxFlat = _box(Color(0.24, 0.25, 0.23, 0.98), Color(1, 1, 1, 0.22))
	var pressed: StyleBoxFlat = _box(Color(0.3, 0.27, 0.16, 1.0), AMBER)
	var disabled: StyleBoxFlat = _box(Color(0.11, 0.11, 0.11, 0.8), Color(1, 1, 1, 0.04))
	for cls: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(0.45, 0.46, 0.44))
		t.set_font_size("font_size", cls, FONT_M)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.05, 0.06, 0.05, 0.96), AMBER.darkened(0.3)))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_S + 1)
	_theme = t
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func panel_box() -> StyleBoxFlat:
	var s: StyleBoxFlat = _box(BG, LINE)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Themes every Control that enters a CanvasLayer (themes don't pass through
## CanvasLayers on their own).
static func theme_layer(layer: CanvasLayer) -> void:
	layer.child_entered_tree.connect(func(n: Node) -> void:
		var c: Control = n as Control
		if c != null:
			c.theme = theme())
	for n2: Node in layer.get_children():
		var c2: Control = n2 as Control
		if c2 != null:
			c2.theme = theme()


static func label(text: String, size: int = FONT_M, color: Color = TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A thin horizontal bar (value 0..1) drawn into any CanvasItem.
static func bar(ci: CanvasItem, r: Rect2, value: float, fill: Color, back: Color = Color(0, 0, 0, 0.55)) -> void:
	ci.draw_rect(r, back)
	var w: float = r.size.x * clampf(value, 0.0, 1.0)
	if w > 0.0:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), fill)


static func health_color(f: float) -> Color:
	if f > 0.66:
		return GOOD
	if f > 0.33:
		return AMBER
	return BAD


static func text(ci: CanvasItem, p: Vector2, s: String, size: int = FONT_M, c: Color = TEXT, shadow: bool = true) -> void:
	var font: Font = ThemeDB.fallback_font
	if shadow:
		ci.draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * c.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


static func text_width(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
