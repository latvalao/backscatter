# SIM: deterministic — no floats, no Nodes
## Root of all simulation state. Pure data + a fixed system order.
##
## Tick order (design doc §7.5):
##   1. Apply commands (sorted by player id, then sequence)
##   2. AI planning                      -> AiSystem (scripted opponents until M7)
##   3. Orders -> movement               -> MovementSystem
##   4. Vision & spotting                -> VisionSystem
##   5. Signature / DF / jamming         -> SignalSystem (also drones' links)
##   6. Weapons + projectiles            -> WeaponSystem, ProjectileSystem
##   7. Damage, suppression, morale      -> MoraleSystem (damage applied inline via Combat)
##   8. Radiation                        -> RadiationSystem
##   9. Logistics / production           -> ConstructionSystem, ProductionSystem,
##                                          ObjectiveSystem, LogisticsSystem
##  10. Veterancy, cleanup, events       -> VictorySystem, _cleanup()
##  11. Checksum every CHECKSUM_INTERVAL ticks
class_name SimWorld
extends RefCounted

const MAX_TEAMS: int = 4
## Map objectives (depots) belong to this team: never targeted, visible to all.
const NEUTRAL_TEAM: int = 3

var tick: int = 0
var match_seed: int = 0
var rng: SimRng
var defs: DefDb
var grid: SimGrid
var pathfinder: PathFinder
var spatial: SpatialHash
var entities: EntityStore = EntityStore.new()
var commands: CommandQueue = CommandQueue.new()

var transform: TransformStore = TransformStore.new()
var units: UnitStore = UnitStore.new()
var mobility: MobilityStore = MobilityStore.new()
var orders: OrderStore = OrderStore.new()
var weapons: WeaponStore = WeaponStore.new()
var squads: SquadStore = SquadStore.new()
var structures: StructureStore = StructureStore.new()
var logistics: LogisticsStore = LogisticsStore.new()
var players: PlayerStore = PlayerStore.new()
var radiation: RadiationStore = RadiationStore.new()
var radfield: RadiationField
## Kaarnavaara plant position (mm) for scenario/presentation; -1 if none.
var plant_x: int = -1
var plant_y: int = -1
var weather: Weather
## Structure id occupying each grid cell (0 = none). Derived from structures.
var occupancy: PackedInt32Array = PackedInt32Array()
## Sim-side AI controllers, stepped in phase 2 in list order.
var ai: Array[AiController] = []
## Skirmish rule: a team with no HQ is defeated.
var hq_required: bool = false
## Winning team once decided (-1 = ongoing).
var winner_team: int = -1
var vision: Array[TeamVision] = []
var projectiles: ProjectileStore = ProjectileStore.new()
var smoke: SmokeStore = SmokeStore.new()

var is_night: bool = false

## Flow fields shared by group move orders; id -> FlowField (lookup only).
var flow_fields: Dictionary = {}
var next_flow_id: int = 1
## Per-tick derived caches (rebuilt deterministically from state each tick; not
## hashed): live unit ids per team, enemies visible to each team, and LOS results
## found by the vision pass (key = observer << 20 | target -> tick checked).
var team_units: Array[PackedInt32Array] = []
var visible_enemies: Array[PackedInt32Array] = []
var los_cache: Dictionary = {}
## Per-entity flags rebuilt by SignalSystem (phase 5) each tick: 1 = inside an
## enemy jammer's radius; 1 = on its team's radio net.
var jammed: PackedByteArray = PackedByteArray()
var on_net: PackedByteArray = PackedByteArray()
## Signals intelligence per team: DF bearings and fixes (§5.5).
var signals: Array[SignalIntel] = []
## Spotting reports from units off the radio net, delivered late:
## [deliver_tick, team, target, x, y]
var pending_spots: Array[PackedInt64Array] = []
## FIFO of entity ids waiting for a path.
var path_requests: PackedInt32Array = PackedInt32Array()

## Events produced since the last drain_events(); presentation drains them each frame.
var events: Array[SimEvent] = []
var last_checksum: int = 0
var last_checksum_tick: int = -1

