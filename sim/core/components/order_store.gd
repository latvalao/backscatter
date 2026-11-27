# SIM: deterministic — no floats, no Nodes
## Current order + queued orders per unit. Variable-length data (paths, queues)
## lives in dictionaries keyed by entity id and is only accessed by key.
class_name OrderStore
extends ComponentStore

const NONE: int = 0
const MOVE: int = 1
const ATTACK_MOVE: int = 2
const ATTACK: int = 3
const FIRE_MISSION: int = 4
const RETREAT: int = 5
const NAMES: Array[String] = ["idle", "move", "attack-move", "attack", "fire mission", "retreat"]

const FLAG_REVERSE: int = 1
const FLAG_SAFE: int = 2
const FLAG_SMOKE: int = 4

var kind: PackedInt32Array = PackedInt32Array()
var flags: PackedInt32Array = PackedInt32Array()
var goal_x: PackedInt64Array = PackedInt64Array()
var goal_y: PackedInt64Array = PackedInt64Array()
var target: PackedInt32Array = PackedInt32Array()
var path_pos: PackedInt32Array = PackedInt32Array()
var flow_id: PackedInt32Array = PackedInt32Array()
var waiting_path: PackedByteArray = PackedByteArray()
var progress_tick: PackedInt32Array = PackedInt32Array()
var progress_dist: PackedInt64Array = PackedInt64Array()
var repaths: PackedInt32Array = PackedInt32Array()
var rounds: PackedInt32Array = PackedInt32Array()

var paths: Dictionary = {}   # id -> PackedInt32Array of waypoint cells
var queue: Dictionary = {}   # id -> PackedInt64Array of (kind, flags, x, y) quads


func add(id: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	clear_current(id)


func clear_current(id: int) -> void:
	kind[id] = NONE
	flags[id] = 0
	goal_x[id] = 0
	goal_y[id] = 0
	target[id] = 0
	path_pos[id] = 0
	flow_id[id] = 0
	waiting_path[id] = 0
	progress_tick[id] = 0
	progress_dist[id] = 0
	repaths[id] = 0
	rounds[id] = 0
	paths.erase(id)


func remove(id: int) -> void:
	super.remove(id)
	paths.erase(id)
	queue.erase(id)


func has_path(id: int) -> bool:
	return paths.has(id)


func get_path(id: int) -> PackedInt32Array:
	return paths.get(id, PackedInt32Array())


func set_path(id: int, cells: PackedInt32Array) -> void:
	if cells.is_empty():
		paths.erase(id)
	else:
		paths[id] = cells
	path_pos[id] = 0


func enqueue(id: int, p_kind: int, p_flags: int, x: int, y: int) -> void:
	var q: PackedInt64Array = queue.get(id, PackedInt64Array())
	q.append_array(PackedInt64Array([p_kind, p_flags, x, y]))
	queue[id] = q


func queue_len(id: int) -> int:
	var q: PackedInt64Array = queue.get(id, PackedInt64Array())
	return q.size() / 4


## Pops the next queued order into out (kind, flags, x, y). False if empty.
func dequeue(id: int, out: PackedInt64Array) -> bool:
	if not queue.has(id):
		return false
	var q: PackedInt64Array = queue[id]
	out.resize(4)
	for i: int in range(4):
		out[i] = q[i]
	if q.size() <= 4:
		queue.erase(id)
	else:
		queue[id] = q.slice(4)
	return true


func _resize_columns(n: int) -> void:
	kind.resize(n)
	flags.resize(n)
	goal_x.resize(n)
	goal_y.resize(n)
	target.resize(n)
	path_pos.resize(n)
	flow_id.resize(n)
	waiting_path.resize(n)
	progress_tick.resize(n)
	progress_dist.resize(n)
	repaths.resize(n)
	rounds.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(kind[id])
	h.add_int(flags[id])
	h.add_int(goal_x[id])
	h.add_int(goal_y[id])
	h.add_int(target[id])
	h.add_int(path_pos[id])
	h.add_int(flow_id[id])
	h.add_int(waiting_path[id])
	h.add_int(progress_tick[id])
	h.add_int(progress_dist[id])
	h.add_int(repaths[id])
	h.add_int(rounds[id])
	for c: int in get_path(id):
		h.add_u32(c)
	var q: PackedInt64Array = queue.get(id, PackedInt64Array())
	for v: int in q:
		h.add_int(v)
