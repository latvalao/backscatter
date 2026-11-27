# SIM: deterministic — no floats, no Nodes
## Strategic + operational + tactical AI for one player (§6).
##  Commander (every think interval): economy, utility-scored goals (capture
##  depot, defend FOB, attack HQ, recon, counter-battery, leave fallout),
##  allocation of units to task forces.
##  Task forces (every 20 ticks): move/attack-move toward their goal, smoke
##  under fire, regroup, safe routing per doctrine.
##  Units (every 10 ticks): resupply when dry, repair when hurt, cover when
##  pinned, get out of hot zones.
## Everything is issued through validated commands, inside the deterministic sim.
class_name CommanderAi
extends AiController

const EASY: int = 0
const NORMAL: int = 1
const HARD: int = 2
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Normal", "Hard"]
const THINK: Array[int] = [100, 50, 30]
## Supply adjustment per minute (§6: resource multipliers only at the extremes).
const SUPPLY_PER_MIN: Array[int] = [-30, 0, 60]
## Attack threshold multiplier (permille) by difficulty: Easy is cautious, Hard pushes.
const AGGRESSION: Array[int] = [1500, 1000, 800]
## After this long without finding the enemy HQ, guess it mirrors ours.
const GUESS_HQ_AFTER: int = 6000
const TF_INTERVAL: int = 20
const UNIT_INTERVAL: int = 10
const RESERVE: int = 100
const DEFEND_RADIUS_MM: int = 700000
const HOT_RATE: int = 2_000_000   # µSv/h — leave
const FIX_FIRE_RADIUS_MM: int = 150000
const SUPPORT_INTERVAL: int = 900
const SUPPORT_CLUSTER_MM: int = 150000
const SUPPORT_MIN_TARGETS: int = 3

var difficulty: int = NORMAL
var doctrine: Doctrine
var task_forces: Array[TaskForce] = []
var _next_tf: int = 1
var _assigned: Dictionary = {}     # unit id -> tf id
var _scout_index: int = 0
var _fired_on: Dictionary = {}     # emitter id -> tick last fired upon
var _easy_hq_hint: int = 0


func _init(p_player: int = 0, p_faction: String = "nc", p_difficulty: int = NORMAL) -> void:
	player = p_player
	difficulty = p_difficulty
	doctrine = Doctrine.for_faction(p_faction)


func step(world: SimWorld, tick: int) -> void:
	var team: int = world.team_of_player(player)
	var phase: int = (tick + player * 13)
	if phase % 600 == 0 and tick > 0:
		world.players.supply[player] = maxi(0, world.players.supply[player] + SUPPLY_PER_MIN[difficulty])
	if phase % UNIT_INTERVAL == 0:
		_unit_micro(world, team)
	if phase % THINK[difficulty] == 0:
		_think(world, team, tick)
	if phase % TF_INTERVAL == 0:
		for tf: TaskForce in task_forces:
			_run_task_force(world, team, tf, tick)


# ------------------------------------------------------------------ commander

func _think(world: SimWorld, team: int, tick: int) -> void:
	for tf: TaskForce in task_forces:
		tf.prune(world)
	var keep: Array[TaskForce] = []
	for tf: TaskForce in task_forces:
		if not tf.units.is_empty() and not _goal_done(world, team, tf):
			keep.append(tf)
		else:
			for u: int in tf.units:
				_assigned.erase(u)
	task_forces = keep
	var hq: int = _own(world, team, "hq")
	if hq == 0:
		return
	_build(world, team, hq)
	_produce(world, team)
	_logistics(world, team, hq)
	_allocate(world, team, hq, tick)
	if tick % SUPPORT_INTERVAL < THINK[difficulty]:
		_call_support(world, team)