var _systems: Array[SimSystem] = []
var _pending_destroy: PackedInt32Array = PackedInt32Array()
var _dying: PackedByteArray = PackedByteArray()


func _init(p_seed: int, p_defs: DefDb, p_grid: SimGrid) -> void:
	match_seed = p_seed
	rng = SimRng.new(p_seed)
	defs = p_defs
	grid = p_grid.clone()
	occupancy.resize(grid.cell_count())
	radfield = RadiationField.new(grid.width_mm(), grid.height_mm())
	weather = Weather.new(p_seed)
	pathfinder = PathFinder.new(grid)
	pathfinder.radiation = radfield
	spatial = SpatialHash.new(grid.width_mm(), grid.height_mm())
	for t: int in range(MAX_TEAMS):
		vision.append(TeamVision.new())
		team_units.append(PackedInt32Array())
		visible_enemies.append(PackedInt32Array())
		signals.append(SignalIntel.new())
	_systems.append(AiSystem.new())          # 2
	_systems.append(MovementSystem.new())    # 3
	_systems.append(VisionSystem.new())      # 4
	_systems.append(SignalSystem.new())      # 5
	_systems.append(WeaponSystem.new())      # 6
	_systems.append(ProjectileSystem.new())  # 6
	_systems.append(MoraleSystem.new())      # 7
	_systems.append(RadiationSystem.new())   # 8
	_systems.append(ConstructionSystem.new())  # 9
	_systems.append(ProductionSystem.new())    # 9
	_systems.append(ObjectiveSystem.new())     # 9
	_systems.append(LogisticsSystem.new())     # 9
	_systems.append(VictorySystem.new())       # 10


## Fixed component store order — part of the checksum definition.
func component_stores() -> Array[ComponentStore]:
	var out: Array[ComponentStore] = [transform, units, mobility, orders, weapons, squads, structures, logistics, radiation]
	return out


## Adds a player. Faction defaults by team (0 = Coalition, else Eastern).
func add_player(team: int, faction: String = "", is_ai: bool = false) -> int:
	if faction == "":
		faction = "nc" if team == 0 else "ec"
	var sup: int = defs.rules.get("start_supply", 0)
	var mp: int = defs.rules.get("start_manpower", 0)
	return players.add(team, faction, sup, mp, is_ai)


func team_of_player(player: int) -> int:
	if player < 0 or player >= players.count():
		return -1
	return players.team[player]


func map_width_mm() -> int:
	return grid.width_mm()


func map_height_mm() -> int:
	return grid.height_mm()


func in_bounds(x_mm: int, y_mm: int) -> bool:
	return x_mm >= 0 and y_mm >= 0 and x_mm < grid.width_mm() and y_mm < grid.height_mm()


func def_of(id: int) -> UnitStats:
	return defs.units[units.def_index[id]]


func is_unit(id: int) -> bool:
	return entities.is_alive(id) and units.has(id) and not is_dying(id)


func is_structure(id: int) -> bool:
	return structures.has(id)


## Teams that are opponents of `team` (excludes itself and the neutral team).
func is_enemy_team(team: int, other: int) -> bool:
	return other != team and other != NEUTRAL_TEAM and team != NEUTRAL_TEAM


## Cover permille from a fortification at (x, y): trenches for infantry,
## vehicle pits for vehicles. 0 if none / still under construction.
func fortification_cover(x_mm: int, y_mm: int, infantry: bool) -> int:
	var s: int = occupancy[grid.cell_at(x_mm, y_mm)]
	if s == 0 or not structures.is_complete(s):
		return 0
	var d: UnitStats = def_of(s)
	if infantry and d.role == "trench":
		return d.cover
	if not infantry and d.role == "vehicle_pit":
		return d.cover
	return 0


func is_air(id: int) -> bool:
	return units.has(id) and def_of(id).is_air


## On the radio net: has a radio, not SILENT, not jammed (filled by SignalSystem).
func is_on_net(id: int) -> bool:
	return id < on_net.size() and on_net[id] == 1


