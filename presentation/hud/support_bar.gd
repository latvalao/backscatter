## Off-map support buttons (top right): what the player's battlegroup can call,
## cost and uses left. Clicking aims the call (SelectionController.Mode.SUPPORT).
class_name SupportBar
extends HBoxContainer

var controller: SelectionController
var _buttons: Array[Button] = []
var _kinds: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -830
	offset_right = -10
	offset_top = -282
	offset_bottom = -250
	alignment = BoxContainer.ALIGNMENT_END
	var w: SimWorld = controller.runner.world
	var me: int = controller.local_player()
	if me >= w.players.count():
		return
	for k: int in range(PlayerStore.SUPPORT_KINDS):
		if not w.defs.support_allowed(k, w.players.faction[me], w.players.battlegroup[me]):
			continue
		var b: Button = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		var kind: int = k
		b.pressed.connect(func() -> void: controller.begin_support(kind))
		add_child(b)
		_buttons.append(b)
		_kinds.append(k)


func _process(_delta: float) -> void:
	var w: SimWorld = controller.runner.world
	var me: int = controller.local_player()
	for i: int in range(_buttons.size()):
		var k: int = _kinds[i]
		var s: Dictionary = SupportCommand.spec(w, k)
		var left: int = SupportCommand.uses_left(w, me, k)
		_buttons[i].text = "%s   %d   %d left" % [s.get("name", "?"), int(s.get("cost", 0)), left]
		_buttons[i].tooltip_text = "Off-map support. The call goes out over the radio from your HQ, so enemy direction finding can locate it.%s" % ("\nNeeds a unit with eyes on the target." if bool(s.get("observer", false)) else "")
		_buttons[i].disabled = left <= 0 or not w.players.can_afford(me, int(s.get("cost", 0)), int(s.get("mp", 0)))
