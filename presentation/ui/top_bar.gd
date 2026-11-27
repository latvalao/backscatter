## Top bar (Phase 8): mode and clock, supply, manpower, depots, game speed,
## weather and wind, dose rate under the cursor, Keys and Menu buttons.
class_name TopBar
extends PanelContainer

var runner: SimRunner
var controller: SelectionController
var views: ViewSync
var scene: GameScene
var on_help: Callable
var on_menu: Callable

var _left: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 34
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	_left = Control.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.custom_minimum_size = Vector2(0, 20)
	_left.draw.connect(_draw_left)
	row.add_child(_left)
	for pair: Array in [["Keys", on_help], ["Menu", on_menu]]:
		var b: Button = Button.new()
		b.text = str(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pair[1] as Callable)
		row.add_child(b)


func _process(_d: float) -> void:
	_left.queue_redraw()


func _draw_left() -> void:
	var w: SimWorld = runner.world
	var me: int = controller.local_player()
	var x: float = 4.0
	var y: float = 17.0
	x = _field(x, y, scene.hud.mode_name(), "%d:%02d" % [w.tick / 600, (w.tick / 10) % 60], UiStyle.TEXT)
	var spd: String = "PAUSED" if runner.speed == 0 else "x%d" % runner.speed
	x = _field(x, y, "", spd, UiStyle.AMBER if runner.speed == 0 else UiStyle.DIM)
	if me < w.players.count() and not scene.replay_mode:
		x = _field(x, y, "Supply", str(w.players.supply[me]), UiStyle.AMBER)
		x = _field(x, y, "Manpower", str(w.players.manpower[me]), UiStyle.TEXT)
		var held: int = 0
		var routed: int = 0
		for d: int in ObjectiveSystem._depots(w):
			if w.structures.holder_team[d] == views.local_team:
				held += 1
				routed += w.structures.connected[d]
		x = _field(x, y, "Depots", "%d (%d linked)" % [held, routed], UiStyle.TEXT)
	var wx: Weather = w.weather
	var cond: String = "Night" if wx.night or w.is_night else ("Rain" if wx.raining else ("Fog" if wx.fog else "Clear"))
	x = _field(x, y, "", cond, UiStyle.TEXT)
	# wind arrow (blowing toward)
	var a: float = -float(wx.wind_dir) / SimConst.ANGLE_FULL * TAU
	var c: Vector2 = Vector2(x + 10, y - 5)
	var d: Vector2 = Vector2(cos(a), sin(a)) * 8.0
	_left.draw_line(c - d, c + d, UiStyle.CYAN, 2.0)
	_left.draw_line(c + d, c + d - d.rotated(0.5) * 0.6, UiStyle.CYAN, 2.0)
	_left.draw_line(c + d, c + d - d.rotated(-0.5) * 0.6, UiStyle.CYAN, 2.0)
	x = _field(x + 24, y, "", "%d m/s" % (wx.wind_speed / 1000), UiStyle.DIM)
	var gp: Variant = controller.cam.ground_point(controller.get_viewport().get_mouse_position())
	if gp != null:
		var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
		var banded: bool = scene.dosimetry != null and scene.dosimetry.banded()
		var rate: int = w.radfield.rate_at(s.x, s.y)
		_field(x, y, "Dose rate", DosimetryOverlay.format_rate(rate, banded), UiStyle.AMBER if rate >= 1000 else UiStyle.DIM)
	if runner.waiting and not scene.replay_mode:
		UiStyle.text(_left, Vector2(_left.size.x - 190, y), "Waiting for players…", UiStyle.FONT_M, UiStyle.AMBER)


func _field(x: float, y: float, name: String, value: String, c: Color) -> float:
	if name != "":
		UiStyle.text(_left, Vector2(x, y), name, UiStyle.FONT_S, UiStyle.DIM, false)
		x += UiStyle.text_width(name, UiStyle.FONT_S) + 6.0
	UiStyle.text(_left, Vector2(x, y), value, UiStyle.FONT_M, c, false)
	return x + UiStyle.text_width(value, UiStyle.FONT_M) + 22.0
