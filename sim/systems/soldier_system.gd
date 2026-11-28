# SIM: deterministic — no floats, no Nodes
## Tick phase 3b (after movement): the soldiers of every infantry squad move
## on their own. The squad entity is the anchor you command; its soldiers
##  - follow it in a loose wedge while it moves, sprinting to catch up,
##  - spread into the best cover around it when it stops (each picks his own
##    spot: walls and houses, tree lines, rocks, trenches; gunners first),
##  - kneel when engaged, go prone under heavy fire or in open ground, crawl
##    when pinned,
##  - when a soldier goes down, a buddy (the medic if there is one) runs to
##    him, drags him into cover and patches him up; untreated, he bleeds out.
## Combat reads the soldiers' own positions, cover and posture (Combat).
class_name SoldierSystem
extends SimSystem

const M: int = SquadStore.MAX_MEMBERS
## Wedge spacing while moving (mm): behind the leader and out to the sides.
const ROW_MM: int = 3200
const SIDE_MM: int = 1900
## Cover search: cells around the anchor, 4 spots per cell.
const SPOT_RADIUS: int = 2
const SPOT_OFF_MM: int = 2100
const SCAN_INTERVAL: int = 25
const SPRINT_PERMILLE: int = 1350
const CRAWL_PERMILLE: int = 300
const DRAG_PERMILLE: int = 380
## A soldier left with this share of his hp (or less) goes down.
const DOWN_HP_PERMILLE: int = 400
const BLEED_TICKS: int = 900
const TREAT_TICKS: int = 220
const MEDIC_TREAT_TICKS: int = 110
## Too much fire to go out for a casualty.
const RESCUE_MAX_SUPPRESSION: int = 850
const REACH_MM: int = 1300


func step(world: SimWorld, tick: int) -> void:
	for id: int in world.entities.ids():
		if world.squads.has(id) and world.is_unit(id):
			_squad(world, id, tick)


func _squad(world: SimWorld, id: int, tick: int) -> void:
	var s: SquadStore = world.squads
	var t: TransformStore = world.transform
	var def: UnitStats = world.def_of(id)
	var base: int = id * M
	if world.units.carrier[id] != 0:
		# mounted: riding inside the carrier
		s.placed[id] = 0
		for m: int in range(M):
			s.mx[base + m] = t.x[id]
			s.my[base + m] = t.y[id]
		return
	if s.placed[id] == 0:
		s.placed[id] = 1
		for m: int in range(M):
			var p: Vector2i = _slot(world, id, m)
			s.mx[base + m] = p.x
			s.my[base + m] = p.y
			s.tx[base + m] = p.x
			s.ty[base + m] = p.y
			s.heading[base + m] = t.heading[id]
	var moving: bool = world.mobility.speed[id] != 0
	if moving:
		for m: int in range(M):
			var p2: Vector2i = _slot(world, id, m)
			s.tx[base + m] = p2.x
			s.ty[base + m] = p2.y
	elif (tick + id) % SCAN_INTERVAL == 0 or _far_from_anchor(world, id):
		_assign_cover(world, id, def)
	_casualties(world, id, def, tick)
	if not world.is_unit(id):
		return
	var speed: int = maxi(300, MovementSystem.effective_max_speed(world, id, def))
	var supp: int = world.units.suppression[id]
	var engaged: int = _target(world, id, def)
	for m2: int in range(M):
		var k: int = base + m2
		if s.member_hp[k] <= 0:
			continue
		if s.state[k] == SquadStore.STATE_DOWN:
			s.posture[k] = SquadStore.PRONE
			continue
		_move_member(world, id, def, m2, speed, supp, engaged, moving)


## Where soldier m walks while the squad moves: leader in front, the rest in a
## loose wedge behind, each with his own small offset.
func _slot(world: SimWorld, id: int, m: int) -> Vector2i:
	var t: TransformStore = world.transform
	var h: int = t.heading[id]
	var c: int = FixedMath.cos_b(h)
	var sn: int = FixedMath.sin_b(h)
	var row: int = (m + 1) / 2
	var side: int = 0 if m == 0 else (-1 if m % 2 == 1 else 1)
	var j: int = SimRng.hash3(id, m, 7)
	var fwd: int = -row * ROW_MM + ((j & 0x3FF) - 512)
	var lat: int = side * (SIDE_MM * row / 2 + SIDE_MM) + (((j >> 10) & 0x3FF) - 512)
	var x: int = t.x[id] + (fwd * c - lat * sn) / FixedMath.ONE
	var y: int = t.y[id] + (fwd * sn + lat * c) / FixedMath.ONE
	return Vector2i(clampi(x, 0, world.map_width_mm() - 1), clampi(y, 0, world.map_height_mm() - 1))


func _far_from_anchor(world: SimWorld, id: int) -> bool:
	var s: SquadStore = world.squads
	var limit: int = (SPOT_RADIUS + 1) * SimGrid.CELL_MM
	for m: int in range(M):
		var k: int = id * M + m
		if s.member_hp[k] > 0 and FixedMath.length2(s.tx[k] - world.transform.x[id], s.ty[k] - world.transform.y[id]) > limit:
			return true
	return false


