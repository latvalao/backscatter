# SIM: deterministic — no floats, no Nodes
## Zone War (design §4): skirmish rules plus victory points. Every held depot
## scores; first team to the target wins, or the leader when time runs out.
## Destroying the enemy HQ still wins outright (VictorySystem).
class_name ZoneWarDirector
extends ScenarioDirector

const SCORE_INTERVAL: int = 100
const VP_TARGET: int = 600
const TIME_LIMIT: int = 18000

var vp: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])


func setup(world: SimWorld, _settings: MatchSettings) -> void:
	title = "Zone War"
	add_objective(world, "Hold depots to score victory points: first to %d, or lead after 30 minutes" % VP_TARGET)
	add_objective(world, "Or destroy the enemy command post")


func step(world: SimWorld, tick: int) -> void:
	if world.winner_team >= 0 or tick % SCORE_INTERVAL != 0 or tick == 0:
		return
	for d: int in ObjectiveSystem._depots(world):
		var h: int = world.structures.holder_team[d]
		if h >= 0 and h < 4:
			vp[h] += 1
	for t: int in range(2):
		if vp[t] >= VP_TARGET:
			finish(world, t)
			return
	if tick >= TIME_LIMIT:
		finish(world, 0 if vp[0] >= vp[1] else 1)
