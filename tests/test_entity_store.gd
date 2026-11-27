extends TestCase


func test_ids_monotonic_and_sorted() -> void:
	var s: EntityStore = EntityStore.new()
	var a: int = s.create()
	var b: int = s.create()
	var c: int = s.create()
	assert_eq(a, 1)
	assert_eq(b, 2)
	assert_eq(c, 3)
	s.destroy(b)
	assert_false(s.is_alive(b))
	assert_eq(s.count(), 2)
	assert_eq(s.ids(), PackedInt32Array([1, 3]))
	var d: int = s.create()
	assert_eq(d, 4, "ids are never reused")
	assert_eq(s.ids(), PackedInt32Array([1, 3, 4]))


func test_invalid_ids_not_alive() -> void:
	var s: EntityStore = EntityStore.new()
	assert_false(s.is_alive(0))
	assert_false(s.is_alive(-1))
	assert_false(s.is_alive(5))
	s.destroy(5)  # no-op, no crash
	assert_eq(s.count(), 0)


func test_world_destroy_is_deferred_to_cleanup() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(32, 32))
	var id: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 100, 100)
	w.destroy_entity(id)
	assert_true(w.entities.is_alive(id), "still alive until phase 10")
	assert_false(w.is_unit(id), "but no longer a valid unit")
	w.step()
	assert_false(w.entities.is_alive(id))
	assert_false(w.transform.has(id))
	assert_false(w.units.has(id))
	var kinds: Array[int] = []
	for e: SimEvent in w.drain_events():
		kinds.append(e.kind)
	var expected: Array[int] = [SimEvent.Type.SPAWNED, SimEvent.Type.DESTROYED]
	assert_eq(kinds, expected)
