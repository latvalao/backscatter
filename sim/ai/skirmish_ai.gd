# SIM: deterministic — no floats, no Nodes
## "Dummy" skirmish opponent (M4 acceptance; the real doctrine AI is M7):
## builds barracks + motor pool + supply depot near its HQ, keeps production
## queues fed, grabs the nearest depots, and attacks the enemy HQ once its army
## is big enough. Knows the enemy HQ position (Easy-level scouting cheat).
class_name SkirmishAi
extends AiController

const THINK_INTERVAL: int = 50
const ATTACK_ARMY: int = 10
const RESERVE: int = 120
const BUILD_ORDER: Array[String] = ["barracks", "motor_pool", "supply_depot"]

## Passive dummies never attack (useful for tests and tutorials).
var aggressive: bool = true
var _attacking: bool = false


func step(world: SimWorld, tick: int) -> void:
	if (tick + player * 7) % THINK_INTERVAL != 0:
		return
	var team: int = world.team_of_player(player)
	var hq: int = _my_structure(world, team, "hq")
	if hq == 0:
		return
	_build(world, team, hq)
	_produce(world, team)
	var army: PackedInt32Array = PackedInt32Array()
	var engineers: PackedInt32Array = PackedInt32Array()
	for id: int in my_units(world):
		var d: UnitStats = world.def_of(id)
		if d.has_ability("build"):
			engineers.append(id)
		elif d.role != "logistics":
			army.append(id)
	if aggressive and (_attacking or army.size() >= ATTACK_ARMY):
		var target: int = _enemy_hq(world, team)
		if target > 0 and tick % (THINK_INTERVAL * 6) == 0:
			_attacking = true
			issue(world, MoveCommand.new(army, world.transform.x[target], world.transform.y[target], MoveCommand.MODE_ATTACK_MOVE))
		return
	if tick % (THINK_INTERVAL * 6) == 0:
		_take_depots(world, team, army)


func _build(world: SimWorld, team: int, hq: int) -> void:
	var engineer: int = 0
	for id: int in my_units(world):
		if world.def_of(id).has_ability("build"):
			if world.orders.kind[id] == OrderStore.BUILD:
				return  # already building something
			if engineer == 0:
				engineer = id
	if engineer == 0:
		return
	var hcx: int = world.structures.cell_x[hq]
	var hcy: int = world.structures.cell_y[hq]
	var dir: int = 1 if world.grid.cell_x(world.grid.cell_at(world.transform.x[hq], 0)) < world.grid.width / 2 else -1
	for i: int in range(BUILD_ORDER.size()):
		var role: String = BUILD_ORDER[i]
		if _my_structure(world, team, role, true) != 0:
			continue
		var def: UnitStats = world.defs.unit(role)
		if world.players.supply[player] < def.cost_supply + RESERVE:
			return
		var site: Vector2i = MatchSetup.find_site(world, def, hcx + dir * (6 + i * 6), hcy + 6 - i * 6, 30)
		if site.x >= 0:
			issue(world, BuildCommand.new(PackedInt32Array([engineer]), role, site.x, site.y))
		return


func _produce(world: SimWorld, team: int) -> void:
	var faction: String = world.players.faction[player]
	for role: String in ["barracks", "motor_pool"]:
		var b: int = _my_structure(world, team, role)
		if b == 0 or world.structures.get_queue(b).size() >= 2:
			continue
		var options: Array[UnitStats] = world.defs.producible(role, faction)
		var pick: UnitStats = null
		for u: UnitStats in options:
			if u.role == "logistics" or u.role == "builder":
				continue
			if world.players.supply[player] >= u.cost_supply + RESERVE and world.players.manpower[player] >= u.cost_manpower:
				# rotate through the affordable options
				if pick == null or (world.tick / THINK_INTERVAL + u.index) % 3 == 0:
					pick = u
		if pick != null:
			issue(world, ProduceCommand.new(b, pick.id, 1))


func _take_depots(world: SimWorld, team: int, army: PackedInt32Array) -> void:
	if army.is_empty():
		return
	var best: int = 0
	var best_d: int = 1 << 60
	var ax: int = world.transform.x[army[0]]
	var ay: int = world.transform.y[army[0]]
	for d: int in ObjectiveSystem._depots(world):
		if world.structures.holder_team[d] == team:
			continue
		var dd: int = FixedMath.dist2_sq(ax, ay, world.transform.x[d], world.transform.y[d])
		if dd < best_d:
			best_d = dd
			best = d
	if best > 0:
		issue(world, MoveCommand.new(army, world.transform.x[best], world.transform.y[best] - 30_000, MoveCommand.MODE_ATTACK_MOVE))


func _my_structure(world: SimWorld, team: int, role: String, include_sites: bool = false) -> int:
	for id: int in world.team_units[team]:
		if world.is_structure(id) and world.units.owner[id] == player and world.def_of(id).role == role:
			if include_sites or world.structures.is_complete(id):
				return id
	return 0


func _enemy_hq(world: SimWorld, team: int) -> int:
	for t: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, t):
			continue
		for id: int in world.team_units[t]:
			if world.is_structure(id) and world.def_of(id).role == "hq":
				return id
	return 0
