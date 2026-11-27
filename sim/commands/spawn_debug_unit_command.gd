# SIM: deterministic — no floats, no Nodes
## M0 debug command: spawns a placeholder unit. Replaced by data-driven
## production in M2/M4.
class_name SpawnDebugUnitCommand
extends SimCommand

var x_mm: int
var y_mm: int
var team: int
var speed_cap: int
var wander_period: int


func _init(p_x_mm: int = 0, p_y_mm: int = 0, p_team: int = 0, p_speed_cap: int = 1000, p_wander_period: int = 0) -> void:
	x_mm = p_x_mm
	y_mm = p_y_mm
	team = p_team
	speed_cap = p_speed_cap
	wander_period = p_wander_period


func validate(world: SimWorld) -> bool:
	return world.in_bounds(x_mm, y_mm) and speed_cap >= 0 and wander_period >= 0


func apply(world: SimWorld) -> void:
	world.spawn_debug_unit(x_mm, y_mm, team, speed_cap, wander_period)


func type_id() -> StringName:
	return &"spawn_debug_unit"
