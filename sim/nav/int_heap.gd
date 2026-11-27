# SIM: deterministic — no floats, no Nodes
## Binary min-heap of non-negative int keys. Callers pack (priority << k | payload)
## so ties break on payload, deterministically.
class_name IntHeap
extends RefCounted

var _a: PackedInt64Array = PackedInt64Array()
var _n: int = 0


func clear() -> void:
	_n = 0


func size() -> int:
	return _n


func is_empty() -> bool:
	return _n == 0


func push(key: int) -> void:
	if _n >= _a.size():
		_a.resize(maxi(64, _a.size() * 2))
	var i: int = _n
	_n += 1
	while i > 0:
		var p: int = (i - 1) >> 1
		var pv: int = _a[p]
		if pv <= key:
			break
		_a[i] = pv
		i = p
	_a[i] = key


func pop() -> int:
	var top: int = _a[0]
	_n -= 1
	if _n > 0:
		var last: int = _a[_n]
		var i: int = 0
		while true:
			var l: int = 2 * i + 1
			if l >= _n:
				break
			var r: int = l + 1
			var c: int = l
			if r < _n and _a[r] < _a[l]:
				c = r
			if _a[c] >= last:
				break
			_a[i] = _a[c]
			i = c
		_a[i] = last
	return top
