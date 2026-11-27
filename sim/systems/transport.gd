# SIM: deterministic — no floats, no Nodes
## Infantry transport rules: capacity, boarding, unloading, bail-out when the
## carrier is destroyed. Carried units stay entities but are out of play.
class_name Transport
extends RefCounted

const BOARD_RANGE_MM: int = 14000
const UNLOAD_SPACING_MM: int = 7000
## Members lost (permille) when the carrier is destroyed with them aboard.
const BAILOUT_LOSS: int = 500


## Squads a vehicle can carry.
static func capacity(def: UnitStats) -> int:
	if def.passenger_capacity <= 0:
		return 0
	return maxi(1, def.passenger_capacity / 6)


static func passengers(world: SimWorld, carrier: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var u: UnitStore = world.units
	for id: int in world.entities.ids():
		if u.has(id) and u.carrier[id] == carrier and not world.is_dying(id):
			out.append(id)
	return out


static func is_carried(world: SimWorld, id: int) -> bool:
	return world.units.has(id) and world.units.carrier[id] != 0


static func free_slots(world: SimWorld, carrier: int) -> int:
	if not world.is_unit(carrier):
		return 0
	return capacity(world.def_of(carrier)) - passengers(world, carrier).size()


## Board now (caller checked range / ownership).
static func board(world: SimWorld, id: int, carrier: int) -> bool:
	if free_slots(world, carrier) <= 0 or is_carried(world, id):
		return false
	world.release_flow(id)
	world.orders.clear_current(id)
	world.orders.queue.erase(id)
	world.units.carrier[id] = carrier
	world.mobility.speed[id] = 0
	world.transform.x[id] = world.transform.x[carrier]
	world.transform.y[id] = world.transform.y[carrier]
	world.emit(SimEvent.Type.MOUNTED, id, carrier)
	return true


## Unload every passenger behind the carrier.
static func unload(world: SimWorld, carrier: int) -> void:
	var t: TransformStore = world.transform
	var back: int = (t.heading[carrier] + SimConst.ANGLE_HALF) & SimConst.ANGLE_MASK
	var k: int = 0
	for id: int in passengers(world, carrier):
		var side: int = (k - 1) * UNLOAD_SPACING_MM
		var bx: int = t.x[carrier] + (world.def_of(carrier).radius_mm + 5000) * FixedMath.cos_b(back) / FixedMath.ONE
		var by: int = t.y[carrier] + (world.def_of(carrier).radius_mm + 5000) * FixedMath.sin_b(back) / FixedMath.ONE
		var px: int = bx + side * FixedMath.cos_b(back + SimConst.ANGLE_QUARTER) / FixedMath.ONE
		var py: int = by + side * FixedMath.sin_b(back + SimConst.ANGLE_QUARTER) / FixedMath.ONE
		var cell: int = world.grid.nearest_passable(TerrainTable.FOOT, world.grid.cell_at(clampi(px, 0, world.map_width_mm() - 1), clampi(py, 0, world.map_height_mm() - 1)), 6)
		if cell >= 0:
			px = world.grid.center_x(cell)
			py = world.grid.center_y(cell)
		_drop(world, id, px, py)
		k += 1


static func _drop(world: SimWorld, id: int, x: int, y: int) -> void:
	world.units.carrier[id] = 0
	world.transform.x[id] = clampi(x, 0, world.map_width_mm() - 1)
	world.transform.y[id] = clampi(y, 0, world.map_height_mm() - 1)
	world.transform.z[id] = world.grid.ground_at(world.transform.x[id], world.transform.y[id])
	world.vision[world.units.team[id]].mark_seen(id, world.transform.x[id], world.transform.y[id], world.tick, 0x3FFFFFFF)
	world.emit(SimEvent.Type.DISMOUNTED, id)


## Carrier destroyed: passengers bail out and lose part of the squad.
static func bail_out(world: SimWorld, carrier: int) -> void:
	var pax: PackedInt32Array = passengers(world, carrier)
	if pax.is_empty():
		return
	unload(world, carrier)
	for id: int in pax:
		var lose: int = world.units.members_alive[id] * BAILOUT_LOSS / 1000
		for i: int in range(lose):
			Combat.kill_one_member(world, id)
		Combat.add_suppression(world, id, 600)
