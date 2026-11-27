## Main menu and lobby. Starts offline matches, hosts/joins LAN (ENet) or Steam
## lobbies (invite-only, §4), and plays the last replay.
class_name MainMenu
extends Control

var _name: LineEdit
var _address: LineEdit
var _main: VBoxContainer
var _lobby_box: VBoxContainer
var _roster: Label
var _status: Label
var _start_btn: Button
var _invite_btn: Button
var _lobby: Lobby
var _transport: NetTransport
var _early: Array[PackedByteArray] = []
var _game: GameScene


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.13, 0.15, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(420, 0)
	center.add_child(col)
	var title: Label = Label.new()
	title.text = "BACKSCATTER"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub: Label = Label.new()
	sub.text = "prototype — M7"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_name = LineEdit.new()
	_name.placeholder_text = "Your name"
	_name.text = "Commander"
	col.add_child(_name)

	_main = VBoxContainer.new()
	col.add_child(_main)
	_button(_main, "Skirmish vs AI — Easy", func() -> void: _start_skirmish(0))
	_button(_main, "Skirmish vs AI — Normal (+ Marauders)", func() -> void: _start_skirmish(1))
	_button(_main, "Skirmish vs AI — Hard (+ Marauders)", func() -> void: _start_skirmish(2))
	_button(_main, "Sandbox battle (combat only)", _start_sandbox)
	_button(_main, "Host LAN game", _host_lan)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host IP"
	_main.add_child(_address)
	_button(_main, "Join LAN game", _join_lan)
	var steam_btn: Button = _button(_main, "Host Steam lobby (invite friends)", _host_steam)
	steam_btn.disabled = not SteamTransport.available()
	if steam_btn.disabled:
		steam_btn.tooltip_text = "Install the GodotSteam addon to enable Steam play"
	_button(_main, "Watch last replay", _watch_replay)
	_button(_main, "Quit", func() -> void: get_tree().quit())

	_lobby_box = VBoxContainer.new()
	_lobby_box.visible = false
	col.add_child(_lobby_box)
	_roster = Label.new()
	_lobby_box.add_child(_roster)
	_button(_lobby_box, "Add AI to Coalition team", func() -> void: _lobby.add_ai(0))
	_button(_lobby_box, "Add AI to Eastern team", func() -> void: _lobby.add_ai(1))
	_invite_btn = _button(_lobby_box, "Invite Steam friends", func() -> void: (_transport as SteamTransport).invite_friends())
	_start_btn = _button(_lobby_box, "Start match", _start_lobby_match)
	_button(_lobby_box, "Leave lobby", _leave_lobby)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_status)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _process(_delta: float) -> void:
	if _lobby != null and _game == null:
		_early.append_array(_lobby.poll())
		_render_roster()


func _start_skirmish(difficulty: int) -> void:
	var s: MatchSettings = MatchSettings.default_skirmish(difficulty, difficulty > 0)
	s.players[0]["name"] = _name.text
	s.match_seed = Time.get_ticks_usec()
	_launch(GameScene.create_offline(s))


func _start_sandbox() -> void:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "sandbox"
	s.match_seed = 20261127
	s.add_player(_name.text, 0, "nc", false)
	s.add_player("Eastern AI", 1, "ec", true)
	_launch(GameScene.create_offline(s))


func _host_lan() -> void:
	var t: ENetTransport = ENetTransport.new()
	var err: Error = t.host(ENetTransport.DEFAULT_PORT, 3)
	if err != OK:
		_status.text = "Could not host on UDP %d (error %d)" % [ENetTransport.DEFAULT_PORT, err]
		return
	_open_lobby(t)
	_status.text = "Hosting on UDP port %d — friends join with your IP" % ENetTransport.DEFAULT_PORT


func _join_lan() -> void:
	var t: ENetTransport = ENetTransport.new()
	var err: Error = t.join(_address.text.strip_edges(), ENetTransport.DEFAULT_PORT)
	if err != OK:
		_status.text = "Could not connect (error %d)" % err
		return
	_open_lobby(t)
	_status.text = "Connecting to %s…" % _address.text


func _host_steam() -> void:
	var t: SteamTransport = SteamTransport.new()
	t.lobby_failed.connect(func(r: String) -> void: _status.text = r)
	t.lobby_ready.connect(func(_id: int) -> void:
		_status.text = "Steam lobby open — invite friends"
		if _lobby == null:
			_open_lobby(t))
	t.host_lobby(4)
	_transport = t
	_status.text = "Creating Steam lobby…"


func _open_lobby(t: NetTransport) -> void:
	_transport = t
	_lobby = Lobby.new(t, _name.text)
	_lobby.map_seed = Time.get_ticks_usec() % 100000
	_lobby.match_started.connect(_on_match_started)
	_lobby.message.connect(func(m: String) -> void: _status.text = m)
	_main.visible = false
	_lobby_box.visible = true
	_start_btn.visible = t.is_host()
	_invite_btn.visible = t is SteamTransport


func _render_roster() -> void:
	var lines: PackedStringArray = PackedStringArray(["Lobby (%s):" % _transport.describe()])
	for i: int in range(_lobby.roster.size()):
		var p: Dictionary = _lobby.roster[i]
		lines.append("  %d. %s — %s%s%s" % [i + 1, p["name"], "Coalition" if int(p["team"]) == 0 else "Eastern",
			" (AI)" if bool(p["ai"]) else "", "  ← you" if i == _lobby.local_player else ""])
	_roster.text = "\n".join(lines)
	_start_btn.disabled = _lobby.roster.size() < 2


func _start_lobby_match() -> void:
	_lobby.start(Time.get_ticks_usec())


func _on_match_started(settings: MatchSettings, local_player: int) -> void:
	var g: GameScene = GameScene.create_networked(settings, _transport, local_player)
	_launch(g)
	for d: PackedByteArray in _early:
		g.lockstep.handle(d)
	_early.clear()


func _leave_lobby() -> void:
	if _transport != null:
		_transport.close()
	_lobby = null
	_transport = null
	_main.visible = true
	_lobby_box.visible = false
	_status.text = ""


func _watch_replay() -> void:
	var data: Dictionary = ReplayRecorder.load_file(ReplayRecorder.default_path())
	if data.is_empty():
		_status.text = "No replay yet — finish or leave a match first."
		return
	_launch(GameScene.create_replay(data))


func _launch(g: GameScene) -> void:
	_game = g
	g.exit_to_menu.connect(_on_exit)
	get_parent().add_child(g)
	visible = false
	set_process(false)


func _on_exit() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	_lobby = null
	_transport = null
	_main.visible = true
	_lobby_box.visible = false
	visible = true
	set_process(true)
