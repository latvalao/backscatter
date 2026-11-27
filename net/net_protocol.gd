## Wire format shared by lockstep, lobby and replays. First byte = message type.
class_name NetProtocol
extends RefCounted

# game messages (< 10): host relays these to every other client
const TURN: int = 1        # [type][player u8][tick u64][command batch]
const HASH: int = 2        # [type][player u8][tick u64][checksum u32]
const CONTROL: int = 3     # [type][player u8][speed u8]  (host: 0 = paused)
# lobby messages (>= 10): point-to-point between host and a client
const HELLO: int = 10      # client -> host: [type][name utf8]
const WELCOME: int = 11    # host -> client: [type][player u8][roster var]
const ROSTER: int = 12     # host -> all: [type][roster var]
const START: int = 13      # host -> all: [type][settings var]
const BYE: int = 14        # either way


static func is_game(data: PackedByteArray) -> bool:
	return not data.is_empty() and data[0] < 10


static func turn(player: int, tick: int, cmds: Array[SimCommand]) -> PackedByteArray:
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.put_u8(TURN)
	b.put_u8(player)
	b.put_64(tick)
	b.put_data(CommandCodec.encode(cmds))
	return b.data_array


static func hash_msg(player: int, tick: int, checksum: int) -> PackedByteArray:
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.put_u8(HASH)
	b.put_u8(player)
	b.put_64(tick)
	b.put_u32(checksum)
	return b.data_array


static func control(player: int, speed: int) -> PackedByteArray:
	return PackedByteArray([CONTROL, player, speed])


static func with_var(type: int, value: Variant) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray([type])
	b.append_array(var_to_bytes(value))
	return b


static func read_var(data: PackedByteArray) -> Variant:
	return bytes_to_var(data.slice(1))
