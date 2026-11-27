# SIM: deterministic — no floats, no Nodes
## Fire at will / hold fire.
class_name StanceCommand
extends UnitCommand

var stance: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_stance: int = 0) -> void:
	unit_ids = p_ids
	stance = p_stance


func validate(world: SimWorld) -> bool:
	return super.validate(world) and (stance == UnitStore.STANCE_FIRE_AT_WILL or stance == UnitStore.STANCE_HOLD_FIRE)


func apply(world: SimWorld) -> void:
	for id: int in owned(world):
		world.units.stance[id] = stance


func type_id() -> StringName:
	return &"stance"
