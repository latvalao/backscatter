# SIM: deterministic — no floats, no Nodes
## Sets where newly produced units drive to.
class_name RallyCommand
extends SimCommand

var building: int
var x_mm: int
var y_mm: int


func _init(p_building: int = 0, p_x: int = 0, p_y: int = 0) -> void:
	building = p_building
	x_mm = p_x
	y_mm = p_y


func validate(world: SimWorld) -> bool:
	return world.is_unit(building) and world.structures.has(building) \
		and world.units.owner[building] == player_id and world.in_bounds(x_mm, y_mm)


func apply(world: SimWorld) -> void:
	world.structures.rally_x[building] = x_mm
	world.structures.rally_y[building] = y_mm


func write(buf: StreamPeerBuffer) -> void:
	buf.put_32(building)
	buf.put_64(x_mm)
	buf.put_64(y_mm)


func read(buf: StreamPeerBuffer) -> void:
	building = buf.get_32()
	x_mm = buf.get_64()
	y_mm = buf.get_64()


func type_id() -> StringName:
	return &"rally"
