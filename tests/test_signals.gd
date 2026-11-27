## M6: emissions/EMCON, DF triangulation, counter-battery radar, jamming,
## drones, radio-net spotting delay, Networked Fires, Barrage Doctrine.
extends TestCase

var w: SimWorld


func before_each() -> void:
	w = SimFixture.world(SimFixture.flat_grid(400, 200))
	w.weather.next_change = 1 << 40
	w.weather.fog = false
	w.weather.raining = false


func _hold(ids: Array) -> void:
	for id: Variant in ids:
		w.units.stance[int(id)] = UnitStore.STANCE_HOLD_FIRE


func test_emcon_controls_emission() -> void:
	var sq: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 500, 500)
	var ew: int = SimFixture.spawn(w, "ec_ew_truck", 1, 600, 500)
	assert_eq(SignalSystem.emission(w, sq), 10)
	assert_eq(SignalSystem.emission(w, ew), 120)
	w.units.emcon[sq] = UnitStore.EMCON_RESTRICTED
	w.units.emcon[ew] = UnitStore.EMCON_RESTRICTED
	assert_eq(SignalSystem.emission(w, sq), 5)
	assert_eq(SignalSystem.emission(w, ew), 0, "jammer off unless EMIT")
	w.units.emcon[sq] = UnitStore.EMCON_SILENT
	assert_eq(SignalSystem.emission(w, sq), 0)
	w.units.last_fired_tick[sq] = w.tick
	assert_eq(SignalSystem.emission(w, sq), 0, "rifles don't pulse")


func test_two_df_sources_triangulate_one_gives_a_wedge() -> void:
	var hq: int = SimFixture.structure(w, "hq", 0, 20, 20)     # DF 1
	var ew: int = SimFixture.spawn(w, "ec_ew_truck", 1, 2400, 600)  # strength 120: 12+ km
	SimFixture.run(w, 11)
	var intel: SignalIntel = w.signals[0]
	assert_true(intel.fix_r.has(ew), "contact from one bearing")
	var r1: int = intel.fix_r[ew]
	assert_true(r1 >= 600000, "single bearing is a wide wedge (%d)" % r1)
	SimFixture.spawn(w, "nc_recon_team", 0, 1800, 1500)  # DF 2, different angle
	SimFixture.run(w, 30)
	var r2: int = intel.fix_r[ew]
	assert_true(r2 < 150000, "cross-fix is tight (%d mm)" % r2)
	var ex: int = intel.fix_x[ew]
	var ey: int = intel.fix_y[ew]
	assert_true(FixedMath.length2(ex - w.transform.x[ew], ey - w.transform.y[ew]) <= r2, "estimate within its radius")
	assert_true(hq > 0)


func test_silent_units_are_invisible_to_df() -> void:
	SimFixture.structure(w, "hq", 0, 20, 20)
	SimFixture.spawn(w, "nc_recon_team", 0, 1800, 1500)
	var sq: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 1200, 900)
	w.units.emcon[sq] = UnitStore.EMCON_SILENT
	SimFixture.run(w, 40)
	assert_false(w.signals[0].fix_r.has(sq))


func test_counter_battery_radar_fixes_firing_artillery() -> void:
	var radar: int = SimFixture.spawn(w, "nc_cbr_radar", 0, 300, 400)
	var spg: int = SimFixture.spawn(w, "ec_spg_122", 1, 2800, 1200)
	SimFixture.spawn(w, "ec_recon_sqd", 1, 600, 600)
	_hold([radar])
	# barrage (Eastern doctrine: unobserved grid allowed)
	SimFixture.cmd(FireMissionCommand.new(PackedInt32Array([spg]), 500_000, 500_000, 2), w, 1)
	var fixed: bool = false
	for i: int in range(200):
		w.step()
		if w.signals[0].fix_r.has(spg) and int(w.signals[0].fix_r[spg]) <= 40000:
			fixed = true
			break
	assert_true(fixed, "CB radar located the SPG")
	assert_true(w.signals[0].targetable(w.transform.x[spg], w.transform.y[spg], FireMissionCommand.MAX_FIX_RADIUS_MM))


