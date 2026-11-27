# SIM: deterministic — no floats, no Nodes
## Uniform bucket grid of entity ids for neighbour queries. Rebuilt each tick.
## Within a bucket ids are ascending; buckets are visited row-major.
class_name SpatialHash
extends RefCounted

const BUCKET_MM: int = 32000

var bw: int = 1
var bh: int = 1
var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()


func _init(width_mm: int = 1, height_mm: int = 1) -> void:
	bw = maxi(1, (width_mm + BUCKET_MM - 1) / BUCKET_MM)
	bh = maxi(1, (height_mm + BUCKET_MM - 1) / BUCKET_MM)
	_head.resize(bw * bh)


func rebuild(world: SimWorld) -> void:
	_head.fill(-1)
	if _next.size() < world.entities.capacity():
		_next.resize(world.entities.capacity())
	var ids: PackedInt32Array = world.entities.ids()
	var t: TransformStore = world.transform
	# insert in descending order so each bucket list reads ascending
	for k: int in range(ids.size() - 1, -1, -1):
		var id: int = ids[k]
		if not t.has(id):
			continue
		var b: int = _bucket(t.x[id], t.y[id])
		_next[id] = _head[b]
		_head[b] = id


func _bucket(x: int, y: int) -> int:
	var bx: int = clampi(x / BUCKET_MM, 0, bw - 1)
	var by: int = clampi(y / BUCKET_MM, 0, bh - 1)
	return by * bw + bx


## Appends ids whose bucket overlaps the square around (x, y) +- r. Caller filters by distance.
func query(x: int, y: int, r: int, out: PackedInt32Array) -> void:
	var bx0: int = clampi((x - r) / BUCKET_MM, 0, bw - 1)
	var bx1: int = clampi((x + r) / BUCKET_MM, 0, bw - 1)
	var by0: int = clampi((y - r) / BUCKET_MM, 0, bh - 1)
	var by1: int = clampi((y + r) / BUCKET_MM, 0, bh - 1)
	for by: int in range(by0, by1 + 1):
		for bx: int in range(bx0, bx1 + 1):
			var id: int = _head[by * bw + bx]
			while id >= 0:
				out.append(id)
				id = _next[id]
