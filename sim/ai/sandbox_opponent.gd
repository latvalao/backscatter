# SIM: deterministic — no floats, no Nodes
## Scripted sandbox opponent: waits, advances in two echelons, and barrages
## whatever its team can see every 40 s. Placeholder until the M7 AI.
class_name SandboxOpponent
extends AiController

var _phase: int = 0


func step(world: SimWorld, tick: int) -> void:
	var team: int = world.team_of_player(player)
	var army: PackedInt32Array = PackedInt32Array()
	var arty: PackedInt32Array = PackedInt32Array()
	for id: int in my_units(world):
		var role: String = world.def_of(id).role
		if role == "artillery" or role == "indirect":
			arty.append(id)
		elif role != "logistics":
			army.append(id)
	var w_mm: int = world.map_width_mm()
	var cy: int = world.map_height_mm() / 2
	if _phase == 0 and tick >= 900:
		issue(world, MoveCommand.new(army, w_mm * 575 / 1000, cy, MoveCommand.MODE_ATTACK_MOVE))
		_phase = 1
	elif _phase == 1 and tick >= 3000:
		issue(world, MoveCommand.new(army, w_mm * 225 / 1000, cy, MoveCommand.MODE_ATTACK_MOVE))
		_phase = 2
	if tick % 400 == 200 and not arty.is_empty():
		var vis: PackedInt32Array = world.visible_enemies[team]
		if not vis.is_empty():
			var tgt: int = vis[0]
			issue(world, FireMissionCommand.new(arty, world.transform.x[tgt], world.transform.y[tgt], 4))
