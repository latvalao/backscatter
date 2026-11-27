# SIM: deterministic — no floats, no Nodes
## Co-op (FEATURES 6.3): hand units, or SUPPLY, to a teammate.
class_name GiveCommand
extends UnitCommand

var to_player: int
var supply: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_to: int = 0, p_supply: int = 0) -> void:
	unit_ids = p_ids
	to_player = p_to
	supply = p_supply


func validate(world: SimWorld) -> bool:
	if to_player < 0 or to_player >= world.players.count() or to_player == player_id:
		return false
	if world.players.team[to_player] != world.team_of_player(player_id):
		return false
	if supply < 0 or supply > world.players.supply[player_id]:
		return false
	return supply > 0 or not owned(world).is_empty()


func apply(world: SimWorld) -> void:
	world.players.supply[player_id] -= supply
	world.players.supply[to_player] += supply
	for id: int in owned(world):
		world.units.owner[id] = to_player
		world.units.link[id] = 0 if world.def_of(id).is_air and world.def_of(id).battery_ticks > 0 else world.units.link[id]


func type_id() -> StringName:
	return &"give"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_u8(to_player)
	buf.put_32(supply)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	to_player = buf.get_u8()
	supply = buf.get_32()
