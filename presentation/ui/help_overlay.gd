## Full key reference (Phase 8), opened from the top bar's Keys button or "/".
## Grouped by task; reflects rebound keys.
class_name HelpOverlay
extends PanelContainer

const GROUPS: Array = [
	["Selecting", [["Left click / drag", "Select, box select"], ["Double click", "All units of that type on screen"], ["Ctrl+1-9 / 1-9", "Set / recall control group"], ["Tab", "Cycle unit types in the selection"], [".", "Next idle unit"], ["Home", "Jump to HQ"], ["Space", "Jump to the last alert"]]],
	["Moving", [["Right click", "Move (on an enemy: attack, on a transport: board)"], ["Right drag", "Move and face the drag direction"], ["Shift + order", "Queue after current orders"], ["Ctrl + right click", "Route around radiation"], ["Alt + right click", "Reverse move"], ["attack_move", ""], ["reverse", ""], ["stop", ""], ["formation", ""], ["seize", ""]]],
	["Fighting", [["hold_fire", ""], ["engage_range", ""], ["overwatch", ""], ["smoke", ""], ["emcon", ""], ["rotate", ""], ["los", ""]]],
	["Transport and engineers", [["unload", ""], ["unload_at", ""], ["mines", ""], ["Right click a wreck", "Salvage it (engineer)"], ["F1-F8", "Build / produce buttons"], ["Ctrl+G", "Give units to a teammate"]]],
	["Fires", [["fire_mission", ""], ["smoke_mission", ""], ["flare", ""], ["auto_cb", ""], ["Support buttons", "Airstrike, artillery, paradrop"]]],
	["View", [["dosimetry", ""], ["signals", ""], ["Arrows / screen edge / middle drag", "Pan"], ["Wheel", "Zoom"], ["Q / E", "Rotate"], ["Page Up / Down", "Tilt"], ["pause", ""], ["+ / -", "Game speed"], ["Esc", "Menu"]]],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 560)
	offset_left = -450
	offset_right = 450
	offset_top = -280
	offset_bottom = 280
	var outer: VBoxContainer = VBoxContainer.new()
	add_child(outer)
	var head: HBoxContainer = HBoxContainer.new()
	outer.add_child(head)
	var t: Label = UiStyle.label("Keys", UiStyle.FONT_L, UiStyle.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close: Button = Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	outer.add_child(cols)
	var col_box: Array[VBoxContainer] = []
	for i: int in range(3):
		var v: VBoxContainer = VBoxContainer.new()
		v.custom_minimum_size = Vector2(280, 0)
		cols.add_child(v)
		col_box.append(v)
	for gi: int in range(GROUPS.size()):
		var g: Array = GROUPS[gi]
		var box: VBoxContainer = col_box[gi % 3]
		box.add_child(UiStyle.label(str(g[0]).to_upper(), UiStyle.FONT_S, UiStyle.AMBER))
		for e: Array in g[1]:
			var key: String = str(e[0])
			var what: String = str(e[1])
			if KeyBindings.ACTIONS.has(key):
				what = str(KeyBindings.ACTIONS[key][1])
				key = OS.get_keycode_string(KeyBindings.key_for(key))
			var row: HBoxContainer = HBoxContainer.new()
			var kl: Label = UiStyle.label(key, UiStyle.FONT_S, UiStyle.CYAN)
			kl.custom_minimum_size = Vector2(110, 0)
			kl.autowrap_mode = TextServer.AUTOWRAP_WORD
			row.add_child(kl)
			var wl: Label = UiStyle.label(what, UiStyle.FONT_S, UiStyle.TEXT)
			wl.custom_minimum_size = Vector2(165, 0)
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD
			row.add_child(wl)
			box.add_child(row)
		box.add_child(UiStyle.label(" ", 6))
