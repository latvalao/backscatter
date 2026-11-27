## Phase 5 smart orders: overwatch sector, seize, auto counter-battery, crew rotation.
extends TestCase


func test_overwatch_ignores_targets_outside_the_sector() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 128))
	var a: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 500, 500)
	var north: int = SimFixture.spawn(w, "ec_mbt_72", 1, 500, 900)
	w.units.stance[north] = UnitStore.STANCE_HOLD_FIRE
	SimFixture.cmd(SmartOrderCommand.new(PackedInt32Array([a]), SmartOrderCommand.OVERWATCH, 900000, 500000), w, 0)
	SimFixture.run(w, 40)
	assert_eq(w.weapons.target[a * WeaponStore.MAX_WEAPONS], 0, "north is outside an east-facing sector")
	w.transform.x[north] = 800000
	w.transform.y[north] = 520000
	SimFixture.run(w, 30)
	assert_eq(w.weapons.target[a * WeaponStore.MAX_WEAPONS], north, "inside the sector")


func test_seize_moves_in_wedge_facing_the_objective() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 128))
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in range(3):
		ids.append(SimFixture.spawn(w, "nc_ifv_90", 0, 100 + i * 20, 100))
	SimFixture.cmd(SmartOrderCommand.new(ids, SmartOrderCommand.SEIZE, 120000, 700000), w, 0)
	w.step()
	for id: int in ids:
		assert_eq(w.orders.kind[id], OrderStore.ATTACK_MOVE)
		assert_near(FixedMath.angle_diff(16384, w.mobility.face[id]), 0, 300, "faces north")


func test_auto_counter_battery_fires_on_a_fix() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(200, 200))
	var gun: int = SimFixture.spawn(w, "nc_spg_155", 0, 100, 100)
	SimFixture.cmd(SmartOrderCommand.new(PackedInt32Array([gun]), SmartOrderCommand.AUTO_CB), w, 0)
	w.step()
	var intel: SignalIntel = w.signals[0]
	intel.fix_x[777] = 1200000
	intel.fix_y[777] = 1200000
	intel.fix_r[777] = 50000
	intel.fix_tick[777] = w.tick
	intel.fix_kind[777] = UnitStats.EMIT_RADIO
	SimFixture.run(w, 20)
	assert_eq(w.orders.kind[gun], OrderStore.FIRE_MISSION, "firing back")


func test_crew_rotation_sends_contaminated_vehicle_to_decon_and_back() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 128))
	SimFixture.structure(w, "decon_point", 0, 10, 10)
	var tank: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 700, 700)
	SimFixture.cmd(SmartOrderCommand.new(PackedInt32Array([tank]), SmartOrderCommand.ROTATE), w, 0)
	w.step()
	w.radiation.contamination[tank] = 5000
	SimFixture.run(w, 20)
	assert_true((w.units.smart[tank] & UnitStore.SMART_ROTATING) != 0, "rotating out")
	assert_eq(w.orders.kind[tank], OrderStore.MOVE)
	assert_near(w.units.home_x[tank], 700000, 5000, "remembers where to return")
