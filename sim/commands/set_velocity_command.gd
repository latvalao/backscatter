# SIM: deterministic — no floats, no Nodes
## M0 debug command: sets an entity's velocity directly. M1 replaces this with
## MoveCommand (pathfinding orders).
class_name SetVelocityCommand
extends SimCommand

var entity_id: int
var vx: int
var vy: int


func _init(p_entity_id: int = 0, p_vx: int = 0, p_vy: int = 0) -> void:
	entity_id = p_entity_id
	vx = p_vx
	vy = p_vy


func validate(world: SimWorld) -> bool:
	return world.entities.is_alive(entity_id) and world.motion.has(entity_id)


func apply(world: SimWorld) -> void:
	var cap: int = world.motion.max_speed[entity_id]
	world.motion.vx[entity_id] = clampi(vx, -cap, cap)
	world.motion.vy[entity_id] = clampi(vy, -cap, cap)
	world.motion.wander_period[entity_id] = 0


func type_id() -> StringName:
	return &"set_velocity"
