## Command card (Phase 8, bottom right). Left: every order the selection can
## take, as buttons with their hotkey and a tooltip. Right: build list for
## engineers / infantry, or the production list and queue of a building.
## F1-F8 press the build / produce buttons.
class_name CommandPanel
extends PanelContainer

## [key, label, tooltip, condition]
const ORDERS: Array = [
	[KEY_A, "Attack-move", "Move and fight anything met on the way. Right-click the ground for a plain move, drag to set the facing.", "unit"],
	[KEY_R, "Reverse", "Back up keeping the front armour toward the enemy.", "vehicle"],
	[KEY_S, "Stop", "Cancel orders.", "unit"],
	[KEY_H, "Hold fire", "Toggle: hold fire / fire at will.", "armed"],
	[KEY_Y, "Fire range", "Click the distance to open fire at. Shift+Y clears it.", "armed"],
	[KEY_N, "Formation", "Cycle block, line, column and wedge for move orders.", "group"],
	[KEY_K, "Seize", "Attack-move to a point in a wedge facing it; infantry digs in on arrival.", "unit"],
	[KEY_O, "Overwatch", "Stay and cover the sector toward the clicked point.", "armed"],
	[KEY_X, "Smoke", "Fire smoke launchers.", "smoke"],
	[KEY_Z, "EMCON", "Cycle radio emissions: emit, restricted, silent. Silent units are hard to find but report late.", "emitter"],
	[KEY_U, "Unload", "Unload passengers here.", "carrier"],
	[KEY_T, "Unload at", "Drive to a point and unload there.", "carrier"],
	[KEY_F, "Fire mission", "Indirect fire on a point a friendly unit can see.", "indirect"],
	[KEY_G, "Smoke mission", "Indirect smoke on a point.", "indirect"],
	[KEY_I, "Flare", "Illumination round: day sight under it at night.", "indirect"],
	[KEY_B, "Auto CB", "Toggle automatic counter-battery fire on enemy guns your radar or DF fixes.", "indirect"],
	[KEY_M, "Mines", "Lay a minefield (30 supply). Right-click a wreck to salvage it.", "engineer"],
	[KEY_J, "Rotation", "Toggle crew rotation: irradiated units go for treatment and come back.", "unit"],
]

var controller: SelectionController
var _orders: GridContainer
var _build_title: Label
var _build: GridContainer
var _queue: Label
var _actions: Array[Callable] = []
var _key: String = ""


func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -830
	offset_top = -244
	offset_right = -10
	offset_bottom = -10
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	row.add_child(left)
	left.add_child(UiStyle.label("ORDERS", UiStyle.FONT_S, UiStyle.DIM))
	_orders = GridContainer.new()
	_orders.columns = 4
	_orders.add_theme_constant_override("h_separation", 3)
	_orders.add_theme_constant_override("v_separation", 3)
	left.add_child(_orders)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_build_title = UiStyle.label("", UiStyle.FONT_S, UiStyle.DIM)
	right.add_child(_build_title)
	_build = GridContainer.new()
	_build.columns = 3
	_build.add_theme_constant_override("h_separation", 3)
	_build.add_theme_constant_override("v_separation", 3)
	right.add_child(_build)
	_queue = UiStyle.label("", UiStyle.FONT_S, UiStyle.CYAN)
	_queue.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_queue)
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var w: SimWorld = controller.runner.world
	var sel: PackedInt32Array = controller.selection
	if sel.size() == 1 and w.is_unit(sel[0]) and w.is_structure(sel[0]):
		var q: PackedInt32Array = w.structures.get_queue(sel[0])
		var names: PackedStringArray = PackedStringArray()
		for d: int in q:
			names.append(w.defs.units[d].display_name)
		if q.is_empty():
			_queue.text = "Queue empty. Right-click the map to set the rally point."
		else:
			_queue.text = "Queue: %s   (%d s)" % [", ".join(names), w.structures.prod_left[sel[0]] / SimConst.TICKS_PER_SECOND]
	var me: int = controller.local_player()
	for b: Node in _build.get_children():
		var btn: Button = b as Button
		if btn != null and btn.has_meta("cost") and me < w.players.count():
			var c: Vector2i = btn.get_meta("cost")
			btn.disabled = not w.players.can_afford(me, c.x, c.y)


func press(i: int) -> void:
	if visible and i < _actions.size():
		_actions[i].call()


func rebuild() -> void:
	var w: SimWorld = controller.runner.world
	var sel: PackedInt32Array = controller.selection
	var key: String = str(sel)
	if key == _key:
		return
	_key = key
	for c: Node in _orders.get_children():
		c.queue_free()
	for c2: Node in _build.get_children():
		c2.queue_free()
	_actions.clear()
	_queue.text = ""
	_build_title.text = ""
	visible = false
	if sel.is_empty() or not w.is_unit(sel[0]):
		return
	visible = true
	var me: int = controller.local_player()
	if sel.size() == 1 and w.is_structure(sel[0]):
		_production(w, sel[0], me)
		return
	var tags: Dictionary = _tags(w, sel)
	for o: Array in ORDERS:
		if tags.has(str(o[3])):
			_order_button(o)
	_build_list(w, sel, me)


