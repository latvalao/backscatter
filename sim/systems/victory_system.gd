# SIM: deterministic — no floats, no Nodes
## Tick phase 10: skirmish defeat/victory. With hq_required, a team that has lost
## all its HQs is defeated; the last team standing wins.
class_name VictorySystem
extends SimSystem

const INTERVAL: int = 10


func step(world: SimWorld, tick: int) -> void:
	if not world.hq_required or world.winner_team >= 0 or tick % INTERVAL != 0:
		return
	var alive_teams: PackedInt32Array = PackedInt32Array()
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		var has_players: bool = false
		for p: int in range(world.players.count()):
			if world.players.team[p] == team:
				has_players = true
		if not has_players:
			continue
		var hq: bool = false
		for id: int in world.team_units[team]:
			if world.is_structure(id) and world.def_of(id).role == "hq":
				hq = true
				break
		if hq:
			alive_teams.append(team)
		else:
			for p: int in range(world.players.count()):
				if world.players.team[p] == team and world.players.defeated[p] == 0:
					world.players.defeated[p] = 1
					world.emit(SimEvent.Type.DEFEATED, 0, p, team)
	if alive_teams.size() == 1:
		world.winner_team = alive_teams[0]
		world.emit(SimEvent.Type.VICTORY, 0, 0, world.winner_team)
