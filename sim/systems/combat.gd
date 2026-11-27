# SIM: deterministic — no floats, no Nodes
## Combat rules shared by weapon/projectile systems: armour facing, penetration,
## hit chance, and applying hits/blasts to units.
class_name Combat
extends RefCounted

const FACE_FRONT: int = 0
const FACE_SIDE: int = 1
const FACE_REAR: int = 2
const FACE_TOP: int = 3

## 45° and 135° in binary angle units.
const FRONT_ARC: int = 8192
const REAR_ARC: int = 24576

const MORALE_LOSS_PER_DEATH: int = 90
const SMOKE_ROUND_RADIUS_MM: int = 25000
const SMOKE_ROUND_TICKS: int = 450


## Which armour face of a target (at tx,ty facing `heading`) a shot from (sx,sy) strikes.
static func facing(heading: int, tx: int, ty: int, sx: int, sy: int) -> int:
	if sx == tx and sy == ty:
		return FACE_FRONT
	var to_shooter: int = FixedMath.atan2_b(sy - ty, sx - tx)
	var rel: int = absi(FixedMath.angle_diff(heading, to_shooter))
	if rel <= FRONT_ARC:
		return FACE_FRONT
	if rel >= REAR_ARC:
		return FACE_REAR
	return FACE_SIDE


static func armour_for(def: UnitStats, face: int) -> int:
	match face:
		FACE_FRONT:
			return def.armour_front
		FACE_SIDE:
			return def.armour_side
		FACE_REAR:
			return def.armour_rear
	return def.armour_top


static func penetrates(penetration: int, armour: int) -> bool:
	return penetration >= armour


## Hit chance permille for shooter firing weapon w at target over distance dist.
static func hit_chance(world: SimWorld, shooter: int, target: int, w: WeaponStats, dist: int) -> int:
	var u: UnitStore = world.units
	var sd: UnitStats = world.def_of(shooter)
	var td: UnitStats = world.def_of(target)
	var acc: int = w.accuracy_at(dist)
	if absi(world.mobility.speed[shooter]) * 10 > sd.max_speed:
		acc = acc * (750 if sd.stabilized else 300) / 1000
	var supp: int = u.suppression[shooter]
	if sd.is_infantry:
		acc = acc * (1000 - supp * 7 / 10) / 1000
	else:
		acc = acc * (1000 - supp * 4 / 10) / 1000
	if (u.damage[shooter] & UnitStore.DMG_OPTICS) != 0:
		acc = acc * 700 / 1000
	acc = acc * DoseState.accuracy(world, shooter) / 1000
	acc = acc * [700, 1000, 1150][td.size_class] / 1000
	if world.mobility.has(target) and absi(world.mobility.speed[target]) * 10 > td.max_speed:
		acc = acc * 850 / 1000
	acc = acc * (1000 - infantry_cover(world, target, td)) / 1000
	if td.is_vehicle():
		acc = acc * (1000 - world.fortification_cover(world.transform.x[target], world.transform.y[target], false)) / 1000
	return clampi(acc, 10, 970)


## Effective cover permille for an infantry target (terrain or trench, whichever is better).
static func infantry_cover(world: SimWorld, target: int, td: UnitStats) -> int:
	if not td.is_infantry:
		return 0
	var x: int = world.transform.x[target]
	var y: int = world.transform.y[target]
	return maxi(TerrainTable.COVER[world.grid.terrain_at(x, y)], world.fortification_cover(x, y, true))


## Direct/ATGM hit on target from position (sx, sy).
static func apply_hit(world: SimWorld, target: int, w: WeaponStats, sx: int, sy: int, shooter: int) -> void:
	if not world.is_unit(target):
		return
	var u: UnitStore = world.units
	var td: UnitStats = world.def_of(target)
	u.last_hit_tick[target] = world.tick
	u.last_attacker[target] = shooter
	if td.is_infantry:
		var hits: int = 1 + w.blast_radius_mm / 3000
		var cover: int = infantry_cover(world, target, td)
		for i: int in range(hits):
			_wound_random_member(world, target, w.inf_damage * (1000 - cover / 2) / 1000, shooter)
		add_suppression(world, target, w.suppression)
	else:
		var face: int = facing(world.transform.heading[target], world.transform.x[target], world.transform.y[target], sx, sy)
		_hit_vehicle(world, target, td, w.penetration, w.damage, w.suppression, face, shooter)


