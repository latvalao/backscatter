# SIM: deterministic — no floats, no Nodes
## Velocity in mm per tick. Placeholder until M1 replaces it with orders + pathing.
class_name MotionStore
extends ComponentStore

var vx: PackedInt64Array = PackedInt64Array()
var vy: PackedInt64Array = PackedInt64Array()
var max_speed: PackedInt64Array = PackedInt64Array()
## Debug wander behaviour: re-roll velocity every N ticks (0 = off).
var wander_period: PackedInt64Array = PackedInt64Array()


func add(id: int, speed_cap: int, wander: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	vx[id] = 0
	vy[id] = 0
	max_speed[id] = speed_cap
	wander_period[id] = wander


func _resize_columns(n: int) -> void:
	vx.resize(n)
	vy.resize(n)
	max_speed.resize(n)
	wander_period.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(vx[id])
	h.add_int(vy[id])
	h.add_int(max_speed[id])
	h.add_int(wander_period[id])
