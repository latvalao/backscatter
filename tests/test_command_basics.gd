## Phase 1 command basics: transports, final facing, formations, engagement range.
extends TestCase


func test_squad_boards_ifv_rides_and_unloads_at_point() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var ifv: int = SimFixture.spawn(w, "nc_ifv_90", 0, 100, 100)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 125, 100)
	SimFixture.cmd(MountCommand.new(PackedInt32Array([sq]), ifv), w, 0)
	SimFixture.run(w, 120)
	assert_eq(w.units.carrier[sq], ifv, "boarded")
	assert_false(w.team_units[0].has(sq), "out of play while carried")
	SimFixture.cmd(UnloadCommand.new(PackedInt32Array([ifv]), 350000, 100000, true), w, 0)
	SimFixture.run(w, 300)
	assert_eq(w.units.carrier[sq], 0, "unloaded")
	assert_true(w.transform.x[sq] > 300000, "unloaded at the destination")


func test_carrier_destroyed_passengers_bail_out_with_losses() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var ifv: int = SimFixture.spawn(w, "nc_ifv_90", 0, 100, 100)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 105, 100)
	assert_true(Transport.board(w, sq, ifv))
	var before: int = w.units.members_alive[sq]
	w.destroy_entity(ifv)
	w.step()
	assert_true(w.is_unit(sq), "squad survives")
	assert_eq(w.units.carrier[sq], 0)
	assert_true(w.units.members_alive[sq] < before, "took losses")


func test_move_with_facing_turns_to_face_after_arrival() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var id: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 100, 100)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 200000, 100000, MoveCommand.MODE_MOVE, false, false, 0, 16384), w, 0)
	SimFixture.run(w, 250)
	assert_near(FixedMath.angle_diff(16384, w.transform.heading[id]), 0, 2000, "faces north")


func test_line_formation_spreads_sideways_and_keeps_slowest_pace() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 128))
	var ids: PackedInt32Array = PackedInt32Array([
		SimFixture.spawn(w, "nc_mbt_2a", 0, 100, 100), SimFixture.spawn(w, "nc_rifle_sqd", 0, 120, 100),
		SimFixture.spawn(w, "nc_mbt_2a", 0, 140, 100)])
	SimFixture.cmd(MoveCommand.new(ids, 120000, 600000, MoveCommand.MODE_MOVE, false, false, Formation.LINE), w, 0)
	w.step()
	var cap: int = w.mobility.speed_cap[ids[0]]
	assert_eq(cap, w.def_of(ids[1]).max_speed, "tank capped to infantry pace")
	var xs: Array[int] = [w.orders.goal_x[ids[0]], w.orders.goal_x[ids[1]], w.orders.goal_x[ids[2]]]
	var ys: Array[int] = [w.orders.goal_y[ids[0]], w.orders.goal_y[ids[1]], w.orders.goal_y[ids[2]]]
	assert_near(ys[0], ys[2], 2000, "same row")
	assert_true(absi(xs[0] - xs[2]) > 10000, "spread sideways")


func test_engagement_range_holds_fire_until_close() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(128, 64))
	var a: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 100, 200)
	var b: int = SimFixture.spawn(w, "ec_mbt_72", 1, 1100, 200, 32768)
	w.units.stance[b] = UnitStore.STANCE_HOLD_FIRE
	SimFixture.cmd(EngageRangeCommand.new(PackedInt32Array([a]), 500000), w, 0)
	SimFixture.run(w, 60)
	assert_eq(w.weapons.target[a * WeaponStore.MAX_WEAPONS], 0, "1 km away: no fire")
	w.transform.x[b] = 450000
	SimFixture.run(w, 30)
	assert_eq(w.weapons.target[a * WeaponStore.MAX_WEAPONS], b, "inside 500 m: engages")


func test_new_commands_round_trip_codec() -> void:
	var cmds: Array[SimCommand] = [MountCommand.new(PackedInt32Array([3]), 9), UnloadCommand.new(PackedInt32Array([9]), 1, 2, true),
		EngageRangeCommand.new(PackedInt32Array([4]), 700000), MoveCommand.new(PackedInt32Array([1]), 5, 6, 0, false, false, Formation.WEDGE, 1234)]
	var back: Array[SimCommand] = CommandCodec.decode(CommandCodec.encode(cmds))
	assert_eq(back.size(), 4)
	var m: MoveCommand = back[3] as MoveCommand
	assert_eq(m.formation, Formation.WEDGE)
	assert_eq(m.face, 1234)
	assert_eq((back[0] as MountCommand).carrier, 9)