## Each soldier takes the best free spot near the anchor: cover first, then
## closeness to the anchor and to where he already is. Support weapons and
## the leader choose first.
func _assign_cover(world: SimWorld, id: int, def: UnitStats) -> void:
	var s: SquadStore = world.squads
	var t: TransformStore = world.transform
	var g: SimGrid = world.grid
	var ac: int = g.cell_at(t.x[id], t.y[id])
	var acx: int = g.cell_x(ac)
	var acy: int = g.cell_y(ac)
	var sx: PackedInt64Array = PackedInt64Array()
	var sy: PackedInt64Array = PackedInt64Array()
	var sc: PackedInt32Array = PackedInt32Array()
	var dug: int = FieldSystem.dug_in_bonus(world, id)
	for dy: int in range(-SPOT_RADIUS, SPOT_RADIUS + 1):
		for dx: int in range(-SPOT_RADIUS, SPOT_RADIUS + 1):
			var cx: int = acx + dx
			var cy: int = acy + dy
			if not g.in_grid(cx, cy):
				continue
			var ci: int = g.index(cx, cy)
			if not g.passable(TerrainTable.FOOT, ci):
				continue
			for q: int in range(4):
				var hq: int = SimRng.hash3(cx, cy, 40 + q)
				var x: int = g.center_x(ci) + (SPOT_OFF_MM if q & 1 == 1 else -SPOT_OFF_MM) + ((hq & 0x7FF) - 1024)
				var y: int = g.center_y(ci) + (SPOT_OFF_MM if q & 2 == 2 else -SPOT_OFF_MM) + (((hq >> 11) & 0x7FF) - 1024)
				var cov: int = maxi(TerrainTable.COVER[g.terrain[ci]], world.fortification_cover(x, y, true))
				sx.append(x)
				sy.append(y)
				sc.append(mini(850, cov + dug))
	if sx.is_empty():
		return
	var taken: PackedByteArray = PackedByteArray()
	taken.resize(sx.size())
	for pass_i: int in range(4):
		for m: int in range(M):
			var k: int = id * M + m
			if s.member_hp[k] <= 0 or s.state[k] == SquadStore.STATE_DOWN:
				continue
			var r: int = s.role[k]
			var prio: int = 0 if (r == SquadStore.ROLE_GUNNER or r == SquadStore.ROLE_AT) else (1 if r == SquadStore.ROLE_LEADER else 2)
			if prio != pass_i:
				continue
			var best: int = -1
			var best_v: int = -(1 << 40)
			for i: int in range(sx.size()):
				if taken[i] == 1:
					continue
				var v: int = sc[i] * 30 - FixedMath.length2(sx[i] - t.x[id], sy[i] - t.y[id]) / 40 \
					- FixedMath.length2(sx[i] - s.mx[k], sy[i] - s.my[k]) / 80
				if v > best_v:
					best_v = v
					best = i
			if best < 0:
				continue
			taken[best] = 1
			s.tx[k] = sx[best]
			s.ty[k] = sy[best]


## First live target of the squad's weapons (0 if none).
func _target(world: SimWorld, id: int, def: UnitStats) -> int:
	for slot: int in range(def.weapons.size()):
		var tg: int = world.weapons.target[id * WeaponStore.MAX_WEAPONS + slot]
		if tg > 0 and world.is_unit(tg):
			return tg
	return 0


func _move_member(world: SimWorld, id: int, def: UnitStats, m: int, speed: int, supp: int, engaged: int, moving: bool) -> void:
	var s: SquadStore = world.squads
	var k: int = id * M + m
	var gx: int = s.tx[k]
	var gy: int = s.ty[k]
	var dragging: bool = false
	if s.task[k] == SquadStore.TASK_DRAG:
		var v: int = id * M + s.task_arg[k]
		if FixedMath.length2(s.mx[v] - s.mx[k], s.my[v] - s.my[k]) > REACH_MM:
			gx = s.mx[v]
			gy = s.my[v]
		else:
			dragging = true
	elif s.task[k] == SquadStore.TASK_TREAT:
		s.posture[k] = SquadStore.CROUCH
		return
	var dx: int = gx - s.mx[k]
	var dy: int = gy - s.my[k]
	var d: int = FixedMath.length2(dx, dy)
	var pinned: bool = supp >= MoraleSystem.PIN_THRESHOLD
	var step: int = speed
	if dragging:
		step = speed * DRAG_PERMILLE / 1000
	elif pinned and not moving:
		step = speed * CRAWL_PERMILLE / 1000
	elif d > 12000:
		step = speed * SPRINT_PERMILLE / 1000
	if d > 0:
		var mv: int = mini(step, d)
		var nx: int = s.mx[k] + dx * mv / d
		var ny: int = s.my[k] + dy * mv / d
		if world.grid.passable_at(TerrainTable.FOOT, nx, ny):
			s.mx[k] = nx
			s.my[k] = ny
			if dragging:
				# the casualty is hauled along just behind
				var v2: int = id * M + s.task_arg[k]
				s.mx[v2] = nx - dx * 900 / d
				s.my[v2] = ny - dy * 900 / d
		s.heading[k] = FixedMath.atan2_b(dy, dx) if not dragging else FixedMath.atan2_b(-dy, -dx)
	if dragging and d <= 600:
		s.task[k] = SquadStore.TASK_TREAT
		s.timer[k] = 0
	var cell: int = world.grid.cell_at(s.mx[k], s.my[k])
	s.cover[k] = maxi(TerrainTable.COVER[world.grid.terrain[cell]], world.fortification_cover(s.mx[k], s.my[k], true))
	if d <= 800 and engaged != 0:
		s.heading[k] = FixedMath.atan2_b(world.transform.y[engaged] - s.my[k], world.transform.x[engaged] - s.mx[k])
	elif d <= 800 and moving:
		s.heading[k] = world.transform.heading[id]
	# posture
	var r: int = s.role[k]
	var p: int = SquadStore.STAND
	if dragging:
		p = SquadStore.CROUCH
	elif d > 800:
		p = SquadStore.PRONE if (pinned and not moving) else (SquadStore.CROUCH if supp > 300 else SquadStore.STAND)
	elif pinned:
		p = SquadStore.PRONE
	elif engaged != 0 or supp > 150:
		if r == SquadStore.ROLE_GUNNER:
			p = SquadStore.PRONE
		elif s.cover[k] >= 400 or r == SquadStore.ROLE_AT:
			p = SquadStore.CROUCH
		else:
			p = SquadStore.PRONE
	elif not moving and (SimRng.hash3(id, m, world.tick / 300) & 3) == 0:
		p = SquadStore.CROUCH
	s.posture[k] = p


