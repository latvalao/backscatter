## M5: dose math, protection factors, dose states, contamination, treatment,
## plume advection + rain-out, radiation-aware "safe" pathing.
extends TestCase

var w: SimWorld


func before_each() -> void:
	w = SimFixture.world(SimFixture.flat_grid(120, 60))
	w.weather.wind_speed = 0
	w.weather.raining = false
	w.weather.fog = false
	w.weather.next_change = 1 << 40


func _uniform(rate: int) -> void:
	w.radfield.ground.fill(rate)


func test_dose_accrual_exact() -> void:
	_uniform(3_600_000)  # 3.6 Sv/h = 100 µSv per tick at PF 1
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 200, 200)
	SimFixture.run(w, 100)
	assert_eq(w.radiation.dose[sq], 100 * 100, "100 ticks × 100 µSv")


func test_protection_factor_scales_dose() -> void:
	_uniform(3_600_000)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 200, 200)
	var mbt: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 400, 200)
	SimFixture.run(w, 120)
	assert_eq(w.radiation.dose[sq] / w.radiation.dose[mbt], 12, "PF 12 tank")


func test_balance_targets_section_11() -> void:
	# a full 30-minute match in a moderate (6.5 Sv/h) hot spot
	_uniform(6_500_000)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 200, 200)
	var mbt: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 400, 200)
	w.units.stance[sq] = UnitStore.STANCE_HOLD_FIRE
	SimFixture.run(w, 3000)
	# extrapolate the measured rate to 18000 ticks
	var inf_30: int = w.radiation.dose[sq] * 6
	var mbt_30: int = w.radiation.dose[mbt] * 6
	assert_eq(DoseState.of(mbt_30), DoseState.EXPOSED, "tank crew buttoned up: Exposed")
	assert_eq(DoseState.of(inf_30), DoseState.SEVERE, "infantry: Severe")


func test_trench_and_nbc_overpressure() -> void:
	_uniform(3_600_000)
	var open_sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 100, 100)
	SimFixture.structure(w, "trench", 0, 50, 20)
	var dug: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 50 * 8 + 4, 20 * 8 + 4)
	var ec_tank: int = SimFixture.spawn(w, "ec_mbt_72", 1, 700, 300)
	for id: int in [open_sq, dug, ec_tank]:
		w.units.stance[id] = UnitStore.STANCE_HOLD_FIRE
	var f0: int = w.logistics.fuel[ec_tank]
	SimFixture.run(w, 60)
	assert_eq(w.radiation.dose[open_sq] / w.radiation.dose[dug], 3, "trench ×3")
	assert_eq(w.radiation.dose[ec_tank], 6000 / (18 * 2), "PF 18 × overpressure 2")
	assert_true(w.logistics.fuel[ec_tank] < f0, "overpressure burns fuel")


func test_dose_states_and_effects() -> void:
	assert_eq(DoseState.of(249_999), DoseState.NORMAL)
	assert_eq(DoseState.of(250_000), DoseState.EXPOSED)
	assert_eq(DoseState.of(1_500_000), DoseState.MILD)
	assert_eq(DoseState.of(2_000_000), DoseState.SEVERE)
	assert_eq(DoseState.of(4_000_000), DoseState.CRITICAL)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 200, 200)
	var tgt: int = SimFixture.spawn(w, "ec_mbt_72", 1, 800, 200)
	var gun: WeaponStats = w.defs.weapon("nc_rifle")
	var a0: int = Combat.hit_chance(w, sq, tgt, gun, 300000)
	w.radiation.dose[sq] = 2_500_000
	assert_true(Combat.hit_chance(w, sq, tgt, gun, 300000) < a0, "Severe: worse aim")
	assert_false(DoseState.can_capture(w, sq), "Severe can't capture")
	# Critical: soldiers start dropping
	w.radiation.dose[sq] = 4_500_000
	SimFixture.run(w, 1250)
	assert_true(w.units.members_alive[sq] < 8, "ARS casualties")


