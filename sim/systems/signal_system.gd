# SIM: deterministic — no floats, no Nodes
## Tick phase 5 — Backscatter (§5.5):
##  * jamming: units inside an active enemy jammer's radius are jammed
##  * radio net: a unit is on the net if it has a radio, isn't SILENT and isn't jammed
##  * emissions: per EMCON state; artillery firing adds a strong pulse
##  * direction finding: DF-capable units take noisy bearings on enemy emitters;
##    two bearings with enough angular separation give a fix (ellipse radius)
##  * counter-battery radar: instant tight fix on firing enemy artillery
##  * drones: battery drain; link lost when the operator dies, is silent or
##    either end is jammed → fly home, crash after LINK_CRASH_TICKS
##  * off-net spotting reports are delivered late (courier delay)
class_name SignalSystem
extends SimSystem

const INTERVAL: int = 10
const RANGE_PER_STRENGTH_MM: int = 100000   # 100 m per strength point
const ARTILLERY_PULSE: int = 60
const PULSE_TICKS: int = 40
const BASE_ERROR: int = 1600                # ~9° half-width at DF quality 1
const MIN_SEPARATION: int = 2730            # 15°
const CB_RADAR_RANGE_MM: int = 15000000
const CB_FIX_RADIUS_MM: int = 40000
const LINK_CRASH_TICKS: int = 300
const OFF_NET_DELAY: int = 50


func step(world: SimWorld, tick: int) -> void:
	if tick % INTERVAL == 0:
		_jamming_and_net(world)
		for team: int in range(SimWorld.MAX_TEAMS):
			if team != SimWorld.NEUTRAL_TEAM:
				world.signals[team].prune(tick)
				_direction_finding(world, team, tick)
	_counter_battery(world, tick)
	_drones(world, tick)
	_deliver_spots(world, tick)


## Current emission strength of a unit (0 = not emitting).
static func emission(world: SimWorld, id: int) -> int:
	if not world.is_unit(id):
		return 0
	var def: UnitStats = world.def_of(id)
	var e: int = world.units.emcon[id]
	var s: int = 0
	if world.is_structure(id) and not world.structures.is_complete(id):
		return 0
	match def.emitter_kind:
		UnitStats.EMIT_RADIO, UnitStats.EMIT_HQ:
			if e == UnitStore.EMCON_EMIT:
				s = def.emitter_strength
			elif e == UnitStore.EMCON_RESTRICTED:
				s = def.emitter_strength / 2
		UnitStats.EMIT_RADAR, UnitStats.EMIT_JAMMER:
			if e == UnitStore.EMCON_EMIT:
				s = def.emitter_strength
		UnitStats.EMIT_DRONE_LINK:
			if world.units.link[id] > 0 and world.units.link_lost[id] == 0:
				s = def.emitter_strength
	# firing artillery cannot be hidden
	if world.tick - world.units.last_fired_tick[id] < PULSE_TICKS and _has_indirect(world, def):
		s = maxi(s, ARTILLERY_PULSE)
	return s


static func _has_indirect(world: SimWorld, def: UnitStats) -> bool:
	for wi: int in def.weapons:
		if world.defs.weapons[wi].is_indirect():
			return true
	return false


static func jammer_active(world: SimWorld, id: int) -> bool:
	var def: UnitStats = world.def_of(id)
	return def.has_ability("jam") and world.units.emcon[id] == UnitStore.EMCON_EMIT


func _jamming_and_net(world: SimWorld) -> void:
	var jammers: PackedInt32Array = PackedInt32Array()
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			if jammer_active(world, id):
				jammers.append(id)
	var t: TransformStore = world.transform
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			var j: int = 0
			for jm: int in jammers:
				if not world.is_enemy_team(team, world.units.team[jm]):
					continue
				var r: int = world.def_of(jm).jam_radius_mm
				if FixedMath.dist2_sq(t.x[id], t.y[id], t.x[jm], t.y[jm]) <= r * r:
					j = 1
					break
			if j == 1 and world.jammed[id] == 0:
				world.emit(SimEvent.Type.JAMMED, id)
			world.jammed[id] = j
			var def: UnitStats = world.def_of(id)
			var radio: bool = def.emitter_kind == UnitStats.EMIT_RADIO or def.emitter_kind == UnitStats.EMIT_HQ \
				or def.emitter_kind == UnitStats.EMIT_RADAR or def.emitter_kind == UnitStats.EMIT_JAMMER
			world.on_net[id] = 1 if radio and j == 0 and world.units.emcon[id] != UnitStore.EMCON_SILENT else 0


