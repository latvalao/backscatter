# SIM: deterministic — no floats, no Nodes
## Move / attack-move / reverse-move to a point, as a formation. queue = Shift.
class_name MoveCommand
extends UnitCommand

const MODE_MOVE: int = 0
const MODE_ATTACK_MOVE: int = 1
const MODE_REVERSE: int = 2

var x_mm: int
var y_mm: int
var mode: int
var queue: bool
var safe: bool
## Formation.BLOCK / LINE / COLUMN / WEDGE.
var formation: int
## Final facing (binary angle), -1 = keep direction of travel.
var face: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_x: int = 0, p_y: int = 0,
		p_mode: int = MODE_MOVE, p_queue: bool = false, p_safe: bool = false, p_formation: int = 0, p_face: int = -1) -> void:
	unit_ids = p_ids
	x_mm = p_x
	y_mm = p_y
	mode = p_mode
	queue = p_queue
	safe = p_safe
	formation = p_formation
	face = p_face


func validate(world: SimWorld) -> bool:
	return super.validate(world) and world.in_bounds(x_mm, y_mm) and mode >= 0 and mode <= 2 \
		and formation >= 0 and formation <= Formation.WEDGE and face >= -1 and face < SimConst.ANGLE_FULL


func apply(world: SimWorld) -> void:
	var kind: int = OrderStore.ATTACK_MOVE if mode == MODE_ATTACK_MOVE else OrderStore.MOVE
	var flags: int = 0
	if mode == MODE_REVERSE:
		flags |= OrderStore.FLAG_REVERSE
	if safe:
		flags |= OrderStore.FLAG_SAFE
	Orders.start_group(world, owned(world), kind, flags, x_mm, y_mm, queue, formation, face)


func type_id() -> StringName:
	return &"move"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_64(x_mm)
	buf.put_64(y_mm)
	buf.put_u8(mode)
	buf.put_u8(int(queue) | (int(safe) << 1))
	buf.put_u8(formation)
	buf.put_32(face)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	x_mm = buf.get_64()
	y_mm = buf.get_64()
	mode = buf.get_u8()
	var f: int = buf.get_u8()
	queue = (f & 1) != 0
	safe = (f & 2) != 0
	formation = buf.get_u8()
	face = buf.get_32()
