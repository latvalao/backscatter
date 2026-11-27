extends TestCase


func test_same_seed_same_sequence() -> void:
	var a: SimRng = SimRng.new(12345)
	var b: SimRng = SimRng.new(12345)
	for i: int in range(1000):
		assert_eq(a.next_u32(), b.next_u32(), "at %d" % i)


func test_different_seed_differs() -> void:
	var a: SimRng = SimRng.new(1)
	var b: SimRng = SimRng.new(2)
	var same: int = 0
	for i: int in range(100):
		if a.next_u32() == b.next_u32():
			same += 1
	assert_true(same < 3)


func test_values_are_u32() -> void:
	var r: SimRng = SimRng.new(-987654321987)
	for i: int in range(10000):
		var v: int = r.next_u32()
		assert_true(v >= 0 and v <= 0xFFFFFFFF, "out of range %d" % v)


func test_zero_seed_is_not_degenerate() -> void:
	var r: SimRng = SimRng.new(0)
	var distinct: Dictionary = {}
	for i: int in range(100):
		distinct[r.next_u32()] = true
	assert_true(distinct.size() > 95)


func test_range_int_bounds_and_coverage() -> void:
	var r: SimRng = SimRng.new(77)
	var seen: PackedInt32Array = PackedInt32Array()
	seen.resize(7)
	for i: int in range(7000):
		var v: int = r.range_int(-3, 3)
		assert_true(v >= -3 and v <= 3)
		seen[v + 3] += 1
	for c: int in seen:
		assert_true(c > 800 and c < 1200, "bucket count %d" % c)


func test_state_roundtrip() -> void:
	var a: SimRng = SimRng.new(42)
	for i: int in range(17):
		a.next_u32()
	var b: SimRng = SimRng.new(999)
	b.set_state(a.get_state())
	for i: int in range(100):
		assert_eq(a.next_u32(), b.next_u32())


func test_mul32_matches_reference() -> void:
	# reference values computed with Python big ints
	assert_eq(SimRng.mul32(0xDEADBEEF, 0x9E3779B9), 0x9226F1B7)
	assert_eq(SimRng.mul32(0x9E3779B9, 0xDEADBEEF), 0x9226F1B7)
	assert_eq(SimRng.mul32(0xFFFFFFFF, 0xFFFFFFFF), 1)
	assert_eq(SimRng.mul32(0x10000, 0x10000), 0)
	assert_eq(SimRng.mul32(12345, 6789), 12345 * 6789)


## Golden values from a Python reference implementation (big ints). Pins the
## generator so a platform/engine change that alters the sequence is caught.
func test_golden_sequence() -> void:
	var r: SimRng = SimRng.new(12345)
	var expected: Array[int] = [2406929884, 353049176, 557672667, 548531977, 4089443424]
	for e: int in expected:
		assert_eq(r.next_u32(), e)
