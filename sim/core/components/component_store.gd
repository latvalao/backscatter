# SIM: deterministic — no floats, no Nodes
## Base for struct-of-arrays component stores indexed by entity id.
class_name ComponentStore
extends RefCounted

var present: PackedByteArray = PackedByteArray()


func has(id: int) -> bool:
	return id < present.size() and present[id] == 1


func ensure_capacity(n: int) -> void:
	if present.size() < n:
		present.resize(n)
		_resize_columns(n)


func remove(id: int) -> void:
	if has(id):
		present[id] = 0


## Override: resize every column to n.
func _resize_columns(_n: int) -> void:
	pass


## Override: feed every column value of entity id into the checksum.
func hash_entity(_id: int, _h: Checksum) -> void:
	pass
