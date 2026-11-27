## Presentation-side driver: advances the match at a fixed 10 Hz from the frame
## loop — through the Lockstep (live play, any number of peers) or a
## ReplayPlayer — and exposes an interpolation factor. Floats are fine here:
## nothing in this file feeds back into sim state.
class_name SimRunner
extends Node

signal ticked(tick: int)

var world: SimWorld
## Live play: commands and ticks go through the lockstep.
var lockstep: Lockstep
## Replay viewing: ticks come from the replay instead.
var replay: ReplayPlayer
## True while the last frame could not advance because a peer's turn is missing.
var waiting: bool = false
## Sim speed multiplier (single-player/co-op: 0 = paused, 1, 2, 4).
var speed: int = 1
## Max ticks per frame, so a long hitch doesn't spiral.
var max_catch_up: int = 4
## Wall-clock cost of the last sim tick (ms), for the HUD.
var last_tick_ms: float = 0.0

## Positions before/after the latest tick, in metres (Godot space).
var prev_pos: Dictionary = {}  # entity id -> Vector3
var curr_pos: Dictionary = {}
var prev_heading: Dictionary = {}  # entity id -> float radians (Godot yaw)
var curr_heading: Dictionary = {}

var _accum_ms: float = 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	if lockstep != null:
		lockstep.receive()
	if speed <= 0:
		return
	_accum_ms += delta * 1000.0 * speed
	var steps: int = 0
	waiting = false
	while _accum_ms >= SimConst.TICK_MS and steps < max_catch_up:
		if not _step_once():
			waiting = true
			_accum_ms = minf(_accum_ms, float(SimConst.TICK_MS))
			break
		_accum_ms -= SimConst.TICK_MS
		steps += 1
	if steps == max_catch_up:
		_accum_ms = minf(_accum_ms, float(SimConst.TICK_MS))


## 0..1 between the last two sim states.
func alpha() -> float:
	return clampf(_accum_ms / SimConst.TICK_MS, 0.0, 1.0)


func interpolated_position(id: int) -> Vector3:
	var b: Vector3 = curr_pos.get(id, Vector3.ZERO)
	var a: Vector3 = prev_pos.get(id, b)
	return a.lerp(b, alpha())


func interpolated_yaw(id: int) -> float:
	var b: float = curr_heading.get(id, 0.0)
	var a: float = prev_heading.get(id, b)
	return lerp_angle(a, b, alpha())


func snapshot() -> void:
	prev_pos = curr_pos
	prev_heading = curr_heading
	curr_pos = {}
	curr_heading = {}
	var t: TransformStore = world.transform
	for id: int in world.entities.ids():
		if t.has(id):
			curr_pos[id] = sim_to_view(t.x[id], t.y[id], t.z[id])
			curr_heading[id] = heading_to_yaw(t.heading[id])


## Sim (x east, y north, z up, mm) -> Godot (x east, y up, -z north, m).
static func sim_to_view(x_mm: int, y_mm: int, z_mm: int) -> Vector3:
	return Vector3(x_mm * 0.001, z_mm * 0.001, -y_mm * 0.001)


static func view_to_sim(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x * 1000.0), roundi(-p.z * 1000.0))


## Binary angle (CCW from east) -> Godot yaw for a model whose front is -Z.
static func heading_to_yaw(h: int) -> float:
	return float(h) / SimConst.ANGLE_FULL * TAU - PI * 0.5


## Advances one tick if possible; false if waiting on peers / replay ended.
func _step_once() -> bool:
	var t0: int = Time.get_ticks_usec()
	var ok: bool = true
	if replay != null:
		ok = replay.step()
	elif lockstep != null:
		ok = lockstep.try_advance()
	else:
		world.step()
	if not ok:
		return false
	last_tick_ms = (Time.get_ticks_usec() - t0) / 1000.0
	snapshot()
	ticked.emit(world.tick)
	return true
