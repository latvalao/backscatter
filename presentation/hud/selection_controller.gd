## Mouse/keyboard command input (§8): click/box selection, right-click contextual
## orders, attack-move / reverse / fire-mission modes, Shift queueing, control
## groups. Produces SimCommands only — never touches sim state.
class_name SelectionController
extends Control

enum Mode { NORMAL, ATTACK_MOVE, REVERSE, FIRE_MISSION, FIRE_SMOKE }

const CLICK_PICK_PX: float = 22.0
const MODE_NAMES: Array[String] = ["", "ATTACK-MOVE: left-click target point", "REVERSE: left-click destination",
	"FIRE MISSION (HE): left-click impact point", "FIRE MISSION (SMOKE): left-click impact point"]

var runner: SimRunner
var views: ViewSync
var cam: RtsCamera
var sink: LocalCommandSink
var mode: Mode = Mode.NORMAL
var selection: PackedInt32Array = PackedInt32Array()
var groups: Dictionary = {}  # int -> PackedInt32Array
var message: String = ""

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_now: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# prune dead units
	var keep: PackedInt32Array = PackedInt32Array()
	for id: int in selection:
		if runner.world.is_unit(id):
			keep.append(id)
	if keep.size() != selection.size():
		_set_selection(keep)
	queue_redraw()


func _draw() -> void:
	if _dragging and _drag_start.distance_to(_drag_now) > 6.0:
		var r: Rect2 = Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.12), true)
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.8), false, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_mouse_button(mb)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _dragging:
		_drag_now = mm.position
		return
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo:
		_key(k)


func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mode != Mode.NORMAL:
				_mode_click(mb.position, mb.shift_pressed)
				return
			_dragging = true
			_drag_start = mb.position
			_drag_now = mb.position
		elif _dragging:
			_dragging = false
			if _drag_start.distance_to(mb.position) > 6.0:
				_box_select(Rect2(_drag_start, mb.position - _drag_start).abs(), mb.shift_pressed)
			else:
				_click_select(mb.position, mb.shift_pressed)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if mode != Mode.NORMAL:
			mode = Mode.NORMAL
			return
		_right_click(mb.position, mb.shift_pressed, mb.alt_pressed)


func _key(k: InputEventKey) -> void:
	var code: Key = k.keycode
	if code >= KEY_1 and code <= KEY_9:
		var g: int = code - KEY_0
		if k.ctrl_pressed:
			groups[g] = selection.duplicate()
			message = "Group %d set (%d units)" % [g, selection.size()]
		elif groups.has(g):
			var grp: PackedInt32Array = groups[g]
			_set_selection(grp)
		return
	if selection.is_empty():
		return
	match code:
		KEY_A:
			mode = Mode.ATTACK_MOVE
		KEY_R:
			mode = Mode.REVERSE
		KEY_F:
			mode = Mode.FIRE_MISSION
		KEY_G:
			mode = Mode.FIRE_SMOKE
		KEY_S:
			sink.submit(StopCommand.new(selection))
		KEY_X:
			sink.submit(SmokeCommand.new(selection))
			message = "Smoke!"
		KEY_H:
			var hold: bool = runner.world.units.stance[selection[0]] != UnitStore.STANCE_HOLD_FIRE
			sink.submit(StanceCommand.new(selection, UnitStore.STANCE_HOLD_FIRE if hold else UnitStore.STANCE_FIRE_AT_WILL))
			message = "Hold fire" if hold else "Fire at will"
		KEY_ESCAPE:
			mode = Mode.NORMAL


func _mode_click(pos: Vector2, shift: bool) -> void:
	var gp: Variant = cam.ground_point(pos)
	if gp == null:
		return
	var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
	match mode:
		Mode.ATTACK_MOVE:
			sink.submit(MoveCommand.new(selection, s.x, s.y, MoveCommand.MODE_ATTACK_MOVE, shift))
		Mode.REVERSE:
			sink.submit(MoveCommand.new(selection, s.x, s.y, MoveCommand.MODE_REVERSE, shift))
		Mode.FIRE_MISSION, Mode.FIRE_SMOKE:
			var smoke: bool = mode == Mode.FIRE_SMOKE
			var cmd: FireMissionCommand = FireMissionCommand.new(selection, s.x, s.y, 3 if smoke else 6, smoke)
			cmd.player_id = sink.player_id
			if not FireMissionCommand.is_observed(runner.world, views.local_team, s.x, s.y):
				message = "No observer has eyes on that point"
			else:
				sink.submit(cmd)
				message = "Fire mission sent"
	if not shift:
		mode = Mode.NORMAL


func _right_click(pos: Vector2, shift: bool, alt: bool) -> void:
	if selection.is_empty():
		return
	var enemy: int = _pick_unit(pos, false)
	if enemy > 0:
		sink.submit(AttackCommand.new(selection, enemy))
		return
	var gp: Variant = cam.ground_point(pos)
	if gp == null:
		return
	var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
	var m: int = MoveCommand.MODE_REVERSE if alt else MoveCommand.MODE_MOVE
	sink.submit(MoveCommand.new(selection, s.x, s.y, m, shift))


## Nearest shown unit to a screen point: own units (own=true) or visible enemies.
func _pick_unit(pos: Vector2, own: bool) -> int:
	var best: int = 0
	var best_d: float = CLICK_PICK_PX
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if not uv.visible or (uv.team == views.local_team) != own:
			continue
		if cam.camera.is_position_behind(uv.global_position):
			continue
		var sp: Vector2 = cam.camera.unproject_position(uv.global_position + Vector3.UP)
		var d: float = sp.distance_to(pos)
		if d < best_d:
			best_d = d
			best = uv.entity_id
	return best


func _click_select(pos: Vector2, add: bool) -> void:
	var id: int = _pick_unit(pos, true)
	var sel: PackedInt32Array = selection.duplicate() if add else PackedInt32Array()
	if id > 0 and not sel.has(id):
		sel.append(id)
	_set_selection(sel)


func _box_select(r: Rect2, add: bool) -> void:
	var sel: PackedInt32Array = selection.duplicate() if add else PackedInt32Array()
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if uv.team != views.local_team or cam.camera.is_position_behind(uv.global_position):
			continue
		if r.has_point(cam.camera.unproject_position(uv.global_position + Vector3.UP)) and not sel.has(uv.entity_id):
			sel.append(uv.entity_id)
	_set_selection(sel)


func _set_selection(ids: PackedInt32Array) -> void:
	selection = ids.duplicate()
	selection.sort()
	views.selected.clear()
	for id: int in selection:
		views.selected[id] = true


func mode_text() -> String:
	return MODE_NAMES[mode]