func _goal_done(world: SimWorld, team: int, tf: TaskForce) -> bool:
	match tf.kind:
		TaskForce.CAPTURE:
			return not world.is_unit(tf.target) or world.structures.holder_team[tf.target] == team
		TaskForce.ATTACK:
			if tf.target == 0:
				# guessed goal: retarget as soon as the HQ is spotted
				var hq_seen: int = _known_enemy_hq(world, team)
				if hq_seen > 0:
					tf.target = hq_seen
					tf.last_order_tick = -100000
				return false
			return not world.is_unit(tf.target)
		TaskForce.DEFEND:
			return _threat_near(world, team, Vector2i(tf.goal_x, tf.goal_y)) == 0
	return false


## Utility-based allocation of free units to task forces.
func _allocate(world: SimWorld, team: int, hq: int, tick: int) -> void:
	var free: PackedInt32Array = PackedInt32Array()
	var recon_units: PackedInt32Array = PackedInt32Array()
	var arty: PackedInt32Array = PackedInt32Array()
	for id: int in my_units(world):
		if _assigned.has(id):
			continue
		var d: UnitStats = world.def_of(id)
		if d.has_ability("build") or d.role == "logistics" or d.role == "support" or d.role == "sensor":
			continue
		if d.is_air:
			continue
		if d.role == "artillery" or d.role == "indirect":
			arty.append(id)
		elif d.role == "scout":
			recon_units.append(id)
		elif d.role == "ew":
			free.append(id)
		else:
			free.append(id)
	if not arty.is_empty():
		_join(world, _tf_of_kind(TaskForce.ARTILLERY, world, hq), arty)
	if not recon_units.is_empty():
		_join(world, _tf_of_kind(TaskForce.RECON, world, hq), recon_units)
	var hq_pos: Vector2i = Vector2i(world.transform.x[hq], world.transform.y[hq])
	# 1. defend the FOB — if the HQ itself is under fire, recall everything nearby
	var threat: int = _threat_near(world, team, hq_pos)
	var hq_hit: bool = tick - world.units.last_hit_tick[hq] < THINK[difficulty] * 2
	if hq_hit:
		threat = maxi(threat, 6)
		for tf_c: TaskForce in task_forces:
			if tf_c.kind == TaskForce.CAPTURE or tf_c.kind == TaskForce.ATTACK:
				var c: Vector2i = tf_c.centroid(world)
				if FixedMath.dist2_sq(c.x, c.y, hq_pos.x, hq_pos.y) <= 2000000 * 2000000:
					for u: int in tf_c.units:
						_assigned.erase(u)
						free.append(u)
					tf_c.units = PackedInt32Array()
	if threat > 0 and not free.is_empty():
		var tf: TaskForce = _tf_of_kind(TaskForce.DEFEND, world, hq)
		tf.goal_x = hq_pos.x
		tf.goal_y = hq_pos.y
		var n: int = free.size() if hq_hit else mini(free.size(), maxi(4, threat * 2))
		_join(world, tf, free.slice(0, n))
		free = free.slice(n)
	# 2. attack when stronger
	var enemy_hq: int = _known_enemy_hq(world, team)
	var mine: int = _strength(world, team)
	var theirs: int = _known_enemy_strength(world, team, tick)
	if theirs == 0:
		theirs = mine  # nothing scouted: assume parity rather than an empty map
	theirs = maxi(1, theirs)
	var attack_tf: TaskForce = _find_kind(TaskForce.ATTACK)
	var ratio: int = doctrine.attack_ratio * AGGRESSION[difficulty] / 1000
	var guess: bool = enemy_hq == 0 and tick >= GUESS_HQ_AFTER
	var army: int = free.size()
	for tf_a: TaskForce in task_forces:
		if tf_a.kind == TaskForce.CAPTURE:
			army += tf_a.units.size()
	if (enemy_hq > 0 or guess) and (attack_tf != null or (mine * 1000 / theirs >= ratio and army >= doctrine.min_attack_size)):
		if attack_tf == null:
			attack_tf = _new_tf(TaskForce.ATTACK)
			# strike with everything: fold the capture groups into the attack
			for tf_c2: TaskForce in task_forces:
				if tf_c2.kind == TaskForce.CAPTURE:
					for u2: int in tf_c2.units:
						_assigned.erase(u2)
						free.append(u2)
					tf_c2.units = PackedInt32Array()
		attack_tf.target = enemy_hq
		if enemy_hq > 0 and world.vision[team].is_known(enemy_hq):
			attack_tf.goal_x = world.vision[team].last_x[enemy_hq]
			attack_tf.goal_y = world.vision[team].last_y[enemy_hq]
		elif enemy_hq > 0:
			attack_tf.goal_x = world.transform.x[enemy_hq]
			attack_tf.goal_y = world.transform.y[enemy_hq]
		else:
			# no scouting report: the enemy base is probably across the map from ours
			attack_tf.goal_x = world.map_width_mm() - world.transform.x[hq]
			attack_tf.goal_y = world.map_height_mm() - world.transform.y[hq]
		_join(world, attack_tf, free)
		free = PackedInt32Array()
	# 3. capture depots, best utility first (pairs, or a lone unit early on)
	while free.size() >= 1:
		var d: int = _best_depot(world, team, hq_pos)
		if d == 0:
			break
		var tf2: TaskForce = _new_tf(TaskForce.CAPTURE)
		tf2.target = d
		tf2.goal_x = world.transform.x[d]
		tf2.goal_y = world.transform.y[d] - 40000
		var n2: int = mini(free.size(), 3)
		_join(world, tf2, free.slice(0, n2))
		free = free.slice(n2)
	# leftovers reinforce a manoeuvre group (never the artillery / recon groups)
	if not free.is_empty():
		for i: int in range(task_forces.size() - 1, -1, -1):
			var k: int = task_forces[i].kind
			if k == TaskForce.CAPTURE or k == TaskForce.ATTACK or k == TaskForce.DEFEND:
				_join(world, task_forces[i], free)
				break


