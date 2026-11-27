# SIM: deterministic — no floats, no Nodes
## Destroyed vehicles left on the field. Engineers salvage them for SUPPLY.
## `entity` is the id the vehicle had, so presentation can match its wreck view.
class_name WreckStore
extends RefCounted

var entity: PackedInt32Array = PackedInt32Array()
var def_index: PackedInt32Array = PackedInt32Array()
var x: PackedInt64Array = PackedInt64Array()
var y: PackedInt64Array = PackedInt64Array()
var value: PackedInt32Array = PackedInt32Array()
## Salvage progress in ticks.
var progress: PackedInt32Array = PackedInt32Array()


func count() -> int:
	return entity.size()


func add(p_entity: int, p_def: int, px: int, py: int, p_value: int) -> void:
	entity.append(p_entity)
	def_index.append(p_def)
	x.append(px)
	y.append(py)
	value.append(p_value)
	progress.append(0)


func find(p_entity: int) -> int:
	for i: int in range(entity.size()):
		if entity[i] == p_entity:
			return i
	return -1


func remove_at(i: int) -> void:
	entity.remove_at(i)
	def_index.remove_at(i)
	x.remove_at(i)
	y.remove_at(i)
	value.remove_at(i)
	progress.remove_at(i)


func hash_into(h: Checksum) -> void:
	h.add_int(entity.size())
	for i: int in range(entity.size()):
		h.add_int(entity[i])
		h.add_int(x[i])
		h.add_int(y[i])
		h.add_int(value[i])
		h.add_int(progress[i])
