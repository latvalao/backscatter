# SIM: deterministic — no floats, no Nodes
## Engineer tasks: salvage a wreck (wreck = its old entity id) or lay a
## minefield at (x, y). The engineer drives there and works when it arrives.
class_name EngineerTaskCommand
extends UnitCommand

const MINEFIELD_COST: int = 30

var task: int
var x_mm: int
var y_mm: int
var wreck: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_task: int = UnitStore.TASK_SALVAGE, p_x: int = 0, p_y: int = 0, p_wreck: int = 0) -> void:
	unit_ids = p_ids
	task = p_task
	x_mm = p_x
	y_mm = p_y
	wreck = p_wreck


func _engineers(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in owned(world):
		if world.def_of(id).has_ability("build"):
			out.append(id)
	return out


func validate(world: SimWorld) -> bool:
	if _engineers(world).is_empty():
		return false
	if task == UnitStore.TASK_SALVAGE:
		return world.wrecks.find(wreck) >= 0
	if task == UnitStore.TASK_LAY_MINES:
		return world.in_bounds(x_mm, y_mm) and world.players.supply[player_id] >= MINEFIELD_COST
	return false


func apply(world: SimWorld) -> void:
	var tx: int = x_mm
	var ty: int = y_mm
	if task == UnitStore.TASK_SALVAGE:
		var wi: int = world.wrecks.find(wreck)
		tx = world.wrecks.x[wi]
		ty = world.wrecks.y[wi]
	else:
		world.players.supply[player_id] -= MINEFIELD_COST
	var eng: PackedInt32Array = _engineers(world)
	if task == UnitStore.TASK_LAY_MINES:
		eng = PackedInt32Array([eng[0]])
	for id: int in eng:
		world.orders.queue.erase(id)
		Orders.start(world, id, OrderStore.MOVE, 0, tx, ty, 0)
		world.units.task[id] = task
		world.units.task_x[id] = tx
		world.units.task_y[id] = ty
		world.units.task_arg[id] = wreck


func type_id() -> StringName:
	return &"engineer_task"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_u8(task)
	buf.put_64(x_mm)
	buf.put_64(y_mm)
	buf.put_32(wreck)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	task = buf.get_u8()
	x_mm = buf.get_64()
	y_mm = buf.get_64()
	wreck = buf.get_32()