func _best_depot(world: SimWorld, team: int, from: Vector2i) -> int:
	var best: int = 0
	var best_u: int = -1
	for d: int in ObjectiveSystem._depots(world):
		if world.structures.holder_team[d] == team or _targeted(d):
			continue
		var dist: int = FixedMath.length2(world.transform.x[d] - from.x, world.transform.y[d] - from.y)
		var u: int = 100000000 / (1000 + dist / 1000)
		if world.radfield.rate_at(world.transform.x[d], world.transform.y[d]) > HOT_RATE:
			u /= 4
		if world.structures.holder_team[d] >= 0:
			u /= 2  # held by the enemy: costlier
		if u > best_u:
			best_u = u
			best = d
	return best


func _targeted(depot: int) -> bool:
	for tf: TaskForce in task_forces:
		if tf.kind == TaskForce.CAPTURE and tf.target == depot:
			return true
	return false


func _threat_near(world: SimWorld, team: int, p: Vector2i) -> int:
	var n: int = 0
	for e: int in world.visible_enemies[team]:
		if world.is_structure(e):
			continue
		if FixedMath.dist2_sq(world.transform.x[e], world.transform.y[e], p.x, p.y) <= DEFEND_RADIUS_MM * DEFEND_RADIUS_MM:
			n += 1
	return n


func _strength(world: SimWorld, team: int) -> int:
	var s: int = 0
	for id: int in my_units(world):
		var d: UnitStats = world.def_of(id)
		if not d.weapons.is_empty() and d.role != "logistics":
			s += d.cost_supply
	return s


## Enemy strength from what we've seen in the last 10 minutes (no cheating).
func _known_enemy_strength(world: SimWorld, team: int, tick: int) -> int:
	var s: int = 0
	var layer: TeamVision = world.vision[team]
	for other: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, other):
			continue
		for id: int in world.team_units[other]:
			if world.is_structure(id) or not layer.is_known(id):
				continue
			if tick - layer.last_tick[id] <= 6000:
				s += world.def_of(id).cost_supply
	return s


