## NATO-style tactical symbols (APP-6 look) for units on the map. Friendly:
## blue rectangle. Hostile: red diamond. Unknown contact: diamond with "?".
## The icon inside says what the unit does; a status bar sits underneath.
class_name NatoSymbol
extends RefCounted

const W: float = 24.0
const H: float = 16.0


static func role_of(def: UnitStats) -> String:
	if def.is_air:
		return "rotary" if def.battery_ticks == 0 else "uav"
	return def.role


## Draws the frame and icon centred at c. scale 1.0 = 24 x 16 px.
static func draw(ci: CanvasItem, c: Vector2, def: UnitStats, friendly: bool, known: bool, alpha: float, sel: bool) -> void:
	var col: Color = UiStyle.PENCIL_BLUE if friendly else UiStyle.PENCIL_RED
	var fill: Color = Color(col.r, col.g, col.b, 0.28 * alpha)
	var ink: Color = Color(0.95, 0.94, 0.88, alpha)
	var edge: Color = Color(col.r, col.g, col.b, alpha)
	if friendly:
		var r: Rect2 = Rect2(c - Vector2(W, H) * 0.5, Vector2(W, H))
		ci.draw_rect(r, fill)
		ci.draw_rect(r, edge, false, 2.0 if sel else 1.5)
		if sel:
			ci.draw_rect(r.grow(3), Color(0.95, 0.94, 0.88, 0.7 * alpha), false, 1.0)
	else:
		var d: PackedVector2Array = PackedVector2Array([c + Vector2(0, -H * 0.75), c + Vector2(W * 0.6, 0), c + Vector2(0, H * 0.75), c + Vector2(-W * 0.6, 0)])
		ci.draw_colored_polygon(d, fill)
		d.append(d[0])
		ci.draw_polyline(d, edge, 1.5)
	if not known:
		UiStyle.text(ci, c + Vector2(-3, 5), "?", UiStyle.FONT_M, ink, false, true)
		return
	var hw: float = W * (0.5 if friendly else 0.32)
	var hh: float = H * (0.5 if friendly else 0.32)
	match role_of(def):
		"infantry", "crew":
			_x(ci, c, hw, hh, ink)
		"at_infantry":
			_x(ci, c, hw, hh, ink)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-hw * 0.6, hh), c + Vector2(0, -hh * 0.2), c + Vector2(hw * 0.6, hh)]), ink, 1.2)
		"scout":
			ci.draw_line(c + Vector2(-hw, hh), c + Vector2(hw, -hh), ink, 1.4)
		"mbt":
			_oval(ci, c, hw * 0.7, hh * 0.55, ink)
		"ifv":
			_x(ci, c, hw, hh, ink)
			_oval(ci, c, hw * 0.55, hh * 0.45, ink)
		"artillery":
			ci.draw_circle(c, 2.6, ink)
			_oval(ci, c + Vector2(0, hh * 0.55), hw * 0.45, hh * 0.25, ink)
		"indirect":
			ci.draw_circle(c, 2.2, ink)
			ci.draw_line(c + Vector2(0, 2), c + Vector2(0, hh * 0.9), ink, 1.2)
		"logistics":
			ci.draw_line(c + Vector2(-hw, hh * 0.45), c + Vector2(hw, hh * 0.45), ink, 1.4)
		"builder":
			UiStyle.text(ci, c + Vector2(-3.5, 5), "E", UiStyle.FONT_S, ink, false, true)
		"air_defence":
			ci.draw_arc(c + Vector2(0, hh * 0.6), hw * 0.6, PI, TAU, 10, ink, 1.4)
		"ew", "sensor":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-hw * 0.7, 0), c + Vector2(-hw * 0.3, -hh * 0.5), c + Vector2(0, hh * 0.4), c + Vector2(hw * 0.3, -hh * 0.5), c + Vector2(hw * 0.7, 0)]), ink, 1.3)
		"support":
			UiStyle.text(ci, c + Vector2(-3.5, 5), "N", UiStyle.FONT_S, ink, false, true)
		"rotary":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw * 0.7, -hh * 0.5), c, c + Vector2(-hw * 0.7, hh * 0.5)]), ink)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(hw * 0.7, -hh * 0.5), c, c + Vector2(hw * 0.7, hh * 0.5)]), ink)
		"uav":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-hw * 0.7, -hh * 0.3), c + Vector2(0, hh * 0.3), c + Vector2(hw * 0.7, -hh * 0.3)]), ink, 1.4)
		"attack_heli":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw * 0.7, -hh * 0.5), c, c + Vector2(-hw * 0.7, hh * 0.5)]), ink)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(hw * 0.7, -hh * 0.5), c, c + Vector2(hw * 0.7, hh * 0.5)]), ink)
			ci.draw_line(c + Vector2(0, -hh), c + Vector2(0, hh), ink, 1.2)
		_:
			ci.draw_circle(c, 2.0, ink)


static func _x(ci: CanvasItem, c: Vector2, hw: float, hh: float, ink: Color) -> void:
	ci.draw_line(c + Vector2(-hw, -hh), c + Vector2(hw, hh), ink, 1.2)
	ci.draw_line(c + Vector2(-hw, hh), c + Vector2(hw, -hh), ink, 1.2)


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, ink: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, ink, 1.3)
