# SIM: deterministic — no floats, no Nodes
## Root of all simulation state. Pure data + a fixed system order.
##
## Tick order (design doc §7.5):
##   1. Apply commands (sorted by player id, then sequence)
##   2. AI planning                      (M7)
##   3. Orders -> movement               -> MovementSystem
##   4. Vision & spotting                -> VisionSystem
##   5. Signature / DF / jamming         (M6)
##   6. Weapons + projectiles            -> WeaponSystem, ProjectileSystem
##   7. Damage, suppression, morale      -> MoraleSystem (damage applied inline via Combat)
##   8. Radiation                        (M5)
##   9. Logistics / production           (M4)
##  10. Veterancy, cleanup, events       -> _cleanup()
##  11. Checksum every CHECKSUM_INTERVAL ticks
class_name SimWorld
extends RefCounted

const MAX_TEAMS: int = 4

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
var vision: Array[TeamVision] = []
var projectiles: ProjectileStore = ProjectileStore.new()
var smoke: SmokeStore = SmokeStore.new()

## player id -> team
var player_team: PackedInt32Array = PackedInt32Array()
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
	grid = p_grid
	pathfinder = PathFinder.new(grid)
	spatial = SpatialHash.new(grid.width_mm(), grid.height_mm())
	for t: int in range(MAX_TEAMS):
		vision.append(TeamVision.new())
		team_units.append(PackedInt32Array())
		visible_enemies.append(PackedInt32Array())
	_systems.append(MovementSystem.new())    # 3
	_systems.append(VisionSystem.new())      # 4
	_systems.append(WeaponSystem.new())      # 6
	_systems.append(ProjectileSystem.new())  # 6
	_systems.append(MoraleSystem.new())      # 7


## Fixed component store order — part of the checksum definition.
func component_stores() -> Array[ComponentStore]:
	var out: Array[ComponentStore] = [transform, units, mobility, orders, weapons, squads]
	return out


func add_player(team: int) -> int:
	player_team.append(team)
	return player_team.size() - 1


func team_of_player(player: int) -> int:
	if player < 0 or player >= player_team.size():
		return -1
	return player_team[player]


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
	var cell: int = grid.nearest_passable(def.mobility_class, grid.cell_at(x_mm, y_mm), 16)
	if cell < 0:
		return 0
	if cell != grid.cell_at(x_mm, y_mm):
		x_mm = grid.center_x(cell)
		y_mm = grid.center_y(cell)
	var id: int = entities.create()
	var cap: int = entities.capacity()
	_dying.resize(cap)
	for v: TeamVision in vision:
		v.ensure_capacity(cap)
	transform.add(id, x_mm, y_mm, grid.ground_at(x_mm, y_mm), heading)
	units.add(id, def, team, owner)
	mobility.add(id, def.mobility_class)
	orders.add(id)
	weapons.add(id, def, defs)
	if def.is_infantry:
		squads.add(id, def)
	vision[team].mark_seen(id, x_mm, y_mm, tick, 0x3FFFFFFF)
	emit(SimEvent.Type.SPAWNED, id, 0, def.index, x_mm, y_mm)
	return id


## Marks an entity for removal at the end of this tick (phase 10).
func destroy_entity(id: int) -> void:
	if entities.is_alive(id) and not is_dying(id):
		_dying[id] = 1
		_pending_destroy.append(id)


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
			if units.has(id) and units.team[id] == t and not is_dying(id):
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
		for store: ComponentStore in component_stores():
			store.remove(id)
		entities.destroy(id)
		emit(SimEvent.Type.DESTROYED, id, 0, owner_team)
	_pending_destroy.clear()