## Enemy HQ if our team has seen it (Easy: always known — scouting cheat).
func _known_enemy_hq(world: SimWorld, team: int) -> int:
	for other: int in range(SimWorld.MAX_TEAMS):
		if not world.is_enemy_team(team, other):
			continue
		for id: int in world.team_units[other]:
			if world.is_structure(id) and world.def_of(id).role == "hq":
				if world.vision[team].is_known(id):
					return id
				if difficulty == EASY:
					_easy_hq_hint = id  # cheat: goal only — artillery still needs real intel
					return id
	return 0


# ------------------------------------------------------------------ economy

func _build(world: SimWorld, team: int, hq: int) -> void:
	var engineer: int = 0
	for id: int in my_units(world):
		if world.def_of(id).has_ability("build"):
			if world.orders.kind[id] == OrderStore.BUILD:
				return
			if engineer == 0:
				engineer = id
	if engineer == 0:
		return
	var hcx: int = world.structures.cell_x[hq]
	var hcy: int = world.structures.cell_y[hq]
	var dir: int = 1 if world.transform.x[hq] < world.map_width_mm() / 2 else -1
	for i: int in range(doctrine.build_order.size()):
		var role: String = doctrine.build_order[i]
		if _own(world, team, role, true) != 0 or not _can_use_building(world, role):
			continue
		var def: UnitStats = world.defs.unit(role)
		# the first two buildings are essential; the rest are luxuries for a healthy economy
		var margin: int = RESERVE if i < 2 else 600
		if world.players.supply[player] < def.cost_supply + margin:
			return
		var ox: int = dir * (6 + (i % 3) * 6)
		var oy: int = 8 - (i / 3) * 16 - (i % 3) * 5
		var site: Vector2i = MatchSetup.find_site(world, def, hcx + ox, hcy + oy, 30)
		if site.x >= 0:
			issue(world, BuildCommand.new(PackedInt32Array([engineer]), role, site.x, site.y))
		return


func _produce(world: SimWorld, team: int) -> void:
	var faction: String = world.players.faction[player]
	var counts: Dictionary = {}
	for id: int in my_units(world):
		var r: String = world.def_of(id).role
		counts[r] = int(counts.get(r, 0)) + 1
	for role: String in ["barracks", "motor_pool", "artillery_park", "helipad"]:
		var b: int = _own(world, team, role)
		if b == 0 or world.structures.get_queue(b).size() >= 2:
			continue
		var best: UnitStats = null
		var best_score: int = -1
		for u: UnitStats in world.defs.producible(role, faction):
			if (u.is_air and u.battery_ticks > 0) or u.role == "logistics" or u.role == "builder":
				continue
			if not world.defs.allowed(u.id, faction, world.players.battlegroup[player]):
				continue
			var wgt: int = doctrine.weights.get(u.role, 0)
			if wgt <= 0 or not world.players.can_afford(player, u.cost_supply + RESERVE, u.cost_manpower):
				continue
			# favour the role we're most short of relative to its weight
			var score: int = wgt * 1000 / (1 + int(counts.get(u.role, 0))) + (u.index * 7 + world.tick / 50) % 13
			if score > best_score:
				best_score = score
				best = u
		if best != null:
			issue(world, ProduceCommand.new(b, best.id, 1))
			counts[best.role] = int(counts.get(best.role, 0)) + 1
	# keep one engineer and one truck alive
	var mp: int = _own(world, team, "motor_pool")
	if mp != 0 and world.structures.get_queue(mp).is_empty():
		if int(counts.get("builder", 0)) == 0:
			issue(world, ProduceCommand.new(mp, faction + "_engineer_veh", 1))
		elif int(counts.get("logistics", 0)) == 0:
			issue(world, ProduceCommand.new(mp, faction + "_supply_truck", 1))


