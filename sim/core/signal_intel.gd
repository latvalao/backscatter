# SIM: deterministic — no floats, no Nodes
## One team's signals intelligence (§5.5): recent DF bearings and the current
## fixes (estimated emitter positions with an uncertainty radius).
class_name SignalIntel
extends RefCounted

const BEARING_TTL: int = 60
const FIX_TTL: int = 300

# bearings (parallel arrays, append-only then pruned)
var b_emitter: PackedInt32Array = PackedInt32Array()
var b_src_x: PackedInt64Array = PackedInt64Array()
var b_src_y: PackedInt64Array = PackedInt64Array()
var b_angle: PackedInt32Array = PackedInt32Array()
var b_error: PackedInt32Array = PackedInt32Array()   # binary angle half-width
var b_tick: PackedInt32Array = PackedInt32Array()

# fixes keyed by emitter id (lookup only; iterate sorted keys)
var fix_x: Dictionary = {}
var fix_y: Dictionary = {}
var fix_r: Dictionary = {}
var fix_tick: Dictionary = {}
var fix_kind: Dictionary = {}


func add_bearing(emitter: int, sx: int, sy: int, angle: int, err: int, tick: int) -> void:
	b_emitter.append(emitter)
	b_src_x.append(sx)
	b_src_y.append(sy)
	b_angle.append(angle)
	b_error.append(err)
	b_tick.append(tick)


func prune(tick: int) -> void:
	var n: int = 0
	for i: int in range(b_tick.size()):
		if tick - b_tick[i] <= BEARING_TTL:
			b_emitter[n] = b_emitter[i]
			b_src_x[n] = b_src_x[i]
			b_src_y[n] = b_src_y[i]
			b_angle[n] = b_angle[i]
			b_error[n] = b_error[i]
			b_tick[n] = b_tick[i]
			n += 1
	b_emitter.resize(n)
	b_src_x.resize(n)
	b_src_y.resize(n)
	b_angle.resize(n)
	b_error.resize(n)
	b_tick.resize(n)
	var stale: Array = []
	for k: int in fix_tick.keys():
		if tick - int(fix_tick[k]) > FIX_TTL:
			stale.append(k)
	for k: int in stale:
		forget(k)


func set_fix(emitter: int, x: int, y: int, r: int, tick: int, kind: int) -> void:
	# keep the better (smaller) fix while it is fresh
	if fix_r.has(emitter) and int(fix_r[emitter]) < r and tick - int(fix_tick[emitter]) < 50:
		return
	fix_x[emitter] = x
	fix_y[emitter] = y
	fix_r[emitter] = r
	fix_tick[emitter] = tick
	fix_kind[emitter] = kind


func forget(emitter: int) -> void:
	fix_x.erase(emitter)
	fix_y.erase(emitter)
	fix_r.erase(emitter)
	fix_tick.erase(emitter)
	fix_kind.erase(emitter)


func fixes() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for k: int in fix_r.keys():
		out.append(k)
	out.sort()
	return out


## True if (x, y) lies inside a fix no wider than max_radius (valid artillery target).
func targetable(x: int, y: int, max_radius: int) -> bool:
	for k: int in fixes():
		var r: int = fix_r[k]
		if r > max_radius:
			continue
		var dx: int = x - int(fix_x[k])
		var dy: int = y - int(fix_y[k])
		if dx * dx + dy * dy <= (r + 25000) * (r + 25000):
			return true
	return false


func hash_into(h: Checksum) -> void:
	h.add_int(b_emitter.size())
	for k: int in fixes():
		h.add_int(k)
		h.add_int(fix_x[k])
		h.add_int(fix_y[k])
		h.add_int(fix_r[k])
