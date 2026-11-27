# SIM: deterministic — no floats, no Nodes
## Base class for all gameplay input. Commands are immutable once queued:
## UI builds one, the net layer schedules it for a tick, the sim applies it.
class_name SimCommand
extends RefCounted

## Issuing player (0..3). Commands within a tick apply sorted by (player_id, sequence).
var player_id: int = 0
## Per-player monotonically increasing sequence number.
var sequence: int = 0
## Tick on which the command is applied.
var tick: int = 0


## Override: return false to drop the command (stale target, not owner, ...).
func validate(_world: SimWorld) -> bool:
	return true


## Override: mutate the world. Called only if validate() returned true.
func apply(_world: SimWorld) -> void:
	pass


## Stable type tag for serialization (lockstep packets, replays).
func type_id() -> StringName:
	return &"base"


## Override: write command-specific fields (header is written by CommandCodec).
func write(_buf: StreamPeerBuffer) -> void:
	pass


## Override: read fields written by write().
func read(_buf: StreamPeerBuffer) -> void:
	pass


static func compare(a: SimCommand, b: SimCommand) -> bool:
	if a.player_id != b.player_id:
		return a.player_id < b.player_id
	return a.sequence < b.sequence
