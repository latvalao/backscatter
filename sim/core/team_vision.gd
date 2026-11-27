# SIM: deterministic — no floats, no Nodes
## One team's knowledge of every entity (§5.8): visible now (seen_until > tick),
## last known position (ghost markers), or unknown (last_tick < 0).
class_name TeamVision
extends RefCounted

var seen_until: PackedInt32Array = PackedInt32Array()
var last_x: PackedInt64Array = PackedInt64Array()
var last_y: PackedInt64Array = PackedInt64Array()
var last_tick: PackedInt32Array = PackedInt32Array()


func ensure_capacity(n: int) -> void:
	if seen_until.size() < n:
		var old: int = seen_until.size()
		seen_until.resize(n)
		last_x.resize(n)
		last_y.resize(n)
		last_tick.resize(n)
		for i: int in range(old, n):
			last_tick[i] = -1


func is_visible(id: int, tick: int) -> bool:
	return id < seen_until.size() and seen_until[id] > tick


func is_known(id: int) -> bool:
	return id < last_tick.size() and last_tick[id] >= 0


func mark_seen(id: int, x: int, y: int, tick: int, until: int) -> void:
	if seen_until[id] < until:
		seen_until[id] = until
	last_x[id] = x
	last_y[id] = y
	last_tick[id] = tick


func hash_into(h: Checksum, ids: PackedInt32Array) -> void:
	for id: int in ids:
		if id < seen_until.size():
			h.add_int(seen_until[id])
			h.add_int(last_tick[id])
