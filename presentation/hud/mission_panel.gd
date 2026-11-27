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
	var font: Font = get_theme_default_font()
	var x: float = size.x - 470.0
	var y: float = 150.0
	_text(font, Vector2(x, y), director.title.to_upper(), 16, Color(0.95, 0.9, 0.75))
	y += 24.0
	for i: int in range(director.objectives.size()):
		var st: int = director.objective_state[i]
		var mark: String = ["[ ]", "[x]", "[!]"][st]
		var col: Color = [Color(0.92, 0.92, 0.88), Color(0.6, 0.9, 0.6), Color(1.0, 0.5, 0.4)][st]
		_text(font, Vector2(x, y), "%s %s" % [mark, director.objectives[i]], 14, col)
		y += 20.0
	var zw: ZoneWarDirector = director as ZoneWarDirector
	if zw != null:
		_text(font, Vector2(x, y), "Victory points  Coalition %d   Eastern %d   (target %d)" % [zw.vp[0], zw.vp[1], ZoneWarDirector.VP_TARGET], 14, Color(0.88, 0.71, 0.29))
		y += 20.0
	var ct: ContainmentDirector = director as ContainmentDirector
	if ct != null:
		var next_t: int = ContainmentDirector.FIRST_WAVE + ct.wave * ContainmentDirector.WAVE_GAP - runner.world.tick
		_text(font, Vector2(x, y), "Assault %d of %d%s" % [ct.wave, ct.waves, ("   next in %d s" % (next_t / 10)) if ct.wave < ct.waves and next_t > 0 else ""], 14, Color(0.88, 0.71, 0.29))
		y += 20.0
	# messages, centre bottom
	var my: float = size.y - 300.0
	for m: Dictionary in _msgs:
		var a: float = clampf(float(m["t"]) / 2.0, 0.0, 1.0)
		var lines: PackedStringArray = _wrap(font, str(m["text"]), 15, 760.0)
		for l: String in lines:
			_text(font, Vector2(size.x * 0.5 - 380.0, my), l, 15, Color(1, 1, 0.92, a))
			my += 20.0
		my += 8.0


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
