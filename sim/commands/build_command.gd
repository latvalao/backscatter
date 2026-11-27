# SIM: deterministic — no floats, no Nodes
## Place a construction site (cost paid now) and send builders to it.
## Engineers build structures with built_at "engineer"; infantry with "dig_in"
## build those with built_at "infantry" (trenches).
class_name BuildCommand
extends UnitCommand

var structure: String
var cell_x: int
var cell_y: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_structure: String = "", p_cx: int = 0, p_cy: int = 0) -> void:
	unit_ids = p_ids
	structure = p_structure
	cell_x = p_cx
	cell_y = p_cy


func builders(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var idx: int = world.defs.unit_index(structure)
	if idx < 0:
		return out
	var sd: UnitStats = world.defs.units[idx]
	for id: int in owned(world):
		var d: UnitStats = world.def_of(id)
		if sd.built_at == "engineer" and d.has_ability("build"):
			out.append(id)
		elif sd.built_at == "infantry" and (d.has_ability("dig_in") or d.has_ability("build")):
			out.append(id)
	return out


func validate(world: SimWorld) -> bool:
	var idx: int = world.defs.unit_index(structure)
	if idx < 0 or builders(world).is_empty():
		return false
	var sd: UnitStats = world.defs.units[idx]
	if not sd.is_structure or (sd.built_at != "engineer" and sd.built_at != "infantry"):
		return false
	if not world.players.can_afford(player_id, sd.cost_supply, sd.cost_manpower):
		return false
	return ConstructionSystem.can_place(world, sd, cell_x, cell_y)


func apply(world: SimWorld) -> void:
	var sd: UnitStats = world.defs.unit(structure)
	world.players.spend(player_id, sd.cost_supply, sd.cost_manpower)
	var site: int = world.spawn_structure(sd, world.team_of_player(player_id), player_id, cell_x, cell_y, false)
	for id: int in builders(world):
		world.orders.queue.erase(id)
		Orders.start(world, id, OrderStore.BUILD, 0, world.transform.x[site], world.transform.y[site], site)


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_utf8_string(structure)
	buf.put_32(cell_x)
	buf.put_32(cell_y)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	structure = buf.get_utf8_string()
	cell_x = buf.get_32()
	cell_y = buf.get_32()


func type_id() -> StringName:
	return &"build"
