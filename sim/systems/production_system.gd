# SIM: deterministic — no floats, no Nodes
## Tick phase 9b: production queues. Costs are paid when queued; the unit at the
## head of the queue is built over its build time, then spawns at the building's
## exit and moves to the rally point.
class_name ProductionSystem
extends SimSystem


func step(world: SimWorld, tick: int) -> void:
	var s: StructureStore = world.structures
	var ids: Array = s.queue.keys()
	ids.sort()
	for b: int in ids:
		if not world.is_unit(b) or not s.is_complete(b):
			continue
		var q: PackedInt32Array = s.get_queue(b)
		if q.is_empty():
			continue
		if s.prod_left[b] <= 0:
			s.prod_left[b] = maxi(1, world.defs.units[q[0]].build_time_ticks)
		s.prod_left[b] -= 1
		if s.prod_left[b] > 0:
			continue
		var def: UnitStats = world.defs.units[q[0]]
		q.remove_at(0)
		s.set_queue(b, q)
		_spawn(world, b, def)


func _spawn(world: SimWorld, b: int, def: UnitStats) -> void:
	var s: StructureStore = world.structures
	var bd: UnitStats = world.def_of(b)
	# exit: the cell just south of the footprint's middle
	var ex: int = s.cell_x[b] + bd.footprint_w / 2
	var ey: int = s.cell_y[b] - 1
	var cell: int = world.grid.nearest_passable(def.mobility_class, world.grid.index(clampi(ex, 0, world.grid.width - 1), clampi(ey, 0, world.grid.height - 1)), 12)
	if cell < 0:
		return
	var owner: int = world.units.owner[b]
	var id: int = world.spawn_unit(def, world.units.team[b], owner, world.grid.center_x(cell), world.grid.center_y(cell), SimConst.ANGLE_QUARTER * 3)
	if id > 0:
		world.emit(SimEvent.Type.PRODUCED, id, b, def.index)
		Orders.start(world, id, OrderStore.MOVE, 0, s.rally_x[b], s.rally_y[b], 0)