## Supply trucks haul stranded depot stock home.
func _logistics(world: SimWorld, team: int, hq: int) -> void:
	for id: int in my_units(world):
		if world.def_of(id).role != "logistics" or world.orders.kind[id] != OrderStore.NONE:
			continue
		if world.logistics.haul[id] > 0:
			issue(world, MoveCommand.new(PackedInt32Array([id]), world.transform.x[hq], world.transform.y[hq] - 30000))
			continue
		for d: int in ObjectiveSystem._depots(world):
			if world.structures.holder_team[d] == team and world.structures.stock[d] >= 100 and world.structures.connected[d] == 0:
				issue(world, MoveCommand.new(PackedInt32Array([id]), world.transform.x[d], world.transform.y[d] - 35000, MoveCommand.MODE_MOVE, false, doctrine.safe_routing))
				break


# ------------------------------------------------------------------ task forces

func _run_task_force(world: SimWorld, team: int, tf: TaskForce, tick: int) -> void:
	tf.prune(world)
	if tf.units.is_empty():
		return
	match tf.kind:
		TaskForce.ARTILLERY:
			_artillery(world, team, tf, tick)
			return
		TaskForce.RECON:
			_recon(world, team, tf, tick)
			return
	var c: Vector2i = tf.centroid(world)
	if tf.kind == TaskForce.ATTACK and tf.target > 0 and world.vision[team].is_known(tf.target):
		tf.goal_x = world.vision[team].last_x[tf.target]
		tf.goal_y = world.vision[team].last_y[tf.target]
	if tf.kind == TaskForce.DEFEND:
		var tc: Vector2i = _threat_centroid(world, team, Vector2i(tf.goal_x, tf.goal_y))
		if tc.x >= 0:
			tf.goal_x = tc.x
			tf.goal_y = tc.y
	# retreat out of fallout if the group sits in a hot zone
	if world.radfield.rate_at(c.x, c.y) > HOT_RATE:
		var hq: int = _own(world, team, "hq")
		if hq > 0 and tick - tf.last_order_tick >= 100:
			issue(world, MoveCommand.new(tf.units, world.transform.x[hq], world.transform.y[hq], MoveCommand.MODE_MOVE, false, true))
			tf.last_order_tick = tick
		return
	# smoke when the group is taking fire
	_smoke_if_hit(world, tf, tick)
	if tick - tf.last_order_tick < 300:
		return
	tf.last_order_tick = tick
	# regroup a strung-out attack group before pushing on
	# (at most once every 90 s, so trickling reinforcements don't stall the push)
	if tf.kind == TaskForce.ATTACK and _spread(world, tf, c) > 500000 and tick - tf.last_regroup_tick >= 900:
		tf.last_regroup_tick = tick
		issue(world, MoveCommand.new(tf.units, c.x, c.y, MoveCommand.MODE_ATTACK_MOVE, false, doctrine.safe_routing))
		return
	var safe: bool = doctrine.safe_routing and FixedMath.length2(tf.goal_x - c.x, tf.goal_y - c.y) > 600000
	issue(world, MoveCommand.new(tf.units, tf.goal_x, tf.goal_y, MoveCommand.MODE_ATTACK_MOVE, false, safe))
	# Eastern EW trucks jam when the group is near the enemy, stay quiet otherwise
	if doctrine.use_ew:
		for u: int in tf.units:
			if world.def_of(u).has_ability("jam"):
				var near: bool = _threat_near(world, team, Vector2i(world.transform.x[u], world.transform.y[u])) > 0
				issue(world, EmconCommand.new(PackedInt32Array([u]), UnitStore.EMCON_EMIT if near else UnitStore.EMCON_RESTRICTED))


func _smoke_if_hit(world: SimWorld, tf: TaskForce, tick: int) -> void:
	var smokers: PackedInt32Array = PackedInt32Array()
	for u: int in tf.units:
		if world.units.smoke_charges[u] > 0 and tick - world.units.last_hit_tick[u] < TF_INTERVAL \
				and world.units.suppression[u] >= 300:
			smokers.append(u)
	if not smokers.is_empty():
		issue(world, SmokeCommand.new(smokers))


