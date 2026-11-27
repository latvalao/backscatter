## Mouse/keyboard command input (§8): click/box selection, right-click contextual
## orders, attack-move / reverse / fire-mission / build-placement modes, Shift
## queueing, control groups, production and rally points. Produces SimCommands
## via the Lockstep only — never touches sim state.
class_name SelectionController
extends Control

enum Mode { NORMAL, ATTACK_MOVE, REVERSE, FIRE_MISSION, FIRE_SMOKE, PLACE, UNLOAD_AT, ENGAGE_RANGE, LAY_MINES, FLARE, SUPPORT, SEIZE, OVERWATCH }

const CLICK_PICK_PX: float = 24.0
const MODE_NAMES: Array[String] = ["", "ATTACK-MOVE: left-click target point", "REVERSE: left-click destination",
	"FIRE MISSION (HE): left-click impact point", "FIRE MISSION (SMOKE): left-click impact point",
	"PLACE %s: left-click to build (Shift: keep placing), right-click cancels",
	"UNLOAD AT: left-click where the transports should drop their troops",
	"ENGAGEMENT RANGE: left-click the distance to open fire at (Shift+Y clears)",
	"MINEFIELD: left-click where the engineer lays mines (30 supply)",
	"ILLUMINATION: left-click where to fire a flare",
	"%s: left-click the target point",
	"SEIZE: left-click the objective (wedge, attack-move, dig in)",
	"OVERWATCH: left-click the centre of the sector to cover"]
const DOUBLE_CLICK_S: float = 0.35
const FACING_DRAG_PX: float = 24.0

var runner: SimRunner
var views: ViewSync
var cam: RtsCamera
var lockstep: Lockstep
var enabled: bool = true
var mode: Mode = Mode.NORMAL
var selection: PackedInt32Array = PackedInt32Array()
var groups: Dictionary = {}  # int -> PackedInt32Array
var message: String = ""
var place_def: UnitStats
var panel: CommandPanel

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_now: Vector2 = Vector2.ZERO
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _ghost_cell: Vector2i = Vector2i(-1, -1)
## Formation used for move orders (cycled with N).
var formation: int = Formation.BLOCK
## Right-drag sets the final facing: press point, current point.
var _rdrag: bool = false
var _rdrag_start: Vector2 = Vector2.ZERO
var _rdrag_now: Vector2 = Vector2.ZERO
var _last_click_ms: int = 0
var _last_click_def: int = -1
var _tab_index: int = 0
## Set by GameScene: alert feed for the Space key.
var alerts: AlertFeed
## Off-map support kind being aimed (Mode.SUPPORT).
var support_kind: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = CommandPanel.new()
	panel.controller = self
	add_child(panel)
	_ghost = MeshInstance3D.new()
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	views.add_child(_ghost)


func local_player() -> int:
	return lockstep.local_player if lockstep != null else 0


func submit(cmd: SimCommand) -> void:
	if enabled and lockstep != null:
		lockstep.submit(cmd)


func _process(_delta: float) -> void:
	var keep: PackedInt32Array = PackedInt32Array()
	for id: int in selection:
		if runner.world.is_unit(id) and runner.world.units.carrier[id] == 0:
			keep.append(id)
	if keep.size() != selection.size():
		_set_selection(keep)
	_update_ghost()
	queue_redraw()


func _draw() -> void:
	if _dragging and _drag_start.distance_to(_drag_now) > 6.0:
		var r: Rect2 = Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.12), true)
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.8), false, 1.0)
	if _rdrag and _rdrag_start.distance_to(_rdrag_now) > FACING_DRAG_PX:
		draw_line(_rdrag_start, _rdrag_now, Color(0.9, 0.95, 1.0, 0.9), 2.0)
		var d: Vector2 = (_rdrag_now - _rdrag_start).normalized()
		draw_line(_rdrag_now, _rdrag_now - d.rotated(0.5) * 14.0, Color(0.9, 0.95, 1.0, 0.9), 2.0)
		draw_line(_rdrag_now, _rdrag_now - d.rotated(-0.5) * 14.0, Color(0.9, 0.95, 1.0, 0.9), 2.0)
	if mode == Mode.ENGAGE_RANGE and not selection.is_empty():
		var c: Vector3 = _selection_center()
		var gp: Variant = cam.ground_point(get_viewport().get_mouse_position())
		if gp != null:
			var r2: float = Vector2(c.x - (gp as Vector3).x, c.z - (gp as Vector3).z).length()
			_draw_ground_circle(c, r2, Color(1.0, 0.8, 0.35, 0.9))


