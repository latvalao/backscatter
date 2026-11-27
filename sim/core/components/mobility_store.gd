# SIM: deterministic — no floats, no Nodes
## Movement state. Static movement stats come from the unit's UnitStats.
class_name MobilityStore
extends ComponentStore

var mobility_class: PackedInt32Array = PackedInt32Array()
## Current signed speed along heading (mm/tick); negative = reversing.
var speed: PackedInt32Array = PackedInt32Array()
## Ticks spent nearly stationary while trying to move (crowd arrival).
var blocked_ticks: PackedInt32Array = PackedInt32Array()
## Facing to turn to when idle (binary angle), -1 = none.
var face: PackedInt32Array = PackedInt32Array()
## Group move speed limit in mm/tick (0 = none): formation keeps the slowest pace.
var speed_cap: PackedInt32Array = PackedInt32Array()


func add(id: int, p_class: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	mobility_class[id] = p_class
	speed[id] = 0
	blocked_ticks[id] = 0
	face[id] = -1
	speed_cap[id] = 0


func _resize_columns(n: int) -> void:
	mobility_class.resize(n)
	speed.resize(n)
	blocked_ticks.resize(n)
	face.resize(n)
	speed_cap.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(mobility_class[id])
	h.add_int(speed[id])
	h.add_int(blocked_ticks[id])
	h.add_int(face[id])
	h.add_int(speed_cap[id])