func _spread(world: SimWorld, tf: TaskForce, c: Vector2i) -> int:
	var m: int = 0
	for u: int in tf.units:
		m = maxi(m, FixedMath.length2(world.transform.x[u] - c.x, world.transform.y[u] - c.y))
	return m


func _threat_centroid(world: SimWorld, team: int, p: Vector2i) -> Vector2i:
	var n: int = 0
	var sx: int = 0
	var sy: int = 0
	for e: int in world.visible_enemies[team]:
		if world.is_structure(e):
			continue
		var x: int = world.transform.x[e]
		var y: int = world.transform.y[e]
		if FixedMath.dist2_sq(x, y, p.x, p.y) <= DEFEND_RADIUS_MM * DEFEND_RADIUS_MM:
			sx += x
			sy += y
			n += 1
	if n == 0:
		return Vector2i(-1, -1)
	return Vector2i(sx / n, sy / n)


## Counter-battery first, then barrages on what we see (Eastern doctrine also
## shells last-known structures); Coalition guns scoot after firing.
func _artillery(world: SimWorld, team: int, tf: TaskForce, tick: int) -> void:
	var ready: PackedInt32Array = PackedInt32Array()
	for u: int in tf.units:
		if world.orders.kind[u] == OrderStore.NONE:
			ready.append(u)
	if ready.is_empty():
		return
	var intel: SignalIntel = world.signals[team]
	# 1. counter-battery: tight fixes on enemy emitters, artillery first
	var best: int = 0
	var best_r: int = FIX_FIRE_RADIUS_MM + 1
	for em: int in intel.fixes():
		var r: int = intel.fix_r[em]
		if r > FIX_FIRE_RADIUS_MM or tick - int(_fired_on.get(em, -100000)) < 300:
			continue
		var pri: int = r - (100000 if int(intel.fix_kind[em]) == UnitStats.EMIT_RADAR else 0)
		if pri < best_r:
			best_r = pri
			best = em
	if best > 0:
		if issue(world, FireMissionCommand.new(ready, intel.fix_x[best], intel.fix_y[best], 4)):
			_fired_on[best] = tick
			return
	# 2. visible enemies (not too close to our own troops)
	for e: int in world.visible_enemies[team]:
		if world.is_air(e):
			continue
		var x: int = world.transform.x[e]
		var y: int = world.transform.y[e]
		if _friendly_near(world, team, x, y, 150000):
			continue
		if issue(world, FireMissionCommand.new(ready, x, y, 3)):
			if doctrine.shoot_and_scoot:
				_scoot(world, ready)
			return
	# 3. Eastern barrage on known enemy structures
	if doctrine.barrage and tick % 600 == 0:
		var layer: TeamVision = world.vision[team]
		for other: int in range(SimWorld.MAX_TEAMS):
			if not world.is_enemy_team(team, other):
				continue
			for s: int in world.team_units[other]:
				if world.is_structure(s) and layer.is_known(s):
					issue(world, FireMissionCommand.new(ready, layer.last_x[s], layer.last_y[s], 4))
					return


## Shoot-and-scoot: queue a 250 m relocation after the fire mission.
func _scoot(world: SimWorld, guns: PackedInt32Array) -> void:
	for g: int in guns:
		if world.orders.kind[g] == OrderStore.FIRE_MISSION:
			var ang: int = world.rng.range_int(0, SimConst.ANGLE_MASK)
			var x: int = clampi(world.transform.x[g] + 250000 * FixedMath.cos_b(ang) / FixedMath.ONE, 0, world.map_width_mm() - 1)
			var y: int = clampi(world.transform.y[g] + 250000 * FixedMath.sin_b(ang) / FixedMath.ONE, 0, world.map_height_mm() - 1)
			world.orders.enqueue(g, OrderStore.MOVE, 0, x, y)


func _friendly_near(world: SimWorld, team: int, x: int, y: int, r: int) -> bool:
	for f: int in world.team_units[team]:
		if FixedMath.dist2_sq(world.transform.x[f], world.transform.y[f], x, y) <= r * r:
			return true
	return false


