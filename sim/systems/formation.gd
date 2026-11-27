# SIM: deterministic — no floats, no Nodes
## Formation slot assignment for group orders: a block of rows facing the
## direction of travel; units keep their relative left/right order.
class_name Formation
extends RefCounted

const KEY_OFFSET: int = 1 << 26
const BLOCK: int = 0
const LINE: int = 1
const COLUMN: int = 2
const WEDGE: int = 3
const NAMES: Array[String] = ["block", "line", "column", "wedge"]


## Returns [x0, y0, x1, y1, ...] goal positions matching ids order.
## mode: BLOCK / LINE / COLUMN / WEDGE. face >= 0 sets the formation's front
## (binary angle); otherwise it faces the direction of travel.
static func slots(world: SimWorld, ids: PackedInt32Array, x: int, y: int, mode: int = BLOCK, face: int = -1) -> PackedInt64Array:
	var n: int = ids.size()
	var out: PackedInt64Array = PackedInt64Array()
	out.resize(n * 2)
	if n == 1:
		out[0] = x
		out[1] = y
		return out
	var t: TransformStore = world.transform
	var cx: int = 0
	var cy: int = 0
	var spacing: int = 0
	for id: int in ids:
		cx += t.x[id]
		cy += t.y[id]
		spacing = maxi(spacing, world.def_of(id).radius_mm * 2 + 6000)
	cx /= n
	cy /= n
	var fwd: int = face if face >= 0 else FixedMath.atan2_b(y - cy, x - cx)
	var fx: int = FixedMath.cos_b(fwd)
	var fy: int = FixedMath.sin_b(fwd)
	# right-hand vector = forward rotated -90°
	var rx: int = fy
	var ry: int = -fx
	var cols: int = FixedMath.isqrt(2 * n - 1) + 1
	if mode == LINE:
		cols = n
	elif mode == COLUMN:
		cols = 1
	# order units: most-forward first, then left-to-right within each row
	var by_fwd: PackedInt64Array = PackedInt64Array()
	for k: int in range(n):
		var id: int = ids[k]
		var proj: int = ((t.x[id] - cx) * fx + (t.y[id] - cy) * fy) / FixedMath.ONE
		by_fwd.append(((KEY_OFFSET - proj) << 20) | k)
	by_fwd.sort()
	var row_start: int = 0
	var slot: int = 0
	while row_start < n:
		var row_n: int = mini(cols, n - row_start)
		var row: PackedInt64Array = PackedInt64Array()
		for r: int in range(row_n):
			var k: int = by_fwd[row_start + r] & 0xFFFFF
			var id: int = ids[k]
			var side: int = ((t.x[id] - cx) * rx + (t.y[id] - cy) * ry) / FixedMath.ONE
			row.append(((side + KEY_OFFSET) << 20) | k)
		row.sort()
		var row_idx: int = row_start / cols
		for r: int in range(row_n):
			var k: int = row[r] & 0xFFFFF
			var lateral: int = (2 * r - (row_n - 1)) * spacing / 2
			var back: int = row_idx * spacing
			if mode == WEDGE:
				# apex first, then alternating left / right and further back
				var w_i: int = slot
				var arm: int = (w_i + 1) / 2
				lateral = arm * spacing * (1 if w_i % 2 == 1 else -1)
				back = arm * spacing
			var sx: int = x + (lateral * rx - back * fx) / FixedMath.ONE
			var sy: int = y + (lateral * ry - back * fy) / FixedMath.ONE
			var mob: int = world.def_of(ids[k]).mobility_class
			var cell: int = world.grid.cell_at(clampi(sx, 0, world.map_width_mm() - 1), clampi(sy, 0, world.map_height_mm() - 1))
			var pc: int = cell if mob == TerrainTable.AIR else world.grid.nearest_passable(mob, cell, 8)
			if pc >= 0 and pc != cell:
				sx = world.grid.center_x(pc)
				sy = world.grid.center_y(pc)
			out[2 * k] = clampi(sx, 0, world.map_width_mm() - 1)
			out[2 * k + 1] = clampi(sy, 0, world.map_height_mm() - 1)
			slot += 1
		row_start += row_n
	return out
