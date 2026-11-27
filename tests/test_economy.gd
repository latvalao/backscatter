## M4: construction, production, depots, supply routes, logistics, repair, victory.
extends TestCase

var w: SimWorld


func before_each() -> void:
	w = SimFixture.world(SimFixture.flat_grid(160, 80))


func _road_row(g: SimGrid, row: int) -> void:
	for x: int in range(g.width):
		g.terrain[g.index(x, row)] = TerrainTable.ROAD


func test_placement_rules() -> void:
	var g: SimGrid = SimGrid.new(40, 40)
	g.terrain[g.index(10, 10)] = TerrainTable.WATER
	g.rebuild_sectors()
	var w2: SimWorld = SimFixture.world(g)
	var bar: UnitStats = w2.defs.unit("barracks")
	assert_true(ConstructionSystem.can_place(w2, bar, 2, 2))
	assert_false(ConstructionSystem.can_place(w2, bar, 9, 9), "water in footprint")
	assert_false(ConstructionSystem.can_place(w2, bar, 39, 2), "off the map")
	SimFixture.structure(w2, "barracks", 0, 2, 2)
	assert_false(ConstructionSystem.can_place(w2, bar, 3, 2), "overlaps")
	SimFixture.spawn(w2, "nc_rifle_sqd", 0, 20 * 8 + 4, 20 * 8 + 4)
	assert_false(ConstructionSystem.can_place(w2, bar, 19, 19), "unit standing there")


func test_structure_blocks_and_unblocks_movement() -> void:
	var s: int = SimFixture.structure(w, "motor_pool", 0, 10, 10)
	var c: int = w.grid.index(11, 11)
	assert_false(w.grid.passable(TerrainTable.TRACKED, c))
	assert_false(w.grid.passable(TerrainTable.FOOT, c))
	var trap: int = SimFixture.structure(w, "tank_trap", 0, 30, 10)
	assert_false(w.grid.passable(TerrainTable.TRACKED, w.grid.index(30, 10)))
	assert_true(w.grid.passable(TerrainTable.FOOT, w.grid.index(30, 10)), "infantry passes tank traps")
	w.destroy_entity(s)
	w.step()
	assert_true(w.grid.passable(TerrainTable.TRACKED, c), "rubble cleared")
	assert_eq(w.occupancy[c], 0)
	assert_true(trap > 0)


func test_engineer_builds_barracks() -> void:
	var eng: int = SimFixture.spawn(w, "nc_engineer_veh", 0, 100, 100)
	var sup0: int = w.players.supply[0]
	SimFixture.cmd(BuildCommand.new(PackedInt32Array([eng]), "barracks", 30, 10), w, 0)
	w.step()
	assert_eq(w.players.supply[0], sup0 - 200)
	var site: int = w.occupancy[w.grid.index(31, 10)]
	assert_true(site > 0)
	assert_false(w.structures.is_complete(site))
	assert_eq(w.orders.kind[eng], OrderStore.BUILD)
	var built: bool = false
	for i: int in range(1200):
		w.step()
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.BUILT and e.entity_id == site:
				built = true
		if built:
			break
	assert_true(built, "barracks finished")
	assert_eq(w.units.hp[site], w.def_of(site).hp)
	assert_eq(w.orders.kind[eng], OrderStore.NONE, "engineer released")


func test_build_rejected_without_supply_or_builder() -> void:
	var eng: int = SimFixture.spawn(w, "nc_engineer_veh", 0, 100, 100)
	var sq: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 140, 100)
	w.players.supply[0] = 100
	SimFixture.cmd(BuildCommand.new(PackedInt32Array([eng]), "barracks", 30, 10), w, 0, 0)
	SimFixture.cmd(BuildCommand.new(PackedInt32Array([sq]), "barracks", 40, 10), w, 0, 1)
	w.step()
	assert_eq(w.players.supply[0], 100)
	# infantry can dig trenches though
	SimFixture.cmd(BuildCommand.new(PackedInt32Array([sq]), "trench", 20, 30), w, 0, 2)
	w.step()
	assert_eq(w.players.supply[0], 80)


