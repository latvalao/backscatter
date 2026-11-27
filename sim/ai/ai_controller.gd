# SIM: deterministic — no floats, no Nodes
## Base for sim-side AI players (§6). Runs inside the deterministic sim, so its
## orders are identical on every peer. Issues orders by applying commands directly.
class_name AiController
extends RefCounted

var player: int = 0
var _seq: int = 0


func step(_world: SimWorld, _tick: int) -> void:
	pass


## Validates and applies a command as this player, this tick.
func issue(world: SimWorld, cmd: SimCommand) -> bool:
	cmd.player_id = player
	cmd.sequence = _seq
	_seq += 1
	cmd.tick = world.tick
	if not cmd.validate(world):
		return false
	cmd.apply(world)
	return true


## This player's live units (not structures, not bailed-out crews heading
## home), ascending.
func my_units(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in world.team_units[world.team_of_player(player)]:
		if world.units.owner[id] == player and not world.is_structure(id) and world.def_of(id).role != "crew":
			out.append(id)
	return out