func _tags(w: SimWorld, sel: PackedInt32Array) -> Dictionary:
	var t: Dictionary = {"unit": true}
	if sel.size() > 1:
		t["group"] = true
	for id: int in sel:
		if not w.is_unit(id) or w.is_structure(id):
			continue
		var d: UnitStats = w.def_of(id)
		if d.is_vehicle():
			t["vehicle"] = true
		if not d.weapons.is_empty():
			t["armed"] = true
		if d.smoke_charges > 0:
			t["smoke"] = true
		if d.emitter_kind != UnitStats.EMIT_NONE:
			t["emitter"] = true
		if Transport.capacity(d) > 0:
			t["carrier"] = true
		if d.has_ability("build"):
			t["engineer"] = true
		for wi: int in d.weapons:
			if w.defs.weapons[wi].is_indirect():
				t["indirect"] = true
	return t


func _order_button(o: Array) -> void:
	var b: Button = Button.new()
	var k: Key = o[0]
	var bound: Key = _bound_key(k)
	b.text = "%s\n%s" % [str(o[1]), OS.get_keycode_string(bound)]
	b.tooltip_text = "%s (%s)\n%s" % [str(o[1]), OS.get_keycode_string(bound), str(o[2])]
	b.custom_minimum_size = Vector2(80, 36)
	b.add_theme_font_size_override("font_size", UiStyle.FONT_S)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: controller.press_key(k))
	_orders.add_child(b)


## The key the player has bound to the action whose default key is k.
func _bound_key(k: Key) -> Key:
	for action: String in KeyBindings.ACTIONS.keys():
		if int(KeyBindings.ACTIONS[action][0]) == k:
			return KeyBindings.key_for(action)
	return k


func _build_list(w: SimWorld, sel: PackedInt32Array, me: int) -> void:
	var operator: int = 0
	var engineer: bool = false
	var infantry: bool = false
	for id: int in sel:
		if not w.is_unit(id) or w.is_structure(id):
			continue
		var d: UnitStats = w.def_of(id)
		engineer = engineer or d.has_ability("build")
		infantry = infantry or d.has_ability("dig_in")
		if d.has_ability("drone_operator") and operator == 0:
			operator = id
	if operator > 0:
		for dd: UnitStats in w.defs.units:
			if dd.is_air and dd.battery_ticks > 0 and dd.faction == w.players.faction[me]:
				var did: String = dd.id
				var ops: PackedInt32Array = PackedInt32Array([operator])
				_add(dd.display_name, Vector2i(dd.cost_supply, 0), "A drone with a limited battery. It needs its operator on the net.",
					func() -> void: controller.submit(LaunchDroneCommand.new(ops, did)))
	var defs: Array[UnitStats] = []
	if engineer:
		defs.append_array(w.defs.buildable("engineer"))
	if engineer or infantry:
		defs.append_array(w.defs.buildable("infantry"))
	for sd: UnitStats in defs:
		var s2: UnitStats = sd
		_add(sd.display_name, Vector2i(sd.cost_supply, 0), "Build %s. Click to place it." % sd.display_name, func() -> void: controller.begin_placement(s2))
	if not _actions.is_empty():
		_build_title.text = "BUILD"


func _production(w: SimWorld, b: int, me: int) -> void:
	var bd: UnitStats = w.def_of(b)
	_build_title.text = bd.display_name.to_upper()
	var options: Array[UnitStats] = w.defs.producible(bd.role, w.players.faction[me])
	if options.is_empty() or not w.structures.is_complete(b):
		_queue.text = "Under construction." if not w.structures.is_complete(b) else ""
		return
	for u: UnitStats in options:
		if not w.defs.allowed(u.id, u.faction, w.players.battlegroup[me]):
			continue
		var def_id: String = u.id
		_add(u.display_name, Vector2i(u.cost_supply, u.cost_manpower), "%s: %s. %d supply, %d manpower, %d s." % [u.display_name, u.role.capitalize(), u.cost_supply, u.cost_manpower, u.build_time_ticks / SimConst.TICKS_PER_SECOND],
			func() -> void: controller.submit(ProduceCommand.new(b, def_id, 1)))
	_add("Cancel last", Vector2i.ZERO, "Remove the last unit in the queue and refund it.", func() -> void: controller.submit(CancelProductionCommand.new(b)))


func _add(text: String, cost: Vector2i, tip: String, action: Callable) -> void:
	var i: int = _actions.size()
	var b: Button = Button.new()
	var cost_txt: String = ""
	if cost.x > 0:
		cost_txt = "  %d" % cost.x + ("/%d" % cost.y if cost.y > 0 else "")
	b.text = ("F%d " % (i + 1) if i < 8 else "") + text + cost_txt
	b.tooltip_text = "%s%s\n%s" % [text, cost_txt, tip]
	b.custom_minimum_size = Vector2(150, 26)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", UiStyle.FONT_S - 1)
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	if cost.x > 0:
		b.set_meta("cost", cost)
	_build.add_child(b)
	_actions.append(action)
