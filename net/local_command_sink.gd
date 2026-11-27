## Offline command path: stamps a command with the local player, a sequence
## number and the next tick, then queues it in the world. M3 replaces this with
## the lockstep scheduler (same interface).
class_name LocalCommandSink
extends RefCounted

## Ticks between issuing and applying (M3 lockstep uses ~3).
const INPUT_DELAY: int = 1

var world: SimWorld
var player_id: int = 0
var _sequence: int = 0


func _init(p_world: SimWorld, p_player: int) -> void:
	world = p_world
	player_id = p_player


func submit(cmd: SimCommand) -> void:
	cmd.player_id = player_id
	cmd.sequence = _sequence
	_sequence += 1
	cmd.tick = world.tick + INPUT_DELAY
	world.queue_command(cmd)
