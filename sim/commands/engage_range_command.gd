# SIM: deterministic — no floats, no Nodes
## Limit the distance at which units open fire (0 = weapon maximum). Units still
## return fire on whoever is hitting them.
class_name EngageRangeCommand
extends UnitCommand

var range_mm: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_range: int = 0) -> void:
	unit_ids = p_ids
	range_mm = p_range


func validate(world: SimWorld) -> bool:
	return super.validate(world) and range_mm >= 0 and range_mm <= 10000000


func apply(world: SimWorld) -> void:
	for id: int in owned(world):
		world.units.engage_range[id] = range_mm


func type_id() -> StringName:
	return &"engage_range"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_32(range_mm)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	range_mm = buf.get_32()
