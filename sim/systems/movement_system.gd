# SIM: deterministic — no floats, no Nodes
## Tick phase 3: path service, order following (A* paths or shared flow fields),
## vehicle steering with turn rates, terrain speed, deterministic separation.
class_name MovementSystem
extends SimSystem

const PATHS_PER_TICK: int = 6
const WAYPOINT_RADIUS_MM: int = 6000
const FLOW_HANDOFF_MM: int = 40000
const PROGRESS_INTERVAL: int = 50
const PROGRESS_MIN_MM: int = 4000
const MAX_REPATHS: int = 6
const SEPARATION_GAP_MM: int = 1500
const MAX_RADIUS_MM: int = 5000
const CROWD_BLOCKED_TICKS: int = 20
const CROWD_ARRIVE_MM: int = 25000

var _near: PackedInt32Array = PackedInt32Array()
var _next_order: PackedInt64Array = PackedInt64Array()


func step(world: SimWorld, tick: int) -> void:
	world.spatial.rebuild(world)
	_serve_paths(world)
	for id: int in world.entities.ids():
		if world.mobility.has(id) and world.is_unit(id):
			_move_unit(world, id, tick)


func _serve_paths(world: SimWorld) -> void:
	var served: int = 0
	while served < PATHS_PER_TICK and not world.path_requests.is_empty():
		var id: int = world.path_requests[0]
		world.path_requests.remove_at(0)
		if not world.is_unit(id) or world.orders.waiting_path[id] == 0:
			continue
		world.orders.waiting_path[id] = 0
		var o: OrderStore = world.orders
		if o.kind[id] == OrderStore.NONE or o.kind[id] == OrderStore.FIRE_MISSION:
			continue
		var start: int = world.grid.cell_at(world.transform.x[id], world.transform.y[id])
		var goal: int = world.grid.cell_at(o.goal_x[id], o.goal_y[id])
		var safe: bool = (o.flags[id] & OrderStore.FLAG_SAFE) != 0
		o.set_path(id, world.pathfinder.find_path(world.mobility.mobility_class[id], start, goal, safe))
		served += 1


## Effective max speed in mm/tick from stats, terrain, damage, crew and suppression.
static func effective_max_speed(world: SimWorld, id: int, def: UnitStats) -> int:
	var u: UnitStore = world.units
	if def.is_vehicle():
		if def.has_crew(UnitStats.CREW_DRIVER) and (u.crew[id] & UnitStats.CREW_DRIVER) == 0:
			return 0
		if (u.damage[id] & UnitStore.DMG_TRACKS) != 0:
			return 0
	var spd: int = def.max_speed
	if (u.damage[id] & UnitStore.DMG_ENGINE) != 0:
		spd = spd * 300 / 1000
	if def.is_infantry and u.suppression[id] >= MoraleSystem.PIN_THRESHOLD:
		spd = spd / 4
	var cell: int = world.grid.cell_at(world.transform.x[id], world.transform.y[id])
	var terrain_speed: int = world.grid.speed(def.mobility_class, cell)
	if terrain_speed <= 0:
		terrain_speed = 250  # unstick a unit standing on impassable ground
	return spd * terrain_speed / 1000


