# SIM: deterministic — no floats, no Nodes
## Integer / fixed-point math. Fixed-point scale is 16.16 (ONE = 65536).
## Angles are binary angles: 0..65535 = one full turn, counter-clockwise from +X.
class_name FixedMath
extends RefCounted

const ONE: int = 65536
const SHIFT: int = 16


## Fixed-point multiply (16.16 x 16.16 -> 16.16).
static func mul(a: int, b: int) -> int:
	return (a * b) >> SHIFT


## Fixed-point divide (16.16 / 16.16 -> 16.16). b must be non-zero.
static func div(a: int, b: int) -> int:
	return (a << SHIFT) / b


## Floor integer square root for n >= 0.
static func isqrt(n: int) -> int:
	assert(n >= 0, "isqrt of negative")
	if n < 2:
		return n
	var x: int = n
	var y: int = (x >> 1) + 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


static func length2(dx: int, dy: int) -> int:
	return isqrt(dx * dx + dy * dy)


static func dist2_sq(ax: int, ay: int, bx: int, by: int) -> int:
	var dx: int = bx - ax
	var dy: int = by - ay
	return dx * dx + dy * dy


static func normalize_angle(a: int) -> int:
	return a & SimConst.ANGLE_MASK


## Signed shortest difference b - a in (-32768, 32768].
static func angle_diff(a: int, b: int) -> int:
	var d: int = (b - a) & SimConst.ANGLE_MASK
	if d > SimConst.ANGLE_HALF:
		d -= SimConst.ANGLE_FULL
	return d


## sin of binary angle, result in 16.16 (-65536..65536).
static func sin_b(angle: int) -> int:
	var a: int = angle & SimConst.ANGLE_MASK
	var quadrant: int = a >> 14
	var within: int = a & (SimConst.ANGLE_QUARTER - 1)
	if quadrant == 0:
		return _sin_quarter(within)
	elif quadrant == 1:
		return _sin_quarter(SimConst.ANGLE_QUARTER - within)
	elif quadrant == 2:
		return -_sin_quarter(within)
	return -_sin_quarter(SimConst.ANGLE_QUARTER - within)


static func cos_b(angle: int) -> int:
	return sin_b(angle + SimConst.ANGLE_QUARTER)


## Binary angle of vector (x, y), 0..65535. atan2(0, 0) == 0.
static func atan2_b(y: int, x: int) -> int:
	if x == 0 and y == 0:
		return 0
	var ax: int = absi(x)
	var ay: int = absi(y)
	var t: int
	if ax >= ay:
		t = _atan_ratio(ay, ax)
	else:
		t = SimConst.ANGLE_QUARTER - _atan_ratio(ax, ay)
	var r: int
	if x >= 0 and y >= 0:
		r = t
	elif x < 0 and y >= 0:
		r = SimConst.ANGLE_HALF - t
	elif x < 0:
		r = SimConst.ANGLE_HALF + t
	else:
		r = SimConst.ANGLE_FULL - t
	return r & SimConst.ANGLE_MASK


## x in [0, 16384] (quarter turn) -> sin in 16.16, linear interpolation over the table.
static func _sin_quarter(x: int) -> int:
	var i: int = x >> 4
	if i >= TrigTables.QUARTER:
		return TrigTables.SIN_Q[TrigTables.QUARTER]
	var frac: int = x & 15
	var a: int = TrigTables.SIN_Q[i]
	var b: int = TrigTables.SIN_Q[i + 1]
	return a + (((b - a) * frac) >> 4)


## atan(num/den) in binary angle units for 0 <= num <= den, den > 0. Result 0..8192.
static func _atan_ratio(num: int, den: int) -> int:
	var scaled: int = (num * TrigTables.ATAN_N * 16) / den
	var i: int = scaled >> 4
	if i >= TrigTables.ATAN_N:
		return TrigTables.ATAN[TrigTables.ATAN_N]
	var frac: int = scaled & 15
	var a: int = TrigTables.ATAN[i]
	var b: int = TrigTables.ATAN[i + 1]
	return a + (((b - a) * frac) >> 4)
