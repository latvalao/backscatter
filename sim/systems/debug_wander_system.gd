# SIM: deterministic — no floats, no Nodes
## M0 debug "AI" (tick phase 2): entities with wander_period > 0 pick a new
## random heading/speed every wander_period ticks. Exercises SimRng + FixedMath.
class_name DebugWanderSystem
extends SimSystem


func step(world: SimWorld, tick: int) -> void:
	var m: MotionStore = world.motion
	for id: int in world.entities.ids():
		if not m.has(id):
			continue
		var period: int = m.wander_period[id]
		if period <= 0 or (tick + id) % period != 0:
			continue
		var angle: int = world.rng.range_int(0, SimConst.ANGLE_MASK)
		var speed: int = world.rng.range_int(0, m.max_speed[id])
		m.vx[id] = (speed * FixedMath.cos_b(angle)) >> FixedMath.SHIFT
		m.vy[id] = (speed * FixedMath.sin_b(angle)) >> FixedMath.SHIFT
