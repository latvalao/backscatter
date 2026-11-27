## Message switch for LoopbackTransports. Each delivery waits `delay` polls of
## the receiver (+ up to `jitter`, from a seeded RNG), preserving per-link order.
class_name LoopbackHub
extends RefCounted

var delay: int = 0
var jitter: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _queues: Dictionary = {}   # conn -> Array of [due_poll, from, data]
var _polls: Dictionary = {}    # conn -> poll counter
var _last_due: Dictionary = {} # "from>to" -> last due (keeps order)


func _init(p_delay: int = 0, p_jitter: int = 0, seed_value: int = 1) -> void:
	delay = p_delay
	jitter = p_jitter
	_rng.seed = seed_value


func register(t: LoopbackTransport) -> void:
	_queues[t.conn_id] = []
	_polls[t.conn_id] = 0
	for c: int in _queues.keys():
		if c != t.conn_id:
			_push(c, t.conn_id, NetTransport.conn_event("connected", t.conn_id))
			_push(t.conn_id, c, NetTransport.conn_event("connected", c))


func endpoints() -> Array:
	var keys: Array = _queues.keys()
	keys.sort()
	return keys


func deliver(from: int, to: int, data: PackedByteArray) -> void:
	if not _queues.has(to):
		return
	_push(to, from, NetTransport.data_event(from, data))


func _push(to: int, from: int, ev: Dictionary) -> void:
	var due: int = int(_polls[to]) + delay + (_rng.randi_range(0, jitter) if jitter > 0 else 0)
	var key: String = "%d>%d" % [from, to]
	due = maxi(due, int(_last_due.get(key, 0)))
	_last_due[key] = due
	var q: Array = _queues[to]
	q.append([due, ev])


func collect(conn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_polls[conn] = int(_polls[conn]) + 1
	var now: int = _polls[conn]
	var q: Array = _queues[conn]
	var keep: Array = []
	for item: Array in q:
		if int(item[0]) <= now:
			out.append(item[1] as Dictionary)
		else:
			keep.append(item)
	_queues[conn] = keep
	return out
