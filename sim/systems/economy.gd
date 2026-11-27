# SIM: deterministic — no floats, no Nodes
## Unit conversions for data/rules/economy.json tunables, plus shared queries.
class_name Economy
extends RefCounted


## Rule given in metres -> mm.
static func mm(world: SimWorld, rule: String) -> int:
	return world.defs.rule(rule) * SimConst.MM_PER_M


## Rule given in seconds -> ticks.
static func ticks(world: SimWorld, rule: String) -> int:
	return world.defs.rule(rule) * SimConst.TICKS_PER_SECOND


## True for completed friendly HQs / supply depots (resupply sources, route ends).
static func is_logistics_node(world: SimWorld, id: int, team: int) -> bool:
	if not world.is_unit(id) or not world.structures.is_complete(id) or world.units.team[id] != team:
		return false
	var role: String = world.def_of(id).role
	return role == "hq" or role == "supply_depot"


## Completed structures of a team with the given role, ascending ids.
static func structures_of(world: SimWorld, team: int, role: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in world.team_units[team] if team >= 0 and team < SimWorld.MAX_TEAMS else PackedInt32Array():
		if world.structures.is_complete(id) and world.def_of(id).role == role:
			out.append(id)
	return out


## Distance from (x, y) to the nearest point of a structure's footprint (mm).
static func dist_to_structure(world: SimWorld, s: int, x: int, y: int) -> int:
	var d: UnitStats = world.def_of(s)
	var x0: int = world.structures.cell_x[s] * SimGrid.CELL_MM
	var y0: int = world.structures.cell_y[s] * SimGrid.CELL_MM
	var x1: int = x0 + d.footprint_w * SimGrid.CELL_MM
	var y1: int = y0 + d.footprint_h * SimGrid.CELL_MM
	var dx: int = maxi(0, maxi(x0 - x, x - x1))
	var dy: int = maxi(0, maxi(y0 - y, y - y1))
	return FixedMath.length2(dx, dy)
