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
	var w: SimWorld = SimWorld.new(1)
	var id: int = w.spawn_debug_unit(1000, 1000, 0, 0, 0)
	w.destroy_entity(id)
	assert_true(w.entities.is_alive(id), "still alive until phase 10")
	w.step()
	assert_false(w.entities.is_alive(id))
	assert_false(w.transform.has(id))
	assert_false(w.motion.has(id))
	var kinds: Array[int] = []
	for e: SimEvent in w.drain_events():
		kinds.append(e.kind)
	var expected: Array[int] = [SimEvent.Type.SPAWNED, SimEvent.Type.DESTROYED]
	assert_eq(kinds, expected)