func test_barrage_doctrine_vs_networked_requirements() -> void:
	var nc_mortar: int = SimFixture.spawn(w, "nc_mortar_team", 0, 300, 300)
	var ec_mortar: int = SimFixture.spawn(w, "ec_mortar_team", 1, 2900, 1300)
	SimFixture.cmd(FireMissionCommand.new(PackedInt32Array([nc_mortar]), 3_000_000, 1_000_000, 2), w, 0, 0)
	SimFixture.cmd(FireMissionCommand.new(PackedInt32Array([ec_mortar]), 2_000_000, 600_000, 2), w, 1, 0)
	w.step()
	assert_eq(w.orders.kind[nc_mortar], OrderStore.NONE, "Coalition needs eyes or a fix")
	assert_eq(w.orders.kind[ec_mortar], OrderStore.FIRE_MISSION, "Eastern pre-planned barrage")
	assert_true((w.orders.flags[ec_mortar] & OrderStore.FLAG_BARRAGE) != 0)


func test_jammer_cuts_net_and_drone_link() -> void:
	var recon: int = SimFixture.spawn(w, "nc_recon_team", 0, 300, 800)
	SimFixture.cmd(LaunchDroneCommand.new(PackedInt32Array([recon]), "nc_uav_quad"), w, 0, 0)
	w.step()
	var drone: int = 0
	for id: int in w.entities.ids():
		if w.units.has(id) and w.def_of(id).is_air:
			drone = id
	assert_true(drone > 0, "drone launched")
	assert_eq(w.units.link[drone], recon)
	assert_eq(w.players.supply[0], 2000 - 40)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([drone]), 2_200_000, 800_000), w, 0, 1)
	SimFixture.run(w, 200)
	assert_true(w.transform.x[drone] > 500_000, "flying")
	assert_true(w.is_on_net(recon))
	var ew: int = SimFixture.spawn(w, "ec_ew_truck", 1, 2600, 800)
	_hold([recon, ew])
	SimFixture.run(w, 30)
	assert_eq(w.jammed[drone], 1, "drone inside the jamming bubble")
	assert_true(w.units.link_lost[drone] > 0, "link lost")
	SimFixture.run(w, 400)
	assert_false(w.is_unit(drone), "drone crashed after losing its link")


func test_drone_battery_runs_out() -> void:
	var recon: int = SimFixture.spawn(w, "nc_recon_team", 0, 300, 800)
	SimFixture.cmd(LaunchDroneCommand.new(PackedInt32Array([recon]), "nc_uav_quad"), w, 0)
	SimFixture.run(w, 3590)
	var alive: int = 0
	for id: int in w.entities.ids():
		if w.is_unit(id) and w.def_of(id).is_air:
			alive += 1
	assert_eq(alive, 1)
	SimFixture.run(w, 20)
	alive = 0
	for id: int in w.entities.ids():
		if w.is_unit(id) and w.def_of(id).is_air:
			alive += 1
	assert_eq(alive, 0, "6-minute battery")


func test_off_net_spotting_is_delayed() -> void:
	var obs: int = SimFixture.spawn(w, "nc_recon_team", 0, 300, 800)
	var tgt: int = SimFixture.spawn(w, "ec_mbt_72", 1, 1500, 800)
	_hold([obs, tgt])
	w.units.emcon[obs] = UnitStore.EMCON_SILENT
	SimFixture.run(w, 12)
	assert_false(w.vision[0].is_visible(tgt, w.tick), "silent observer: report not yet in")
	SimFixture.run(w, 60)
	assert_true(w.vision[0].is_known(tgt), "courier delay delivered it")


func test_networked_fires_coalition_mortar() -> void:
	var mortar: int = SimFixture.spawn(w, "nc_mortar_team", 0, 300, 800)
	var obs: int = SimFixture.spawn(w, "nc_recon_team", 0, 1600, 800)
	var tgt: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 2600, 820)
	_hold([obs, tgt])
	var hits: int = 0
	for i: int in range(600):
		w.step()
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.SHOT and e.entity_id == mortar:
				hits += 1
	assert_true(hits >= 2, "mortar fired on the recon team's sighting (%d rounds)" % hits)


func test_air_targets_need_anti_air_weapons() -> void:
	var recon: int = SimFixture.spawn(w, "nc_recon_team", 0, 300, 800)
	SimFixture.cmd(LaunchDroneCommand.new(PackedInt32Array([recon]), "nc_uav_quad"), w, 0)
	w.step()
	var drone: int = w.entities.ids()[w.entities.ids().size() - 1]
	var atgm: WeaponStats = w.defs.weapon("ec_atgm_wire")
	var aa: WeaponStats = w.defs.weapon("ec_aa_23")
	assert_eq(WeaponSystem.effectiveness(w, atgm, recon, drone), 0)
	assert_true(WeaponSystem.effectiveness(w, aa, recon, drone) > 0)
