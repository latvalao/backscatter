## Settings (Phase 7): volumes, graphics, accessibility and key bindings.
## Opened from the main menu and the in-game Esc menu; saved to user://graphics.cfg.
class_name SettingsPanel
extends PanelContainer

var _waiting_action: String = ""
var _key_buttons: Dictionary = {}


func _ready() -> void:
	GraphicsSettings.load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760, 560)
	offset_left = -380
	offset_right = 380
	offset_top = -280
	offset_bottom = 280
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 540)
	add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_header(box, "Sound")
	for bus: String in ["Master", "Effects", "Ambient", "Radio"]:
		var row: HBoxContainer = HBoxContainer.new()
		box.add_child(row)
		var l: Label = Label.new()
		l.text = bus
		l.custom_minimum_size = Vector2(160, 0)
		row.add_child(l)
		var s: HSlider = HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(GraphicsSettings.volumes.get(bus, 0.8))
		s.custom_minimum_size = Vector2(300, 0)
		var b: String = bus
		s.value_changed.connect(func(v: float) -> void:
			GraphicsSettings.volumes[b] = v
			GraphicsSettings.apply_audio())
		row.add_child(s)
	_header(box, "Graphics")
	var q: OptionButton = OptionButton.new()
	for n: String in GraphicsSettings.NAMES:
		q.add_item("Quality: " + n)
	q.selected = GraphicsSettings.quality
	q.item_selected.connect(func(i: int) -> void: GraphicsSettings.quality = i)
	box.add_child(q)
	var season: OptionButton = OptionButton.new()
	season.add_item("Season: Autumn")
	season.add_item("Season: Winter")
	season.selected = 1 if GraphicsSettings.season == "winter" else 0
	season.item_selected.connect(func(i: int) -> void: GraphicsSettings.season = "winter" if i == 1 else "autumn")
	box.add_child(season)
	var retro: OptionButton = OptionButton.new()
	for n2: String in GraphicsSettings.RETRO_NAMES:
		retro.add_item("Retro filter: " + n2)
	retro.selected = GraphicsSettings.retro
	retro.item_selected.connect(func(i: int) -> void: GraphicsSettings.retro = i)
	box.add_child(retro)
	_check(box, "Tilt-shift depth of field", GraphicsSettings.tilt_shift, func(on: bool) -> void: GraphicsSettings.tilt_shift = on)
	_check(box, "Film grain", GraphicsSettings.grain, func(on: bool) -> void: GraphicsSettings.grain = on)
	var note: Label = Label.new()
	note.text = "Quality and season apply to the next match."
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)
	_header(box, "Keys (click, then press a key)")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for action: String in KeyBindings.ACTIONS.keys():
		var l2: Label = Label.new()
		l2.text = str(KeyBindings.ACTIONS[action][1])
		l2.custom_minimum_size = Vector2(190, 0)
		grid.add_child(l2)
		var kb: Button = Button.new()
		kb.custom_minimum_size = Vector2(150, 0)
		kb.text = OS.get_keycode_string(KeyBindings.key_for(action))
		var a: String = action
		kb.pressed.connect(func() -> void:
			_waiting_action = a
			kb.text = "press a key…")
		grid.add_child(kb)
		_key_buttons[action] = kb
	var reset: Button = Button.new()
	reset.text = "Reset keys"
	reset.pressed.connect(func() -> void:
		GraphicsSettings.keys.clear()
		_refresh_keys())
	box.add_child(reset)
	var close: Button = Button.new()
	close.text = "Save and close"
	close.pressed.connect(func() -> void:
		GraphicsSettings.save_settings()
		queue_free())
	box.add_child(close)


func _header(box: VBoxContainer, t: String) -> void:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	box.add_child(l)


func _check(box: VBoxContainer, t: String, on: bool, cb: Callable) -> void:
	var c: CheckBox = CheckBox.new()
	c.text = t
	c.button_pressed = on
	c.toggled.connect(cb)
	box.add_child(c)


func _refresh_keys() -> void:
	for action: String in _key_buttons.keys():
		var b: Button = _key_buttons[action]
		b.text = OS.get_keycode_string(KeyBindings.key_for(action))


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed:
		return
	if k.keycode != KEY_ESCAPE:
		GraphicsSettings.keys[_waiting_action] = int(k.keycode)
	_waiting_action = ""
	_refresh_keys()
	get_viewport().set_input_as_handled()
