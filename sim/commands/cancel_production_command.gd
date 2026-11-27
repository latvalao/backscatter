# SIM: deterministic — no floats, no Nodes
## Removes the last queued unit at a building and refunds it.
class_name CancelProductionCommand
extends SimCommand

var building: int


func _init(p_building: int = 0) -> void:
	building = p_building


func validate(world: SimWorld) -> bool:
	return world.is_unit(building) and world.units.owner[building] == player_id \
		and not world.structures.get_queue(building).is_empty()


func apply(world: SimWorld) -> void:
	var q: PackedInt32Array = world.structures.get_queue(building)
	var ud: UnitStats = world.defs.units[q[q.size() - 1]]
	q.remove_at(q.size() - 1)
	if q.is_empty():
		world.structures.prod_left[building] = 0
	world.structures.set_queue(building, q)
	world.players.refund(player_id, ud.cost_supply, ud.cost_manpower)


func write(buf: StreamPeerBuffer) -> void:
	buf.put_32(building)


func read(buf: StreamPeerBuffer) -> void:
	building = buf.get_32()


func type_id() -> StringName:
	return &"cancel_production"
