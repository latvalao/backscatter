# SIM: deterministic — no floats, no Nodes
## Structure state: footprint, construction, production queue, rally point,
## and (for depot objectives) capture / stock / supply-route status.
class_name StructureStore
extends ComponentStore

var cell_x: PackedInt32Array = PackedInt32Array()   # footprint origin (south-west cell)
var cell_y: PackedInt32Array = PackedInt32Array()
## Construction work remaining, in 1/100 builder-ticks (0 = complete).
var build_left: PackedInt32Array = PackedInt32Array()  # in 1/100 builder-ticks
## Ticks left on the unit at the head of the production queue.
var prod_left: PackedInt32Array = PackedInt32Array()
var rally_x: PackedInt64Array = PackedInt64Array()
var rally_y: PackedInt64Array = PackedInt64Array()
## Depot objectives: owning team (-1 none), player credited with income,
## capturing team and its progress (ticks), stored supply, route connected flag.
var holder_team: PackedInt32Array = PackedInt32Array()
var holder_player: PackedInt32Array = PackedInt32Array()
var capture_team: PackedInt32Array = PackedInt32Array()
var capture_progress: PackedInt32Array = PackedInt32Array()
var stock: PackedInt32Array = PackedInt32Array()
var connected: PackedByteArray = PackedByteArray()

var queue: Dictionary = {}  # id -> PackedInt32Array of unit def indices


func add(id: int, cx: int, cy: int, build_ticks: int, rx: int, ry: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	cell_x[id] = cx
	cell_y[id] = cy
	build_left[id] = build_ticks
	prod_left[id] = 0
	rally_x[id] = rx
	rally_y[id] = ry
	holder_team[id] = -1
	holder_player[id] = -1
	capture_team[id] = -1
	capture_progress[id] = 0
	stock[id] = 0
	connected[id] = 0


func is_complete(id: int) -> bool:
	return has(id) and build_left[id] <= 0


func get_queue(id: int) -> PackedInt32Array:
	return queue.get(id, PackedInt32Array())


func set_queue(id: int, q: PackedInt32Array) -> void:
	if q.is_empty():
		queue.erase(id)
	else:
		queue[id] = q


func remove(id: int) -> void:
	super.remove(id)
	queue.erase(id)


func _resize_columns(n: int) -> void:
	cell_x.resize(n)
	cell_y.resize(n)
	build_left.resize(n)
	prod_left.resize(n)
	rally_x.resize(n)
	rally_y.resize(n)
	holder_team.resize(n)
	holder_player.resize(n)
	capture_team.resize(n)
	capture_progress.resize(n)
	stock.resize(n)
	connected.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(cell_x[id])
	h.add_int(cell_y[id])
	h.add_int(build_left[id])
	h.add_int(prod_left[id])
	h.add_int(rally_x[id])
	h.add_int(rally_y[id])
	h.add_int(holder_team[id])
	h.add_int(holder_player[id])
	h.add_int(capture_team[id])
	h.add_int(capture_progress[id])
	h.add_int(stock[id])
	h.add_int(connected[id])
	for d: int in get_queue(id):
		h.add_u32(d)
