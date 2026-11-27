# SIM: deterministic — no floats, no Nodes
## Tick phase 3 (placeholder): integrates velocity, reflects off map edges,
## turns heading toward the direction of travel. M1 replaces this with
## pathfinding + steering + avoidance.
class_name MovementSystem
extends SimSystem


func step(world: SimWorld, _tick: int) -> void:
	var t: TransformStore = world.transform
	var m: MotionStore = world.motion
	for id: int in world.entities.ids():
		if not (t.has(id) and m.has(id)):
			continue
		var vx: int = m.vx[id]
		var vy: int = m.vy[id]
		if vx == 0 and vy == 0:
			continue
		var nx: int = t.x[id] + vx
		var ny: int = t.y[id] + vy
		if nx < 0 or nx > world.map_width_mm:
			vx = -vx
			nx = clampi(nx, 0, world.map_width_mm)
		if ny < 0 or ny > world.map_height_mm:
			vy = -vy
			ny = clampi(ny, 0, world.map_height_mm)
		t.x[id] = nx
		t.y[id] = ny
		m.vx[id] = vx
		m.vy[id] = vy
		t.heading[id] = FixedMath.atan2_b(vy, vx)
