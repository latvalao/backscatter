# SIM: deterministic — no floats, no Nodes
## Tick phase 6a: target acquisition and firing for direct-fire and ATGM weapons,
## plus fire missions for indirect weapons.
class_name WeaponSystem
extends SimSystem

const RETARGET_INTERVAL: int = 5
const LOS_CANDIDATES: int = 3
const LIMITED_AMMO: int = 10
const NEAR_MISS_RADIUS_MM: int = 20000


func step(world: SimWorld, tick: int) -> void:
	for id: int in world.entities.ids():
		if not world.is_unit(id):
			continue
		var def: UnitStats = world.def_of(id)
		if def.weapons.is_empty():
			continue
		var can_fire: bool = can_operate_weapons(world, id, def)
		var retarget: bool = (id + tick) % RETARGET_INTERVAL == 0
		for slot: int in range(def.weapons.size()):
			var w: WeaponStats = world.defs.weapons[def.weapons[slot]]
			var k: int = id * WeaponStore.MAX_WEAPONS + slot
			_tick_reload(world, id, def, k)
			if not can_fire:
				world.weapons.target[k] = 0
				continue
			if w.is_indirect():
				_fire_mission(world, id, def, slot, w, tick)
				continue
			_direct(world, id, def, slot, w, tick, retarget)


static func can_operate_weapons(world: SimWorld, id: int, def: UnitStats) -> bool:
	var u: UnitStore = world.units
	if def.is_infantry:
		return u.members_alive[id] > 0
	if def.has_crew(UnitStats.CREW_GUNNER) and (u.crew[id] & UnitStats.CREW_GUNNER) == 0:
		return false
	return (u.damage[id] & UnitStore.DMG_TURRET) == 0


## True if any direct weapon currently has a target (attack-move halts for it).
static func has_engaged_target(world: SimWorld, id: int) -> bool:
	var def: UnitStats = world.def_of(id)
	for s: int in range(def.weapons.size()):
		var tgt: int = world.weapons.target[id * WeaponStore.MAX_WEAPONS + s]
		if tgt > 0 and world.is_unit(tgt):
			return true
	return false


func _tick_reload(world: SimWorld, id: int, def: UnitStats, k: int) -> void:
	var r: int = world.weapons.reload[k]
	if r <= 0:
		return
	# missing loader: reload progresses on 2 of 3 ticks
	if def.has_crew(UnitStats.CREW_LOADER) and (world.units.crew[id] & UnitStats.CREW_LOADER) == 0 and world.tick % 3 == 0:
		return
	world.weapons.reload[k] = r - 1


func _direct(world: SimWorld, id: int, def: UnitStats, slot: int, w: WeaponStats, tick: int, retarget: bool) -> void:
	var ws: WeaponStore = world.weapons
	var k: int = id * WeaponStore.MAX_WEAPONS + slot
	var cur: int = ws.target[k]
	var team: int = world.units.team[id]
	if cur > 0 and not _still_valid(world, id, cur, w, team, tick):
		cur = 0
	if retarget or cur == 0:
		var best: int = _acquire(world, id, def, w, team, tick)
		if best != cur:
			cur = best
			ws.aim[k] = w.aim_ticks
	ws.target[k] = cur
	if cur == 0:
		return
	if ws.ammo[k] < w.ammo_per_shot:
		ws.target[k] = 0
		return
	if ws.aim[k] > 0:
		ws.aim[k] -= 1
		return
	if ws.reload[k] > 0:
		return
	_fire(world, id, def, slot, w, cur, tick)


func _still_valid(world: SimWorld, id: int, tgt: int, w: WeaponStats, team: int, tick: int) -> bool:
	if not world.is_unit(tgt) or not world.vision[team].is_visible(tgt, tick):
		return false
	var d: int = _dist(world, id, tgt)
	return d >= w.range_min_mm and d <= w.range_max_mm


## Picks the best visible target in range with own line of sight; 0 if none.
func _acquire(world: SimWorld, id: int, def: UnitStats, w: WeaponStats, team: int, tick: int) -> int:
	var forced: int = 0
	var o: OrderStore = world.orders
	if o.kind[id] == OrderStore.ATTACK:
		forced = o.target[id]
	if world.units.stance[id] == UnitStore.STANCE_HOLD_FIRE and forced == 0:
		return 0
	var scored: PackedInt64Array = PackedInt64Array()
	for tgt: int in world.visible_enemies[team]:
		if not world.is_unit(tgt):
			continue
		var d: int = _dist(world, id, tgt)
		if d < w.range_min_mm or d > w.range_max_mm:
			continue
		var eff: int = effectiveness(world, w, id, tgt)
		if eff <= 0:
			continue
		if tgt == forced:
			eff += 5000
		if world.units.last_attacker[id] == tgt and tick - world.units.last_hit_tick[id] < 100:
			eff += 200
		var score: int = eff * 1000 - d / 10
		# sort ascending on negated score; ties broken by id
		scored.append(((0x3FFFFFFF - score) << 20) | tgt)
	if scored.is_empty():
		return 0
	scored.sort()
	for i: int in range(mini(LOS_CANDIDATES, scored.size())):
		var tgt: int = scored[i] & 0xFFFFF
		if world.los_cached(id, tgt, VisionSystem.INTERVAL) or Los.between(world, id, tgt) == Los.CLEAR:
			return tgt
	return 0


