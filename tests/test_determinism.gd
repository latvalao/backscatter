## Determinism: identical seed + command log => identical checksum every tick.
extends TestCase

const UNITS: int = 100
const TICKS: int = 400
const DEFS: Array[String] = ["nc_rifle_sqd", "nc_mbt_2a", "nc_ifv_90", "ec_motor_rifle", "ec_mbt_72", "ec_ifv_2"]


## Builds a world through commands only (as a real match would) and runs it,
## recording the checksum of every tick. shuffle_seed permutes the order in
## which commands are queued (must not matter).
static func run_match(match_seed: int, shuffle_seed: int = 0) -> PackedInt64Array:
	var w: SimWorld = SimFixture.world(SimFixture.test_map(), match_seed)
	var setup: SimRng = SimRng.new(match_seed ^ 0x5EED)
	var cmds: Array[SimCommand] = []
	for i: int in range(UNITS):
		var player: int = i % 2
		var x: int = setup.range_int(200_000, 1_200_000) + player * 2_600_000
		var y: int = setup.range_int(500_000, 3_500_000)
		var c: SpawnUnitCommand = SpawnUnitCommand.new(DEFS[(i % 3) + player * 3], x, y, 0)
		c.player_id = player
		c.sequence = i
		c.tick = 0
		cmds.append(c)
	# both sides advance toward each other on tick 5
	for player: int in range(2):
		var ids: PackedInt32Array = PackedInt32Array()
		for k: int in range(UNITS / 2):
			ids.append(2 * k + 1 + player)
		var m: MoveCommand = MoveCommand.new(ids, 2_000_000 + (player * 2 - 1) * 300_000, 2_000_000, MoveCommand.MODE_ATTACK_MOVE)
		m.player_id = player
		m.sequence = 1000
		m.tick = 5
		cmds.append(m)
	if shuffle_seed != 0:
		var r: SimRng = SimRng.new(shuffle_seed)
		for i: int in range(cmds.size() - 1, 0, -1):
			var j: int = r.range_int(0, i)
			var tmp: SimCommand = cmds[i]
			cmds[i] = cmds[j]
			cmds[j] = tmp
	for c: SimCommand in cmds:
		w.queue_command(c)
	# collect the sim's periodic checksum (every CHECKSUM_INTERVAL ticks) — the
	# same signal lockstep peers compare — instead of hashing every tick
	var sums: PackedInt64Array = PackedInt64Array()
	for t: int in range(TICKS):
		w.step()
		if w.last_checksum_tick == t:
			sums.append(w.last_checksum)
	sums.append(Checksum.compute(w))
	return sums


static var _reference: PackedInt64Array = PackedInt64Array()


## run_match(42) is shared by two tests (computed once).
static func ref_run() -> PackedInt64Array:
	if _reference.is_empty():
		_reference = run_match(42)
	return _reference


func _assert_same(a: PackedInt64Array, b: PackedInt64Array) -> void:
	assert_eq(a.size(), b.size())
	for t: int in range(a.size()):
		if a[t] != b[t]:
			fail("desync at checksum #%d (tick %d): %x vs %x" % [t, t * SimConst.CHECKSUM_INTERVAL, a[t], b[t]])
			return


func test_same_seed_identical_checksums() -> void:
	_assert_same(ref_run(), run_match(42))


func test_command_insertion_order_does_not_matter() -> void:
	_assert_same(ref_run(), run_match(42, 99))


func test_different_seed_diverges() -> void:
	var b: PackedInt64Array = run_match(2)
	assert_ne(ref_run()[ref_run().size() - 1], b[b.size() - 1])


func test_periodic_checksum_recorded() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(16, 16), 3)
	SimFixture.run(w, 41)
	assert_eq(w.last_checksum_tick, 40)
	assert_ne(w.last_checksum, 0)
