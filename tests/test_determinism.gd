## M0 acceptance: 100 entities, 1000 ticks, checksum identical across two runs.
extends TestCase

const ENTITIES: int = 100
const TICKS: int = 1000


## Builds a world through commands only (as a real match would) and runs it,
## recording the checksum of every tick.
static func run_match(match_seed: int) -> PackedInt64Array:
	var w: SimWorld = SimWorld.new(match_seed)
	var setup: SimRng = SimRng.new(match_seed ^ 0x5EED)
	for i: int in range(ENTITIES):
		var c: SpawnDebugUnitCommand = SpawnDebugUnitCommand.new(
			setup.range_int(0, w.map_width_mm),
			setup.range_int(0, w.map_height_mm),
			i % 2,
			setup.range_int(200, 1500),
			setup.range_int(5, 40))
		c.player_id = i % 2
		c.sequence = i
		c.tick = 0
		w.queue_command(c)
	var sums: PackedInt64Array = PackedInt64Array()
	sums.resize(TICKS)
	for t: int in range(TICKS):
		w.step()
		sums[t] = Checksum.compute(w)
	return sums


func test_same_seed_identical_checksums() -> void:
	var a: PackedInt64Array = run_match(20261127)
	var b: PackedInt64Array = run_match(20261127)
	assert_eq(a.size(), TICKS)
	for t: int in range(TICKS):
		if a[t] != b[t]:
			fail("desync at tick %d: %x vs %x" % [t, a[t], b[t]])
			return


func test_different_seed_diverges() -> void:
	var a: PackedInt64Array = run_match(1)
	var b: PackedInt64Array = run_match(2)
	assert_ne(a[TICKS - 1], b[TICKS - 1])


func test_entities_actually_move_and_stay_in_bounds() -> void:
	var w: SimWorld = SimWorld.new(7)
	var id: int = w.spawn_debug_unit(2_000_000, 2_000_000, 0, 1500, 10)
	for t: int in range(TICKS):
		w.step()
		assert_true(w.in_bounds(w.transform.x[id], w.transform.y[id]), "out of bounds at %d" % t)
	assert_true(w.transform.x[id] != 2_000_000 or w.transform.y[id] != 2_000_000)


func test_periodic_checksum_recorded() -> void:
	var w: SimWorld = SimWorld.new(3)
	for t: int in range(41):
		w.step()
	assert_eq(w.last_checksum_tick, 40)
	assert_ne(w.last_checksum, 0)
