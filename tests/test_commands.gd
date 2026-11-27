extends TestCase


func _cmd(player: int, seq: int, tick: int, id: int, vx: int) -> SetVelocityCommand:
	var c: SetVelocityCommand = SetVelocityCommand.new(id, vx, 0)
	c.player_id = player
	c.sequence = seq
	c.tick = tick
	return c


func test_command_applies_on_its_tick() -> void:
	var w: SimWorld = SimWorld.new(1)
	var id: int = w.spawn_debug_unit(1000, 1000, 0, 500, 0)
	assert_true(w.queue_command(_cmd(0, 0, 3, id, 100)))
	for i: int in range(3):
		w.step()
	assert_eq(w.motion.vx[id], 0, "not applied before tick 3")
	w.step()
	assert_eq(w.motion.vx[id], 100)
	assert_eq(w.transform.x[id], 1100, "moved during the same tick")


func test_order_is_player_then_sequence() -> void:
	var w: SimWorld = SimWorld.new(1)
	var id: int = w.spawn_debug_unit(1000, 1000, 0, 500, 0)
	# Last applied wins: (1,0) must apply after (0,5), regardless of insertion order.
	w.queue_command(_cmd(1, 0, 0, id, 300))
	w.queue_command(_cmd(0, 5, 0, id, 200))
	w.queue_command(_cmd(0, 1, 0, id, 100))
	w.step()
	assert_eq(w.motion.vx[id], 300)


func test_invalid_command_dropped() -> void:
	var w: SimWorld = SimWorld.new(1)
	w.queue_command(_cmd(0, 0, 0, 999, 100))
	w.step()  # must not crash
	assert_eq(w.commands.pending_count(), 0)


func test_past_tick_rejected() -> void:
	var w: SimWorld = SimWorld.new(1)
	w.step()
	w.step()
	assert_false(w.queue_command(_cmd(0, 0, 1, 1, 0)))


func test_velocity_clamped_to_max_speed() -> void:
	var w: SimWorld = SimWorld.new(1)
	var id: int = w.spawn_debug_unit(1000, 1000, 0, 50, 0)
	w.queue_command(_cmd(0, 0, 0, id, 10_000))
	w.step()
	assert_eq(w.motion.vx[id], 50)


func test_spawn_command_out_of_bounds_rejected() -> void:
	var w: SimWorld = SimWorld.new(1)
	var c: SpawnDebugUnitCommand = SpawnDebugUnitCommand.new(-5, 0, 0, 100, 0)
	w.queue_command(c)
	w.step()
	assert_eq(w.entities.count(), 0)