## Downed soldiers bleed; a free buddy (medic first, then the nearest
## rifleman) goes out for each, drags him to his own cover spot and treats him.
func _casualties(world: SimWorld, id: int, def: UnitStats, tick: int) -> void:
	var s: SquadStore = world.squads
	var base: int = id * M
	var any_ok: bool = false
	var any_down: bool = false
	for m: int in range(M):
		var k: int = base + m
		if s.member_hp[k] <= 0:
			continue
		if s.state[k] == SquadStore.STATE_DOWN:
			any_down = true
		else:
			any_ok = true
	if not any_down:
		return
	if not any_ok:
		# nobody left to help: the wounded are lost
		for m0: int in range(M):
			if s.member_hp[base + m0] > 0:
				Combat.kill_member(world, id, m0, 0)
				if not world.is_unit(id):
					return
		return
	for m2: int in range(M):
		var k2: int = base + m2
		if s.member_hp[k2] <= 0 or s.state[k2] != SquadStore.STATE_DOWN:
			continue
		var helper: int = _helper_of(world, id, m2)
		if helper >= 0 and s.task[base + helper] == SquadStore.TASK_TREAT:
			s.timer[base + helper] += 1
			var need: int = MEDIC_TREAT_TICKS if s.role[base + helper] == SquadStore.ROLE_MEDIC else TREAT_TICKS
			if s.timer[base + helper] >= need:
				s.state[k2] = SquadStore.STATE_OK
				s.member_hp[k2] = maxi(s.member_hp[k2], def.hp / 2)
				s.timer[k2] = 0
				s.task[base + helper] = SquadStore.TASK_NONE
				s.timer[base + helper] = 0
			continue
		s.timer[k2] += 1
		if s.timer[k2] >= BLEED_TICKS:
			if helper >= 0:
				s.task[base + helper] = SquadStore.TASK_NONE
			Combat.kill_member(world, id, m2, 0)
			if not world.is_unit(id):
				return
			continue
		if helper < 0 and world.units.suppression[id] < RESCUE_MAX_SUPPRESSION:
			var pick: int = _pick_helper(world, id, m2)
			if pick >= 0:
				s.task[base + pick] = SquadStore.TASK_DRAG
				s.task_arg[base + pick] = m2
				s.timer[base + pick] = 0


func _helper_of(world: SimWorld, id: int, victim: int) -> int:
	var s: SquadStore = world.squads
	for m: int in range(M):
		var k: int = id * M + m
		if s.member_hp[k] > 0 and s.task[k] != SquadStore.TASK_NONE and s.task_arg[k] == victim:
			return m
	return -1


func _pick_helper(world: SimWorld, id: int, victim: int) -> int:
	var s: SquadStore = world.squads
	var v: int = id * M + victim
	var best: int = -1
	var best_d: int = 1 << 40
	for m: int in range(M):
		var k: int = id * M + m
		if s.member_hp[k] <= 0 or s.state[k] != SquadStore.STATE_OK or s.task[k] != SquadStore.TASK_NONE:
			continue
		var r: int = s.role[k]
		if r == SquadStore.ROLE_GUNNER or r == SquadStore.ROLE_AT:
			continue
		var d: int = FixedMath.length2(s.mx[k] - s.mx[v], s.my[k] - s.my[v])
		if r == SquadStore.ROLE_MEDIC:
			d -= 1 << 30
		if d < best_d:
			best_d = d
			best = m
	return best
