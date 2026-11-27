# SIM: deterministic — no floats, no Nodes
## Cancels current and queued orders.
class_name StopCommand
extends UnitCommand


func _init(p_ids: PackedInt32Array = PackedInt32Array()) -> void:
	unit_ids = p_ids


func apply(world: SimWorld) -> void:
	for id: int in owned(world):
		world.orders.queue.erase(id)
		world.release_flow(id)
		world.orders.clear_current(id)


func type_id() -> StringName:
	return &"stop"