func is_dying(id: int) -> bool:
	return id < _dying.size() and _dying[id] == 1


## Schedules a command. Commands for past ticks are rejected.
func queue_command(cmd: SimCommand) -> bool:
	if cmd.tick < tick:
		return false
	commands.push(cmd)
	return true


## Advance the simulation by exactly one tick.
func step() -> void:
	for cmd: SimCommand in commands.take(tick):
		if cmd.validate(self):
			cmd.apply(self)
	for system: SimSystem in _systems:
		system.step(self, tick)
	_cleanup()
	if tick % SimConst.CHECKSUM_INTERVAL == 0:
		last_checksum = Checksum.compute(self)
		last_checksum_tick = tick
	tick += 1


## Returns and clears pending events.
func drain_events() -> Array[SimEvent]:
	var out: Array[SimEvent] = events
	var fresh: Array[SimEvent] = []
	events = fresh
	return out


func emit(type: SimEvent.Type, entity_id: int, other_id: int = 0, value: int = 0, x: int = 0, y: int = 0) -> void:
	var e: SimEvent = SimEvent.new(type, entity_id, tick)
	e.other_id = other_id
	e.value = value
	e.x = x
	e.y = y
	events.append(e)


## Creates a unit from its definition. Position is snapped to the nearest passable cell.
func spawn_unit(def: UnitStats, team: int, owner: int, x_mm: int, y_mm: int, heading: int) -> int:
	var cell: int = grid.cell_at(x_mm, y_mm) if def.is_air else grid.nearest_passable(def.mobility_class, grid.cell_at(x_mm, y_mm), 16)
	if cell < 0:
		return 0
	if cell != grid.cell_at(x_mm, y_mm):
		x_mm = grid.center_x(cell)
		y_mm = grid.center_y(cell)
	assert(not def.is_structure, "use spawn_structure")
	var id: int = _new_entity()
	transform.add(id, x_mm, y_mm, grid.ground_at(x_mm, y_mm) + def.altitude_mm, heading)
	units.add(id, def, team, owner)
	mobility.add(id, def.mobility_class)
	orders.add(id)
	weapons.add(id, def, defs)
	logistics.add(id, def)
	radiation.add(id)
	on_net[id] = 1 if def.emitter_kind == UnitStats.EMIT_RADIO else 0
	if def.is_infantry:
		squads.add(id, def)
	vision[team].mark_seen(id, x_mm, y_mm, tick, 0x3FFFFFFF)
	emit(SimEvent.Type.SPAWNED, id, 0, def.index, x_mm, y_mm)
	return id


func _new_entity() -> int:
	var id: int = entities.create()
	var cap: int = entities.capacity()
	_dying.resize(cap)
	jammed.resize(cap)
	on_net.resize(cap)
	for v: TeamVision in vision:
		v.ensure_capacity(cap)
	return id


