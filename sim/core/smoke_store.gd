# SIM: deterministic — no floats, no Nodes
## Active smoke clouds (circles). Block visual LOS; thermal sees through at reduced range.
class_name SmokeStore
extends RefCounted

var x: PackedInt64Array = PackedInt64Array()
var y: PackedInt64Array = PackedInt64Array()
var radius: PackedInt32Array = PackedInt32Array()
var expire_tick: PackedInt32Array = PackedInt32Array()


func count() -> int:
	return x.size()


func add(px: int, py: int, r: int, expire: int) -> void:
	x.append(px)
	y.append(py)
	radius.append(r)
	expire_tick.append(expire)


func expire(tick: int) -> void:
	var n: int = 0
	for i: int in range(x.size()):
		if expire_tick[i] > tick:
			x[n] = x[i]
			y[n] = y[i]
			radius[n] = radius[i]
			expire_tick[n] = expire_tick[i]
			n += 1
	x.resize(n)
	y.resize(n)
	radius.resize(n)
	expire_tick.resize(n)


## True if segment (ax,ay)-(bx,by) passes through any cloud.
func blocks(ax: int, ay: int, bx: int, by: int) -> bool:
	var dx: int = bx - ax
	var dy: int = by - ay
	var len2: int = dx * dx + dy * dy
	for i: int in range(x.size()):
		var cx: int = x[i] - ax
		var cy: int = y[i] - ay
		var t: int = 0
		if len2 > 0:
			t = clampi((cx * dx + cy * dy) / (len2 / 1000 + 1), 0, 1000)
		var px: int = (dx * t) / 1000 - cx
		var py: int = (dy * t) / 1000 - cy
		var r: int = radius[i]
		if px * px + py * py <= r * r:
			return true
	return false


func hash_into(h: Checksum) -> void:
	for i: int in range(x.size()):
		h.add_int(x[i])
		h.add_int(y[i])
		h.add_int(radius[i])
		h.add_int(expire_tick[i])