func _direction_finding(world: SimWorld, team: int, tick: int) -> void:
	var intel: SignalIntel = world.signals[team]
	var t: TransformStore = world.transform
	var sources: PackedInt32Array = PackedInt32Array()
	for id: int in world.team_units[team]:
		var q: int = world.def_of(id).df_quality
		if q > 0 and (not world.is_structure(id) or world.structures.is_complete(id)):
			sources.append(id)
	if sources.is_empty():
		return
	for other: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, other):
			continue
		for em: int in world.team_units[other]:
			var s: int = emission(world, em)
			if s <= 0:
				continue
			var got: bool = false
			for src: int in sources:
				var q: int = world.def_of(src).df_quality
				var reach: int = s * RANGE_PER_STRENGTH_MM * (2 + q) / 3
				var dx: int = t.x[em] - t.x[src]
				var dy: int = t.y[em] - t.y[src]
				if dx * dx + dy * dy > reach * reach:
					continue
				var err: int = BASE_ERROR / q
				var noise: int = world.rng.range_int(-err, err)
				intel.add_bearing(em, t.x[src], t.y[src], (FixedMath.atan2_b(dy, dx) + noise) & SimConst.ANGLE_MASK, err, tick)
				got = true
			if got:
				_try_fix(world, intel, em, tick, team)


## Triangulates from the freshest pair of bearings with enough separation.
func _try_fix(world: SimWorld, intel: SignalIntel, em: int, tick: int, team: int) -> void:
	var idx: PackedInt32Array = PackedInt32Array()
	for i: int in range(intel.b_emitter.size()):
		if intel.b_emitter[i] == em:
			idx.append(i)
	var t: TransformStore = world.transform
	var best_r: int = 1 << 40
	for a: int in range(idx.size()):
		for b: int in range(a + 1, idx.size()):
			var i: int = idx[a]
			var j: int = idx[b]
			var sep: int = absi(FixedMath.angle_diff(intel.b_angle[i], intel.b_angle[j]))
			if sep > SimConst.ANGLE_QUARTER:
				sep = SimConst.ANGLE_HALF - sep
			if sep < MIN_SEPARATION:
				continue
			var d: int = FixedMath.length2(t.x[em] - int(intel.b_src_x[i]), t.y[em] - int(intel.b_src_y[i]))
			# more bearings on a steady emitter average the error down (÷ √n)
			var err: int = (intel.b_error[i] + intel.b_error[j]) / 2 / maxi(1, FixedMath.isqrt(idx.size()))
			# r ≈ distance × angular error / sin(separation)
			var r: int = d * err / 10430 * FixedMath.ONE / maxi(1, FixedMath.sin_b(sep))
			best_r = mini(best_r, r)
	if best_r >= (1 << 40):
		# single bearing: a long thin wedge — record as a wide, low-value contact
		var d1: int = FixedMath.length2(t.x[em] - int(intel.b_src_x[idx[idx.size() - 1]]), t.y[em] - int(intel.b_src_y[idx[idx.size() - 1]]))
		best_r = maxi(600000, d1 / 2)
	best_r = maxi(25000, best_r)
	# the estimate is wrong by up to half the radius (deterministic)
	var off_r: int = world.rng.range_int(0, best_r / 2)
	var ang: int = world.rng.range_int(0, SimConst.ANGLE_MASK)
	var ex: int = t.x[em] + off_r * FixedMath.cos_b(ang) / FixedMath.ONE
	var ey: int = t.y[em] + off_r * FixedMath.sin_b(ang) / FixedMath.ONE
	intel.set_fix(em, ex, ey, best_r, tick, world.def_of(em).emitter_kind)
	if best_r <= 150000:
		world.emit(SimEvent.Type.SIGNAL_FIX, em, team, best_r, ex, ey)


