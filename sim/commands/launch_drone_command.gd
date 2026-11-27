# SIM: deterministic — no floats, no Nodes
## A drone operator (recon) launches a UAV it then controls over a radio link.
## One drone per operator; the drone costs SUPPLY.
class_name LaunchDroneCommand
extends UnitCommand

var drone_def: String


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_def: String = "") -> void:
	unit_ids = p_ids
	drone_def = p_def


func _operator(world: SimWorld) -> int:
	for id: int in owned(world):
		if world.def_of(id).has_ability("drone_operator") and _drone_of(world, id) == 0:
			return id
	return 0


static func _drone_of(world: SimWorld, op: int) -> int:
	for id: int in world.team_units[world.units.team[op]] if world.units.team[op] < SimWorld.MAX_TEAMS else PackedInt32Array():
		if world.units.link[id] == op and world.is_unit(id):
			return id
	return 0


func validate(world: SimWorld) -> bool:
	var idx: int = world.defs.unit_index(drone_def)
	if idx < 0:
		return false
	var d: UnitStats = world.defs.units[idx]
	if not d.is_air or d.faction != world.players.faction[player_id]:
		return false
	world.rebuild_team_rosters()
	return _operator(world) > 0 and world.players.can_afford(player_id, d.cost_supply, d.cost_manpower)


func apply(world: SimWorld) -> void:
	var d: UnitStats = world.defs.unit(drone_def)
	var op: int = _operator(world)
	world.players.spend(player_id, d.cost_supply, d.cost_manpower)
	var t: TransformStore = world.transform
	var id: int = world.spawn_unit(d, world.units.team[op], player_id, t.x[op], t.y[op], t.heading[op])
	world.units.link[id] = op
	world.rebuild_team_rosters()


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_utf8_string(drone_def)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	drone_def = buf.get_utf8_string()


func type_id() -> StringName:
	return &"launch_drone"
