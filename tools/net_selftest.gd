## Two-process lockstep test over real ENet (localhost):
##   godot --headless --path . -s res://tools/net_selftest.gd -- --host --port=27961 &
##   godot --headless --path . -s res://tools/net_selftest.gd -- --join=127.0.0.1 --port=27961
## Each prints "NETTEST <role> tick=<t> checksum=<hex>" and exits 0 on success.
extends SceneTree

const TICKS: int = 600
const TIMEOUT_FRAMES: int = 60000

var _role: String = "host"
var _transport: ENetTransport
var _lobby: Lobby
var _lockstep: Lockstep
var _world: SimWorld
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _frames: int = 0
var _local: int = -1
var _started: bool = false


func _initialize() -> void:
	var port: int = 27961
	var address: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a == "--host":
			_role = "host"
		elif a.begins_with("--join="):
			_role = "client"
			address = a.substr(7)
		elif a.begins_with("--port="):
			port = a.substr(7).to_int()
	_transport = ENetTransport.new()
	var err: Error = _transport.host(port, 3) if _role == "host" else _transport.join(address, port)
	if err != OK:
		printerr("NETTEST %s: transport error %d" % [_role, err])
		quit(2)
		return
	_lobby = Lobby.new(_transport, _role)
	_lobby.map_seed = 5
	_lobby.match_started.connect(_on_start)
	_lobby.message.connect(func(m: String) -> void: print("NETTEST %s: %s" % [_role, m]))


func _on_start(settings: MatchSettings, local_player: int) -> void:
	settings.map_cells = 160
	_local = local_player
	_world = MatchSetup.create(settings, DefLoader.load_default())
	_lockstep = Lockstep.new(_world, _transport, local_player, Lobby.human_players(settings), 3)
	_lockstep.recorder = ReplayRecorder.new(settings.to_dict())
	_lockstep.desync.connect(func(t: int, d: String) -> void:
		printerr("NETTEST %s DESYNC at %d: %s" % [_role, t, d])
		quit(3))
	_rng.seed = 1000 + local_player
	_started = true
	print("NETTEST %s: match started as player %d" % [_role, local_player])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > TIMEOUT_FRAMES:
		printerr("NETTEST %s: timeout (tick %d)" % [_role, _world.tick if _world != null else -1])
		quit(4)
		return true
	if not _started:
		var early: Array[PackedByteArray] = _lobby.poll()
		if _role == "host" and _lobby.roster.size() >= 2 and not _started:
			# MatchSettings map size is fixed in _on_start on both sides
			_lobby.start(77)
		if _lockstep != null:
			for d: PackedByteArray in early:
				_lockstep.handle(d)
		return false
	for d: PackedByteArray in _lobby.poll():
		_lockstep.handle(d)
	if _rng.randi_range(0, 20) == 0:
		var mine: PackedInt32Array = PackedInt32Array()
		for id: int in _world.entities.ids():
			if _world.units.owner[id] == _local and _world.mobility.has(id):
				mine.append(id)
		if not mine.is_empty():
			_lockstep.submit(MoveCommand.new(mine, _rng.randi_range(100_000, 1_200_000), _rng.randi_range(100_000, 1_200_000)))
	for i: int in range(2):
		if _world.tick < TICKS:
			_lockstep.try_advance()
	if _world.tick >= TICKS:
		# keep pumping a little so the last hashes reach the peer
		for i: int in range(30):
			_transport.poll()
		var replay_ok: bool = ReplayPlayer.new(_lockstep.recorder.to_dict()).verify()
		print("NETTEST %s tick=%d checksum=%08x stalls=%d replay=%s" % [_role, _world.tick, Checksum.compute(_world), _lockstep.stalls, "ok" if replay_ok else "BAD"])
		quit(0 if replay_ok else 5)
		return true
	return false