func _move_unit(world: SimWorld, id: int, tick: int) -> void:
	var t: TransformStore = world.transform
	var m: MobilityStore = world.mobility
	var o: OrderStore = world.orders
	var def: UnitStats = world.def_of(id)
	var x: int = t.x[id]
	var y: int = t.y[id]
	var kind: int = o.kind[id]
	var has_dest: bool = false
	var tx: int = x
	var ty: int = y
	var final_leg: bool = false
	var reverse: bool = (o.flags[id] & OrderStore.FLAG_REVERSE) != 0
	var max_spd: int = effective_max_speed(world, id, def)

	if kind == OrderStore.MOVE or kind == OrderStore.ATTACK_MOVE or kind == OrderStore.RETREAT or kind == OrderStore.ATTACK:
		if kind == OrderStore.ATTACK:
			_update_attack_goal(world, id, def)
		var gx: int = o.goal_x[id]
		var gy: int = o.goal_y[id]
		var dist: int = FixedMath.length2(gx - x, gy - y)
		var engaged: bool = kind == OrderStore.ATTACK_MOVE and WeaponSystem.has_engaged_target(world, id)
		if kind == OrderStore.ATTACK and _attack_in_position(world, id, def):
			engaged = true
		if dist <= def.radius_mm + 1500:
			if kind != OrderStore.ATTACK:
				_complete_order(world, id)
		elif engaged:
			# standing to fight is not being stuck: restart the stall timer
			o.progress_tick[id] = tick
			o.progress_dist[id] = dist
		elif o.waiting_path[id] == 1:
			pass
		else:
			has_dest = true
			var cell: int = world.grid.cell_at(x, y)
			var fid: int = o.flow_id[id]
			if fid != 0:
				var ff: FlowField = world.flow_fields.get(fid, null)
				if ff == null or not ff.reachable(cell):
					world.release_flow(id)
					world.request_path(id)
					has_dest = false
				elif dist <= FLOW_HANDOFF_MM + FixedMath.length2(gx - world.grid.center_x(ff.goal), gy - world.grid.center_y(ff.goal)):
					# close enough to peel off toward this unit's own formation slot
					tx = gx
					ty = gy
					final_leg = true
				else:
					var n1: int = ff.next_cell(cell)
					if n1 < 0:
						tx = gx
						ty = gy
					else:
						var n2: int = ff.next_cell(n1)
						var tc: int = n2 if n2 >= 0 else n1
						tx = world.grid.center_x(tc)
						ty = world.grid.center_y(tc)
			elif o.has_path(id):
				var path: PackedInt32Array = o.get_path(id)
				var pi: int = o.path_pos[id]
				while pi < path.size() - 1:
					var c: int = path[pi]
					if FixedMath.length2(world.grid.center_x(c) - x, world.grid.center_y(c) - y) > WAYPOINT_RADIUS_MM:
						break
					pi += 1
				o.path_pos[id] = pi
				if pi >= path.size() - 1:
					tx = gx
					ty = gy
					final_leg = true
				else:
					tx = world.grid.center_x(path[pi])
					ty = world.grid.center_y(path[pi])
			else:
				tx = gx
				ty = gy
				final_leg = true
			_check_progress(world, id, dist, tick)
			# crowd arrival: blocked near the goal by other units
			if dist <= CROWD_ARRIVE_MM and m.blocked_ticks[id] >= CROWD_BLOCKED_TICKS and kind != OrderStore.ATTACK:
				_complete_order(world, id)
				has_dest = false

	var heading: int = t.heading[id]
	var target_speed: int = 0
	if has_dest and max_spd > 0:
		var desired: int = FixedMath.atan2_b(ty - y, tx - x)
		if reverse:
			desired = (desired + SimConst.ANGLE_HALF) & SimConst.ANGLE_MASK
		var err: int = FixedMath.angle_diff(heading, desired)
		var turn: int = clampi(err, -def.turn_rate, def.turn_rate)
		heading = (heading + turn) & SimConst.ANGLE_MASK
		var abs_err: int = absi(err - turn)
		target_speed = max_spd
		if abs_err > 10923:
			target_speed = max_spd / 6
		elif abs_err > 3641:
			target_speed = max_spd / 2
		if final_leg:
			# kinematic braking: v = sqrt(2 * decel * distance), decel = 2 * accel
			var d_left: int = FixedMath.length2(tx - x, ty - y)
			target_speed = mini(target_speed, maxi(def.accel, FixedMath.isqrt(4 * def.accel * d_left)))
		if reverse:
			target_speed = -(target_speed / 3)
	elif kind == OrderStore.NONE or kind == OrderStore.FIRE_MISSION or (kind != OrderStore.NONE and not has_dest):
		# idle vehicles turn their front armour toward the current target
		if def.is_vehicle() and max_spd > 0:
			var tgt: int = world.weapons.target[id * WeaponStore.MAX_WEAPONS]
			if tgt > 0 and world.is_unit(tgt):
				var want: int = FixedMath.atan2_b(t.y[tgt] - y, t.x[tgt] - x)
				var e2: int = FixedMath.angle_diff(heading, want)
				if absi(e2) > 1820:
					heading = (heading + clampi(e2, -def.turn_rate, def.turn_rate)) & SimConst.ANGLE_MASK

	var spd: int = m.speed[id]
	if spd < target_speed:
		spd = mini(target_speed, spd + def.accel)
	elif spd > target_speed:
		spd = maxi(target_speed, spd - def.accel * 2)
	var nx: int = x + (spd * FixedMath.cos_b(heading)) / FixedMath.ONE
	var ny: int = y + (spd * FixedMath.sin_b(heading)) / FixedMath.ONE

	# separation from neighbours (positional push, symmetric per pair)
	var push_x: int = 0
	var push_y: int = 0
	_near.clear()
	world.spatial.query(x, y, def.radius_mm + MAX_RADIUS_MM + SEPARATION_GAP_MM, _near)
	for other: int in _near:
		if other == id or not world.mobility.has(other):
			continue
		var od: UnitStats = world.def_of(other)
		var ddx: int = x - t.x[other]
		var ddy: int = y - t.y[other]
		var min_d: int = def.radius_mm + od.radius_mm + SEPARATION_GAP_MM
		if absi(ddx) >= min_d or absi(ddy) >= min_d:
			continue
		var d2: int = ddx * ddx + ddy * ddy
		if d2 >= min_d * min_d:
			continue
		var d: int = FixedMath.isqrt(d2)
		var overlap: int = min_d - d
		if d == 0:
			# exactly stacked: separate along an id-derived direction
			var ang: int = ((id - other) * 9973) & SimConst.ANGLE_MASK
			push_x += (overlap * FixedMath.cos_b(ang)) / FixedMath.ONE / 2
			push_y += (overlap * FixedMath.sin_b(ang)) / FixedMath.ONE / 2
		else:
			push_x += (ddx * overlap) / d / 2
			push_y += (ddy * overlap) / d / 2
	var push_cap: int = maxi(def.max_speed, 400)
	push_x = clampi(push_x, -push_cap, push_cap)
	push_y = clampi(push_y, -push_cap, push_cap)
	nx += push_x
	ny += push_y

	# terrain collision: slide along blocked axis
	var mob: int = def.mobility_class
	if not world.grid.passable_at(mob, nx, ny):
		if world.grid.passable_at(mob, nx, y):
			ny = y
		elif world.grid.passable_at(mob, x, ny):
			nx = x
		else:
			nx = x
			ny = y
			spd = 0
	nx = clampi(nx, 0, world.map_width_mm() - 1)
	ny = clampi(ny, 0, world.map_height_mm() - 1)

	var moved: int = absi(nx - x) + absi(ny - y)
	if has_dest and moved * 4 < maxi(def.max_speed, 40):
		m.blocked_ticks[id] += 1
	else:
		m.blocked_ticks[id] = 0
	t.x[id] = nx
	t.y[id] = ny
	t.z[id] = world.grid.ground_at(nx, ny)
	t.heading[id] = heading
	m.speed[id] = spd


