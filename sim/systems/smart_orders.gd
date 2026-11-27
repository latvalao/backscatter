# SIM: deterministic — no floats, no Nodes
## Smart orders (FEATURES phase 5): automatic counter-battery for artillery and
## crew rotation for irradiated units. Seize and overwatch are set up by
## SmartOrderCommand; any manual move cancels overwatch.
class_name SmartOrders
extends SimSystem

const OVERWATCH_HALF_ARC: int = 8192   # ±45°
const INTERVAL: int = 10
const CB_ROUNDS: int = 4
## Units this irradiated go for treatment when crew rotation is on.
const ROTATE_AT: int = DoseState.MILD
const ROTATE_CONTAMINATION: int = 1500
const ARRIVE_MM: int = 30000


func step(world: SimWorld, tick: int) -> void:
	if tick % INTERVAL != 0:
		return
	var u: UnitStore = world.units
	for team: int in range(SimWorld.MAX_TEAMS):
		for id: int in world.team_units[team]:
			var s: int = u.smart[id]
			if s == 0:
				continue
			if (s & UnitStore.SMART_AUTO_CB) != 0 and world.orders.kind[id] == OrderStore.NONE:
				_counter_battery(world, id, team)
			if (s & UnitStore.SMART_ROTATE) != 0:
				_rotate(world, id, team)


## Fire on the tightest enemy fix in range (radar or DF), like the AI does.
func _counter_battery(world: SimWorld, id: int, team: int) -> void:
	var intel: SignalIntel = world.signals[team]
	var best: int = 0
	var best_r: int = FireMissionCommand.MAX_FIX_RADIUS_MM + 1
	var def: UnitStats = world.def_of(id)
	for em: int in intel.fixes():
		var r: int = intel.fix_r[em]
		if r >= best_r:
			continue
		var d: int = FixedMath.length2(intel.fix_x[em] - world.transform.x[id], intel.fix_y[em] - world.transform.y[id])
		for wi: int in def.weapons:
			var w: WeaponStats = world.defs.weapons[wi]
			if w.is_indirect() and not w.smoke and d >= w.range_min_mm and d <= w.range_max_mm:
				best = em
				best_r = r
				break
	if best == 0:
		return
	var cmd: FireMissionCommand = FireMissionCommand.new(PackedInt32Array([id]), intel.fix_x[best], intel.fix_y[best], CB_ROUNDS)
	cmd.player_id = world.units.owner[id]
	cmd.tick = world.tick
	if cmd.validate(world):
		cmd.apply(world)


func _rotate(world: SimWorld, id: int, team: int) -> void:
	var u: UnitStore = world.units
	if not world.radiation.has(id):
		return
	var t: TransformStore = world.transform
	var bad: bool = DoseState.of(world.radiation.dose[id]) >= ROTATE_AT or world.radiation.contamination[id] >= ROTATE_CONTAMINATION
	if (u.smart[id] & UnitStore.SMART_ROTATING) != 0:
		# away for treatment: go back once clean (contamination gone)
		if world.radiation.contamination[id] < ROTATE_CONTAMINATION / 3 and world.orders.kind[id] == OrderStore.NONE:
			var care: int = _care_point(world, id, team)
			if care == 0 or FixedMath.length2(t.x[care] - t.x[id], t.y[care] - t.y[id]) <= ARRIVE_MM * 2:
				u.smart[id] &= ~UnitStore.SMART_ROTATING
				Orders.start(world, id, OrderStore.MOVE, 0, u.home_x[id], u.home_y[id], 0)
		return
	if not bad:
		return
	var care2: int = _care_point(world, id, team)
	if care2 == 0:
		return
	u.home_x[id] = t.x[id]
	u.home_y[id] = t.y[id]
	u.smart[id] |= UnitStore.SMART_ROTATING
	world.orders.queue.erase(id)
	Orders.start(world, id, OrderStore.MOVE, OrderStore.FLAG_SAFE, t.x[care2], t.y[care2] - 20000, 0)


## Nearest decontamination point (vehicles) or field hospital (infantry), else HQ.
static func _care_point(world: SimWorld, id: int, team: int) -> int:
	var def: UnitStats = world.def_of(id)
	var want: String = "field_hospital" if def.is_infantry else "decon_point"
	var best: int = 0
	var best_d: int = 0
	for role: String in [want, "hq"]:
		for s: int in Economy.structures_of(world, team, role):
			var d: int = FixedMath.length2(world.transform.x[s] - world.transform.x[id], world.transform.y[s] - world.transform.y[id])
			if best == 0 or d < best_d:
				best = s
				best_d = d
		if best != 0:
			return best
	return best
