# SIM: deterministic — no floats, no Nodes
## Seeded sim RNG: xoshiro128** on 32-bit lanes.
## Implemented with 32-bit masked arithmetic so no step can overflow GDScript's
## signed 64-bit int (a 64-bit generator would rely on wrap-around multiply).
## Only sim code may call this, and only in deterministic order.
class_name SimRng
extends RefCounted

const MASK: int = 0xFFFFFFFF

var _s0: int
var _s1: int
var _s2: int
var _s3: int


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


func reseed(p_seed: int) -> void:
	var lo: int = p_seed & MASK
	var hi: int = (p_seed >> 32) & MASK
	_s0 = _fmix32(lo ^ 0x9E3779B9)
	_s1 = _fmix32(hi ^ 0x85EBCA6B)
	_s2 = _fmix32((lo + 0x3C6EF372) & MASK)
	_s3 = _fmix32((hi + 0xC2B2AE35) & MASK)
	if (_s0 | _s1 | _s2 | _s3) == 0:
		_s0 = 1


## Next uniformly distributed value in [0, 2^32).
func next_u32() -> int:
	var result: int = mul32(_rotl(mul32(_s1, 5), 7), 9)
	var t: int = (_s1 << 9) & MASK
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## Integer in [lo, hi] inclusive. Requires hi >= lo and span < 2^32.
func range_int(lo: int, hi: int) -> int:
	assert(hi >= lo, "range_int: hi < lo")
	var span: int = hi - lo + 1
	return lo + (next_u32() % span)


## True with probability permille/1000.
func chance_permille(permille: int) -> bool:
	return (next_u32() % 1000) < permille


func get_state() -> PackedInt64Array:
	return PackedInt64Array([_s0, _s1, _s2, _s3])


func set_state(state: PackedInt64Array) -> void:
	assert(state.size() == 4)
	_s0 = state[0]
	_s1 = state[1]
	_s2 = state[2]
	_s3 = state[3]


## (a * b) mod 2^32 for a, b in [0, 2^32) without 64-bit overflow.
static func mul32(a: int, b: int) -> int:
	var lo: int = a * (b & 0xFFFF)
	var hi: int = ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK


## MurmurHash3 finalizer — used for seeding only.
static func _fmix32(h: int) -> int:
	var x: int = h & MASK
	x ^= x >> 16
	x = mul32(x, 0x85EBCA6B)
	x ^= x >> 13
	x = mul32(x, 0xC2B2AE35)
	x ^= x >> 16
	return x
