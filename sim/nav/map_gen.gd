# SIM: deterministic — no floats, no Nodes
## Procedural test map: rolling terrain, lakes with boggy shores, forest,
## granite outcrops, two crossing roads and a village at the crossroads.
## Pure integer value-noise, so any peer generates the identical grid from a seed.
class_name MapGen
extends RefCounted

const NOISE_ONE: int = 1024


static func generate(seed_value: int, width: int, height: int, symmetric: bool = false) -> SimGrid:
	var g: SimGrid = SimGrid.new(width, height)
	var h_lo: PackedInt32Array = _noise_field(seed_value, 1, width, height, 96)
	var h_hi: PackedInt32Array = _noise_field(seed_value, 2, width, height, 24)
	var lake: PackedInt32Array = _noise_field(seed_value, 3, width, height, 80)
	var forest: PackedInt32Array = _noise_field(seed_value, 4, width, height, 48)
	var forest_d: PackedInt32Array = _noise_field(seed_value, 5, width, height, 12)
	var rock: PackedInt32Array = _noise_field(seed_value, 6, width, height, 20)
	var bog: PackedInt32Array = _noise_field(seed_value, 7, width, height, 40)

	for i: int in range(width * height):
		var hgt: int = (h_lo[i] * 45000 + h_hi[i] * 12000) / NOISE_ONE
		var t: int = TerrainTable.FIELD
		if lake[i] < 190:
			t = TerrainTable.WATER
			hgt = mini(hgt, 8000)
		elif lake[i] < 250 or bog[i] < 90:
			t = TerrainTable.BOG
		elif rock[i] > 930 and h_lo[i] > 550:
			t = TerrainTable.ROCK
		elif forest[i] + forest_d[i] / 4 > 790:
			t = TerrainTable.FOREST
		g.terrain[i] = t
		g.ground_mm[i] = hgt

	# Village at the crossroads (centre, offset by noise).
	var vx: int = width / 2 + (SimRng.hash3(seed_value, 11, 0) % 41) - 20
	var vy: int = height / 2 + (SimRng.hash3(seed_value, 12, 0) % 41) - 20
	var village: PackedInt32Array = _noise_field(seed_value, 8, width, height, 6)
	for cy: int in range(maxi(0, vy - 20), mini(height, vy + 21)):
		for cx: int in range(maxi(0, vx - 20), mini(width, vx + 21)):
			var dx: int = cx - vx
			var dy: int = cy - vy
			if dx * dx + dy * dy <= 20 * 20:
				var i: int = g.index(cx, cy)
				g.terrain[i] = TerrainTable.URBAN if village[i] > 470 else TerrainTable.FIELD

	_road(g, seed_value, 21, true, vy)
	_road(g, seed_value, 22, false, vx)
	if symmetric:
		_rotate_halves(g)
	g.rebuild_sectors()
	return g


## Point symmetry for fair versus maps: the east half becomes the west half
## rotated 180° about the centre; roads crossing the seam are reconnected.
static func _rotate_halves(g: SimGrid) -> void:
	var w: int = g.width
	var h: int = g.height
	var half: int = w / 2
	for y: int in range(h):
		for x: int in range(half, w):
			var src: int = g.index(w - 1 - x, h - 1 - y)
			var dst: int = g.index(x, y)
			g.terrain[dst] = g.terrain[src]
			g.ground_mm[dst] = g.ground_mm[src]
	# reconnect: a road at row r just west of the seam continues at row h-1-r east of it
	for y: int in range(h):
		if g.terrain[g.index(half - 1, y)] == TerrainTable.ROAD:
			var y2: int = h - 1 - y
			for yy: int in range(mini(y, y2), maxi(y, y2) + 1):
				g.terrain[g.index(half, yy)] = TerrainTable.ROAD


## A sinuous road crossing the whole map through `through` (row if horizontal).
static func _road(g: SimGrid, seed_value: int, salt: int, horizontal: bool, through: int) -> void:
	var length: int = g.width if horizontal else g.height
	var span: int = g.height if horizontal else g.width
	var wander: PackedInt32Array = _noise_line(seed_value, salt, length, 120)
	var prev: int = -1
	for a: int in range(length):
		# road bends but is pinned to pass the village near the centre
		var dist_c: int = absi(a - length / 2)
		var amp: int = (span / 5) * mini(dist_c, length / 4) / maxi(1, length / 4)
		var b: int = clampi(through + (wander[a] - NOISE_ONE / 2) * amp / (NOISE_ONE / 2), 1, span - 2)
		if prev < 0:
			prev = b
		var lo: int = mini(prev, b)
		var hi: int = maxi(prev, b)
		for bb: int in range(lo, hi + 1):
			_mark_road(g, a, bb, horizontal)
		prev = b


static func _mark_road(g: SimGrid, a: int, b: int, horizontal: bool) -> void:
	var cx: int = a if horizontal else b
	var cy: int = b if horizontal else a
	if g.in_grid(cx, cy):
		g.terrain[g.index(cx, cy)] = TerrainTable.ROAD


## Smoothed value noise, values 0..1024, lattice spacing `period` cells.
static func _noise_field(seed_value: int, salt: int, width: int, height: int, period: int) -> PackedInt32Array:
	var lw: int = width / period + 2
	var lh: int = height / period + 2
	var lattice: PackedInt32Array = PackedInt32Array()
	lattice.resize(lw * lh)
	for ly: int in range(lh):
		for lx: int in range(lw):
			lattice[ly * lw + lx] = SimRng.hash3(seed_value * 31 + salt, lx, ly) % (NOISE_ONE + 1)
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(width * height)
	for cy: int in range(height):
		var gy: int = cy / period
		var sy: int = _smooth((cy % period) * NOISE_ONE / period)
		for cx: int in range(width):
			var gx: int = cx / period
			var sx: int = _smooth((cx % period) * NOISE_ONE / period)
			var a: int = lattice[gy * lw + gx]
			var b: int = lattice[gy * lw + gx + 1]
			var c: int = lattice[(gy + 1) * lw + gx]
			var d: int = lattice[(gy + 1) * lw + gx + 1]
			var top: int = a + ((b - a) * sx) / NOISE_ONE
			var bot: int = c + ((d - c) * sx) / NOISE_ONE
			out[cy * width + cx] = top + ((bot - top) * sy) / NOISE_ONE
	return out


static func _noise_line(seed_value: int, salt: int, length: int, period: int) -> PackedInt32Array:
	var n: int = length / period + 2
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(length)
	for a: int in range(length):
		var g0: int = a / period
		var s: int = _smooth((a % period) * NOISE_ONE / period)
		var v0: int = SimRng.hash3(seed_value * 37 + salt, g0, 0) % (NOISE_ONE + 1)
		var v1: int = SimRng.hash3(seed_value * 37 + salt, mini(g0 + 1, n), 0) % (NOISE_ONE + 1)
		out[a] = v0 + ((v1 - v0) * s) / NOISE_ONE
	return out


## Smoothstep on 0..1024.
static func _smooth(t: int) -> int:
	return (t * t * (3 * NOISE_ONE - 2 * t)) / (NOISE_ONE * NOISE_ONE)