## Expected usefulness of weapon w against target (0 = pointless), permille-ish.
static func effectiveness(world: SimWorld, w: WeaponStats, shooter: int, tgt: int) -> int:
	var td: UnitStats = world.def_of(tgt)
	if td.is_infantry:
		var e: int = mini(1000, w.inf_damage * w.burst * 4)
		if w.ammo_capacity <= LIMITED_AMMO:
			e /= 4
		return e
	var t: TransformStore = world.transform
	var face: int = Combat.facing(t.heading[tgt], t.x[tgt], t.y[tgt], t.x[shooter], t.y[shooter])
	var armour: int = Combat.armour_for(td, face)
	if Combat.penetrates(w.penetration, armour):
		return 1000 + mini(1000, w.damage * 1000 / maxi(1, td.hp))
	if w.penetration * 3 >= armour and w.penetration >= 20:
		return 60
	return 0


func _fire(world: SimWorld, id: int, def: UnitStats, slot: int, w: WeaponStats, tgt: int, tick: int) -> void:
	var ws: WeaponStore = world.weapons
	var k: int = id * WeaponStore.MAX_WEAPONS + slot
	var t: TransformStore = world.transform
	ws.ammo[k] -= w.ammo_per_shot
	ws.reload[k] = w.reload_ticks
	world.units.last_fired_tick[id] = tick
	var d: int = _dist(world, id, tgt)
	var acc: int = Combat.hit_chance(world, id, tgt, w, d)
	world.emit(SimEvent.Type.SHOT, id, tgt, w.index, t.x[tgt], t.y[tgt])
	if w.projectile_speed > 0:
		var flight: int = maxi(1, d / w.projectile_speed)
		world.projectiles.launch(w.index, id, tgt, world.units.team[id], t.x[id], t.y[id],
			t.x[tgt], t.y[tgt], tick, tick + flight, acc)
		return
	var shots: int = w.burst
	if def.is_infantry:
		shots = maxi(1, (w.burst * world.units.members_alive[id] + def.members - 1) / def.members)
	for s: int in range(shots):
		if not world.is_unit(tgt):
			break
		if world.rng.chance_permille(acc):
			Combat.apply_hit(world, tgt, w, t.x[id], t.y[id], id)
		else:
			Combat.add_suppression(world, tgt, w.suppression / 4)


## Indirect weapons only fire on an explicit fire mission.
func _fire_mission(world: SimWorld, id: int, def: UnitStats, slot: int, w: WeaponStats, tick: int) -> void:
	var o: OrderStore = world.orders
	if o.kind[id] != OrderStore.FIRE_MISSION:
		return
	var want_smoke: bool = (o.flags[id] & OrderStore.FLAG_SMOKE) != 0
	if w.smoke != want_smoke:
		return
	var ws: WeaponStore = world.weapons
	var k: int = id * WeaponStore.MAX_WEAPONS + slot
	var t: TransformStore = world.transform
	var gx: int = o.goal_x[id]
	var gy: int = o.goal_y[id]
	var d: int = FixedMath.length2(gx - t.x[id], gy - t.y[id])
	if d < w.range_min_mm or d > w.range_max_mm or ws.ammo[k] < w.ammo_per_shot:
		Orders.finish(world, id)
		return
	if ws.target[k] != -1:
		ws.target[k] = -1  # -1 marks "laying on a grid point"
		ws.aim[k] = w.aim_ticks
	if ws.aim[k] > 0:
		ws.aim[k] -= 1
		return
	if ws.reload[k] > 0:
		return
	ws.ammo[k] -= w.ammo_per_shot
	ws.reload[k] = w.reload_ticks
	world.units.last_fired_tick[id] = tick
	var disp: int = w.dispersion_per_km_mm * d / 1000000
	var r: int = world.rng.range_int(0, maxi(0, disp))
	var ang: int = world.rng.range_int(0, SimConst.ANGLE_MASK)
	var ix: int = gx + (r * FixedMath.cos_b(ang)) / FixedMath.ONE
	var iy: int = gy + (r * FixedMath.sin_b(ang)) / FixedMath.ONE
	var flight: int = maxi(10, d / maxi(1, w.projectile_speed))
	world.emit(SimEvent.Type.SHOT, id, 0, w.index, ix, iy)
	world.projectiles.launch(w.index, id, 0, world.units.team[id], t.x[id], t.y[id], ix, iy, tick, tick + flight, 0)
	o.rounds[id] -= 1
	if o.rounds[id] <= 0:
		ws.target[k] = 0
		Orders.finish(world, id)


static func _dist(world: SimWorld, a: int, b: int) -> int:
	var t: TransformStore = world.transform
	return FixedMath.length2(t.x[b] - t.x[a], t.y[b] - t.y[a])
