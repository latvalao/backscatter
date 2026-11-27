## Deterministic lockstep (§7.4). Local commands are scheduled for
## current_tick + input_delay and sent to every peer as a "turn" (possibly
## empty). Tick t only runs once turns for t from every player have arrived.
## Checksums are exchanged every CHECKSUM_INTERVAL ticks to detect desyncs.
class_name Lockstep
extends RefCounted

signal desync(tick: int, details: String)
signal control_received(speed: int)

var world: SimWorld
var transport: NetTransport
var local_player: int = 0
## Human players taking part (AI players act inside the sim and send nothing).
var players: PackedInt32Array = PackedInt32Array()
var input_delay: int = 3
var recorder: ReplayRecorder
var desynced: bool = false
## Wall-clock-free stat: how many try_advance() calls found a turn missing.
var stalls: int = 0

## First tick this session simulates (non-zero after loading a save).
var _start_tick: int = 0
var _turns: Dictionary = {}           # tick -> {player: Array[SimCommand]}
var _pending: Array[SimCommand] = []  # local, not yet sent
var _next_send: int = 0
var _sequence: int = 0
var _local_hashes: Dictionary = {}    # tick -> checksum
var _remote_hashes: Dictionary = {}   # tick -> {player: checksum}


func _init(p_world: SimWorld, p_transport: NetTransport, p_local: int, p_players: PackedInt32Array, p_delay: int = 3) -> void:
	world = p_world
	transport = p_transport
	local_player = p_local
	players = p_players.duplicate()
	players.sort()
	input_delay = maxi(1, p_delay)
	_next_send = world.tick + input_delay
	_start_tick = world.tick


## Queue a local command; it is stamped and sent with the next outgoing turn.
func submit(cmd: SimCommand) -> void:
	cmd.player_id = local_player
	cmd.sequence = _sequence
	_sequence += 1
	_pending.append(cmd)


## Processes incoming network traffic. Call every frame.
func receive() -> void:
	for e: Dictionary in transport.poll():
		if e["kind"] != "data":
			continue
		handle(e["data"])


## Feed one message (also used by sessions that demultiplex lobby traffic).
func handle(data: PackedByteArray) -> void:
	if data.is_empty():
		return
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.data_array = data
	var type: int = b.get_u8()
	match type:
		NetProtocol.TURN:
			var p: int = b.get_u8()
			var t: int = b.get_64()
			var cmds: Array[SimCommand] = CommandCodec.decode(data.slice(10))
			_store_turn(t, p, cmds)
		NetProtocol.HASH:
			var p2: int = b.get_u8()
			var t2: int = b.get_64()
			var sum: int = b.get_u32()
			if not _remote_hashes.has(t2):
				_remote_hashes[t2] = {}
			var d: Dictionary = _remote_hashes[t2]
			d[p2] = sum
			_compare(t2)
		NetProtocol.CONTROL:
			control_received.emit(data[2])


func send_control(speed: int) -> void:
	transport.send(NetTransport.BROADCAST, NetProtocol.control(local_player, speed))


func _store_turn(t: int, p: int, cmds: Array[SimCommand]) -> void:
	if t < world.tick:
		return
	if not _turns.has(t):
		_turns[t] = {}
	var d: Dictionary = _turns[t]
	d[p] = cmds


## True if every player's turn for the current tick is here.
func ready() -> bool:
	var t: int = world.tick
	if t < _start_tick + input_delay:
		return true
	if not _turns.has(t):
		return players.is_empty()
	var d: Dictionary = _turns[t]
	for p: int in players:
		if not d.has(p):
			return false
	return true


## Sends our turn(s) and, if all inputs for the current tick are present,
## applies them and steps the world. Returns true if a tick was simulated.
func try_advance() -> bool:
	if desynced:
		return false
	_send_turns()
	if not ready():
		stalls += 1
		return false
	var t: int = world.tick
	var applied: Array[SimCommand] = []
	if _turns.has(t):
		var d: Dictionary = _turns[t]
		for p: int in players:
			if d.has(p):
				var cmds: Array[SimCommand] = d[p]
				for c: SimCommand in cmds:
					c.tick = t
					c.player_id = p
					world.queue_command(c)
					applied.append(c)
		_turns.erase(t)
	if recorder != null:
		recorder.record_tick(t, applied)
	world.step()
	if world.last_checksum_tick == t:
		_local_hashes[t] = world.last_checksum
		if recorder != null:
			recorder.record_checksum(t, world.last_checksum)
		if players.size() > 1:
			transport.send(NetTransport.BROADCAST, NetProtocol.hash_msg(local_player, t, world.last_checksum))
		_compare(t)
	return true


func _send_turns() -> void:
	while _next_send <= world.tick + input_delay:
		var cmds: Array[SimCommand] = _pending
		_pending = []
		for c: SimCommand in cmds:
			c.tick = _next_send
		_store_turn(_next_send, local_player, cmds)
		if players.size() > 1:
			transport.send(NetTransport.BROADCAST, NetProtocol.turn(local_player, _next_send, cmds))
		_next_send += 1


func _compare(t: int) -> void:
	if not _local_hashes.has(t) or not _remote_hashes.has(t):
		return
	var mine: int = _local_hashes[t]
	var d: Dictionary = _remote_hashes[t]
	for p: int in d.keys():
		if int(d[p]) != mine and not desynced:
			desynced = true
			var path: String = DesyncDump.write(world, t, mine, p, int(d[p]))
			desync.emit(t, "checksum mismatch at tick %d with player %d (dump: %s)" % [t, p, path])
	# prune old hashes once every player has reported
	if d.size() >= players.size() - 1:
		_remote_hashes.erase(t)
		_local_hashes.erase(t)
