# SIM: deterministic — no floats, no Nodes
## In-flight projectiles (ATGMs, shells). Kept in launch order; compacted when resolved.
class_name ProjectileStore
extends RefCounted

var next_id: int = 1
var id: PackedInt32Array = PackedInt32Array()
var weapon: PackedInt32Array = PackedInt32Array()
var shooter: PackedInt32Array = PackedInt32Array()
var target: PackedInt32Array = PackedInt32Array()
var team: PackedInt32Array = PackedInt32Array()
var src_x: PackedInt64Array = PackedInt64Array()
var src_y: PackedInt64Array = PackedInt64Array()
var aim_x: PackedInt64Array = PackedInt64Array()
var aim_y: PackedInt64Array = PackedInt64Array()
var launch_tick: PackedInt32Array = PackedInt32Array()
var impact_tick: PackedInt32Array = PackedInt32Array()
## Hit chance permille decided at launch (direct/ATGM); -1 = guidance lost.
var accuracy: PackedInt32Array = PackedInt32Array()


func count() -> int:
	return id.size()


func launch(p_weapon: int, p_shooter: int, p_target: int, p_team: int, sx: int, sy: int,
		ax: int, ay: int, now: int, impact: int, acc: int) -> int:
	var pid: int = next_id
	next_id += 1
	id.append(pid)
	weapon.append(p_weapon)
	shooter.append(p_shooter)
	target.append(p_target)
	team.append(p_team)
	src_x.append(sx)
	src_y.append(sy)
	aim_x.append(ax)
	aim_y.append(ay)
	launch_tick.append(now)
	impact_tick.append(impact)
	accuracy.append(acc)
	return pid


## Removes entries whose keep flag is 0, preserving order.
func compact(keep: PackedByteArray) -> void:
	var n: int = 0
	for i: int in range(id.size()):
		if keep[i] == 1:
			if n != i:
				id[n] = id[i]
				weapon[n] = weapon[i]
				shooter[n] = shooter[i]
				target[n] = target[i]
				team[n] = team[i]
				src_x[n] = src_x[i]
				src_y[n] = src_y[i]
				aim_x[n] = aim_x[i]
				aim_y[n] = aim_y[i]
				launch_tick[n] = launch_tick[i]
				impact_tick[n] = impact_tick[i]
				accuracy[n] = accuracy[i]
			n += 1
	id.resize(n)
	weapon.resize(n)
	shooter.resize(n)
	target.resize(n)
	team.resize(n)
	src_x.resize(n)
	src_y.resize(n)
	aim_x.resize(n)
	aim_y.resize(n)
	launch_tick.resize(n)
	impact_tick.resize(n)
	accuracy.resize(n)


func hash_into(h: Checksum) -> void:
	h.add_int(next_id)
	for i: int in range(id.size()):
		h.add_int(id[i])
		h.add_int(target[i])
		h.add_int(aim_x[i])
		h.add_int(aim_y[i])
		h.add_int(impact_tick[i])
		h.add_int(accuracy[i])
