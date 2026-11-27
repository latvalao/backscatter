# SIM: deterministic — no floats, no Nodes
## Tick phase 6b: guides and resolves in-flight projectiles in launch order.
## Wire-guided ATGMs fail if the operator dies, is heavily suppressed or loses LOS.
class_name ProjectileSystem
extends SimSystem

const WIRE_SUPPRESSION_LIMIT: int = 600
const WIRE_LOS_INTERVAL: int = 3

var _keep: PackedByteArray = PackedByteArray()


func step(world: SimWorld, tick: int) -> void:
	var p: ProjectileStore = world.projectiles
	var n: int = p.count()
	if n == 0:
		return
	_keep.resize(n)
	for i: int in range(n):
		_keep[i] = 1
		var w: WeaponStats = world.defs.weapons[p.weapon[i]]
		var tgt: int = p.target[i]
		# guided munitions track the target
		if w.type == WeaponStats.ATGM and tgt > 0 and world.is_unit(tgt):
			p.aim_x[i] = world.transform.x[tgt]
			p.aim_y[i] = world.transform.y[tgt]
		if w.guidance == WeaponStats.GUIDE_WIRE and p.accuracy[i] >= 0:
			if not _wire_ok(world, p.shooter[i], tgt, tick, p.id[i]):
				p.accuracy[i] = -1
		if tick < p.impact_tick[i]:
			continue
		_keep[i] = 0
		_resolve(world, i, w)
	p.compact(_keep)


func _wire_ok(world: SimWorld, shooter: int, tgt: int, tick: int, pid: int) -> bool:
	if not world.is_unit(shooter) or not world.is_unit(tgt):
		return false
	if world.units.suppression[shooter] >= WIRE_SUPPRESSION_LIMIT:
		return false
	if (tick + pid) % WIRE_LOS_INTERVAL == 0 and Los.between(world, shooter, tgt) != Los.CLEAR:
		return false
	return true


func _resolve(world: SimWorld, i: int, w: WeaponStats) -> void:
	var p: ProjectileStore = world.projectiles
	var shooter: int = p.shooter[i]
	if w.is_indirect():
		Combat.apply_blast(world, p.aim_x[i], p.aim_y[i], w, shooter)
		return
	var tgt: int = p.target[i]
	if tgt > 0 and world.is_unit(tgt) and p.accuracy[i] >= 0 and world.rng.chance_permille(p.accuracy[i]):
		world.emit(SimEvent.Type.IMPACT, tgt, shooter, w.index, world.transform.x[tgt], world.transform.y[tgt])
		Combat.apply_hit(world, tgt, w, p.src_x[i], p.src_y[i], shooter)
		return
	# miss: lands near the aim point, suppresses
	var mx: int = p.aim_x[i] + world.rng.range_int(-15000, 15000)
	var my: int = p.aim_y[i] + world.rng.range_int(-15000, 15000)
	world.emit(SimEvent.Type.MISSED, shooter, tgt, w.index, mx, my)
	if tgt > 0 and world.is_unit(tgt):
		Combat.add_suppression(world, tgt, w.suppression / 4)