## Recon sweeps the enemy half of the map; the Coalition also flies drones.
func _recon(world: SimWorld, team: int, tf: TaskForce, tick: int) -> void:
	if doctrine.use_drones:
		var op: int = 0
		for u: int in tf.units:
			if world.def_of(u).has_ability("drone_operator") and LaunchDroneCommand._drone_of(world, u) == 0:
				op = u
				break
		if op > 0 and world.players.supply[player] >= 400:
			issue(world, LaunchDroneCommand.new(PackedInt32Array([op]), world.players.faction[player] + "_uav_quad"))
		for id: int in my_units(world):
			if world.def_of(id).is_air and world.orders.kind[id] == OrderStore.NONE:
				var p: Vector2i = _scout_point(world, team, 3)
				issue(world, MoveCommand.new(PackedInt32Array([id]), p.x, p.y))
	if tick - tf.last_order_tick < 600:
		return
	tf.last_order_tick = tick
	var p2: Vector2i = _scout_point(world, team, 2)
	issue(world, MoveCommand.new(tf.units, p2.x, p2.y, MoveCommand.MODE_MOVE, false, doctrine.safe_routing))


## Cycles through points on the enemy side of the map.
func _scout_point(world: SimWorld, team: int, depth: int) -> Vector2i:
	_scout_index += 1
	var west: bool = false
	var hq: int = _own(world, team, "hq")
	if hq > 0:
		west = world.transform.x[hq] < world.map_width_mm() / 2
	var fx: Array[int] = [400, 300, 200, 350, 250]
	if west:
		fx = [600, 700, 800, 650, 750]
	var fy: Array[int] = [500, 250, 750, 400, 600]
	var k: int = _scout_index % 5
	var x: int = world.map_width_mm() * fx[k] / 1000
	if depth >= 3:
		x = world.map_width_mm() * (900 if west else 100) / 1000
	return Vector2i(x, world.map_height_mm() * fy[k] / 1000)


# ------------------------------------------------------------------ unit AI

func _unit_micro(world: SimWorld, team: int) -> void:
	var hq: int = _own(world, team, "hq")
	if hq == 0:
		return
	var hx: int = world.transform.x[hq]
	var hy: int = world.transform.y[hq] - 40000
	for id: int in my_units(world):
		var d: UnitStats = world.def_of(id)
		if d.is_air or d.has_ability("build"):
			continue
		var x: int = world.transform.x[id]
		var y: int = world.transform.y[id]
		var going_home: bool = world.orders.kind[id] == OrderStore.MOVE and FixedMath.dist2_sq(world.orders.goal_x[id], world.orders.goal_y[id], hx, hy) < 10000 * 10000
		if going_home:
			continue
		# hot zone: get out (safe route home)
		if world.radfield.rate_at(x, y) > HOT_RATE * 2 and not d.has_ability("decon"):
			_detach(id)
			issue(world, MoveCommand.new(PackedInt32Array([id]), hx, hy, MoveCommand.MODE_MOVE, false, true))
			continue
		# dry or badly hurt vehicles go home for resupply / repair
		if d.is_vehicle():
			var dry: bool = d.fuel_capacity > 0 and world.logistics.fuel[id] * 10 < d.fuel_capacity
			if not d.weapons.is_empty():
				dry = dry or world.weapons.ammo[id * WeaponStore.MAX_WEAPONS] < world.defs.weapons[d.weapons[0]].ammo_per_shot
			var hurt: bool = world.units.hp[id] * 10 < d.hp * 4
			if dry or hurt:
				_detach(id)
				issue(world, MoveCommand.new(PackedInt32Array([id]), hx, hy, MoveCommand.MODE_MOVE, false, doctrine.safe_routing))
				continue
		# pinned infantry in the open crawl to cover
		if d.is_infantry and world.units.suppression[id] >= MoraleSystem.PIN_THRESHOLD \
				and Combat.infantry_cover(world, id, d) < 300 and world.orders.kind[id] != OrderStore.RETREAT:
			var c: int = _cover_cell(world, x, y)
			if c >= 0:
				issue(world, MoveCommand.new(PackedInt32Array([id]), world.grid.center_x(c), world.grid.center_y(c)))


