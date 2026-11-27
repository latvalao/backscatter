## M1 movement tests, including the acceptance test (200 units, 4×4 km map).
extends TestCase


func test_single_unit_reaches_goal_and_faces_travel() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var id: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 50, 50)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 50000, 400000), w, 0)
	SimFixture.run(w, 30)
	assert_near(w.transform.heading[id], 16384, 400, "turned north")
	SimFixture.run(w, 400)
	assert_eq(w.orders.kind[id], OrderStore.NONE, "arrived")
	assert_near(w.transform.y[id], 400000, 4000)


func test_vehicle_turn_rate_limited() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var id: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 250, 250)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 50000, 250000), w, 0)
	w.step()
	w.step()
	var def: UnitStats = w.def_of(id)
	assert_true(absi(FixedMath.angle_diff(0, w.transform.heading[id])) <= def.turn_rate * 2)


func test_reverse_move_keeps_front_toward_start() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var id: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 300, 100, 0)  # facing east
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 200000, 100000, MoveCommand.MODE_REVERSE), w, 0)
	SimFixture.run(w, 200)
	assert_true(w.transform.x[id] < 290000, "moved west")
	assert_near(FixedMath.angle_diff(0, w.transform.heading[id]), 0, 600, "still facing east")


func test_group_move_spreads_into_formation() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 128))
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in range(16):
		ids.append(SimFixture.spawn(w, "nc_rifle_sqd", 0, 100 + (i % 4) * 15, 100 + (i / 4) * 15))
	SimFixture.cmd(MoveCommand.new(ids, 450000, 400000), w, 0)
	SimFixture.run(w, 3000)
	for id: int in ids:
		assert_eq(w.orders.kind[id], OrderStore.NONE, "unit %d still moving" % id)
	_assert_no_stacking(w, ids)


func test_vehicle_routes_around_water() -> void:
	var g: SimGrid = SimGrid.new(64, 64)
	for y: int in range(10, 64):
		g.terrain[g.index(30, y)] = TerrainTable.WATER
	g.rebuild_sectors()
	var w: SimWorld = SimFixture.world(g)
	var id: int = SimFixture.spawn(w, "nc_supply_truck", 0, 100, 400)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 400000, 400000), w, 0)
	for i: int in range(3000):
		w.step()
		assert_true(g.passable(TerrainTable.WHEELED, g.cell_at(w.transform.x[id], w.transform.y[id])), "in water")
		if w.orders.kind[id] == OrderStore.NONE:
			break
	assert_near(w.transform.x[id], 400000, 6000)


static func _assert_no_stacking_static(w: SimWorld, ids: PackedInt32Array, tc: TestCase) -> int:
	var worst: int = 1 << 40
	for a: int in ids:
		for b: int in ids:
			if b <= a:
				continue
			var d: int = FixedMath.length2(w.transform.x[a] - w.transform.x[b], w.transform.y[a] - w.transform.y[b])
			var need: int = (w.def_of(a).radius_mm + w.def_of(b).radius_mm) / 2
			worst = mini(worst, d - need)
			if d < need:
				tc.fail("units %d and %d stacked (%d mm apart)" % [a, b, d])
				return worst
	return worst


func _assert_no_stacking(w: SimWorld, ids: PackedInt32Array) -> void:
	_assert_no_stacking_static(w, ids, self)


## M1 ACCEPTANCE: 200 mixed units cross the 4×4 km procedural map without
## stacking or getting stuck.
func test_m1_acceptance_200_units_cross_map() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.test_map())
	var defs: Array[String] = ["nc_rifle_sqd", "nc_mbt_2a", "nc_ifv_90", "nc_supply_truck"]
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in range(200):
		ids.append(SimFixture.spawn(w, defs[i % 4], 0, 300 + (i % 10) * 30, 1400 + (i / 10) * 30))
	var groups: Array[PackedInt32Array] = []
	for d: int in range(4):
		var grp: PackedInt32Array = PackedInt32Array()
		for i: int in range(200):
			if i % 4 == d:
				grp.append(ids[i])
		groups.append(grp)
	var t0: int = Time.get_ticks_msec()
	# infantry gets a shorter trip (walking pace); vehicles cross 2.4 km
	SimFixture.cmd(MoveCommand.new(groups[0], 1_300_000, 1_700_000), w, 0, 0)
	SimFixture.cmd(MoveCommand.new(groups[1], 2_900_000, 1_800_000), w, 0, 1)
	SimFixture.cmd(MoveCommand.new(groups[2], 2_900_000, 2_200_000), w, 0, 2)
	SimFixture.cmd(MoveCommand.new(groups[3], 2_900_000, 2_600_000), w, 0, 3)
	var ticks: int = 0
	while ticks < 9000:
		w.step()
		ticks += 1
		var moving: int = 0
		for id: int in ids:
			if w.orders.kind[id] != OrderStore.NONE:
				moving += 1
		if moving == 0:
			break
	var dt: int = Time.get_ticks_msec() - t0
	print("    200 units: %d ticks, %d ms total, %.2f ms/tick" % [ticks, dt, float(dt) / ticks])
	var far: int = 0
	var goal_x: Array[int] = [1_300_000, 2_900_000, 2_900_000, 2_900_000]
	var goal_y: Array[int] = [1_700_000, 1_800_000, 2_200_000, 2_600_000]
	for i: int in range(200):
		var id: int = ids[i]
		assert_eq(w.orders.kind[id], OrderStore.NONE, "unit %d (%s) never finished" % [id, defs[i % 4]])
		var d: int = FixedMath.length2(w.transform.x[id] - goal_x[i % 4], w.transform.y[id] - goal_y[i % 4])
		if d > 250_000:
			far += 1
	assert_true(far <= 4, "%d units ended far (>250 m) from their group's goal" % far)
	_assert_no_stacking(w, ids)
