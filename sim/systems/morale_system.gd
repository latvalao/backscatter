# SIM: deterministic — no floats, no Nodes
## Tick phase 7: suppression decay, morale recovery, pinning and retreat.
## Thresholds shift with unit quality (base morale).
class_name MoraleSystem
extends SimSystem

const PIN_THRESHOLD: int = 600
const BREAK_THRESHOLD: int = 900
const RETREAT_DISTANCE_MM: int = 150000
const QUIET_TICKS: int = 20


func step(world: SimWorld, tick: int) -> void:
	var u: UnitStore = world.units
	for id: int in world.entities.ids():
		if not world.is_unit(id):
			continue
		var def: UnitStats = world.def_of(id)
		var quiet: bool = tick - u.last_hit_tick[id] > QUIET_TICKS
		var s: int = u.suppression[id]
		if s > 0:
			# better troops shake off suppression faster
			var decay: int = (8 + def.morale / 100) if quiet else 2
			u.suppression[id] = maxi(0, s - decay)
		if quiet and u.suppression[id] < 200 and u.morale[id] < def.morale and tick % 5 == 0:
			u.morale[id] += 1
		if def.is_infantry and u.suppression[id] >= BREAK_THRESHOLD and u.morale[id] < 400 \
				and world.orders.kind[id] != OrderStore.RETREAT:
			_retreat(world, id)


func _retreat(world: SimWorld, id: int) -> void:
	var t: TransformStore = world.transform
	var away: int = (t.heading[id] + SimConst.ANGLE_HALF) & SimConst.ANGLE_MASK
	var att: int = world.units.last_attacker[id]
	if world.is_unit(att):
		away = FixedMath.atan2_b(t.y[id] - t.y[att], t.x[id] - t.x[att])
	var x: int = t.x[id] + (RETREAT_DISTANCE_MM * FixedMath.cos_b(away)) / FixedMath.ONE
	var y: int = t.y[id] + (RETREAT_DISTANCE_MM * FixedMath.sin_b(away)) / FixedMath.ONE
	world.orders.queue.erase(id)
	Orders.start(world, id, OrderStore.RETREAT, 0, x, y, 0)
