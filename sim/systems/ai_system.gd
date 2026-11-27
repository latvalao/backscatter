# SIM: deterministic — no floats, no Nodes
## Tick phase 2: steps AI controllers in list order.
class_name AiSystem
extends SimSystem


func step(world: SimWorld, tick: int) -> void:
	if world.ai.is_empty():
		return
	world.rebuild_team_rosters()
	for c: AiController in world.ai:
		if world.players.defeated[c.player] == 0:
			c.step(world, tick)
