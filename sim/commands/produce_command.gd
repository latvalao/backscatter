# SIM: deterministic — no floats, no Nodes
## Queue units at a production building (barracks / motor pool / artillery park).
## Cost is paid when queued, per unit.
class_name ProduceCommand
extends SimCommand

var building: int
var unit_def: String
var count: int


func _init(p_building: int = 0, p_def: String = "", p_count: int = 1) -> void:
	building = p_building
	unit_def = p_def
	count = p_count


func validate(world: SimWorld) -> bool:
	if count <= 0 or not world.is_unit(building) or not world.structures.is_complete(building):
		return false
	if world.units.owner[building] != player_id:
		return false
	var idx: int = world.defs.unit_index(unit_def)
	if idx < 0:
		return false
	var ud: UnitStats = world.defs.units[idx]
	if ud.is_structure or ud.built_at != world.def_of(building).role or ud.faction != world.players.faction[player_id]:
		return false
	if not world.defs.allowed(ud.id, ud.faction, world.players.battlegroup[player_id]):
		return false
	if world.structures.get_queue(building).size() >= world.defs.rule("production_queue_max"):
		return false
	return world.players.can_afford(player_id, ud.cost_supply, ud.cost_manpower)


func apply(world: SimWorld) -> void:
	var ud: UnitStats = world.defs.unit(unit_def)
	var q: PackedInt32Array = world.structures.get_queue(building)
	var cap: int = world.defs.rule("production_queue_max")
	for i: int in range(count):
		if q.size() >= cap or not world.players.can_afford(player_id, ud.cost_supply, ud.cost_manpower):
			break
		world.players.spend(player_id, ud.cost_supply, ud.cost_manpower)
		q.append(ud.index)
	world.structures.set_queue(building, q)


func write(buf: StreamPeerBuffer) -> void:
	buf.put_32(building)
	buf.put_utf8_string(unit_def)
	buf.put_u8(count)


func read(buf: StreamPeerBuffer) -> void:
	building = buf.get_32()
	unit_def = buf.get_utf8_string()
	count = buf.get_u8()


func type_id() -> StringName:
	return &"produce"
