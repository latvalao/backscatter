# SIM: deterministic — no floats, no Nodes
## Allocates entity ids. Ids are monotonic and never reused within a match, so
## ascending-id iteration is a stable, deterministic order.
class_name EntityStore
extends RefCounted

var _next_id: int = 1
var _alive: PackedByteArray = PackedByteArray([0])
var _count: int = 0


func create() -> int:
	var id: int = _next_id
	_next_id += 1
	_alive.resize(_next_id)
	_alive[id] = 1
	_count += 1
	return id


func destroy(id: int) -> void:
	if is_alive(id):
		_alive[id] = 0
		_count -= 1


func is_alive(id: int) -> bool:
	return id > 0 and id < _next_id and _alive[id] == 1


func count() -> int:
	return _count


## Upper bound (exclusive) for ids; component stores size themselves to this.
func capacity() -> int:
	return _next_id


## Alive ids in ascending order.
func ids() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(_count)
	var n: int = 0
	for id: int in range(1, _next_id):
		if _alive[id] == 1:
			out[n] = id
			n += 1
	return out
