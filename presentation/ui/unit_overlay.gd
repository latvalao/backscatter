## Screen-space unit markers (Phase 8): health bars when damaged or selected,
## veterancy chevrons, pinned / routing / dug-in status, passengers, build and
## capture progress on structures, "?" contacts, and the active order mode next
## to the cursor. Replaces the old floating text labels. Read-only.
class_name UnitOverlay
extends Control

var runner: SimRunner
var views: ViewSync
var controller: SelectionController

const BAR_W: float = 34.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()
	var hint: bool = controller.mode != SelectionController.Mode.NORMAL
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if hint else Input.CURSOR_ARROW)


func _draw() -> void:
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	var cam: Camera3D = controller.cam.camera
	var rect: Rect2 = get_viewport_rect().grow(40)
	var far: bool = controller.cam.distance > 900.0
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if not uv.visible or not w.units.has(uv.entity_id) or cam.is_position_behind(uv.global_position):
			continue
		var head: float = 4.0 if uv.def.is_infantry else (13.0 if uv.def.is_structure else 6.0)
		var sp: Vector2 = cam.unproject_position(uv.global_position + Vector3.UP * head)
		if not rect.has_point(sp):
			continue
		if uv.def.is_structure:
			_structure(w, uv, sp)
		else:
			_unit(w, uv, sp, far)
	if controller.mode != SelectionController.Mode.NORMAL:
		var m: Vector2 = get_viewport().get_mouse_position()
		var t: String = controller.mode_text()
		var wdt: float = UiStyle.text_width(t, UiStyle.FONT_S) + 14.0
		draw_rect(Rect2(m + Vector2(18, 14), Vector2(wdt, 20)), UiStyle.BG)
		UiStyle.text(self, m + Vector2(25, 29), t, UiStyle.FONT_S, UiStyle.AMBER, false)


func _unit(w: SimWorld, uv: UnitView, sp: Vector2, far: bool) -> void:
	var id: int = uv.entity_id
	var u: UnitStore = w.units
	var own: bool = uv.team == views.local_team
	var sel: bool = views.selected.has(id)
	if not uv.is_identified():
		UiStyle.text(self, sp + Vector2(-6, 0), "?", UiStyle.FONT_M, UiStyle.BAD)
		if not far:
			UiStyle.text(self, sp + Vector2(6, 0), uv.contact_class(), UiStyle.FONT_S, Color(1, 0.75, 0.6, 0.85))
		return
	var f: float = _health(w, uv)
	var routing: bool = u.rout_until[id] > w.tick
	var pinned: bool = u.suppression[id] >= MoraleSystem.PIN_THRESHOLD
	var show: bool = sel or f < 0.999 or routing or pinned
	if not show and (far or u.rank[id] == 0):
		return
	var x: float = sp.x - BAR_W * 0.5
	if show:
		UiStyle.bar(self, Rect2(x, sp.y, BAR_W, 4), f, UiStyle.health_color(f) if own else UiStyle.BAD.lightened(0.15))
		if u.suppression[id] > 0:
			UiStyle.bar(self, Rect2(x, sp.y + 5, BAR_W, 2), u.suppression[id] / 1000.0, UiStyle.AMBER, Color(0, 0, 0, 0.35))
	# veterancy chevrons left of the bar
	for r: int in range(u.rank[id]):
		var cx: float = x - 6.0 - r * 6.0
		draw_polyline(PackedVector2Array([Vector2(cx - 3, sp.y - 1), Vector2(cx, sp.y + 3), Vector2(cx + 3, sp.y - 1)]), UiStyle.AMBER, 1.5)
	var tag: String = ""
	var tc: Color = UiStyle.AMBER
	if routing:
		tag = "ROUTING"
		tc = UiStyle.BAD
	elif pinned:
		tag = "PINNED"
	elif uv.def.is_infantry and FieldSystem.dug_in_bonus(w, id) > 0 and sel:
		tag = "DUG IN"
		tc = UiStyle.DIM
	if Transport.capacity(uv.def) > 0 and sel:
		var pax: int = Transport.passengers(w, id).size()
		if pax > 0:
			tag = ("%s  " % tag if tag != "" else "") + "+%d squad%s" % [pax, "" if pax == 1 else "s"]
			tc = UiStyle.CYAN if not routing and not pinned else tc
	if tag != "":
		UiStyle.text(self, Vector2(x, sp.y - 4), tag, UiStyle.FONT_S - 1, tc)


func _health(w: SimWorld, uv: UnitView) -> float:
	var id: int = uv.entity_id
	if uv.def.is_infantry:
		return float(w.units.members_alive[id]) / maxi(1, uv.def.members)
	return float(maxi(0, w.units.hp[id])) / maxi(1, uv.def.hp)


func _structure(w: SimWorld, uv: UnitView, sp: Vector2) -> void:
	var id: int = uv.entity_id
	var s: StructureStore = w.structures
	var x: float = sp.x - BAR_W
	if not s.is_complete(id):
		var total: int = maxi(1, uv.def.build_time_ticks * 100)
		var f: float = 1.0 - float(s.build_left[id]) / total
		UiStyle.bar(self, Rect2(x, sp.y, BAR_W * 2, 5), f, UiStyle.CYAN)
		UiStyle.text(self, Vector2(x, sp.y - 4), "Building %d%%" % int(f * 100.0), UiStyle.FONT_S, UiStyle.CYAN)
		return
	if uv.def.role == "depot_objective":
		var holder: int = s.holder_team[id]
		var name: String = "Depot"
		var col: Color = UnitView.FLAG_COLORS[holder] if holder >= 0 else UiStyle.DIM
		if s.capture_team[id] >= 0:
			var cf: float = float(s.capture_progress[id]) / maxi(1, Economy.ticks(w, "capture_s"))
			UiStyle.bar(self, Rect2(x, sp.y, BAR_W * 2, 5), cf, UnitView.FLAG_COLORS[s.capture_team[id]])
			name = "Depot: capturing"
		elif holder >= 0:
			name = "Depot  %d" % s.stock[id] + ("" if s.connected[id] == 1 else "  no route")
		UiStyle.text(self, Vector2(x, sp.y - 4), name, UiStyle.FONT_S, col)
		return
	var q: PackedInt32Array = s.get_queue(id)
	var f2: float = float(maxi(0, w.units.hp[id])) / maxi(1, uv.def.hp)
	if f2 < 0.999 or views.selected.has(id):
		UiStyle.bar(self, Rect2(x, sp.y, BAR_W * 2, 4), f2, UiStyle.health_color(f2))
	if not q.is_empty() and uv.team == views.local_team:
		var pd: UnitStats = w.defs.units[q[0]]
		var pf: float = 1.0 - float(s.prod_left[id]) / maxi(1, pd.build_time_ticks)
		UiStyle.bar(self, Rect2(x, sp.y + 6, BAR_W * 2, 3), pf, UiStyle.CYAN, Color(0, 0, 0, 0.35))
		UiStyle.text(self, Vector2(x, sp.y - 4), "%s%s" % [pd.display_name, (" +%d" % (q.size() - 1)) if q.size() > 1 else ""], UiStyle.FONT_S, UiStyle.CYAN)
