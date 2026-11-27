## Replay viewer controls (Phase 4.2): timeline, pause / speed, skip ahead,
## and whose view to watch (everything, or one side's fog of war).
class_name ReplayControls
extends PanelContainer

var runner: SimRunner
var views: ViewSync
var terrain: TerrainView
var _bar: ProgressBar
var _time: Label
var _view: Button
var _view_mode: int = 0  # 0 all, 1 Coalition, 2 Eastern


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -330
	offset_right = 330
	offset_top = 42
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	_time = Label.new()
	_time.custom_minimum_size = Vector2(120, 0)
	row.add_child(_time)
	for pair: Array in [["Pause", 0], ["1x", 1], ["2x", 2], ["4x", 4], ["8x", 8]]:
		var b: Button = Button.new()
		b.text = str(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		var spd: int = pair[1]
		b.pressed.connect(func() -> void: runner.speed = spd)
		row.add_child(b)
	var skip: Button = Button.new()
	skip.text = "+1 min"
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func() -> void: runner.fast_forward_to = runner.world.tick + 600)
	row.add_child(skip)
	var skip5: Button = Button.new()
	skip5.text = "+5 min"
	skip5.focus_mode = Control.FOCUS_NONE
	skip5.pressed.connect(func() -> void: runner.fast_forward_to = runner.world.tick + 3000)
	row.add_child(skip5)
	_view = Button.new()
	_view.focus_mode = Control.FOCUS_NONE
	_view.pressed.connect(_cycle_view)
	row.add_child(_view)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(640, 8)
	box.add_child(_bar)
	_apply_view()


func _cycle_view() -> void:
	_view_mode = (_view_mode + 1) % 3
	_apply_view()


func _apply_view() -> void:
	views.reveal_all = _view_mode == 0
	views.local_team = 0 if _view_mode <= 1 else 1
	terrain.set_fog_enabled(_view_mode != 0)
	_view.text = ["View: everything", "View: Coalition", "View: Eastern"][_view_mode]


func _process(_delta: float) -> void:
	if runner.replay == null:
		return
	var total: int = maxi(1, int(runner.replay.data["final_tick"]))
	var t: int = runner.world.tick
	_bar.max_value = total
	_bar.value = t
	_time.text = "%d:%02d / %d:%02d%s" % [t / 600, (t / 10) % 60, total / 600, (total / 10) % 60, "  skipping…" if runner.fast_forward_to > 0 else ""]