## Active counter-battery radars fix enemy artillery the tick after it fires.
func _counter_battery(world: SimWorld, tick: int) -> void:
	var p: ProjectileStore = world.projectiles
	if p.count() == 0:
		return
	var t: TransformStore = world.transform
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		var radars: PackedInt32Array = PackedInt32Array()
		for id: int in world.team_units[team]:
			if world.def_of(id).has_ability("cb_radar") and world.units.emcon[id] == UnitStore.EMCON_EMIT and world.jammed[id] == 0:
				radars.append(id)
		if radars.is_empty():
			continue
		for i: int in range(p.count()):
			if p.launch_tick[i] != tick - 1 or not world.is_enemy_team(team, p.team[i]):
				continue
			if not world.defs.weapons[p.weapon[i]].is_indirect():
				continue
			var shooter: int = p.shooter[i]
			if not world.is_unit(shooter):
				continue
			for rd: int in radars:
				if FixedMath.dist2_sq(t.x[rd], t.y[rd], int(p.src_x[i]), int(p.src_y[i])) <= CB_RADAR_RANGE_MM * CB_RADAR_RANGE_MM:
					var ox: int = world.rng.range_int(-CB_FIX_RADIUS_MM / 2, CB_FIX_RADIUS_MM / 2)
					var oy: int = world.rng.range_int(-CB_FIX_RADIUS_MM / 2, CB_FIX_RADIUS_MM / 2)
					world.signals[team].set_fix(shooter, int(p.src_x[i]) + ox, int(p.src_y[i]) + oy, CB_FIX_RADIUS_MM, tick, UnitStats.EMIT_RADAR)
					world.emit(SimEvent.Type.SIGNAL_FIX, shooter, team, CB_FIX_RADIUS_MM, int(p.src_x[i]) + ox, int(p.src_y[i]) + oy)
					break


func _drones(world: SimWorld, tick: int) -> void:
	var u: UnitStore = world.units
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			var def: UnitStats = world.def_of(id)
			if not def.is_air:
				continue
			# battery
			var lg: LogisticsStore = world.logistics
			if def.battery_ticks > 0:
				lg.odometer[id] += 1
				if lg.odometer[id] >= def.battery_ticks:
					world.emit(SimEvent.Type.DRONE_LOST, id)
					world.destroy_entity(id)
					continue
			var op: int = u.link[id]
			var ok: bool = op > 0 and world.is_unit(op) and u.emcon[op] != UnitStore.EMCON_SILENT \
				and world.jammed[op] == 0 and world.jammed[id] == 0
			if ok:
				u.link_lost[id] = 0
				continue
			u.link_lost[id] += 1
			if u.link_lost[id] == 1:
				world.emit(SimEvent.Type.JAMMED, id)
			if u.link_lost[id] >= LINK_CRASH_TICKS:
				world.emit(SimEvent.Type.DRONE_LOST, id)
				world.destroy_entity(id)
			elif u.link_lost[id] % 20 == 1:
				# lost link: autopilot flies back toward the operator / launch point
				var hx: int = world.transform.x[op] if world.is_unit(op) else world.transform.x[id]
				var hy: int = world.transform.y[op] if world.is_unit(op) else world.transform.y[id]
				Orders.start(world, id, OrderStore.MOVE, 0, hx, hy, 0)


func _deliver_spots(world: SimWorld, tick: int) -> void:
	if world.pending_spots.is_empty():
		return
	var keep: Array[PackedInt64Array] = []
	for s: PackedInt64Array in world.pending_spots:
		if tick >= s[0]:
			var tgt: int = s[2]
			if world.is_unit(tgt):
				world.vision[s[1]].mark_seen(tgt, s[3], s[4], tick, tick + VisionSystem.INTERVAL + 1)
		else:
			keep.append(s)
	world.pending_spots = keep
