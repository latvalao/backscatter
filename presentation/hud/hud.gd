## In-match interface (Phase 8): top bar, unit card, unit markers, banners,
## the Esc menu and the key reference. The command card lives with the
## SelectionController; minimap, alerts, objectives and support are added by
## GameScene. All styling comes from UiStyle.
class_name Hud
extends CanvasLayer

var runner: SimRunner
var controller: SelectionController
var views: ViewSync
var scene: GameScene

var overlay: UnitOverlay
var _top: TopBar
var _card: UnitCard
var _banner: Label
var _message: Label
var _menu: PanelContainer
var _help: HelpOverlay
var _msg_timer: float = 0.0
var _last_msg: String = ""
var _ended: bool = false


func _ready() -> void:
	overlay = UnitOverlay.new()
	overlay.runner = runner
	overlay.views = views
	overlay.controller = controller
	add_child(overlay)
	_top = TopBar.new()
	_top.runner = runner
	_top.controller = controller
	_top.views = views
	_top.scene = scene
	_top.on_help = toggle_help
	_top.on_menu = toggle_menu
	add_child(_top)
	_card = UnitCard.new()
	_card.runner = runner
	_card.controller = controller
	_card.views = views
	add_child(_card)
	_message = UiStyle.label("", UiStyle.FONT_M, UiStyle.AMBER)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_top = -250
	_message.offset_bottom = -226
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)
	_banner = UiStyle.label("", 34, UiStyle.TEXT)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.visible = false
	add_child(_banner)
	_build_menu()
	_help = HelpOverlay.new()
	_help.visible = false
	add_child(_help)


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var box: VBoxContainer = VBoxContainer.new()
	_menu.add_child(box)
	box.add_child(UiStyle.label("Paused menu", UiStyle.FONT_L))
	for pair: Array in [["Resume", func() -> void: toggle_menu()],
			["Save game", func() -> void: banner("Game saved: " + ProjectSettings.globalize_path(scene.save_game()))],
			["Settings", func() -> void: add_child(SettingsPanel.new())],
			["Keys", func() -> void: toggle_help()],
			["Save replay", func() -> void: banner("Replay saved: " + ProjectSettings.globalize_path(scene.save_replay()))],
			["Leave match", func() -> void: scene.leave()]]:
		var b: Button = Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(260, 36)
		b.pressed.connect(pair[1] as Callable)
		box.add_child(b)
	_menu.visible = false
	add_child(_menu)


func toggle_menu() -> void:
	_menu.visible = not _menu.visible


func toggle_help() -> void:
	_help.visible = not _help.visible


func hide_banner() -> void:
	_banner.visible = false


func banner(text: String) -> void:
	_banner.text = text
	_banner.visible = text != ""


func mode_name() -> String:
	if scene.replay_mode:
		return "Replay"
	return settings_mode()


func settings_mode() -> String:
	return {"skirmish": "Skirmish", "sandbox": "Sandbox", "zone_war": "Zone War", "containment": "Containment",
		"operation": "Operation", "mission": "Campaign"}.get(scene.settings.mode, scene.settings.mode)


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_SLASH:
		toggle_help()


func _process(delta: float) -> void:
	var w: SimWorld = runner.world
	var team: int = views.local_team
	if controller.message != _last_msg:
		_last_msg = controller.message
		_msg_timer = 3.0
	_msg_timer -= delta
	_message.text = controller.message if _msg_timer > 0.0 else ""
	if w.winner_team >= 0 and not _ended:
		_ended = true
		if scene.stats != null:
			var ms: MatchSummary = MatchSummary.new()
			ms.stats = scene.stats
			ms.local_team = team
			ms.on_leave = func() -> void: scene.leave()
			add_child(ms)
			ms.build(w.winner_team)
		else:
			banner("VICTORY" if w.winner_team == team else "DEFEAT")
