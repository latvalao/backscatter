# SIM: deterministic — no floats, no Nodes
## Emission control (§5.5): EMIT / RESTRICTED / SILENT per unit. Jammers and
## radars only transmit on EMIT; SILENT units leave the radio net.
class_name EmconCommand
extends UnitCommand

var level: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_level: int = 0) -> void:
	unit_ids = p_ids
	level = p_level


func validate(world: SimWorld) -> bool:
	return super.validate(world) and level >= UnitStore.EMCON_EMIT and level <= UnitStore.EMCON_SILENT


func apply(world: SimWorld) -> void:
	for id: int in owned(world):
		world.units.emcon[id] = level


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_u8(level)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	level = buf.get_u8()


func type_id() -> StringName:
	return &"emcon"
