## Phase 3: helicopters, off-map support over the radio, battlegroups.
extends TestCase


func test_helicopter_flies_high_and_drops_low_when_stopped() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 64))
	var h: int = SimFixture.spawn(w, "nc_heli_attack", 0, 100, 200)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([h]), 900000, 200000), w, 0)
	SimFixture.run(w, 60)
	var ground: int = w.grid.ground_at(w.transform.x[h], w.transform.y[h])
	assert_true(w.transform.z[h] - ground > 25000, "cruising altitude")
	SimFixture.run(w, 200)
	assert_eq(w.orders.kind[h], OrderStore.NONE, "arrived")
	ground = w.grid.ground_at(w.transform.x[h], w.transform.y[h])
	assert_true(w.transform.z[h] - ground < 15000, "hovering low")


func test_transport_helicopter_carries_a_squad() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 64))
	var h: int = SimFixture.spawn(w, "nc_heli_transport", 0, 100, 200)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 104, 200)
	assert_true(Transport.board(w, sq, h))
	SimFixture.cmd(UnloadCommand.new(PackedInt32Array([h]), 800000, 200000, true), w, 0)
	SimFixture.run(w, 250)
	assert_eq(w.units.carrier[sq], 0)
	assert_true(w.transform.x[sq] > 700000, "dropped far away")


func test_low_flying_helicopter_sees_over_forest() -> void:
	var g: SimGrid = SimFixture.flat_grid(64, 32)
	for y: int in range(32):
		for x: int in range(20, 30):
			g.terrain[g.index(x, y)] = TerrainTable.FOREST
	g.rebuild_sectors()
	var w: SimWorld = SimFixture.world(g)
	var ax: int = 100000
	var bx: int = 400000
	assert_eq(Los.check(w, ax, 100000, 2000, bx, 100000, 2000), Los.BLOCKED, "ground units: forest blocks")
	assert_eq(Los.check(w, ax, 100000, 35000, bx, 100000, 2000), Los.CLEAR, "from 35 m: over the canopy")


func test_airstrike_needs_observer_hits_and_reveals_the_caller() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 64))
	var hq: int = SimFixture.structure(w, "hq", 0, 5, 30)
	var spotter: int = SimFixture.spawn(w, "nc_recon_team", 0, 600, 250)
	var tank: int = SimFixture.spawn(w, "ec_mbt_72", 1, 800, 250)
	SimFixture.run(w, 10)
	var cmd: SupportCommand = SupportCommand.new(SupportCommand.KIND_AIRSTRIKE, 800000, 250000)
	cmd.player_id = 0
	assert_true(cmd.validate(w), "observed point")
	SimFixture.cmd(cmd, w, 0)
	w.step()
	assert_eq(w.units.tx_tick[hq], w.tick - 1, "HQ made the radio call")
	assert_true(SignalSystem.emission(w, hq) >= SignalSystem.ARTILLERY_PULSE, "strong burst")
	var hp: int = w.units.hp[tank]
	SimFixture.run(w, 260)
	assert_true(not w.is_unit(tank) or w.units.hp[tank] < hp, "bombs landed")
	assert_eq(SupportCommand.uses_left(w, 0, SupportCommand.KIND_AIRSTRIKE), 2)
	assert_true(spotter > 0)


func test_paradrop_spawns_squads() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 64))
	SimFixture.structure(w, "hq", 0, 5, 30)
	w.players.battlegroup[0] = 1  # air-mobile
	w.players.supply[0] = 1000
	w.players.manpower[0] = 100
	var before: int = w.entities.ids().size()
	SimFixture.cmd(SupportCommand.new(SupportCommand.KIND_PARADROP, 600000, 250000), w, 0)
	SimFixture.run(w, 320)
	assert_eq(w.entities.ids().size(), before + 2)


func test_battlegroup_limits_production_and_support() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 64))
	var pad: int = SimFixture.structure(w, "helipad", 0, 20, 20)
	w.players.supply[0] = 5000
	w.players.battlegroup[0] = 0  # armoured: no helicopters, no paradrop
	var c: ProduceCommand = ProduceCommand.new(pad, "nc_heli_attack")
	c.player_id = 0
	assert_false(c.validate(w), "no helicopters for the armoured group")
	w.players.battlegroup[0] = 2  # recon and fires
	assert_true(c.validate(w), "attack helicopters allowed")
	var s: SupportCommand = SupportCommand.new(SupportCommand.KIND_PARADROP, 600000, 250000)
	s.player_id = 0
	assert_false(s.validate(w), "recon group has no paradrop")
