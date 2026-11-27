# SIM: deterministic — no floats, no Nodes
## Tick phase 9e: mines (trigger, reveal, clear), engineer tasks (salvage
## wrecks, lay minefields), bailed-out crew recovery and infantry digging in.
class_name FieldSystem
extends SimSystem

const MINE_TRIGGER_MM: int = 3500
const MINE_REVEAL_MM: int = 60000
const MINE_CLEAR_MM: int = 30000
const MINE_CLEAR_TICKS: int = 40
const MINE_DAMAGE: int = 350
const MINES_PER_FIELD: int = 7
const MINEFIELD_SPACING_MM: int = 9000
const TASK_RANGE_MM: int = 22000
const SALVAGE_TICKS: int = 200
const RECOVER_RANGE_MM: int = 60000
## Infantry standing still this long count as dug in (garrisoned in villages).
const DIG_IN_TICKS: int = 150


func step(world: SimWorld, tick: int) -> void:
	_still(world)
	if world.mines.count() > 0:
		_mines(world, tick)
	if tick % 5 == 0:
		_tasks(world)
		_recover_crews(world)


func _still(world: SimWorld) -> void:
	var u: UnitStore = world.units
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			if not world.mobility.has(id):
				continue
			if world.mobility.speed[id] == 0:
				u.still_ticks[id] = mini(u.still_ticks[id] + 1, 100000)
			else:
				u.still_ticks[id] = 0


## Extra cover permille for infantry that has had time to dig in.
static func dug_in_bonus(world: SimWorld, id: int) -> int:
	if world.units.still_ticks[id] < DIG_IN_TICKS:
		return 0
	var t: int = world.grid.terrain_at(world.transform.x[id], world.transform.y[id])
	return 250 if t == TerrainTable.URBAN else 120


func _mines(world: SimWorld, tick: int) -> void:
	var m: MineStore = world.mines
	var t: TransformStore = world.transform
	var near: PackedInt32Array = PackedInt32Array()
	var i: int = 0
	while i < m.count():
		near.clear()
		world.spatial.query(m.x[i], m.y[i], MINE_REVEAL_MM, near)
		near.sort()
		var triggered: int = 0
		var cleared: bool = false
		for id: int in near:
			if not world.is_unit(id) or world.is_structure(id) or world.is_air(id) or not world.is_enemy_team(m.team[i], world.units.team[id]):
				continue
			var def: UnitStats = world.def_of(id)
			var d: int = FixedMath.length2(t.x[id] - m.x[i], t.y[id] - m.y[i])
			var team: int = world.units.team[id]
			if d <= MINE_TRIGGER_MM + (def.radius_mm if not def.is_infantry else 0):
				triggered = id
				break
			if def.role == "scout" or def.has_ability("build"):
				m.known[i] |= 1 << team
			if def.has_ability("build") and m.is_known(i, team) and d <= MINE_CLEAR_MM \
					and world.orders.kind[id] == OrderStore.NONE and (tick + i) % MINE_CLEAR_TICKS == 0:
				cleared = true
				break
		if triggered != 0:
			_detonate(world, i, triggered)
			m.remove_at(i)
			continue
		if cleared:
			m.remove_at(i)
			continue
		i += 1


func _detonate(world: SimWorld, i: int, victim: int) -> void:
	var def: UnitStats = world.def_of(victim)
	world.emit(SimEvent.Type.MINE, victim, 0, 0, world.mines.x[i], world.mines.y[i])
	world.units.last_hit_tick[victim] = world.tick
	if def.is_infantry:
		for k: int in range(2):
			if world.is_unit(victim):
				Combat.kill_one_member(world, victim)
		if world.is_unit(victim):
			Combat.add_suppression(world, victim, 500)
		return
	world.units.damage[victim] |= UnitStore.DMG_TRACKS
	world.units.hp[victim] -= MINE_DAMAGE
	Combat.add_suppression(world, victim, 400)
	if world.units.hp[victim] <= 0:
		world.destroy_entity(victim)


func _tasks(world: SimWorld) -> void:
	var u: UnitStore = world.units
	var t: TransformStore = world.transform
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			var task: int = u.task[id]
			if task == UnitStore.TASK_NONE or world.orders.kind[id] != OrderStore.NONE:
				continue
			var d: int = FixedMath.length2(u.task_x[id] - t.x[id], u.task_y[id] - t.y[id])
			if d > TASK_RANGE_MM:
				u.task[id] = UnitStore.TASK_NONE  # gave up or was ordered elsewhere
				continue
			if task == UnitStore.TASK_LAY_MINES:
				_lay(world, id, team)
				u.task[id] = UnitStore.TASK_NONE
			elif task == UnitStore.TASK_SALVAGE:
				var wi: int = world.wrecks.find(u.task_arg[id])
				if wi < 0:
					u.task[id] = UnitStore.TASK_NONE
					continue
				world.wrecks.progress[wi] += 5
				if world.wrecks.progress[wi] >= SALVAGE_TICKS:
					var owner: int = u.owner[id]
					if owner >= 0 and owner < world.players.count():
						world.players.supply[owner] += world.wrecks.value[wi]
					world.emit(SimEvent.Type.SALVAGED, world.wrecks.entity[wi], id, world.wrecks.value[wi], world.wrecks.x[wi], world.wrecks.y[wi])
					world.wrecks.remove_at(wi)
					u.task[id] = UnitStore.TASK_NONE


## A short minefield across the direction the engineer is facing.
func _lay(world: SimWorld, id: int, team: int) -> void:
	var t: TransformStore = world.transform
	var side: int = (t.heading[id] + SimConst.ANGLE_QUARTER) & SimConst.ANGLE_MASK
	for k: int in range(MINES_PER_FIELD):
		var off: int = (k - MINES_PER_FIELD / 2) * MINEFIELD_SPACING_MM
		var stagger: int = 4000 if k % 2 == 0 else -4000
		var mx: int = t.x[id] + (off * FixedMath.cos_b(side) + stagger * FixedMath.cos_b(t.heading[id])) / FixedMath.ONE + 15000 * FixedMath.cos_b(t.heading[id]) / FixedMath.ONE
		var my: int = t.y[id] + (off * FixedMath.sin_b(side) + stagger * FixedMath.sin_b(t.heading[id])) / FixedMath.ONE + 15000 * FixedMath.sin_b(t.heading[id]) / FixedMath.ONE
		if world.in_bounds(mx, my):
			world.mines.add(mx, my, team)


## Bailed-out crews walking into their HQ or barracks return their manpower.
func _recover_crews(world: SimWorld) -> void:
	var t: TransformStore = world.transform
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			var def: UnitStats = world.def_of(id)
			if not def.has_ability("recover"):
				continue
			for s: int in world.team_units[team]:
				if not world.is_structure(s) or not world.structures.is_complete(s):
					continue
				var role: String = world.def_of(s).role
				if role != "hq" and role != "barracks":
					continue
				if FixedMath.length2(t.x[s] - t.x[id], t.y[s] - t.y[id]) <= RECOVER_RANGE_MM:
					var owner: int = world.units.owner[id]
					if owner >= 0 and owner < world.players.count():
						world.players.manpower[owner] += world.units.members_alive[id]
					world.emit(SimEvent.Type.ALERT, id, 0, 1)
					world.destroy_entity(id)
					break