## Footprint cells of a structure def placed with origin (cx, cy).
func footprint_cells(def: UnitStats, cx: int, cy: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for y: int in range(cy, cy + def.footprint_h):
		for x: int in range(cx, cx + def.footprint_w):
			if grid.in_grid(x, y):
				out.append(grid.index(x, y))
	return out


## Places a structure (complete or as a construction site). Caller validates placement.
func spawn_structure(def: UnitStats, team: int, owner: int, cx: int, cy: int, complete: bool) -> int:
	assert(def.is_structure)
	var id: int = _new_entity()
	var x: int = cx * SimGrid.CELL_MM + def.footprint_w * SimGrid.CELL_MM / 2
	var y: int = cy * SimGrid.CELL_MM + def.footprint_h * SimGrid.CELL_MM / 2
	transform.add(id, x, y, grid.ground_at(x, y), 0)
	units.add(id, def, team, owner)
	weapons.add(id, def, defs)
	structures.add(id, cx, cy, 0 if complete else maxi(1, def.build_time_ticks * 100),
		x, y - (def.footprint_h * SimGrid.CELL_MM / 2 + 16000))
	if not complete:
		units.hp[id] = maxi(1, def.hp / 10)
	var cells: PackedInt32Array = footprint_cells(def, cx, cy)
	for c: int in cells:
		occupancy[c] = id
	if def.blocks_mask != 0:
		grid.set_blocked_cells(cells, def.blocks_mask)
	if team == NEUTRAL_TEAM:
		for v: TeamVision in vision:
			v.mark_seen(id, x, y, tick, 0x3FFFFFFF)
	else:
		vision[team].mark_seen(id, x, y, tick, 0x3FFFFFFF)
	emit(SimEvent.Type.SPAWNED, id, 0, def.index, x, y)
	return id


## Marks an entity for removal at the end of this tick (phase 10).
func destroy_entity(id: int) -> void:
	if entities.is_alive(id) and not is_dying(id):
		_dying[id] = 1
		_pending_destroy.append(id)
		if units.has(id) and def_of(id).passenger_capacity > 0:
			Transport.bail_out(self, id)


## Rebuild team_units (call once per tick before vision).
func rebuild_team_rosters() -> void:
	var built: Array[PackedInt32Array] = []
	for t: int in range(MAX_TEAMS):
		built.append(PackedInt32Array())
	var per_team: Array[PackedInt32Array] = built
	var ids: PackedInt32Array = entities.ids()
	for t: int in range(MAX_TEAMS):
		var arr: PackedInt32Array = PackedInt32Array()
		for id: int in ids:
			if units.has(id) and units.team[id] == t and not is_dying(id) and units.carrier[id] == 0:
				arr.append(id)
		per_team[t] = arr
	team_units = per_team


## Rebuild visible_enemies from the vision layers (call after vision).
func rebuild_visible_enemies() -> void:
	for t: int in range(MAX_TEAMS):
		var out: PackedInt32Array = PackedInt32Array()
		var layer: TeamVision = vision[t]
		for o: int in range(MAX_TEAMS):
			if o == t:
				continue
			if not is_enemy_team(t, o):
				continue
			for id: int in team_units[o]:
				if layer.is_visible(id, tick) and is_unit(id):
					out.append(id)
		out.sort()
		visible_enemies[t] = out


func los_cached(observer: int, target: int, max_age: int) -> bool:
	var key: int = (observer << 20) | target
	return los_cache.has(key) and tick - int(los_cache[key]) <= max_age


func request_path(id: int) -> void:
	if orders.waiting_path[id] == 0:
		orders.waiting_path[id] = 1
		path_requests.append(id)


func release_flow(id: int) -> void:
	if not orders.has(id):
		return
	var fid: int = orders.flow_id[id]
	if fid == 0:
		return
	orders.flow_id[id] = 0
	if flow_fields.has(fid):
		var ff: FlowField = flow_fields[fid]
		ff.users -= 1
		if ff.users <= 0:
			flow_fields.erase(fid)


func _cleanup() -> void:
	smoke.expire(tick)
	if tick % 100 == 0 and not los_cache.is_empty():
		var stale: Array = []
		for key: int in los_cache.keys():
			if tick - int(los_cache[key]) > 50:
				stale.append(key)
		for key: int in stale:
			los_cache.erase(key)
	if _pending_destroy.is_empty():
		return
	_pending_destroy.sort()
	for id: int in _pending_destroy:
		if not entities.is_alive(id):
			continue
		release_flow(id)
		var owner_team: int = units.team[id] if units.has(id) else 0
		if structures.has(id):
			var sd: UnitStats = def_of(id)
			var cells: PackedInt32Array = footprint_cells(sd, structures.cell_x[id], structures.cell_y[id])
			for c: int in cells:
				if occupancy[c] == id:
					occupancy[c] = 0
			if sd.blocks_mask != 0:
				grid.set_blocked_cells(cells, 0)
		for store: ComponentStore in component_stores():
			store.remove(id)
		entities.destroy(id)
		emit(SimEvent.Type.DESTROYED, id, 0, owner_team)
	_pending_destroy.clear()