func test_contamination_pickup_decon_and_repair_block() -> void:
	_uniform(2)
	w.radfield.add_hotspot(300_000, 240_000, 200_000, 5_000_000)
	var truck: int = SimFixture.spawn(w, "nc_supply_truck", 0, 150, 240)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([truck]), 450_000, 240_000), w, 0)
	SimFixture.run(w, 200)
	var c: int = w.radiation.contamination[truck]
	assert_true(c > RadiationSystem.REPAIR_BLOCK_CONTAMINATION, "picked up fallout dust (%d)" % c)
	# repair is refused while contaminated
	SimFixture.cmd(StopCommand.new(PackedInt32Array([truck])), w, 0, 1)
	w.step()
	SimFixture.structure(w, "repair_yard", 0, 60, 26)
	w.transform.x[truck] = 60 * 8000 + 30000
	w.transform.y[truck] = 26 * 8000 - 20000
	w.units.hp[truck] = 100
	SimFixture.run(w, 41)
	assert_eq(w.units.hp[truck], 100, "no repair while contaminated")
	# a CBRN squad next to it scrubs it clean
	SimFixture.spawn(w, "nc_decon_sqd", 0, w.transform.x[truck] / 1000 + 10, w.transform.y[truck] / 1000)
	SimFixture.run(w, 600)
	assert_true(w.radiation.contamination[truck] < c / 10, "decontaminated")


func test_field_hospital_recovers_mild() -> void:
	SimFixture.structure(w, "field_hospital", 0, 20, 20)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 20 * 8 + 12, 20 * 8 - 20)
	w.radiation.dose[sq] = 1_200_000
	SimFixture.run(w, 401)
	assert_true(w.radiation.dose[sq] < 1_200_000 - 20 * 20000)


func test_plume_drifts_with_wind_and_rains_out() -> void:
	var f: RadiationField = RadiationField.new(4_000_000, 4_000_000)
	f.add_source(0, 30, 1_000_000, 2_000_000, 500_000)
	for t: int in range(0, 300, 10):
		f.step(t, 6000, 0, false)
	var c1: Vector2i = f.air_centroid()
	for t: int in range(300, 1200, 10):
		f.step(t, 6000, 0, false)
	var c2: Vector2i = f.air_centroid()
	assert_true(c2.x > c1.x + 300_000, "plume moved east with the wind (%d -> %d)" % [c1.x, c2.x])
	assert_near(c2.y, 2_000_000, 64_000, "no north-south drift")
	var g0: int = f.ground[f.index_at(c2.x, c2.y)]
	for t: int in range(1200, 1500, 10):
		f.step(t, 6000, 0, true)
	var gsum: int = 0
	for v: int in f.ground:
		gsum += v
	assert_true(gsum > RadiationField.BACKGROUND * f.w * f.h + 1000, "rain deposited fallout")
	assert_true(g0 >= 0)


func test_safe_move_avoids_hotspot() -> void:
	var g: SimGrid = SimFixture.flat_grid(150, 80)
	var w2: SimWorld = SimFixture.world(g)
	w2.radfield.add_hotspot(600_000, 320_000, 220_000, 8_000_000)
	var fast: PackedInt32Array = w2.pathfinder.find_path(TerrainTable.TRACKED, g.index(10, 40), g.index(140, 40), false)
	var safe: PackedInt32Array = w2.pathfinder.find_path(TerrainTable.TRACKED, g.index(10, 40), g.index(140, 40), true)
	var exposure_fast: int = _exposure(w2, g, g.index(10, 40), fast)
	var exposure_safe: int = _exposure(w2, g, g.index(10, 40), safe)
	assert_true(exposure_safe * 5 < exposure_fast, "safe route exposure %d vs fastest %d" % [exposure_safe, exposure_fast])
	# and through the command path
	var t: int = SimFixture.spawn(w2, "nc_mbt_2a", 0, 80, 320)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([t]), 1_120_000, 320_000, MoveCommand.MODE_MOVE, false, true), w2, 0)
	var max_rate: int = 0
	for i: int in range(1200):
		w2.step()
		max_rate = maxi(max_rate, w2.radfield.rate_at(w2.transform.x[t], w2.transform.y[t]))
	assert_true(max_rate < 2_000_000, "never entered the hot core (peak %d µSv/h)" % max_rate)


## Sum of dose rate sampled every 4 m along a path.
func _exposure(w2: SimWorld, g: SimGrid, start: int, path: PackedInt32Array) -> int:
	var total: int = 0
	var prev: int = start
	for c: int in path:
		var ax: int = g.center_x(prev)
		var ay: int = g.center_y(prev)
		var bx: int = g.center_x(c)
		var by: int = g.center_y(c)
		var n: int = maxi(1, FixedMath.length2(bx - ax, by - ay) / 4000)
		for k: int in range(n):
			total += w2.radfield.rate_at(ax + (bx - ax) * k / n, ay + (by - ay) * k / n) / 1000
		prev = c
	return total
