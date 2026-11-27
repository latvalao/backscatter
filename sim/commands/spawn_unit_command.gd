# SIM: deterministic — no floats, no Nodes
## Scenario / debug spawn. M4 replaces player use with production queues.
class_name SpawnUnitCommand
extends SimCommand

var unit_def: String
var x_mm: int
var y_mm: int
var heading: int


func _init(p_def: String = "", p_x: int = 0, p_y: int = 0, p_heading: int = 0) -> void:
	unit_def = p_def
	x_mm = p_x
	y_mm = p_y
	heading = p_heading


func validate(world: SimWorld) -> bool:
	return world.defs.unit_index(unit_def) >= 0 and world.in_bounds(x_mm, y_mm) \
		and world.team_of_player(player_id) >= 0


func apply(world: SimWorld) -> void:
	world.spawn_unit(world.defs.unit(unit_def), world.team_of_player(player_id), player_id, x_mm, y_mm, heading)


func type_id() -> StringName:
	return &"spawn_unit"
