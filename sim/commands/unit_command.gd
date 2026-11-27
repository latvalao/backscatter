# SIM: deterministic — no floats, no Nodes
## Base for commands addressed to a set of the issuing player's units.
class_name UnitCommand
extends SimCommand

var unit_ids: PackedInt32Array = PackedInt32Array()


## The subset of unit_ids that are alive, mobile (not structures) and owned by
## the issuing player, ascending.
func owned(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in unit_ids:
		if world.is_unit(id) and world.mobility.has(id) and world.units.owner[id] == player_id and not out.has(id):
			out.append(id)
	out.sort()
	return out


func validate(world: SimWorld) -> bool:
	return not owned(world).is_empty()


func write_ids(buf: StreamPeerBuffer) -> void:
	buf.put_u16(unit_ids.size())
	for id: int in unit_ids:
		buf.put_32(id)


func read_ids(buf: StreamPeerBuffer) -> void:
	var n: int = buf.get_u16()
	unit_ids = PackedInt32Array()
	for i: int in range(n):
		unit_ids.append(buf.get_32())


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