static func _hit_vehicle(world: SimWorld, target: int, td: UnitStats, pen: int, dmg: int, supp: int, face: int, shooter: int) -> void:
	var u: UnitStore = world.units
	var armour: int = armour_for(td, face)
	if penetrates(pen, armour):
		var roll: int = world.rng.range_int(800, 1300)
		u.hp[target] -= dmg * roll / 1000
		if not td.is_structure:
			if world.rng.chance_permille(300):
				u.damage[target] |= 1 << world.rng.range_int(0, 3)
			if world.rng.chance_permille(350):
				_kill_random_crew(world, target)
		add_suppression(world, target, supp)
		world.emit(SimEvent.Type.PENETRATED, target, shooter, face)
	else:
		u.hp[target] -= dmg / 20
		add_suppression(world, target, supp / 2)
		world.emit(SimEvent.Type.BOUNCED, target, shooter, face)
	if u.hp[target] <= 0 or (td.crew_slots != 0 and u.crew[target] == 0):
		_credit_kill(world, shooter)
		world.destroy_entity(target)


static func _kill_random_crew(world: SimWorld, target: int) -> void:
	var mask: int = world.units.crew[target]
	var alive: PackedInt32Array = PackedInt32Array()
	for b: int in range(4):
		if (mask & (1 << b)) != 0:
			alive.append(b)
	if alive.is_empty():
		return
	var pick: int = alive[world.rng.range_int(0, alive.size() - 1)]
	world.units.crew[target] = mask & ~(1 << pick)


static func _wound_random_member(world: SimWorld, target: int, dmg: int, shooter: int) -> void:
	var u: UnitStore = world.units
	if u.members_alive[target] <= 0:
		return
	var pick: int = world.rng.range_int(0, u.members_alive[target] - 1)
	var base: int = target * SquadStore.MAX_MEMBERS
	for m: int in range(SquadStore.MAX_MEMBERS):
		if world.squads.member_hp[base + m] <= 0:
			continue
		if pick == 0:
			world.squads.member_hp[base + m] -= dmg
			if world.squads.member_hp[base + m] <= 0:
				world.squads.member_hp[base + m] = 0
				u.members_alive[target] -= 1
				u.morale[target] = maxi(0, u.morale[target] - MORALE_LOSS_PER_DEATH)
				world.emit(SimEvent.Type.SOLDIER_KILLED, target, shooter, u.members_alive[target])
				if u.members_alive[target] <= 0:
					_credit_kill(world, shooter)
					world.destroy_entity(target)
			return
		pick -= 1


## Kills the first living squad member (no RNG; used for bail-out losses).
static func kill_one_member(world: SimWorld, target: int) -> void:
	var u: UnitStore = world.units
	var base: int = target * SquadStore.MAX_MEMBERS
	for m: int in range(SquadStore.MAX_MEMBERS):
		if world.squads.member_hp[base + m] > 0:
			world.squads.member_hp[base + m] = 0
			u.members_alive[target] -= 1
			if u.members_alive[target] <= 0:
				world.destroy_entity(target)
			return


static func _credit_kill(world: SimWorld, shooter: int) -> void:
	if world.is_unit(shooter):
		world.units.kills[shooter] += 1


static func add_suppression(world: SimWorld, target: int, amount: int) -> void:
	world.units.suppression[target] = mini(1000, world.units.suppression[target] + amount)


## Indirect / blast impact at (x, y).
static func apply_blast(world: SimWorld, x: int, y: int, w: WeaponStats, shooter: int) -> void:
	world.emit(SimEvent.Type.IMPACT, 0, shooter, w.index, x, y)
	if w.smoke:
		world.smoke.add(x, y, SMOKE_ROUND_RADIUS_MM, world.tick + SMOKE_ROUND_TICKS)
		return
	var r: int = w.blast_radius_mm
	if r <= 0:
		return
	var near: PackedInt32Array = PackedInt32Array()
	world.spatial.query(x, y, 2 * r, near)
	near.sort()
	var t: TransformStore = world.transform
	for id: int in near:
		if not world.is_unit(id):
			continue
		var d: int = FixedMath.length2(t.x[id] - x, t.y[id] - y)
		if d > 2 * r:
			continue
		var td: UnitStats = world.def_of(id)
		if td.is_air:
			continue
		world.units.last_hit_tick[id] = world.tick
		world.units.last_attacker[id] = shooter
		add_suppression(world, id, w.suppression * (2 * r - d) / (2 * r))
		if d > r:
			continue
		if td.is_infantry:
			var cover: int = infantry_cover(world, id, td)
			var chance: int = 1000 * (r - d) / r * (1000 - cover) / 1000
			for m: int in range(world.units.members_alive[id]):
				if world.rng.chance_permille(chance):
					_wound_random_member(world, id, w.inf_damage, shooter)
					if not world.is_unit(id):
						break
		else:
			var pen: int = w.penetration if d <= td.radius_mm else w.penetration * (r - d) / r
			_hit_vehicle(world, id, td, pen, w.damage, 0, FACE_TOP, shooter)
