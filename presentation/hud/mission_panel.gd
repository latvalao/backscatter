## Objectives and mission messages for scripted modes (Phase 6). Reads the
## ScenarioDirector in world.ai; messages arrive as SimEvent.MISSION events.
class_name MissionPanel
extends Control

const MSG_LIFE_S: float = 14.0

var runner: SimRunner
var views: ViewSync
var director: ScenarioDirector
var _msgs: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c: AiController in runner.world.ai:
		if c is ScenarioDirector:
			director = c as ScenarioDirector
	if director != null:
		for m: String in director.messages:
			_msgs.append({"text": m, "t": MSG_LIFE_S * 2.0})


func _process(delta: float) -> void:
	if director == null:
		return
	for e: SimEvent in views.last_events:
		if e.kind == SimEvent.Type.MISSION and e.other_id == 0 and e.value < director.messages.size():
			_msgs.append({"text": director.messages[e.value], "t": MSG_LIFE_S})
	for i: int in range(_msgs.size() - 1, -1, -1):
		_msgs[i]["t"] = float(_msgs[i]["t"]) - delta
		if float(_msgs[i]["t"]) <= 0.0:
			_msgs.remove_at(i)
	while _msgs.size() > 3:
		_msgs.pop_front()
	queue_redraw()


func _draw() -> void:
	if director == null:
		return
	var lines: Array = []  # [text, size, color]
	lines.append([director.title.to_upper(), UiStyle.FONT_M, UiStyle.AMBER])
	for i: int in range(director.objectives.size()):
		var st: int = director.objective_state[i]
		var mark: String = ["-", "Done:", "Failed:"][st]
		var col: Color = [UiStyle.TEXT, UiStyle.GOOD, UiStyle.BAD][st]
		for l: String in _wrap(ThemeDB.fallback_font, "%s %s" % [mark, director.objectives[i]], UiStyle.FONT_S + 1, 330.0):
			lines.append([l, UiStyle.FONT_S + 1, col])
	var zw: ZoneWarDirector = director as ZoneWarDirector
	if zw != null:
		lines.append(["Victory points: Coalition %d, Eastern %d (of %d)" % [zw.vp[0], zw.vp[1], ZoneWarDirector.VP_TARGET], UiStyle.FONT_S + 1, UiStyle.AMBER])
	var ct: ContainmentDirector = director as ContainmentDirector
	if ct != null:
		var next_t: int = ContainmentDirector.FIRST_WAVE + ct.wave * ContainmentDirector.WAVE_GAP - runner.world.tick
		lines.append(["Assault %d of %d%s" % [ct.wave, ct.waves, (", next in %d s" % (next_t / 10)) if ct.wave < ct.waves and next_t > 0 else ""], UiStyle.FONT_S + 1, UiStyle.AMBER])
	var x: float = size.x - 370.0
	var h: float = lines.size() * 19.0 + 14.0
	draw_rect(Rect2(x - 10, 44, 362, h), UiStyle.BG)
	var y: float = 62.0
	for l2: Array in lines:
		UiStyle.text(self, Vector2(x, y), str(l2[0]), int(l2[1]), l2[2] as Color, false)
		y += 19.0
	# briefing / hint messages: top centre, under the bar
	var my: float = 50.0
	for m: Dictionary in _msgs:
		var a: float = clampf(float(m["t"]) / 2.0, 0.0, 1.0)
		var ml: PackedStringArray = _wrap(ThemeDB.fallback_font, str(m["text"]), UiStyle.FONT_M, 600.0)
		var bx: float = size.x * 0.5 - 315.0
		var bg: Color = UiStyle.BG
		bg.a *= a
		draw_rect(Rect2(bx, my, 630, ml.size() * 20.0 + 12.0), bg)
		draw_rect(Rect2(bx, my, 3, ml.size() * 20.0 + 12.0), Color(UiStyle.AMBER.r, UiStyle.AMBER.g, UiStyle.AMBER.b, a))
		var ty: float = my + 21.0
		for l3: String in ml:
			UiStyle.text(self, Vector2(bx + 14, ty), l3, UiStyle.FONT_M, Color(1, 1, 0.94, a), false)
			ty += 20.0
		my += ml.size() * 20.0 + 18.0


func _text(font: Font, p: Vector2, t: String, sz: int, c: Color) -> void:
	draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.8 * c.a))
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _wrap(font: Font, t: String, sz: int, width: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in t.split(" "):
		var test: String = word if line == "" else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
