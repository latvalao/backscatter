## End-of-match summary (Phase 4.3): result, a per-side table and the army
## strength graph over time. Shown by the HUD when the match ends.
class_name MatchSummary
extends PanelContainer

var stats: MatchStats
var local_team: int = 0
var on_leave: Callable
var _graph: Control


func build(winner: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(720, 470)
	offset_left = -360
	offset_right = 360
	offset_top = -235
	offset_bottom = 235
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var title: Label = Label.new()
	title.text = "VICTORY" if winner == local_team else "DEFEAT"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var w: SimWorld = stats.runner.world
	var sub: Label = Label.new()
	sub.text = "Match length %d:%02d" % [w.tick / 600, (w.tick / 10) % 60]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	var rows: Array = [["", "Coalition", "Eastern"],
		["Units produced", stats.produced[0], stats.produced[1]],
		["Units lost", stats.lost[0], stats.lost[1]],
		["Enemy units destroyed", stats.kills[0], stats.kills[1]],
		["Supply salvaged", stats.salvage[0], stats.salvage[1]],
		["Support calls", stats.support_calls[0], stats.support_calls[1]],
		["Radiation dose of survivors (mSv)", stats.dose_msv(0), stats.dose_msv(1)]]
	for r: Array in rows:
		for c: Variant in r:
			var l: Label = Label.new()
			l.text = str(c)
			l.custom_minimum_size = Vector2(230, 0)
			grid.add_child(l)
	var gl: Label = Label.new()
	gl.text = "Army strength over time"
	box.add_child(gl)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(690, 160)
	_graph.draw.connect(_draw_graph)
	box.add_child(_graph)
	var b: Button = Button.new()
	b.text = "Leave match"
	b.pressed.connect(func() -> void: on_leave.call())
	box.add_child(b)
	var k: Button = Button.new()
	k.text = "Keep watching"
	k.pressed.connect(func() -> void: visible = false)
	box.add_child(k)


func _draw_graph() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _graph.size)
	_graph.draw_rect(r, Color(0, 0, 0, 0.35))
	var top: int = 1
	for t: int in range(2):
		for v: int in stats.strength[t]:
			top = maxi(top, v)
	for t2: int in range(2):
		var s: PackedInt32Array = stats.strength[t2]
		if s.size() < 2:
			continue
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(s.size()):
			pts.append(Vector2(r.size.x * i / (s.size() - 1), r.size.y * (1.0 - float(s[i]) / top)))
		_graph.draw_polyline(pts, UnitView.TEAM_COLORS[t2], 2.0)
