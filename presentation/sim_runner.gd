## Presentation-side driver: steps the SimWorld at a fixed 10 Hz from the frame
## loop and exposes an interpolation factor. Floats are fine here — nothing in
## this file feeds back into sim state.
class_name SimRunner
extends Node

signal ticked(tick: int)

var world: SimWorld
## Sim speed multiplier (single-player/co-op: 0 = paused, 1, 2, 4).
var speed: int = 1
## Max ticks per frame, so a long hitch doesn't spiral.
var max_catch_up: int = 5

## Positions before/after the latest tick, in metres (presentation units).
var prev_pos: Dictionary = {}  # entity id -> Vector3
var curr_pos: Dictionary = {}

var _accum_ms: float = 0.0


func _process(delta: float) -> void:
	if world == null or speed <= 0:
		return
	_accum_ms += delta * 1000.0 * speed
	var steps: int = 0
	while _accum_ms >= SimConst.TICK_MS and steps < max_catch_up:
		_accum_ms -= SimConst.TICK_MS
		_step_once()
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


func snapshot_positions() -> void:
	prev_pos = curr_pos
	curr_pos = {}
	var t: TransformStore = world.transform
	for id: int in world.entities.ids():
		if t.has(id):
			curr_pos[id] = sim_to_view(t.x[id], t.y[id], t.z[id])


## Sim (x east, y north, z up, mm) -> Godot (x east, y up, -z north, m).
static func sim_to_view(x_mm: int, y_mm: int, z_mm: int) -> Vector3:
	return Vector3(x_mm * 0.001, z_mm * 0.001, -y_mm * 0.001)


func _step_once() -> void:
	world.step()
	snapshot_positions()
	ticked.emit(world.tick)