func test_production_queue_spawns_and_rallies() -> void:
	var bar: int = SimFixture.structure(w, "barracks", 0, 20, 20)
	var sup0: int = w.players.supply[0]
	var mp0: int = w.players.manpower[0]
	SimFixture.cmd(RallyCommand.new(bar, 400_000, 300_000), w, 0, 0)
	SimFixture.cmd(ProduceCommand.new(bar, "nc_rifle_sqd", 2), w, 0, 1)
	SimFixture.cmd(ProduceCommand.new(bar, "ec_motor_rifle", 1), w, 0, 2)  # wrong faction
	SimFixture.cmd(ProduceCommand.new(bar, "nc_mbt_2a", 1), w, 0, 3)       # wrong building
	w.step()
	assert_eq(w.structures.get_queue(bar).size(), 2)
	assert_eq(w.players.supply[0], sup0 - 120)
	assert_eq(w.players.manpower[0], mp0 - 16)
	var produced: PackedInt32Array = PackedInt32Array()
	for i: int in range(450):
		w.step()
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.PRODUCED:
				produced.append(e.entity_id)
	assert_eq(produced.size(), 2, "two squads in 2×20 s")
	assert_eq(w.def_of(produced[0]).id, "nc_rifle_sqd")
	assert_eq(w.orders.kind[produced[1]], OrderStore.MOVE, "heading to rally")
	assert_eq(w.orders.goal_x[produced[1]] / 1000, 400)


func test_cancel_refunds() -> void:
	var mp: int = SimFixture.structure(w, "motor_pool", 0, 20, 20)
	var sup0: int = w.players.supply[0]
	SimFixture.cmd(ProduceCommand.new(mp, "nc_mbt_2a", 1), w, 0, 0)
	w.step()
	assert_eq(w.players.supply[0], sup0 - 520)
	SimFixture.cmd(CancelProductionCommand.new(mp), w, 0, 1)
	w.step()
	assert_eq(w.players.supply[0], sup0)
	assert_true(w.structures.get_queue(mp).is_empty())


func test_depot_capture_and_contest() -> void:
	var d: int = SimFixture.structure(w, "depot_objective", -1, 60, 30)
	var a: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 60 * 8 - 20, 30 * 8 + 12)
	SimFixture.run(w, 150)
	assert_eq(w.structures.capture_team[d], 0, "capturing")
	assert_eq(w.structures.holder_team[d], -1)
	var b: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 60 * 8 + 40, 30 * 8 + 12)
	w.units.stance[a] = UnitStore.STANCE_HOLD_FIRE
	w.units.stance[b] = UnitStore.STANCE_HOLD_FIRE
	var p: int = w.structures.capture_progress[d]
	SimFixture.run(w, 200)
	assert_eq(w.structures.capture_progress[d], p, "contested: frozen")
	w.destroy_entity(b)
	SimFixture.run(w, 200)
	assert_eq(w.structures.holder_team[d], 0, "captured")
	assert_eq(w.structures.holder_player[d], 0)
	assert_false(w.vision[1].is_visible(d, 0) == false, "depots are visible to all")


