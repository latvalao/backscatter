# SIM: deterministic — no floats, no Nodes
## Laid mines. Hidden from the enemy until something hits one, an engineer clears
## it or recon finds it (known = bitmask of teams that know about the mine).
class_name MineStore
extends RefCounted

var x: PackedInt64Array = PackedInt64Array()
var y: PackedInt64Array = PackedInt64Array()
var team: PackedInt32Array = PackedInt32Array()
var known: PackedInt32Array = PackedInt32Array()


func count() -> int:
	return x.size()


func add(px: int, py: int, p_team: int) -> void:
	x.append(px)
	y.append(py)
	team.append(p_team)
	known.append(1 << p_team)


func remove_at(i: int) -> void:
	x.remove_at(i)
	y.remove_at(i)
	team.remove_at(i)
	known.remove_at(i)


func is_known(i: int, p_team: int) -> bool:
	return (known[i] & (1 << p_team)) != 0


func hash_into(h: Checksum) -> void:
	h.add_int(x.size())
	for i: int in range(x.size()):
		h.add_int(x[i])
		h.add_int(y[i])
		h.add_int(team[i])
		h.add_int(known[i])
