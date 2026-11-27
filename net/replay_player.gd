## Plays a replay back by re-running the sim with the recorded inputs and
## verifying every recorded checksum.
class_name ReplayPlayer
extends RefCounted

var data: Dictionary
var world: SimWorld
var mismatch_tick: int = -1


func _init(p_data: Dictionary, grid: SimGrid = null) -> void:
	data = p_data
	var settings: MatchSettings = MatchSettings.from_dict(data["settings"])
	world = MatchSetup.create(settings, DefLoader.load_default(), grid)


func finished() -> bool:
	return world.tick >= int(data["final_tick"])


## Steps one tick; returns false at the end or after a checksum mismatch.
func step() -> bool:
	if finished() or mismatch_tick >= 0:
		return false
	var t: int = world.tick
	var ticks: Dictionary = data["ticks"]
	if ticks.has(t):
		for c: SimCommand in CommandCodec.decode(ticks[t]):
			c.tick = t
			world.queue_command(c)
	world.step()
	var sums: Dictionary = data["checksums"]
	if world.last_checksum_tick == t and sums.has(t) and int(sums[t]) != world.last_checksum:
		mismatch_tick = t
		return false
	return true


## Runs to the end. True if every checksum matched.
func verify() -> bool:
	while step():
		pass
	return mismatch_tick < 0 and finished()
