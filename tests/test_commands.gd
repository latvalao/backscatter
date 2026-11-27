extends TestCase

var w: SimWorld


func before_each() -> void:
	w = SimFixture.world(SimFixture.flat_grid(64, 64))


func _move(ids: PackedInt32Array, x_m: int, y_m: int, player: int, seq: int, tick: int) -> MoveCommand:
	var c: MoveCommand = MoveCommand.new(ids, x_m * 1000, y_m * 1000)
	c.player_id = player
	c.sequence = seq
	c.tick = tick
	return c


func test_command_applies_on_its_tick() -> void:
	var id: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 50, 50)
	assert_true(w.queue_command(_move(PackedInt32Array([id]), 200, 50, 0, 0, 3)))
	SimFixture.run(w, 3)
	assert_eq(w.orders.kind[id], OrderStore.NONE, "not applied before tick 3")
	w.step()
	assert_eq(w.orders.kind[id], OrderStore.MOVE)


func test_order_is_player_then_sequence() -> void:
	var id: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 50, 50)
	# same player: higher sequence applies last and wins regardless of insertion order
	w.queue_command(_move(PackedInt32Array([id]), 300, 50, 0, 5, 0))
	w.queue_command(_move(PackedInt32Array([id]), 100, 50, 0, 1, 0))
	w.step()
	assert_eq(w.orders.goal_x[id], 300000)


func test_cannot_command_other_players_units() -> void:
	var id: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 50, 50)
	w.queue_command(_move(PackedInt32Array([id]), 300, 50, 1, 0, 0))
	w.step()
	assert_eq(w.orders.kind[id], OrderStore.NONE)


func test_invalid_command_dropped() -> void:
	w.queue_command(_move(PackedInt32Array([999]), 100, 100, 0, 0, 0))
	w.step()
	assert_eq(w.commands.pending_count(), 0)


func test_past_tick_rejected() -> void:
	SimFixture.run(w, 2)
	assert_false(w.queue_command(_move(PackedInt32Array([1]), 1, 1, 0, 0, 1)))


func test_spawn_out_of_bounds_rejected() -> void:
	SimFixture.cmd(SpawnUnitCommand.new("nc_rifle_sqd", -5, 0), w, 0)
	SimFixture.cmd(SpawnUnitCommand.new("no_such_unit", 1000, 1000), w, 0)
	w.step()
	assert_eq(w.entities.count(), 0)


func test_shift_queue_runs_in_order() -> void:
	var id: int = SimFixture.spawn(w, "nc_supply_truck", 0, 50, 50)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 150000, 50000), w, 0, 0)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 150000, 150000, MoveCommand.MODE_MOVE, true), w, 0, 1)
	w.step()
	assert_eq(w.orders.queue_len(id), 1)
	SimFixture.run(w, 400)
	assert_eq(w.orders.kind[id], OrderStore.NONE)
	assert_near(w.transform.x[id], 150000, 3000)
	assert_near(w.transform.y[id], 150000, 3000)


func test_stop_clears_orders() -> void:
	var id: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 50, 50)
	SimFixture.cmd(MoveCommand.new(PackedInt32Array([id]), 400000, 50000), w, 0, 0)
	SimFixture.run(w, 5)
	SimFixture.cmd(StopCommand.new(PackedInt32Array([id])), w, 0, 1)
	SimFixture.run(w, 20)
	assert_eq(w.orders.kind[id], OrderStore.NONE)
	assert_eq(w.mobility.speed[id], 0)
