# SIM: deterministic — no floats, no Nodes
## Infantry walk to a friendly transport and board it (one squad per free slot).
class_name MountCommand
extends UnitCommand

var carrier: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_carrier: int = 0) -> void:
	unit_ids = p_ids
	carrier = p_carrier


func validate(world: SimWorld) -> bool:
	return super.validate(world) and world.is_unit(carrier) and world.units.owner[carrier] == player_id \
		and Transport.capacity(world.def_of(carrier)) > 0


func apply(world: SimWorld) -> void:
	var slots: int = Transport.free_slots(world, carrier)
	for id: int in owned(world):
		if slots <= 0:
			break
		if not world.def_of(id).is_infantry:
			continue
		world.orders.queue.erase(id)
		Orders.start(world, id, OrderStore.MOUNT, 0, world.transform.x[carrier], world.transform.y[carrier], carrier)
		slots -= 1


func type_id() -> StringName:
	return &"mount"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_32(carrier)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	carrier = buf.get_32()