func _check_progress(world: SimWorld, id: int, dist: int, tick: int) -> void:
	var o: OrderStore = world.orders
	if tick - o.progress_tick[id] < PROGRESS_INTERVAL:
		return
	# expect at least a third of top speed over the interval (slow walkers included)
	var need: int = mini(PROGRESS_MIN_MM, world.def_of(id).max_speed * PROGRESS_INTERVAL / 3)
	if o.progress_tick[id] > 0 and o.progress_dist[id] - dist < need:
		o.repaths[id] += 1
		if o.repaths[id] > MAX_REPATHS:
			_complete_order(world, id)
			return
		# flow-field users stalled in a crowd keep their field; only A* users repath
		if o.flow_id[id] == 0:
			world.request_path(id)
	elif o.progress_dist[id] - dist >= need:
		o.repaths[id] = 0
	o.progress_tick[id] = tick
	o.progress_dist[id] = dist


## ATTACK order: chase the target's last known position.
func _update_attack_goal(world: SimWorld, id: int, def: UnitStats) -> void:
	var o: OrderStore = world.orders
	var tgt: int = o.target[id]
	var team: int = world.units.team[id]
	if not world.is_unit(tgt) or not world.vision[team].is_known(tgt):
		_complete_order(world, id)
		return
	var lx: int = world.vision[team].last_x[tgt]
	var ly: int = world.vision[team].last_y[tgt]
	if FixedMath.length2(lx - o.goal_x[id], ly - o.goal_y[id]) > 30000:
		o.goal_x[id] = lx
		o.goal_y[id] = ly
		world.release_flow(id)
		world.request_path(id)


func _attack_in_position(world: SimWorld, id: int, def: UnitStats) -> bool:
	var tgt: int = world.orders.target[id]
	if not world.is_unit(tgt):
		return false
	for s: int in range(def.weapons.size()):
		if world.weapons.target[id * WeaponStore.MAX_WEAPONS + s] == tgt:
			return true
	return false


## Finish the current order; start the next queued one if any.
func _complete_order(world: SimWorld, id: int) -> void:
	world.release_flow(id)
	world.orders.clear_current(id)
	world.mobility.blocked_ticks[id] = 0
	if world.orders.dequeue(id, _next_order):
		Orders.start(world, id, _next_order[0], _next_order[1], _next_order[2], _next_order[3], 0)
