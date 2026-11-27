# SIM: deterministic — no floats, no Nodes
## Tick phase 9c: depot objectives (§5.1). Capture by presence; income goes to the
## holder if a road route links the depot to a friendly HQ/supply depot without
## passing near enemy units, otherwise it piles up as stock for supply trucks.
class_name ObjectiveSystem
extends SimSystem

const CAPTURE_INTERVAL: int = 10
const INCOME_INTERVAL: int = 100

var _cut: PackedInt32Array = PackedInt32Array()
var _seen: PackedInt32Array = PackedInt32Array()
var _stamp: int = 0


func step(world: SimWorld, tick: int) -> void:
	if tick % CAPTURE_INTERVAL == 0:
		for d: int in _depots(world):
			_capture(world, d)
	if tick % INCOME_INTERVAL == 0:
		for d: int in _depots(world):
			_income(world, d)


static func _depots(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in world.team_units[SimWorld.NEUTRAL_TEAM]:
		if world.def_of(id).role == "depot_objective":
			out.append(id)
	return out


func _capture(world: SimWorld, d: int) -> void:
	var s: StructureStore = world.structures
	var r: int = Economy.mm(world, "capture_radius_m")
	var need: int = Economy.ticks(world, "capture_s")
	var present: PackedInt32Array = PackedInt32Array()
	present.resize(SimWorld.MAX_TEAMS)
	var first_player: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		for id: int in world.team_units[team]:
			if world.is_structure(id) or not can_capture(world, id):
				continue
			if Economy.dist_to_structure(world, d, world.transform.x[id], world.transform.y[id]) <= r:
				present[team] += 1
				if first_player[team] < 0:
					first_player[team] = world.units.owner[id]
	var teams_here: PackedInt32Array = PackedInt32Array()
	for team: int in range(SimWorld.MAX_TEAMS):
		if present[team] > 0:
			teams_here.append(team)
	if teams_here.size() != 1:
		return  # empty or contested: nothing changes
	var t: int = teams_here[0]
	if s.holder_team[d] == t:
		s.capture_team[d] = -1
		s.capture_progress[d] = 0
		return
	if s.capture_team[d] != t:
		s.capture_team[d] = t
		s.capture_progress[d] = 0
	s.capture_progress[d] += CAPTURE_INTERVAL
	if s.capture_progress[d] >= need:
		s.holder_team[d] = t
		s.holder_player[d] = first_player[t]
		s.capture_team[d] = -1
		s.capture_progress[d] = 0
		world.emit(SimEvent.Type.CAPTURED, d, first_player[t], t)


## Units that can take objectives (severe radiation sickness blocks this in M5).
static func can_capture(world: SimWorld, id: int) -> bool:
	var role: String = world.def_of(id).role
	return role != "logistics"


func _income(world: SimWorld, d: int) -> void:
	var s: StructureStore = world.structures
	var team: int = s.holder_team[d]
	if team < 0:
		s.connected[d] = 0
		return
	var amount: int = world.defs.rule("depot_income_per_min") * INCOME_INTERVAL / 600
	var ok: bool = route_connected(world, d, team)
	s.connected[d] = 1 if ok else 0
	var p: int = s.holder_player[d]
	if ok and p >= 0 and world.players.defeated[p] == 0:
		world.players.supply[p] += amount
	else:
		s.stock[d] = mini(world.defs.rule("depot_stock_cap"), s.stock[d] + amount)


## BFS over road cells from near the depot to near a friendly logistics node,
## avoiding road cells within route_enemy_radius of enemy units.
func route_connected(world: SimWorld, d: int, team: int) -> bool:
	var g: SimGrid = world.grid
	var n: int = g.cell_count()
	if _cut.size() != n:
		_cut.resize(n)
		_seen.resize(n)
	_stamp += 1
	var stamp: int = _stamp
	var link: int = Economy.mm(world, "logistics_link_radius_m")
	var enemy_r: int = Economy.mm(world, "route_enemy_radius_m") / SimGrid.CELL_MM
	# mark cut cells around enemy units
	for other: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, other):
			continue
		for id: int in world.team_units[other]:
			if world.is_structure(id):
				continue
			var c: int = g.cell_at(world.transform.x[id], world.transform.y[id])
			var cx: int = g.cell_x(c)
			var cy: int = g.cell_y(c)
			for y: int in range(maxi(0, cy - enemy_r), mini(g.height, cy + enemy_r + 1)):
				for x: int in range(maxi(0, cx - enemy_r), mini(g.width, cx + enemy_r + 1)):
					if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= enemy_r * enemy_r:
						_cut[y * g.width + x] = stamp
	# targets: friendly logistics nodes
	var nodes: PackedInt32Array = PackedInt32Array()
	for id: int in world.team_units[team]:
		if Economy.is_logistics_node(world, id, team):
			nodes.append(id)
	if nodes.is_empty():
		return false
	# seed: road cells within link radius of the depot
	var frontier: PackedInt32Array = _road_cells_near(world, d, link, stamp)
	var head: int = 0
	while head < frontier.size():
		var c: int = frontier[head]
		head += 1
		var x: int = g.cell_x(c)
		var y: int = g.cell_y(c)
		for node: int in nodes:
			if Economy.dist_to_structure(world, node, g.center_x(c), g.center_y(c)) <= link:
				return true
		for k: int in range(8):
			var nx: int = x + PathFinder.DX[k]
			var ny: int = y + PathFinder.DY[k]
			if not g.in_grid(nx, ny):
				continue
			var nb: int = ny * g.width + nx
			if _seen[nb] == stamp or _cut[nb] == stamp or g.terrain[nb] != TerrainTable.ROAD:
				continue
			_seen[nb] = stamp
			frontier.append(nb)
	return false


func _road_cells_near(world: SimWorld, d: int, r: int, stamp: int) -> PackedInt32Array:
	var g: SimGrid = world.grid
	var out: PackedInt32Array = PackedInt32Array()
	var rc: int = r / SimGrid.CELL_MM + 2
	var c0: int = g.cell_at(world.transform.x[d], world.transform.y[d])
	var cx: int = g.cell_x(c0)
	var cy: int = g.cell_y(c0)
	for y: int in range(maxi(0, cy - rc), mini(g.height, cy + rc + 1)):
		for x: int in range(maxi(0, cx - rc), mini(g.width, cx + rc + 1)):
			var c: int = y * g.width + x
			if g.terrain[c] != TerrainTable.ROAD or _cut[c] == stamp:
				continue
			if Economy.dist_to_structure(world, d, g.center_x(c), g.center_y(c)) <= r:
				_seen[c] = stamp
				out.append(c)
	return out
