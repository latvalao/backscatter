# SIM: deterministic — no floats, no Nodes
## Unload transports now, or drive to (x, y) and unload there. Selected
## passengers make their own carrier unload.
class_name UnloadCommand
extends UnitCommand

var x_mm: int
var y_mm: int
var at_point: bool


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_x: int = 0, p_y: int = 0, p_at_point: bool = false) -> void:
	unit_ids = p_ids
	x_mm = p_x
	y_mm = p_y
	at_point = p_at_point


func validate(world: SimWorld) -> bool:
	return not owned(world, true).is_empty() and (not at_point or world.in_bounds(x_mm, y_mm))


func _carriers(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in owned(world, true):
		var c: int = world.units.carrier[id] if world.units.carrier[id] != 0 else id
		if world.is_unit(c) and Transport.capacity(world.def_of(c)) > 0 and not out.has(c):
			out.append(c)
	out.sort()
	return out


func apply(world: SimWorld) -> void:
	var cs: PackedInt32Array = _carriers(world)
	if at_point:
		Orders.start_group(world, cs, OrderStore.MOVE, OrderStore.FLAG_UNLOAD, x_mm, y_mm, false)
	else:
		for c: int in cs:
			Transport.unload(world, c)


func type_id() -> StringName:
	return &"unload"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_64(x_mm)
	buf.put_64(y_mm)
	buf.put_u8(int(at_point))


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	x_mm = buf.get_64()
	y_mm = buf.get_64()
	at_point = buf.get_u8() == 1