func _cover_cell(world: SimWorld, x: int, y: int) -> int:
	var g: SimGrid = world.grid
	var c0: int = g.cell_at(x, y)
	for r: int in range(1, 9):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var cx: int = g.cell_x(c0) + dx
				var cy: int = g.cell_y(c0) + dy
				if not g.in_grid(cx, cy):
					continue
				var c: int = g.index(cx, cy)
				if TerrainTable.COVER[g.terrain[c]] >= 400 and g.passable(TerrainTable.FOOT, c):
					return c
	return -1


# ------------------------------------------------------------------ helpers

func _detach(id: int) -> void:
	if not _assigned.has(id):
		return
	var tfid: int = _assigned[id]
	_assigned.erase(id)
	for tf: TaskForce in task_forces:
		if tf.id == tfid:
			var i: int = tf.units.find(id)
			if i >= 0:
				tf.units.remove_at(i)


func _join(world: SimWorld, tf: TaskForce, ids: PackedInt32Array) -> void:
	for u: int in ids:
		if not tf.units.has(u):
			tf.units.append(u)
			_assigned[u] = tf.id
	tf.units.sort()
	tf.start_size = maxi(tf.start_size, tf.units.size())
	tf.last_order_tick = -100000


func _new_tf(kind: int) -> TaskForce:
	var tf: TaskForce = TaskForce.new()
	tf.id = _next_tf
	_next_tf += 1
	tf.kind = kind
	task_forces.append(tf)
	return tf


func _find_kind(kind: int) -> TaskForce:
	for tf: TaskForce in task_forces:
		if tf.kind == kind:
			return tf
	return null


func _tf_of_kind(kind: int, world: SimWorld, hq: int) -> TaskForce:
	var tf: TaskForce = _find_kind(kind)
	if tf == null:
		tf = _new_tf(kind)
		tf.goal_x = world.transform.x[hq]
		tf.goal_y = world.transform.y[hq]
	return tf


func _own(world: SimWorld, team: int, role: String, include_sites: bool = false) -> int:
	for id: int in world.team_units[team]:
		if world.is_structure(id) and world.units.owner[id] == player and world.def_of(id).role == role:
			if include_sites or world.structures.is_complete(id):
				return id
	return 0


## Does this AI's battlegroup have anything to produce in the building?
func _can_use_building(world: SimWorld, role: String) -> bool:
	if role != "helipad":
		return true
	var faction: String = world.players.faction[player]
	for u: UnitStats in world.defs.producible(role, faction):
		if world.defs.allowed(u.id, faction, world.players.battlegroup[player]) and doctrine.weights.get(u.role, 0) > 0:
			return true
	return false


## Off-map support on the densest visible enemy cluster, when rich enough.
func _call_support(world: SimWorld, team: int) -> void:
	if world.players.supply[player] < 800:
		return
	var vis: PackedInt32Array = world.visible_enemies[team]
	var best: int = 0
	var best_n: int = 0
	for a: int in vis:
		if world.is_structure(a) or world.is_air(a):
			continue
		var n: int = 0
		for b: int in vis:
			if FixedMath.length2(world.transform.x[a] - world.transform.x[b], world.transform.y[a] - world.transform.y[b]) <= SUPPORT_CLUSTER_MM:
				n += 1
		if n > best_n:
			best_n = n
			best = a
	if best == 0 or best_n < SUPPORT_MIN_TARGETS:
		return
	for k: int in [SupportCommand.KIND_ARTILLERY, SupportCommand.KIND_AIRSTRIKE]:
		if issue(world, SupportCommand.new(k, world.transform.x[best], world.transform.y[best])):
			return
