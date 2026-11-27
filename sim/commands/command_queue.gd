# SIM: deterministic — no floats, no Nodes
## Holds scheduled commands keyed by tick. Only looked up by key, never iterated
## in dictionary order.
class_name CommandQueue
extends RefCounted

var _by_tick: Dictionary = {}  # int -> Array[SimCommand]


func push(cmd: SimCommand) -> void:
	if not _by_tick.has(cmd.tick):
		var bucket: Array[SimCommand] = []
		_by_tick[cmd.tick] = bucket
	var list: Array[SimCommand] = _by_tick[cmd.tick]
	list.append(cmd)


## Removes and returns the commands for tick, sorted by (player_id, sequence).
func take(tick: int) -> Array[SimCommand]:
	var out: Array[SimCommand] = []
	if _by_tick.has(tick):
		out = _by_tick[tick]
		_by_tick.erase(tick)
		out.sort_custom(SimCommand.compare)
	return out


func pending_count() -> int:
	var n: int = 0
	for key: int in _by_tick.keys():
		var list: Array[SimCommand] = _by_tick[key]
		n += list.size()
	return n