func test_income_needs_road_route_and_trucks_ferry_stock() -> void:
	var g: SimGrid = SimGrid.new(200, 40)
	_road_row(g, 20)
	g.rebuild_sectors()
	var w2: SimWorld = SimFixture.world(g)
	var hq: int = SimFixture.structure(w2, "hq", 0, 5, 22)
	var d: int = SimFixture.structure(w2, "depot_objective", -1, 150, 22)
	w2.structures.holder_team[d] = 0
	w2.structures.holder_player[d] = 0
	var sup0: int = w2.players.supply[0]
	SimFixture.run(w2, 201)
	assert_eq(w2.structures.connected[d], 1, "road links depot and HQ")
	assert_true(w2.players.supply[0] > sup0, "income arrives")
	# enemy squad sits on the road halfway: route cut, income piles up as stock
	var e: int = SimFixture.spawn(w2, "ec_motor_rifle", 1, 640, 164)
	w2.units.stance[e] = UnitStore.STANCE_HOLD_FIRE
	var sup1: int = w2.players.supply[0]
	SimFixture.run(w2, 200)
	assert_eq(w2.structures.connected[d], 0, "route cut")
	assert_eq(w2.players.supply[0], sup1, "no direct income")
	assert_true(w2.structures.stock[d] > 0, "stock accumulates")
	# a truck parked at the depot loads, then delivers at the HQ
	var tr: int = SimFixture.spawn(w2, "nc_supply_truck", 0, 1200, 200)
	var stock0: int = w2.structures.stock[d]
	SimFixture.run(w2, 21)
	assert_true(w2.logistics.haul[tr] > 0, "truck loaded")
	assert_true(w2.structures.stock[d] < stock0)
	w2.transform.x[tr] = 80_000
	w2.transform.y[tr] = 200_000
	var sup2: int = w2.players.supply[0]
	SimFixture.run(w2, 21)
	assert_true(w2.players.supply[0] > sup2, "truck unloaded at HQ")
	assert_eq(w2.logistics.haul[tr], 0)
	assert_true(hq > 0)


func test_fuel_burns_and_empty_tank_stops() -> void:
	var t: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 50, 300)
	var f0: int = w.logistics.fuel[t]
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([t]), 1_050_000, 300_000), w, 0)
	SimFixture.run(w, 900)
	var used: int = f0 - w.logistics.fuel[t]
	assert_near(used, 8000, 1200, "~8 L for 1 km")
	w.logistics.fuel[t] = 0
	var x0: int = w.transform.x[t]
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([t]), 100_000, 300_000), w, 0, 1)
	SimFixture.run(w, 100)
	assert_near(w.transform.x[t], x0, 3000, "out of fuel: immobile")


func test_resupply_near_hq_costs_supply() -> void:
	SimFixture.structure(w, "hq", 0, 10, 10)
	var t: int = SimFixture.spawn(w, "nc_ifv_90", 0, 130, 100)
	var k: int = t * WeaponStore.MAX_WEAPONS
	w.weapons.ammo[k] = 0
	w.logistics.fuel[t] = 100_000
	var sup0: int = w.players.supply[0]
	SimFixture.run(w, 41)
	assert_true(w.weapons.ammo[k] > 0, "ammo restored")
	assert_true(w.logistics.fuel[t] > 100_000, "fuel restored")
	assert_true(w.players.supply[0] < sup0, "paid for")


func test_repair_yard_heals_and_fixes() -> void:
	SimFixture.structure(w, "repair_yard", 0, 10, 10)
	var t: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 130, 100)
	w.units.hp[t] = 700
	w.units.damage[t] = UnitStore.DMG_TRACKS
	SimFixture.run(w, 401)
	assert_true(w.units.hp[t] > 700)
	assert_eq(w.units.damage[t], 0, "tracks fixed once above half")


func test_losing_hq_loses_the_game() -> void:
	w.hq_required = true
	var hq0: int = SimFixture.structure(w, "hq", 0, 10, 10)
	var hq1: int = SimFixture.structure(w, "hq", 1, 140, 60)
	SimFixture.run(w, 20)
	assert_eq(w.winner_team, -1)
	w.destroy_entity(hq1)
	SimFixture.run(w, 21)
	assert_eq(w.winner_team, 0)
	assert_eq(w.players.defeated[1], 1)
	assert_true(hq0 > 0)


func test_tanks_can_kill_an_hq() -> void:
	var hq: int = SimFixture.structure(w, "hq", 1, 100, 30)
	w.vision[0].mark_seen(hq, w.transform.x[hq], w.transform.y[hq], 0, 1 << 30)
	var t: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 500, 260)
	SimFixture.cmd(AttackCommand.new(PackedInt32Array([t]), hq), w, 0)
	SimFixture.run(w, 900)
	assert_false(w.is_unit(hq), "HQ destroyed")
