## Context buttons (bottom right): build menu for engineers / infantry, or the
## production list and queue of a selected production building. F1–F8 press them.
class_name CommandPanel
extends PanelContainer

var controller: SelectionController
var _box: VBoxContainer
var _title: Label
var _grid: GridContainer
var _queue: Label
var _actions: Array[Callable] = []
var _key: String = ""


func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -640
	offset_top = -230
	offset_right = -12
	offset_bottom = -12
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	add_child(_box)
	_title = Label.new()
	_box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 3
	_box.add_child(_grid)
	_queue = Label.new()
	_queue.add_theme_font_size_override("font_size", 13)
	_box.add_child(_queue)
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	# refresh the queue line and button affordability
	var w: SimWorld = controller.runner.world
	var sel: PackedInt32Array = controller.selection
	if sel.size() == 1 and w.is_unit(sel[0]) and w.is_structure(sel[0]):
		var q: PackedInt32Array = w.structures.get_queue(sel[0])
		var names: PackedStringArray = PackedStringArray()
		for d: int in q:
			names.append(w.defs.units[d].display_name)
		var left: String = ""
		if not q.is_empty():
			left = " — %ds left" % (w.structures.prod_left[sel[0]] / SimConst.TICKS_PER_SECOND)
		_queue.text = ("Queue: " + ", ".join(names) + left) if not q.is_empty() else "Queue empty · right-click map: rally point"


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
	for c: Node in _grid.get_children():
		c.queue_free()
	_actions.clear()
	_queue.text = ""
	visible = false
	if sel.is_empty() or not w.is_unit(sel[0]):
		return
	var me: int = controller.local_player()
	if sel.size() == 1 and w.is_structure(sel[0]):
		var b: int = sel[0]
		var bd: UnitStats = w.def_of(b)
		var options: Array[UnitStats] = w.defs.producible(bd.role, w.players.faction[me])
		if options.is_empty() or not w.structures.is_complete(b):
			return
		_title.text = "%s — produce" % bd.display_name
		for u: UnitStats in options:
			if not w.defs.allowed(u.id, u.faction, w.players.battlegroup[me]):
				continue
			var def_id: String = u.id
			_add("%s  %d/%d" % [u.display_name, u.cost_supply, u.cost_manpower], func() -> void:
				controller.submit(ProduceCommand.new(b, def_id, 1)))
		_add("Cancel last", func() -> void: controller.submit(CancelProductionCommand.new(b)))
		visible = true
		return
	var operator: int = 0
	for id: int in sel:
		if w.is_unit(id) and not w.is_structure(id) and w.def_of(id).has_ability("drone_operator"):
			operator = id
			break
	var engineer: bool = false
	var infantry: bool = false
	for id: int in sel:
		if not w.is_unit(id) or w.is_structure(id):
			continue
		var d: UnitStats = w.def_of(id)
		engineer = engineer or d.has_ability("build")
		infantry = infantry or d.has_ability("dig_in")
	var defs: Array[UnitStats] = []
	if engineer:
		defs.append_array(w.defs.buildable("engineer"))
	if engineer or infantry:
		defs.append_array(w.defs.buildable("infantry"))
	if operator > 0:
		_title.text = "Recon / Build" if not defs.is_empty() else "Recon"
		for dd: UnitStats in w.defs.units:
			if dd.is_air and dd.battery_ticks > 0 and dd.faction == w.players.faction[me]:
				var did: String = dd.id
				var op_ids: PackedInt32Array = PackedInt32Array([operator])
				_add("Launch %s  %d" % [dd.display_name, dd.cost_supply], func() -> void:
					controller.submit(LaunchDroneCommand.new(op_ids, did)))
		visible = true
	if defs.is_empty():
		return
	if operator == 0:
		_title.text = "Build"
	for d2: UnitStats in defs:
		var sd: UnitStats = d2
		_add("%s  %d" % [sd.display_name, sd.cost_supply], func() -> void: controller.begin_placement(sd))
	visible = true


func _add(text: String, action: Callable) -> void:
	var i: int = _actions.size()
	var b: Button = Button.new()
	b.text = ("F%d %s" % [i + 1, text]) if i < 8 else text
	b.custom_minimum_size = Vector2(200, 28)
	b.add_theme_font_size_override("font_size", 13)
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	_grid.add_child(b)
	_actions.append(action)
