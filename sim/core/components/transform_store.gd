# SIM: deterministic — no floats, no Nodes
## Position (mm) and heading (binary angle). y is the map's north axis; z is height.
class_name TransformStore
extends ComponentStore

var x: PackedInt64Array = PackedInt64Array()
var y: PackedInt64Array = PackedInt64Array()
var z: PackedInt64Array = PackedInt64Array()
var heading: PackedInt64Array = PackedInt64Array()


func add(id: int, px: int, py: int, pz: int, h: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	x[id] = px
	y[id] = py
	z[id] = pz
	heading[id] = h & SimConst.ANGLE_MASK


func _resize_columns(n: int) -> void:
	x.resize(n)
	y.resize(n)
	z.resize(n)
	heading.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(x[id])
	h.add_int(y[id])
	h.add_int(z[id])
	h.add_int(heading[id])
