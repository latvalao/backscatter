# SIM: deterministic — no floats, no Nodes
## Contamination grid (§5.4) on 32 m cells. Two layers, both dose rates in µSv/h:
##   ground — deposited fallout (baked hot spots + rain-out from plumes)
##   air    — airborne plume concentration; advected by wind, decays, rains out
## Dose rate at a point = ground + air.
class_name RadiationField
extends RefCounted

const CELL_MM: int = 32000
const BACKGROUND: int = 2            # µSv/h
const AIR_DECAY_PERMILLE: int = 3    # per update (1 s)
const DIFFUSE_PERMILLE: int = 40     # spread to the 4 neighbours per update
const RAIN_OUT_PERMILLE: int = 25    # air -> ground per update while raining

var w: int = 1
var h: int = 1
var ground: PackedInt32Array = PackedInt32Array()
var air: PackedInt32Array = PackedInt32Array()
## Scripted airborne releases: [start_tick, end_tick, x_mm, y_mm, rate_per_update]
var sources: Array[PackedInt64Array] = []
var _scratch: PackedInt32Array = PackedInt32Array()


func _init(width_mm: int = CELL_MM, height_mm: int = CELL_MM) -> void:
	w = maxi(1, (width_mm + CELL_MM - 1) / CELL_MM)
	h = maxi(1, (height_mm + CELL_MM - 1) / CELL_MM)
	ground.resize(w * h)
	ground.fill(BACKGROUND)
	air.resize(w * h)
	_scratch.resize(w * h)


func index_at(x_mm: int, y_mm: int) -> int:
	return clampi(y_mm / CELL_MM, 0, h - 1) * w + clampi(x_mm / CELL_MM, 0, w - 1)


func rate_at(x_mm: int, y_mm: int) -> int:
	var i: int = index_at(x_mm, y_mm)
	return ground[i] + air[i]


func rate_index(i: int) -> int:
	return ground[i] + air[i]


## Adds a hot spot with a cone profile (peak at centre, 0 at radius).
func add_hotspot(x_mm: int, y_mm: int, radius_mm: int, peak: int) -> void:
	var rc: int = radius_mm / CELL_MM + 1
	var cx: int = x_mm / CELL_MM
	var cy: int = y_mm / CELL_MM
	for y: int in range(maxi(0, cy - rc), mini(h, cy + rc + 1)):
		for x: int in range(maxi(0, cx - rc), mini(w, cx + rc + 1)):
			var dx: int = x * CELL_MM + CELL_MM / 2 - x_mm
			var dy: int = y * CELL_MM + CELL_MM / 2 - y_mm
			var d: int = FixedMath.length2(dx, dy)
			if d < radius_mm:
				ground[y * w + x] += peak * (radius_mm - d) / radius_mm


func add_source(start_tick: int, end_tick: int, x_mm: int, y_mm: int, rate: int) -> void:
	sources.append(PackedInt64Array([start_tick, end_tick, x_mm, y_mm, rate]))


## One 1-second update: releases, upwind advection, diffusion, decay, rain-out.
func step(tick: int, wind_x_mm_s: int, wind_y_mm_s: int, raining: bool) -> void:
	for s: PackedInt64Array in sources:
		if tick >= s[0] and tick < s[1]:
			air[index_at(s[2], s[3])] += s[4]
	_advect_x(wind_x_mm_s * 1000 / CELL_MM)
	_advect_y(wind_y_mm_s * 1000 / CELL_MM)
	_diffuse()
	for i: int in range(w * h):
		var a: int = air[i]
		if a == 0:
			continue
		a -= a * AIR_DECAY_PERMILLE / 1000 + (1 if a < 300 else 0)
		if raining and a > 0:
			var dep: int = a * RAIN_OUT_PERMILLE / 1000
			ground[i] += dep
			a -= dep
		air[i] = maxi(0, a)


## Semi-Lagrangian upwind shift by f permille of a cell along x.
func _advect_x(f: int) -> void:
	if f == 0:
		return
	var s: int = 1 if f > 0 else -1
	var af: int = mini(1000, absi(f))
	for y: int in range(h):
		var row: int = y * w
		for x: int in range(w):
			var up: int = x - s
			var from_up: int = air[row + up] if up >= 0 and up < w else 0
			_scratch[row + x] = air[row + x] * (1000 - af) / 1000 + from_up * af / 1000
	var tmp: PackedInt32Array = air
	air = _scratch
	_scratch = tmp


func _advect_y(f: int) -> void:
	if f == 0:
		return
	var s: int = 1 if f > 0 else -1
	var af: int = mini(1000, absi(f))
	for y: int in range(h):
		var up: int = y - s
		for x: int in range(w):
			var from_up: int = air[up * w + x] if up >= 0 and up < h else 0
			_scratch[y * w + x] = air[y * w + x] * (1000 - af) / 1000 + from_up * af / 1000
	var tmp: PackedInt32Array = air
	air = _scratch
	_scratch = tmp


func _diffuse() -> void:
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var c: int = air[i]
			var acc: int = c * (1000 - DIFFUSE_PERMILLE) / 1000
			var share: int = 0
			if x > 0:
				share += air[i - 1]
			if x < w - 1:
				share += air[i + 1]
			if y > 0:
				share += air[i - w]
			if y < h - 1:
				share += air[i + w]
			_scratch[i] = acc + share * DIFFUSE_PERMILLE / 4000
	var tmp: PackedInt32Array = air
	air = _scratch
	_scratch = tmp


func total_air() -> int:
	var t: int = 0
	for v: int in air:
		t += v
	return t


## Centre of mass of the airborne layer (mm), for tests and overlays.
func air_centroid() -> Vector2i:
	var t: int = 0
	var sx: int = 0
	var sy: int = 0
	for i: int in range(w * h):
		var a: int = air[i]
		if a <= 0:
			continue
		t += a
		sx += a * ((i % w) * CELL_MM + CELL_MM / 2) / 1000
		sy += a * ((i / w) * CELL_MM + CELL_MM / 2) / 1000
	if t == 0:
		return Vector2i(-1, -1)
	return Vector2i(sx * 1000 / t, sy * 1000 / t)


func hash_into(hc: Checksum) -> void:
	var a: int = 0
	var g: int = 0
	for i: int in range(w * h):
		a = (a * 31 + air[i]) & 0xFFFFFFFF
		g = (g * 31 + ground[i]) & 0xFFFFFFFF
	hc.add_u32(a)
	hc.add_u32(g)
