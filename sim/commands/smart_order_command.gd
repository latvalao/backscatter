# SIM: deterministic — no floats, no Nodes
## Smart orders (FEATURES phase 5):
##   SEIZE     attack-move to the point in a wedge facing it; infantry then dig in
##   OVERWATCH stay put and cover the sector toward the point (±45°), firing only
##             inside it and inside the distance to the point
##   AUTO_CB   toggle automatic counter-battery fire (artillery)
##   ROTATE    toggle crew rotation (irradiated units go for treatment, then return)
##   CLEAR     drop overwatch and engagement limits
class_name SmartOrderCommand
extends UnitCommand

const SEIZE: int = 0
const OVERWATCH: int = 1
const AUTO_CB: int = 2
const ROTATE: int = 3
const CLEAR: int = 4
const NAMES: Array[String] = ["seize", "overwatch", "auto counter-battery", "crew rotation", "clear"]

var order: int
var x_mm: int
var y_mm: int
var on: bool


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_order: int = SEIZE, p_x: int = 0, p_y: int = 0, p_on: bool = true) -> void:
	unit_ids = p_ids
	order = p_order
	x_mm = p_x
	y_mm = p_y
	on = p_on


func validate(world: SimWorld) -> bool:
	if order < SEIZE or order > CLEAR or not super.validate(world):
		return false
	return (order != SEIZE and order != OVERWATCH) or world.in_bounds(x_mm, y_mm)


func apply(world: SimWorld) -> void:
	var ids: PackedInt32Array = owned(world)
	var u: UnitStore = world.units
	match order:
		SEIZE:
			var t: TransformStore = world.transform
			var cx: int = 0
			var cy: int = 0
			for id: int in ids:
				cx += t.x[id]
				cy += t.y[id]
				u.overwatch_dir[id] = -1
			cx /= ids.size()
			cy /= ids.size()
			var face: int = FixedMath.atan2_b(y_mm - cy, x_mm - cx)
			Orders.start_group(world, ids, OrderStore.ATTACK_MOVE, 0, x_mm, y_mm, false, Formation.WEDGE, face)
		OVERWATCH:
			for id2: int in ids:
				var d: int = FixedMath.length2(x_mm - world.transform.x[id2], y_mm - world.transform.y[id2])
				u.overwatch_dir[id2] = FixedMath.atan2_b(y_mm - world.transform.y[id2], x_mm - world.transform.x[id2])
				u.engage_range[id2] = maxi(50000, d)
				world.mobility.face[id2] = u.overwatch_dir[id2]
				world.release_flow(id2)
				world.orders.clear_current(id2)
				world.orders.queue.erase(id2)
		AUTO_CB:
			for id3: int in ids:
				u.smart[id3] = (u.smart[id3] | UnitStore.SMART_AUTO_CB) if on else (u.smart[id3] & ~UnitStore.SMART_AUTO_CB)
		ROTATE:
			for id4: int in ids:
				u.smart[id4] = (u.smart[id4] | UnitStore.SMART_ROTATE) if on else (u.smart[id4] & ~(UnitStore.SMART_ROTATE | UnitStore.SMART_ROTATING))
		CLEAR:
			for id5: int in ids:
				u.overwatch_dir[id5] = -1
				u.engage_range[id5] = 0


func type_id() -> StringName:
	return &"smart"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_u8(order)
	buf.put_64(x_mm)
	buf.put_64(y_mm)
	buf.put_u8(int(on))


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	order = buf.get_u8()
	x_mm = buf.get_64()
	y_mm = buf.get_64()
	on = buf.get_u8() == 1