func _draw_ground_circle(c: Vector3, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(49):
		var a: float = TAU * i / 48.0
		var p: Vector3 = c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = cam.terrain.height_at(p) + 1.0
		if cam.camera.is_position_behind(p):
			return
		pts.append(cam.camera.unproject_position(p))
	draw_polyline(pts, col, 2.0)


func _selection_center() -> Vector3:
	var c: Vector3 = Vector3.ZERO
	var n: int = 0
	for id: int in selection:
		var v: UnitView = views.view_of(id)
		if v != null:
			c += v.global_position
			n += 1
	return c / maxf(1.0, n)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_mouse_button(mb)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if _dragging:
			_drag_now = mm.position
		if _rdrag:
			_rdrag_now = mm.position
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
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			if mode != Mode.NORMAL:
				set_mode(Mode.NORMAL)
				return
			_rdrag = true
			_rdrag_start = mb.position
			_rdrag_now = mb.position
		elif _rdrag:
			_rdrag = false
			if _rdrag_start.distance_to(mb.position) > FACING_DRAG_PX:
				_right_drag(_rdrag_start, mb.position, mb.shift_pressed)
			else:
				_right_click(_rdrag_start, mb.shift_pressed, mb.alt_pressed)


## Right-drag: move to the press point and face toward the release point.
func _right_drag(a: Vector2, b: Vector2, shift: bool) -> void:
	if selection.is_empty():
		return
	var ga: Variant = cam.ground_point(a)
	var gb: Variant = cam.ground_point(b)
	if ga == null or gb == null:
		return
	var sa: Vector2i = SimRunner.view_to_sim(ga as Vector3)
	var sb: Vector2i = SimRunner.view_to_sim(gb as Vector3)
	var face: int = FixedMath.atan2_b(sb.y - sa.y, sb.x - sa.x)
	submit(MoveCommand.new(_movers(), sa.x, sa.y, MoveCommand.MODE_MOVE, shift, Input.is_key_pressed(KEY_CTRL), formation, face))


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
	if code >= KEY_F1 and code <= KEY_F8:
		panel.press(code - KEY_F1)
		return
	match code:
		KEY_SPACE:
			if alerts != null:
				var p: Variant = alerts.last_position()
				if p != null:
					cam.focus(p as Vector3)
			return
		KEY_HOME:
			_focus_hq()
			return
		KEY_PERIOD:
			_select_idle()
			return
		KEY_N:
			formation = (formation + 1) % Formation.NAMES.size()
			message = "Formation: " + Formation.NAMES[formation]
			return
	if selection.is_empty():
		return
	match code:
		KEY_TAB:
			_cycle_subgroup()
		KEY_U:
			submit(UnloadCommand.new(selection))
			message = "Unload"
		KEY_T:
			set_mode(Mode.UNLOAD_AT)
		KEY_M:
			set_mode(Mode.LAY_MINES)
		KEY_K:
			set_mode(Mode.SEIZE)
		KEY_O:
			set_mode(Mode.OVERWATCH)
		KEY_B:
			var cb: bool = (runner.world.units.smart[selection[0]] & UnitStore.SMART_AUTO_CB) == 0
			submit(SmartOrderCommand.new(selection, SmartOrderCommand.AUTO_CB, 0, 0, cb))
			message = "Auto counter-battery " + ("on" if cb else "off")
		KEY_J:
			var rot: bool = (runner.world.units.smart[selection[0]] & UnitStore.SMART_ROTATE) == 0
			submit(SmartOrderCommand.new(selection, SmartOrderCommand.ROTATE, 0, 0, rot))
			message = "Crew rotation " + ("on" if rot else "off")
		KEY_I:
			set_mode(Mode.FLARE)
		KEY_Y:
			if k.shift_pressed:
				submit(EngageRangeCommand.new(selection, 0))
				message = "Engagement range: weapon maximum"
			else:
				set_mode(Mode.ENGAGE_RANGE)
		KEY_A:
			set_mode(Mode.ATTACK_MOVE)
		KEY_R:
			set_mode(Mode.REVERSE)
		KEY_F:
			set_mode(Mode.FIRE_MISSION)
		KEY_G:
			set_mode(Mode.FIRE_SMOKE)
		KEY_S:
			submit(StopCommand.new(selection))
		KEY_X:
			submit(SmokeCommand.new(selection))
			message = "Smoke!"
		KEY_Z:
			var lvl: int = (runner.world.units.emcon[selection[0]] + 1) % 3
			submit(EmconCommand.new(selection, lvl))
			message = "EMCON " + UnitStore.EMCON_NAMES[lvl]
		KEY_H:
			var hold: bool = runner.world.units.stance[selection[0]] != UnitStore.STANCE_HOLD_FIRE
			submit(StanceCommand.new(selection, UnitStore.STANCE_HOLD_FIRE if hold else UnitStore.STANCE_FIRE_AT_WILL))
			message = "Hold fire" if hold else "Fire at will"


func begin_support(kind: int) -> void:
	support_kind = kind
	set_mode(Mode.SUPPORT)


func set_mode(m: Mode) -> void:
	mode = m
	if m != Mode.PLACE:
		place_def = null
		_ghost.visible = false


func begin_placement(def: UnitStats) -> void:
	place_def = def
	set_mode(Mode.PLACE)


func _placement_cell(pos: Vector2) -> Vector2i:
	var gp: Variant = cam.ground_point(pos)
	if gp == null or place_def == null:
		return Vector2i(-1, -1)
	var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
	return Vector2i(s.x / SimGrid.CELL_MM - place_def.footprint_w / 2, s.y / SimGrid.CELL_MM - place_def.footprint_h / 2)


func _update_ghost() -> void:
	if mode != Mode.PLACE or place_def == null:
		_ghost.visible = false
		return
	var cell: Vector2i = _placement_cell(get_viewport().get_mouse_position())
	if cell.x < 0:
		_ghost.visible = false
		return
	var cm: float = SimGrid.CELL_MM * 0.001
	var box: BoxMesh = _ghost.mesh as BoxMesh
	if box == null:
		box = BoxMesh.new()
		_ghost.mesh = box
	box.size = Vector3(place_def.footprint_w * cm, 4.0, place_def.footprint_h * cm)
	var center: Vector3 = Vector3((cell.x + place_def.footprint_w * 0.5) * cm, 0, -(cell.y + place_def.footprint_h * 0.5) * cm)
	center.y = cam.terrain.height_at(center) + 2.0
	_ghost.position = center
	var ok: bool = ConstructionSystem.can_place(runner.world, place_def, cell.x, cell.y)
	var affordable: bool = runner.world.players.supply[local_player()] >= place_def.cost_supply
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if ok and affordable else Color(1.0, 0.3, 0.25, 0.45)
	_ghost.visible = true
	_ghost_cell = cell


func _mode_click(pos: Vector2, shift: bool) -> void:
	if mode == Mode.SUPPORT:
		var gp2: Variant = cam.ground_point(pos)
		if gp2 != null:
			var s2: Vector2i = SimRunner.view_to_sim(gp2 as Vector3)
			var sc: SupportCommand = SupportCommand.new(support_kind, s2.x, s2.y)
			sc.player_id = local_player()
			if sc.validate(runner.world):
				submit(sc)
				message = "%s called in" % str(SupportCommand.spec(runner.world, support_kind).get("name", "Support"))
			else:
				message = "Can't call that there (observer, radio, supply or uses left)"
		set_mode(Mode.NORMAL)
		return
	if mode == Mode.PLACE:
		var cell: Vector2i = _placement_cell(pos)
		if cell.x >= 0 and place_def != null:
			if not ConstructionSystem.can_place(runner.world, place_def, cell.x, cell.y):
				message = "Can't build there"
				return
			submit(BuildCommand.new(_builders(), place_def.id, cell.x, cell.y))
			message = "Building %s" % place_def.display_name
		if not shift:
			set_mode(Mode.NORMAL)
		return
	var gp: Variant = cam.ground_point(pos)
	if gp == null:
		return
	var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
	match mode:
		Mode.UNLOAD_AT:
			submit(UnloadCommand.new(selection, s.x, s.y, true))
			message = "Unloading at the marked point"
		Mode.SEIZE:
			submit(SmartOrderCommand.new(selection, SmartOrderCommand.SEIZE, s.x, s.y))
			message = "Seize"
		Mode.OVERWATCH:
			submit(SmartOrderCommand.new(selection, SmartOrderCommand.OVERWATCH, s.x, s.y))
			message = "Overwatch"
		Mode.LAY_MINES:
			submit(EngineerTaskCommand.new(selection, UnitStore.TASK_LAY_MINES, s.x, s.y))
			message = "Laying mines"
		Mode.FLARE:
			submit(FlareCommand.new(selection, s.x, s.y))
			message = "Illumination round"
		Mode.ENGAGE_RANGE:
			var c: Vector3 = _selection_center()
			var r: float = Vector2(c.x - (gp as Vector3).x, c.z - (gp as Vector3).z).length()
			submit(EngageRangeCommand.new(selection, int(r * 1000.0)))
			message = "Open fire inside %d m" % int(r)
		Mode.ATTACK_MOVE:
			submit(MoveCommand.new(selection, s.x, s.y, MoveCommand.MODE_ATTACK_MOVE, shift, false, formation))
		Mode.REVERSE:
			submit(MoveCommand.new(selection, s.x, s.y, MoveCommand.MODE_REVERSE, shift))
		Mode.FIRE_MISSION, Mode.FIRE_SMOKE:
			var smoke: bool = mode == Mode.FIRE_SMOKE
			if not FireMissionCommand.is_observed(runner.world, views.local_team, s.x, s.y):
				message = "No observer has eyes on that point"
			else:
				submit(FireMissionCommand.new(selection, s.x, s.y, 3 if smoke else 6, smoke))
				message = "Fire mission sent"
	if not shift:
		set_mode(Mode.NORMAL)


func _right_click(pos: Vector2, shift: bool, alt: bool) -> void:
	if selection.is_empty():
		return
	var gp: Variant = cam.ground_point(pos)
	# a selected production building: right-click sets its rally point
	if selection.size() == 1 and runner.world.is_structure(selection[0]):
		if gp != null:
			var r: Vector2i = SimRunner.view_to_sim(gp as Vector3)
			submit(RallyCommand.new(selection[0], r.x, r.y))
			message = "Rally point set"
		return
	var enemy: int = _pick_unit(pos, false)
	if enemy > 0 and runner.world.units.team[enemy] != SimWorld.NEUTRAL_TEAM:
		submit(AttackCommand.new(selection, enemy))
		return
	# right-click a wreck with an engineer selected: salvage it
	var wreck: int = views.pick_wreck(pos, cam.camera)
	if wreck != 0 and _has_engineer():
		submit(EngineerTaskCommand.new(selection, UnitStore.TASK_SALVAGE, 0, 0, wreck))
		message = "Salvaging"
		return
	# right-click a friendly transport with infantry selected: board it
	var own: int = _pick_unit(pos, true)
	if own > 0 and not selection.has(own) and Transport.capacity(runner.world.def_of(own)) > 0 and _has_infantry():
		submit(MountCommand.new(selection, own))
		message = "Boarding"
		return
	if gp == null:
		return
	var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
	var m: int = MoveCommand.MODE_REVERSE if alt else MoveCommand.MODE_MOVE
	# Ctrl+right-click: "safe" route that avoids fallout (§8)
	submit(MoveCommand.new(_movers(), s.x, s.y, m, shift, Input.is_key_pressed(KEY_CTRL), formation))


func _movers() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in selection:
		if not runner.world.is_structure(id):
			out.append(id)
	return out


func _has_engineer() -> bool:
	for id: int in selection:
		if runner.world.is_unit(id) and runner.world.def_of(id).has_ability("build"):
			return true
	return false


func _has_infantry() -> bool:
	for id: int in selection:
		if runner.world.is_unit(id) and runner.world.def_of(id).is_infantry:
			return true
	return false


## Tab: narrow the selection to one unit type at a time, cycling.
func _cycle_subgroup() -> void:
	var types: PackedInt32Array = PackedInt32Array()
	var full: PackedInt32Array = groups.get(-1, selection)
	for id: int in full:
		var di: int = runner.world.units.def_index[id] if runner.world.units.has(id) else -1
		if di >= 0 and not types.has(di):
			types.append(di)
	if types.size() <= 1:
		return
	types.sort()
	_tab_index = (_tab_index + 1) % types.size()
	var sel: PackedInt32Array = PackedInt32Array()
	for id2: int in groups.get(-1, selection):
		if runner.world.is_unit(id2) and runner.world.units.def_index[id2] == types[_tab_index]:
			sel.append(id2)
	selection = sel
	views.selected.clear()
	for id3: int in sel:
		views.selected[id3] = true
	message = "%s (%d)" % [runner.world.defs.units[types[_tab_index]].display_name, sel.size()]
	if panel != null:
		panel.rebuild()


## "." selects the next idle combat unit and centres the camera on it.
func _select_idle() -> void:
	var w: SimWorld = runner.world
	var ids: PackedInt32Array = w.entities.ids()
	var start: int = selection[0] if selection.size() == 1 else 0
	var found: int = 0
	for pass_i: int in range(2):
		for id: int in ids:
			if (pass_i == 0 and id <= start) or not w.is_unit(id) or w.is_structure(id) or w.units.carrier[id] != 0:
				continue
			if w.units.owner[id] != local_player() or w.orders.kind[id] != OrderStore.NONE or w.def_of(id).is_air:
				continue
			found = id
			break
		if found != 0:
			break
	if found == 0:
		message = "No idle units"
		return
	_set_selection(PackedInt32Array([found]))
	var v: UnitView = views.view_of(found)
	if v != null:
		cam.focus(v.global_position)


func _focus_hq() -> void:
	var w: SimWorld = runner.world
	for id: int in w.entities.ids():
		if w.is_structure(id) and w.units.owner[id] == local_player() and w.def_of(id).role == "hq":
			var v: UnitView = views.view_of(id)
			if v != null:
				cam.focus(v.global_position)
			return


## Units in the selection that can build the structure being placed.
func _builders() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if place_def == null:
		return out
	for id: int in selection:
		if not runner.world.is_unit(id) or runner.world.is_structure(id):
			continue
		var d: UnitStats = runner.world.def_of(id)
		if (place_def.built_at == "engineer" and d.has_ability("build")) \
				or (place_def.built_at == "infantry" and (d.has_ability("dig_in") or d.has_ability("build"))):
			out.append(id)
	return out


## Nearest shown unit/structure to a screen point: own (own=true) or others.
func _pick_unit(pos: Vector2, own: bool) -> int:
	var best: int = 0
	var best_d: float = INF
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if not uv.visible or (uv.team == views.local_team) != own:
			continue
		if cam.camera.is_position_behind(uv.global_position):
			continue
		var sp: Vector2 = cam.camera.unproject_position(uv.global_position + Vector3.UP * 2.0)
		var reach: float = CLICK_PICK_PX * (2.0 if uv.def.is_structure else 1.0)
		var d: float = sp.distance_to(pos)
		if d < reach and d < best_d:
			best_d = d
			best = uv.entity_id
	return best


func _click_select(pos: Vector2, add: bool) -> void:
	var id: int = _pick_unit(pos, true)
	var now: int = Time.get_ticks_msec()
	if id > 0 and runner.world.units.def_index[id] == _last_click_def and now - _last_click_ms < int(DOUBLE_CLICK_S * 1000.0):
		_select_type_on_screen(runner.world.units.def_index[id], add)
		_last_click_ms = 0
		return
	_last_click_ms = now
	_last_click_def = runner.world.units.def_index[id] if id > 0 else -1
	var sel: PackedInt32Array = selection.duplicate() if add else PackedInt32Array()
	if id > 0 and runner.world.units.owner[id] == local_player() and not sel.has(id):
		sel.append(id)
	_set_selection(sel)


## Double-click: every own unit of that type visible on screen.
func _select_type_on_screen(def_index: int, add: bool) -> void:
	var sel: PackedInt32Array = selection.duplicate() if add else PackedInt32Array()
	var rect: Rect2 = get_viewport().get_visible_rect()
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if not uv.visible or uv.team != views.local_team or cam.camera.is_position_behind(uv.global_position):
			continue
		if runner.world.units.owner[uv.entity_id] != local_player() or runner.world.units.def_index[uv.entity_id] != def_index:
			continue
		if rect.has_point(cam.camera.unproject_position(uv.global_position)) and not sel.has(uv.entity_id):
			sel.append(uv.entity_id)
	_set_selection(sel)


func _box_select(r: Rect2, add: bool) -> void:
	var sel: PackedInt32Array = selection.duplicate() if add else PackedInt32Array()
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if uv.team != views.local_team or uv.def.is_structure or cam.camera.is_position_behind(uv.global_position):
			continue
		if runner.world.units.owner[uv.entity_id] != local_player():
			continue
		if r.has_point(cam.camera.unproject_position(uv.global_position + Vector3.UP)) and not sel.has(uv.entity_id):
			sel.append(uv.entity_id)
	_set_selection(sel)


func _set_selection(ids: PackedInt32Array) -> void:
	selection = ids.duplicate()
	selection.sort()
	groups[-1] = selection.duplicate()
	_tab_index = -1
	views.selected.clear()
	for id: int in selection:
		views.selected[id] = true
	if panel != null:
		panel.rebuild()


func mode_text() -> String:
	if mode == Mode.PLACE and place_def != null:
		return MODE_NAMES[mode] % place_def.display_name
	if mode == Mode.SUPPORT:
		return MODE_NAMES[mode] % str(SupportCommand.spec(runner.world, support_kind).get("name", "Support")).to_upper()
	return MODE_NAMES[mode]
