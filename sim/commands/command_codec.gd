# SIM: deterministic — no floats, no Nodes
## Binary encoding of commands for lockstep packets and replays.
## Layout per command: type tag (utf8), player (u8), sequence (u32), tick (u64), payload.
class_name CommandCodec
extends RefCounted


## New, empty command instance for a type tag (null if unknown).
static func create(type: String) -> SimCommand:
	match type:
		"spawn_unit":
			return SpawnUnitCommand.new()
		"move":
			return MoveCommand.new()
		"stop":
			return StopCommand.new()
		"attack":
			return AttackCommand.new()
		"fire_mission":
			return FireMissionCommand.new()
		"smoke":
			return SmokeCommand.new()
		"stance":
			return StanceCommand.new()
		"build":
			return BuildCommand.new()
		"produce":
			return ProduceCommand.new()
		"cancel_production":
			return CancelProductionCommand.new()
		"rally":
			return RallyCommand.new()
		"emcon":
			return EmconCommand.new()
		"launch_drone":
			return LaunchDroneCommand.new()
	return null


static func write_command(buf: StreamPeerBuffer, cmd: SimCommand) -> void:
	buf.put_utf8_string(String(cmd.type_id()))
	buf.put_u8(cmd.player_id)
	buf.put_u32(cmd.sequence)
	buf.put_64(cmd.tick)
	cmd.write(buf)


static func read_command(buf: StreamPeerBuffer) -> SimCommand:
	var cmd: SimCommand = create(buf.get_utf8_string())
	if cmd == null:
		return null
	cmd.player_id = buf.get_u8()
	cmd.sequence = buf.get_u32()
	cmd.tick = buf.get_64()
	cmd.read(buf)
	return cmd


static func encode(cmds: Array[SimCommand]) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_u16(cmds.size())
	for c: SimCommand in cmds:
		write_command(buf, c)
	return buf.data_array


## Decodes a batch; returns an empty array (and sets ok=false via size mismatch) on garbage.
static func decode(bytes: PackedByteArray) -> Array[SimCommand]:
	var out: Array[SimCommand] = []
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	if bytes.size() < 2:
		return out
	var n: int = buf.get_u16()
	for i: int in range(n):
		var c: SimCommand = read_command(buf)
		if c == null:
			break
		out.append(c)
	return out
