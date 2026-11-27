## Alerts (Phase 1.7): under attack, units lost, out of fuel, radiation
## casualties, depot changes, construction and production done. Reads sim events
## through ViewSync and sim state; never writes. Space jumps to the last alert.
class_name AlertFeed
extends Control

const LIFE_S: float = 9.0
const MAX_SHOWN: int = 6
## Same alert kind near the same place is suppressed for this long.
const THROTTLE_S: float = 20.0
const AREA_M: float = 300.0

var runner: SimRunner
var views: ViewSync
var local_player: int = 0
var minimap: Minimap

var _items: Array[Dictionary] = []   # {text, color, t, pos}
var _last: Dictionary = {}            # throttle key -> time
var _clock: float = 0.0
var _last_pos: Variant = null
var _seen_hit: Dictionary = {}        # id -> last_hit_tick handled


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func last_position() -> Variant:
	return _last_pos


func push(text: String, color: Color, pos: Variant, key: String = "") -> void:
	if key != "":
		var k: String = key
		if pos != null:
			var p: Vector3 = pos
			k += "_%d_%d" % [int(p.x / AREA_M), int(p.z / AREA_M)]
		if _clock - float(_last.get(k, -1000.0)) < THROTTLE_S:
			return
		_last[k] = _clock
	_items.push_front({"text": text, "color": color, "t": LIFE_S, "pos": pos})
	if _items.size() > MAX_SHOWN:
		_items.pop_back()
	if pos != null:
		_last_pos = pos
		if minimap != null:
			minimap.ping(pos as Vector3, color)


func _process(delta: float) -> void:
	_clock += delta
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	var team: int = w.team_of_player(local_player)
	for e: SimEvent in views.last_events:
		_event(w, e, team)
	for id: int in views.lost.keys():
		var info: Array = views.lost[id]
		if int(info[1]) == team:
			push("Lost: %s" % info[0], Color(1.0, 0.45, 0.35), info[2], "")
	# under attack (own units hit recently)
	if Engine.get_process_frames() % 6 == 0:
		for id2: int in w.team_units[team] if team >= 0 and team < w.team_units.size() else PackedInt32Array():
			if w.units.owner[id2] != local_player:
				continue
			var lh: int = w.units.last_hit_tick[id2]
			if lh > w.tick - 20 and int(_seen_hit.get(id2, -1)) != lh:
				_seen_hit[id2] = lh
				var p: Vector3 = runner.interpolated_position(id2)
				var base: bool = w.is_structure(id2)
				push("Base under attack" if base else "Under attack: %s" % w.def_of(id2).display_name,
					Color(1.0, 0.6, 0.3), p, "base" if base else "hit")
	for i: int in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		it["t"] = float(it["t"]) - delta
		if float(it["t"]) <= 0.0:
			_items.remove_at(i)
	queue_redraw()


func _event(w: SimWorld, e: SimEvent, team: int) -> void:
	var mine: bool = w.units.has(e.entity_id) and w.units.owner[e.entity_id] == local_player
	var pos: Variant = runner.interpolated_position(e.entity_id) if mine else null
	match e.kind:
		SimEvent.Type.OUT_OF_FUEL:
			if mine:
				push("Out of fuel: %s" % w.def_of(e.entity_id).display_name, Color(1.0, 0.8, 0.3), pos, "fuel")
		SimEvent.Type.RADIATION_CASUALTY:
			if mine:
				push("Radiation casualties: %s" % w.def_of(e.entity_id).display_name, Color(0.88, 0.71, 0.29), pos, "rad")
		SimEvent.Type.BUILT:
			if mine:
				push("Construction complete: %s" % w.def_of(e.entity_id).display_name, Color(0.7, 0.9, 0.7), pos, "")
		SimEvent.Type.PRODUCED:
			if mine:
				push("Ready: %s" % w.def_of(e.entity_id).display_name, Color(0.7, 0.9, 0.7), pos, "prod")
		SimEvent.Type.CAPTURED:
			var p2: Vector3 = SimRunner.sim_to_view(w.transform.x[e.entity_id], w.transform.y[e.entity_id], 0) if w.transform.has(e.entity_id) else Vector3.ZERO
			if e.value == team:
				push("Depot captured", Color(0.6, 0.85, 1.0), p2, "")
			else:
				push("Depot lost", Color(1.0, 0.45, 0.35), p2, "")
		SimEvent.Type.PROMOTED:
			if mine:
				push("Promoted: %s" % w.def_of(e.entity_id).display_name, Color(0.85, 0.85, 0.6), pos, "")
		SimEvent.Type.ROUTED:
			if mine:
				push("Routing: %s" % w.def_of(e.entity_id).display_name, Color(1.0, 0.55, 0.4), pos, "rout")
		SimEvent.Type.MINE:
			if mine:
				push("Mine strike", Color(1.0, 0.5, 0.3), pos, "mine")


func _draw() -> void:
	var y: float = 46.0
	for it: Dictionary in _items:
		var a: float = clampf(float(it["t"]) / 1.5, 0.0, 1.0)
		var c: Color = it["color"]
		c.a = a
		var t: String = str(it["text"])
		var wdt: float = UiStyle.text_width(t, UiStyle.FONT_M) + 22.0
		var bg: Color = UiStyle.BG_SOFT
		bg.a *= a
		draw_rect(Rect2(10, y, wdt, 22), bg)
		draw_rect(Rect2(10, y, 3, 22), c)
		UiStyle.text(self, Vector2(20, y + 16), t, UiStyle.FONT_M, Color(UiStyle.TEXT.r, UiStyle.TEXT.g, UiStyle.TEXT.b, a), false)
		y += 25.0
