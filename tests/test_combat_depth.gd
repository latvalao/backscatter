## Phase 2 combat depth: veterancy, routing, crew bail-out and recovery,
## digging in, mines, salvage, illumination flares.
extends TestCase


func test_kills_promote_and_veterans_shoot_better() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var a: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 100, 100)
	var b: int = SimFixture.spawn(w, "ec_mbt_72", 1, 300, 100)
	var base: int = Combat.hit_chance(w, a, b, w.defs.weapons[w.def_of(a).weapons[0]], 2500000)
	Veterancy.award(w, a, Veterancy.THRESHOLDS[2])
	assert_eq(w.units.rank[a], 2, "elite")
	assert_true(Combat.hit_chance(w, a, b, w.defs.weapons[w.def_of(a).weapons[0]], 2500000) > base, "better aim")
	var promoted: bool = false
	for e: SimEvent in w.drain_events():
		promoted = promoted or e.kind == SimEvent.Type.PROMOTED
	assert_true(promoted)


func test_broken_infantry_routs_and_ignores_orders() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var sq: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 200, 200)
	w.units.suppression[sq] = 1000
	w.units.morale[sq] = 100
	w.units.last_hit_tick[sq] = 0
	w.step()
	assert_true(w.units.rout_until[sq] > w.tick, "routing")
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([sq]), 400000, 400000), w, 1)
	SimFixture.run(w, 3)
	assert_eq(w.orders.kind[sq], OrderStore.RETREAT, "still running")


func test_destroyed_tank_leaves_wreck_and_crew_that_can_be_recovered() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	SimFixture.structure(w, "hq", 0, 10, 10)
	var tank: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 300, 300)
	var mp: int = w.players.manpower[0]
	w.units.hp[tank] = 0
	w.destroy_entity(tank)
	w.step()
	assert_eq(w.wrecks.count(), 1, "wreck left")
	var crew: int = 0
	for id: int in w.entities.ids():
		if w.units.has(id) and w.def_of(id).id == "nc_crew":
			crew = id
	assert_true(crew != 0, "crew bailed out")
	assert_eq(w.units.members_alive[crew], 4)
	w.transform.x[crew] = 100000
	w.transform.y[crew] = 100000
	SimFixture.run(w, 10)
	assert_false(w.is_unit(crew), "recovered at HQ")
	assert_true(w.players.manpower[0] >= mp + 4)


func test_engineer_salvages_wreck_for_supply() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var eng: int = SimFixture.spawn(w, "nc_engineer_veh", 0, 100, 100)
	w.wrecks.add(999, w.defs.unit_index("ec_mbt_72"), 160000, 100000, 85)
	var sup: int = w.players.supply[0]
	SimFixture.cmd(EngineerTaskCommand.new(PackedInt32Array([eng]), UnitStore.TASK_SALVAGE, 0, 0, 999), w, 0)
	SimFixture.run(w, 400)
	assert_eq(w.wrecks.count(), 0, "salvaged")
	assert_eq(w.players.supply[0], sup + 85)


func test_minefield_damages_enemy_vehicle_and_is_hidden_until_then() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	w.mines.add(300000, 100000, 0)
	assert_false(w.mines.is_known(0, 1), "hidden from the enemy")
	var tank: int = SimFixture.spawn(w, "ec_mbt_72", 1, 200, 100)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([tank]), 400000, 100000), w, 1)
	SimFixture.run(w, 200)
	assert_eq(w.mines.count(), 0, "mine went off")
	assert_true((w.units.damage[tank] & UnitStore.DMG_TRACKS) != 0, "tracks broken")


func test_engineer_lays_minefield() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var eng: int = SimFixture.spawn(w, "nc_engineer_veh", 0, 100, 100)
	SimFixture.cmd(EngineerTaskCommand.new(PackedInt32Array([eng]), UnitStore.TASK_LAY_MINES, 200000, 100000), w, 0)
	SimFixture.run(w, 200)
	assert_eq(w.mines.count(), FieldSystem.MINES_PER_FIELD)


func test_infantry_digs_in_for_extra_cover() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 100, 100)
	var before: int = Combat.infantry_cover(w, sq, w.def_of(sq))
	SimFixture.run(w, FieldSystem.DIG_IN_TICKS + 5)
	assert_true(Combat.infantry_cover(w, sq, w.def_of(sq)) > before)


func test_flare_lets_infantry_spot_at_night() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(200, 64))
	w.weather.night = true
	w.weather.next_change = 1 << 30
	var obs: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 100, 200)
	var mortar: int = SimFixture.spawn(w, "ec_mortar_team", 1, 90, 200)
	var tgt: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 1150, 200)
	SimFixture.run(w, 20)
	assert_false(w.vision[1].is_visible(tgt, w.tick), "dark: unseen at 1 km")
	SimFixture.cmd(FlareCommand.new(PackedInt32Array([mortar]), 1150000, 200000), w, 1)
	SimFixture.run(w, 20)
	assert_true(w.vision[1].is_visible(tgt, w.tick), "lit by the flare")
	assert_true(obs > 0)
