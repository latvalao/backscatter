# SIM: deterministic — no floats, no Nodes
## Helpers that start orders, shared by commands and systems.
class_name Orders
extends RefCounted

## Group moves with at least this many units of one mobility class share a flow field.
const FLOW_MIN_UNITS: int = 6
const FLOW_MARGIN_CELLS: int = 40


## Starts a single-unit order (path is requested; flow fields are set up by start_group).
static func start(world: SimWorld, id: int, kind: int, flags: int, x: int, y: int, target: int) -> void:
	var o: OrderStore = world.orders
	world.release_flow(id)
	o.clear_current(id)
	o.kind[id] = kind
	o.flags[id] = flags
	o.goal_x[id] = clampi(x, 0, world.map_width_mm() - 1)
	o.goal_y[id] = clampi(y, 0, world.map_height_mm() - 1)
	o.target[id] = target
	o.progress_tick[id] = world.tick
	o.progress_dist[id] = FixedMath.length2(o.goal_x[id] - world.transform.x[id], o.goal_y[id] - world.transform.y[id])
	world.mobility.blocked_ticks[id] = 0
	if (kind == OrderStore.MOVE or kind == OrderStore.ATTACK_MOVE or kind == OrderStore.RETREAT \
			or kind == OrderStore.ATTACK or kind == OrderStore.BUILD or kind == OrderStore.MOUNT) and not world.def_of(id).is_air:
		world.request_path(id)


## Group move: assigns formation slots around (x, y), then either shares a flow
## field per mobility class or requests individual paths.
static func start_group(world: SimWorld, ids: PackedInt32Array, kind: int, flags: int, x: int, y: int, queue: bool,
		formation: int = Formation.BLOCK, face: int = -1) -> void:
	if ids.is_empty():
		return
	var slots: PackedInt64Array = Formation.slots(world, ids, x, y, formation, face)
	# final facing and, for an explicit formation, the slowest member's pace
	var cap: int = 0
	if formation != Formation.BLOCK and ids.size() > 1:
		cap = 1 << 30
		for id: int in ids:
			cap = mini(cap, world.def_of(id).max_speed)
	for id2: int in ids:
		world.mobility.face[id2] = face
		world.mobility.speed_cap[id2] = cap
	if queue:
		for k: int in range(ids.size()):
			var id: int = ids[k]
			if world.orders.kind[id] == OrderStore.NONE and world.orders.queue_len(id) == 0:
				start(world, ids[k], kind, flags, slots[2 * k], slots[2 * k + 1], 0)
			else:
				world.orders.enqueue(id, kind, flags, slots[2 * k], slots[2 * k + 1])
		return
	for k: int in range(ids.size()):
		world.orders.queue.erase(ids[k])
		start(world, ids[k], kind, flags, slots[2 * k], slots[2 * k + 1], 0)
	if (flags & OrderStore.FLAG_SAFE) != 0:
		return  # safe routing uses per-unit cost-aware A*
	for mob: int in range(TerrainTable.MOBILITY_COUNT):
		var members: PackedInt32Array = PackedInt32Array()
		var x0: int = world.grid.width
		var y0: int = world.grid.height
		var x1: int = 0
		var y1: int = 0
		for id: int in ids:
			if world.mobility.mobility_class[id] != mob:
				continue
			members.append(id)
			var c: int = world.grid.cell_at(world.transform.x[id], world.transform.y[id])
			x0 = mini(x0, world.grid.cell_x(c))
			y0 = mini(y0, world.grid.cell_y(c))
			x1 = maxi(x1, world.grid.cell_x(c))
			y1 = maxi(y1, world.grid.cell_y(c))
		if members.size() < FLOW_MIN_UNITS:
			continue
		var goal: int = world.grid.nearest_passable(mob, world.grid.cell_at(x, y), 24)
		if goal < 0:
			continue
		x0 = mini(x0, world.grid.cell_x(goal)) - FLOW_MARGIN_CELLS
		y0 = mini(y0, world.grid.cell_y(goal)) - FLOW_MARGIN_CELLS
		x1 = maxi(x1, world.grid.cell_x(goal)) + FLOW_MARGIN_CELLS
		y1 = maxi(y1, world.grid.cell_y(goal)) + FLOW_MARGIN_CELLS
		var ff: FlowField = FlowField.new()
		ff.id = world.next_flow_id
		world.next_flow_id += 1
		ff.build(world.grid, mob, goal, x0, y0, x1, y1)
		for id: int in members:
			var c2: int = world.grid.cell_at(world.transform.x[id], world.transform.y[id])
			if ff.reachable(c2):
				world.orders.flow_id[id] = ff.id
				world.orders.waiting_path[id] = 0
				ff.users += 1
		if ff.users > 0:
			world.flow_fields[ff.id] = ff


## Ends the current order without moving on through the movement system.
static func finish(world: SimWorld, id: int) -> void:
	world.release_flow(id)
	world.orders.clear_current(id)
	var next: PackedInt64Array = PackedInt64Array()
	if world.orders.dequeue(id, next):
		start(world, id, next[0], next[1], next[2], next[3], 0)
