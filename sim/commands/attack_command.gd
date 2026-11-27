# SIM: deterministic — no floats, no Nodes
## Engage a specific enemy unit: close to weapon range and fire.
class_name AttackCommand
extends UnitCommand

var target_id: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_target: int = 0) -> void:
	unit_ids = p_ids
	target_id = p_target


func validate(world: SimWorld) -> bool:
	if not super.validate(world) or not world.is_unit(target_id):
		return false
	var team: int = world.team_of_player(player_id)
	return world.units.team[target_id] != team and world.vision[team].is_known(target_id)


func apply(world: SimWorld) -> void:
	var team: int = world.team_of_player(player_id)
	var lx: int = world.vision[team].last_x[target_id]
	var ly: int = world.vision[team].last_y[target_id]
	for id: int in owned(world):
		world.orders.queue.erase(id)
		Orders.start(world, id, OrderStore.ATTACK, 0, lx, ly, target_id)


func type_id() -> StringName:
	return &"attack"
