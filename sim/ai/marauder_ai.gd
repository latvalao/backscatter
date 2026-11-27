# SIM: deterministic — no floats, no Nodes
## Marauder doctrine (§3.3, §6): camps in the forest near roads, ambush anything
## that comes close (hold fire until it's within AMBUSH_RANGE), raid weak
## targets (trucks, lone units, held depots) from a camp, fall back when a raid
## has lost half its strength, and trickle in reinforcements. No economy.
class_name MarauderAi
extends AiController

const THINK: int = 50
const AMBUSH_RANGE_MM: int = 350000
const RAID_RANGE_MM: int = 1600000
const RAID_START_TICK: int = 3000
const REINFORCE_INTERVAL: int = 3000
const MAX_UNITS: int = 14
const CAMP_KIT: Array[String] = ["mr_militia", "mr_militia", "mr_rpg", "mr_technical", "mr_mortar"]

var camps: Array[Vector2i] = []
var _raid: PackedInt32Array = PackedInt32Array()
var _raid_start: int = 0
var _home: Dictionary = {}  # unit -> camp index


## Spawns the starting garrisons. Called once by MatchSetup.
func setup(world: SimWorld, camp_count: int, rng: SimRng) -> void:
	var g: SimGrid = world.grid
	var tries: int = 0
	while camps.size() < camp_count and tries < 2000:
		tries += 1
		var cx: int = rng.range_int(g.width / 4, g.width * 3 / 4)
		var cy: int = rng.range_int(g.height / 8, g.height * 7 / 8)
		var c: int = g.index(cx, cy)
		if g.terrain[c] != TerrainTable.FOREST or world.radfield.rate_index(world.radfield.index_at(g.center_x(c), g.center_y(c))) > 1_500_000:
			continue
		if tries < 1000 and not _road_within(g, cx, cy, 40):
			continue
		var p: Vector2i = Vector2i(g.center_x(c), g.center_y(c))
		var ok: bool = true
		for other: Vector2i in camps:
			if FixedMath.length2(other.x - p.x, other.y - p.y) < 600000:
				ok = false
		if ok:
			camps.append(p)
	var team: int = world.team_of_player(player)
	for k: int in range(camps.size()):
		for i: int in range(CAMP_KIT.size()):
			var id: int = world.spawn_unit(world.defs.unit(CAMP_KIT[i]), team, player,
				camps[k].x + ((i % 3) - 1) * 25000, camps[k].y + (i / 3) * 25000, 0)
			if id > 0:
				_home[id] = k
				world.units.stance[id] = UnitStore.STANCE_HOLD_FIRE
	if camps.size() > 1:
		var id2: int = world.spawn_unit(world.defs.unit("mr_mbt_55"), team, player, camps[1].x, camps[1].y + 40000, 0)
		if id2 > 0:
			_home[id2] = 1
			world.units.stance[id2] = UnitStore.STANCE_HOLD_FIRE


static func _road_within(g: SimGrid, cx: int, cy: int, r: int) -> bool:
	for y: int in range(maxi(0, cy - r), mini(g.height, cy + r + 1), 3):
		for x: int in range(maxi(0, cx - r), mini(g.width, cx + r + 1), 3):
			if g.terrain[g.index(x, y)] == TerrainTable.ROAD:
				return true
	return false


func step(world: SimWorld, tick: int) -> void:
	if (tick + 29) % THINK != 0 or camps.is_empty():
		return
	var team: int = world.team_of_player(player)
	var units: PackedInt32Array = my_units(world)
	_ambush(world, team, units)
	if tick >= RAID_START_TICK:
		_raids(world, team, units, tick)
	if tick > 0 and tick % REINFORCE_INTERVAL < THINK and units.size() < MAX_UNITS:
		var k: int = (tick / REINFORCE_INTERVAL) % camps.size()
		var id: int = world.spawn_unit(world.defs.unit("mr_militia"), team, player, camps[k].x, camps[k].y, 0)
		if id > 0:
			_home[id] = k
			world.units.stance[id] = UnitStore.STANCE_HOLD_FIRE


## Hold fire until prey walks into the kill zone, then open up.
func _ambush(world: SimWorld, team: int, units: PackedInt32Array) -> void:
	var t: TransformStore = world.transform
	var open: PackedInt32Array = PackedInt32Array()
	var hold: PackedInt32Array = PackedInt32Array()
	for id: int in units:
		if _raid.has(id):
			continue
		var close: bool = world.units.last_hit_tick[id] > world.tick - 100
		for e: int in world.visible_enemies[team]:
			if FixedMath.dist2_sq(t.x[e], t.y[e], t.x[id], t.y[id]) <= AMBUSH_RANGE_MM * AMBUSH_RANGE_MM:
				close = true
				break
		if close:
			if world.units.stance[id] != UnitStore.STANCE_FIRE_AT_WILL:
				open.append(id)
		elif world.units.stance[id] != UnitStore.STANCE_HOLD_FIRE:
			hold.append(id)
	if not open.is_empty():
		issue(world, StanceCommand.new(open, UnitStore.STANCE_FIRE_AT_WILL))
	if not hold.is_empty():
		issue(world, StanceCommand.new(hold, UnitStore.STANCE_HOLD_FIRE))


func _raids(world: SimWorld, team: int, units: PackedInt32Array, tick: int) -> void:
	var t: TransformStore = world.transform
	var alive: PackedInt32Array = PackedInt32Array()
	for id: int in _raid:
		if world.is_unit(id):
			alive.append(id)
	_raid = alive
	if not _raid.is_empty():
		# fall back after heavy losses or a long raid
		if _raid.size() * 2 < _raid_start or tick - world.orders.progress_tick[_raid[0]] > 3000:
			for id: int in _raid:
				var k: int = _home.get(id, 0)
				issue(world, MoveCommand.new(PackedInt32Array([id]), camps[k].x, camps[k].y))
			_raid = PackedInt32Array()
		return
	if tick % 900 >= THINK:
		return
	# pick prey: the weakest known enemy near any camp
	var best: int = 0
	var best_score: int = -1
	for other: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, other):
			continue
		for e: int in world.team_units[other]:
			if not world.vision[team].is_visible(e, tick):
				continue
			var d: UnitStats = world.def_of(e)
			if d.is_air or d.role == "hq":
				continue
			var near: bool = false
			for c: Vector2i in camps:
				if FixedMath.dist2_sq(t.x[e], t.y[e], c.x, c.y) <= RAID_RANGE_MM * RAID_RANGE_MM:
					near = true
			if not near:
				continue
			var score: int = 1000 - d.cost_supply
			if d.role == "logistics":
				score += 2000
			if score > best_score:
				best_score = score
				best = e
	if best == 0:
		return
	var group: PackedInt32Array = PackedInt32Array()
	for id: int in units:
		var r: String = world.def_of(id).role
		if r != "indirect" and group.size() < 6:
			group.append(id)
	if group.size() < 2:
		return
	_raid = group
	_raid_start = group.size()
	issue(world, StanceCommand.new(group, UnitStore.STANCE_FIRE_AT_WILL))
	issue(world, MoveCommand.new(group, t.x[best], t.y[best], MoveCommand.MODE_ATTACK_MOVE))
