# SIM: deterministic — no floats, no Nodes
## Seeded weather schedule (§5.6): wind (drives plumes), rain (rain-out, optics),
## fog (optics; thermal less affected), night. Its own RNG stream so weather
## never perturbs combat randomness.
class_name Weather
extends RefCounted

const CHANGE_MIN_TICKS: int = 3000   # 5 min
const CHANGE_MAX_TICKS: int = 7200   # 12 min

var wind_dir: int = 0          # binary angle the wind blows TOWARD
var wind_speed: int = 4000     # mm/s
var raining: bool = false
var fog: bool = false
var night: bool = false
var next_change: int = 0
var _rng: SimRng


func _init(seed_value: int = 1) -> void:
	_rng = SimRng.new(seed_value ^ 0x77EA7E)
	_roll()
	next_change = _rng.range_int(CHANGE_MIN_TICKS, CHANGE_MAX_TICKS)


func step(tick: int) -> bool:
	if tick < next_change:
		return false
	_roll()
	next_change = tick + _rng.range_int(CHANGE_MIN_TICKS, CHANGE_MAX_TICKS)
	return true


func _roll() -> void:
	# prevailing westerlies with variation
	wind_dir = (_rng.range_int(-12000, 12000)) & SimConst.ANGLE_MASK
	wind_speed = _rng.range_int(1500, 8000)
	raining = _rng.chance_permille(250)
	fog = not raining and _rng.chance_permille(150)


func wind_x() -> int:
	return wind_speed * FixedMath.cos_b(wind_dir) / FixedMath.ONE


func wind_y() -> int:
	return wind_speed * FixedMath.sin_b(wind_dir) / FixedMath.ONE


## Optics multiplier permille for (thermal) sights.
func optics_factor(thermal: bool) -> int:
	var f: int = 1000
	if raining:
		f = f * (850 if thermal else 750) / 1000
	if fog:
		f = f * (850 if thermal else 550) / 1000
	return f


func hash_into(h: Checksum) -> void:
	h.add_int(wind_dir)
	h.add_int(wind_speed)
	h.add_int(int(raining) | (int(fog) << 1) | (int(night) << 2))
	h.add_int(next_change)
	for s: int in _rng.get_state():
		h.add_int(s)
