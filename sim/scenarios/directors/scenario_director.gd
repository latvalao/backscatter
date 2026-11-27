# SIM: deterministic — no floats, no Nodes
## Base for scripted scenarios (modes and campaign missions). Runs in the AI
## phase like any AiController; spawns and orders units directly, tracks
## objectives and decides the winner. Text lives here; presentation reads it
## through world.ai (MissionPanel) and SimEvent.Type.MISSION events.
class_name ScenarioDirector
extends AiController

const OPEN: int = 0
const DONE: int = 1
const FAILED: int = 2

var title: String = ""
var briefing: String = ""
var messages: Array[String] = []
var objectives: Array[String] = []
var objective_state: PackedInt32Array = PackedInt32Array()
## The side the human players are on.
var human_team: int = 0
## Enemy player id the director commands (-1 = none).
var enemy: int = -1
var rng: SimRng
## Map markers for the current objectives: [x0, y0, x1, y1, ...] in mm.
var markers: PackedInt64Array = PackedInt64Array()


func mark(points: Array) -> void:
	markers = PackedInt64Array()
	for p: Variant in points:
		var v: Vector2i = p
		markers.append(v.x)
		markers.append(v.y)


func setup(_world: SimWorld, _settings: MatchSettings) -> void:
	pass


func say(world: SimWorld, text: String) -> void:
	messages.append(text)
	world.emit(SimEvent.Type.MISSION, 0, 0, messages.size() - 1)


func add_objective(world: SimWorld, text: String) -> int:
	objectives.append(text)
	objective_state.append(OPEN)
	world.emit(SimEvent.Type.MISSION, 0, 1, objectives.size() - 1)
	return objectives.size() - 1


func complete(world: SimWorld, i: int) -> void:
	if objective_state[i] == OPEN:
		objective_state[i] = DONE
		world.emit(SimEvent.Type.MISSION, 0, 2, i)


func fail(world: SimWorld, i: int) -> void:
	if objective_state[i] == OPEN:
		objective_state[i] = FAILED
		world.emit(SimEvent.Type.MISSION, 0, 3, i)


func finish(world: SimWorld, team: int) -> void:
	if world.winner_team < 0:
		world.winner_team = team
		world.emit(SimEvent.Type.VICTORY, 0, 0, team)


## Spawns a list of unit ids around (x, y) for a player; returns the new ids.
func spawn_group(world: SimWorld, p: int, ids: Array, x: int, y: int, face: int, spacing: int = 30000) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var team: int = world.team_of_player(p)
	for i: int in range(ids.size()):
		var ox: int = ((i % 4) - 1) * spacing
		var oy: int = (i / 4) * spacing
		var id: int = world.spawn_unit(world.defs.unit(String(ids[i])), team, p,
			clampi(x + ox, 0, world.map_width_mm() - 1), clampi(y + oy, 0, world.map_height_mm() - 1), face)
		if id != 0:
			out.append(id)
	return out


func alive(world: SimWorld, ids: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in ids:
		if world.is_unit(id):
			out.append(id)
	return out


## Units of `team` within r of (x, y) (no structures, no carried units).
func count_near(world: SimWorld, team: int, x: int, y: int, r: int) -> int:
	var n: int = 0
	for id: int in world.team_units[team]:
		if world.is_structure(id):
			continue
		if FixedMath.length2(world.transform.x[id] - x, world.transform.y[id] - y) <= r:
			n += 1
	return n


func has_hq(world: SimWorld, team: int) -> bool:
	for id: int in world.team_units[team]:
		if world.is_structure(id) and world.def_of(id).role == "hq":
			return true
	return false


## Orders a group (as the enemy player) to attack-move somewhere.
func attack(world: SimWorld, ids: PackedInt32Array, x: int, y: int) -> void:
	var live: PackedInt32Array = alive(world, ids)
	if live.is_empty():
		return
	var cmd: MoveCommand = MoveCommand.new(live, x, y, MoveCommand.MODE_ATTACK_MOVE)
	cmd.player_id = world.units.owner[live[0]]
	cmd.tick = world.tick
	if cmd.validate(world):
		cmd.apply(world)


## A friendly HQ plus a starting kit for every human player of the team.
func base_for_humans(world: SimWorld, cx: int, cy: int, kit: Dictionary, extra_supply: int) -> int:
	var hq_def: UnitStats = world.defs.unit("hq")
	var first_hq: int = 0
	var n: int = 0
	for p: int in range(world.players.count()):
		if world.players.team[p] != human_team or world.players.faction[p] == "mr" or p == enemy:
			continue
		var site: Vector2i = MatchSetup.find_site(world, hq_def, cx + n * 14, cy, 60)
		n += 1
		if site.x < 0:
			continue
		var hq: int = world.spawn_structure(hq_def, human_team, p, site.x, site.y, true)
		if first_hq == 0:
			first_hq = hq
		var list: Array = kit.get(world.players.faction[p], [])
		spawn_group(world, p, list, world.transform.x[hq] + 60000, world.transform.y[hq], 16384)
		world.players.supply[p] += extra_supply
	return first_hq
