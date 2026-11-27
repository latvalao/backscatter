extends TestCase


func test_isqrt_exact_and_floor() -> void:
	assert_eq(FixedMath.isqrt(0), 0)
	assert_eq(FixedMath.isqrt(1), 1)
	assert_eq(FixedMath.isqrt(15), 3)
	assert_eq(FixedMath.isqrt(16), 4)
	assert_eq(FixedMath.isqrt(1_000_000), 1000)
	assert_eq(FixedMath.isqrt(999_999), 999)
	var big: int = 3_037_000_499
	assert_eq(FixedMath.isqrt(big * big), big)
	assert_eq(FixedMath.isqrt(big * big - 1), big - 1)


func test_length2() -> void:
	assert_eq(FixedMath.length2(3000, 4000), 5000)
	assert_eq(FixedMath.length2(-3000, -4000), 5000)


func test_sin_cos_cardinals() -> void:
	var one: int = FixedMath.ONE
	assert_eq(FixedMath.sin_b(0), 0)
	assert_eq(FixedMath.sin_b(16384), one)
	assert_eq(FixedMath.sin_b(32768), 0)
	assert_eq(FixedMath.sin_b(49152), -one)
	assert_eq(FixedMath.cos_b(0), one)
	assert_eq(FixedMath.cos_b(32768), -one)
	assert_eq(FixedMath.sin_b(65536 + 16384), one, "wraps")
	assert_eq(FixedMath.sin_b(-16384), -one, "negative angles wrap")


func test_sin_45_degrees() -> void:
	# sin(45°) * 65536 = 46341
	assert_near(FixedMath.sin_b(8192), 46341, 2)
	assert_near(FixedMath.cos_b(8192), 46341, 2)


func test_atan2_cardinals_and_octants() -> void:
	assert_eq(FixedMath.atan2_b(0, 0), 0)
	assert_eq(FixedMath.atan2_b(0, 100), 0)
	assert_eq(FixedMath.atan2_b(100, 0), 16384)
	assert_eq(FixedMath.atan2_b(0, -100), 32768)
	assert_eq(FixedMath.atan2_b(-100, 0), 49152)
	assert_eq(FixedMath.atan2_b(100, 100), 8192)
	assert_eq(FixedMath.atan2_b(100, -100), 24576)
	assert_eq(FixedMath.atan2_b(-100, -100), 40960)
	assert_eq(FixedMath.atan2_b(-100, 100), 57344)


func test_atan2_inverts_sin_cos() -> void:
	var r: int = 1_000_000
	for a: int in range(0, 65536, 397):
		var x: int = (r * FixedMath.cos_b(a)) >> FixedMath.SHIFT
		var y: int = (r * FixedMath.sin_b(a)) >> FixedMath.SHIFT
		var back: int = FixedMath.atan2_b(y, x)
		assert_near(FixedMath.angle_diff(a, back), 0, 4, "angle %d" % a)


func test_angle_diff() -> void:
	assert_eq(FixedMath.angle_diff(0, 100), 100)
	assert_eq(FixedMath.angle_diff(100, 0), -100)
	assert_eq(FixedMath.angle_diff(65000, 500), 1036)
	assert_eq(FixedMath.angle_diff(500, 65000), -1036)


func test_fixed_mul_div() -> void:
	var one: int = FixedMath.ONE
	assert_eq(FixedMath.mul(3 * one, 2 * one), 6 * one)
	assert_eq(FixedMath.div(6 * one, 4 * one), one + one / 2)
