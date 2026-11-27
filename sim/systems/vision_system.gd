# SIM: deterministic — no floats, no Nodes
## Tick phase 4: spotting. Each observer re-scans every INTERVAL ticks (staggered
## by id). A target is visible to a team while seen_until > tick.
## Spot range = observer optics (day/night/thermal) × target visibility, where
## visibility = unit concealment × terrain concealment × moving × recently fired.
class_name VisionSystem
extends SimSystem

const INTERVAL: int = 5
const FIRED_REVEAL_TICKS: int = 30
const FIRED_FACTOR: int = 2500
const MOVING_FACTOR: int = 1300
const MAX_FACTOR: int = 1600


func step(world: SimWorld, tick: int) -> void:
	world.rebuild_team_rosters()
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		for obs: int in world.team_units[team]:
			if (obs + tick) % INTERVAL != 0:
				continue
			_scan(world, obs, team, tick)
	world.rebuild_visible_enemies()


## Optical (day or night) and thermal ranges for an observer, after crew/optics damage.
static func observer_ranges(world: SimWorld, obs: int) -> Vector2i:
	var def: UnitStats = world.def_of(obs)
	var u: UnitStore = world.units
	if world.is_structure(obs) and not world.structures.is_complete(obs):
		return Vector2i(0, 0)
	var optical: int = def.vision_night_mm if world.is_night else def.vision_day_mm
	var thermal: int = def.vision_thermal_mm
	var mult: int = 1000
	if (u.damage[obs] & UnitStore.DMG_OPTICS) != 0:
		mult = 500
	if def.has_crew(UnitStats.CREW_COMMANDER) and (u.crew[obs] & UnitStats.CREW_COMMANDER) == 0:
		mult = mult * 700 / 1000
	return Vector2i(optical * mult / 1000, thermal * mult / 1000)


## Target visibility multiplier permille.
static func target_factor(world: SimWorld, target: int, tick: int) -> int:
	var def: UnitStats = world.def_of(target)
	var t: TransformStore = world.transform
	var f: int = def.visibility * TerrainTable.CONCEAL[world.grid.terrain_at(t.x[target], t.y[target])] / 1000
	var fort: int = world.fortification_cover(t.x[target], t.y[target], def.is_infantry)
	if fort > 0:
		f = f * (1000 - fort / 2) / 1000
	if world.mobility.has(target) and world.mobility.speed[target] != 0:
		f = f * MOVING_FACTOR / 1000
	if tick - world.units.last_fired_tick[target] <= FIRED_REVEAL_TICKS:
		f = f * FIRED_FACTOR / 1000
	return mini(f, MAX_FACTOR)


func _scan(world: SimWorld, obs: int, team: int, tick: int) -> void:
	var layer: TeamVision = world.vision[team]
	var ranges: Vector2i = observer_ranges(world, obs)
	var reach: int = maxi(ranges.x, ranges.y) * MAX_FACTOR / 1000
	var t: TransformStore = world.transform
	var ox: int = t.x[obs]
	var oy: int = t.y[obs]
	var until: int = tick + INTERVAL + 1
	for other_team: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, other_team):
			continue
		for tgt: int in world.team_units[other_team]:
			_consider(world, obs, tgt, ox, oy, reach, ranges, layer, until, tick)


func _consider(world: SimWorld, obs: int, tgt: int, ox: int, oy: int, reach: int, ranges: Vector2i,
	layer: TeamVision, until: int, tick: int) -> void:
	var t: TransformStore = world.transform
	var dx: int = t.x[tgt] - ox
	var dy: int = t.y[tgt] - oy
	if absi(dx) > reach or absi(dy) > reach:
		return
	var d2: int = dx * dx + dy * dy
	var f: int = target_factor(world, tgt, tick)
	var opt: int = ranges.x * f / 1000
	var thr: int = ranges.y * f / 1000
	var need: int = maxi(opt, thr)
	if d2 > need * need:
		return
	var los: int = Los.between(world, obs, tgt)
	if los == Los.BLOCKED:
		return
	if los == Los.SMOKE:
		# visual sight blocked; thermal sees through smoke at half range
		if d2 > (thr / 2) * (thr / 2):
			return
	layer.mark_seen(tgt, t.x[tgt], t.y[tgt], tick, until)
	if los == Los.CLEAR:
		world.los_cache[(obs << 20) | tgt] = tick
