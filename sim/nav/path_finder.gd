# SIM: deterministic — no floats, no Nodes
## Hierarchical pathfinding (§7.6): A* over the sector graph picks a corridor,
## then cell-level A* runs inside that corridor. Falls back to an unrestricted
## (budget-limited) search, and finally to the closest reachable cell.
## Paths are smoothed so units don't zig-zag along cell centres.
class_name PathFinder
extends RefCounted

const CELL_BITS: int = 21
const CELL_MASK: int = (1 << CELL_BITS) - 1
const CORRIDOR_BUDGET: int = 60000
const FULL_BUDGET: int = 160000
const SMOOTH_LOOKAHEAD: int = 20
## Heuristic weight permille (>1000 trades optimality for speed; still deterministic).
const H_WEIGHT: int = 1400
const DX: Array[int] = [1, -1, 0, 0, 1, -1, 1, -1]
const DY: Array[int] = [0, 0, 1, -1, 1, 1, -1, -1]

var grid: SimGrid
## Optional extra per-cell cost for "safest" routing (dose/threat; filled in M5/M7).
var safety_cost: PackedInt32Array = PackedInt32Array()

var _g: PackedInt32Array = PackedInt32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _stamp: PackedInt32Array = PackedInt32Array()
var _closed: PackedInt32Array = PackedInt32Array()
var _search: int = 0
var _heap: IntHeap = IntHeap.new()
var _sector_allowed: PackedByteArray = PackedByteArray()
var expanded_last: int = 0
## Diagnostics (not sim state): number of find_path calls.
var calls: int = 0


func _init(p_grid: SimGrid) -> void:
	grid = p_grid
	var n: int = grid.cell_count()
	_g.resize(n)
	_parent.resize(n)
	_stamp.resize(n)
	_closed.resize(n)
	_sector_allowed.resize(grid.sector_count())


## Returns smoothed waypoint cells from start (exclusive) to goal (inclusive).
## Empty if no progress is possible.
func find_path(mobility: int, start: int, goal: int, safe: bool = false) -> PackedInt32Array:
	calls += 1
	var g: int = grid.nearest_passable(mobility, goal, 24)
	if g < 0:
		return PackedInt32Array()
	if g == start:
		return PackedInt32Array([g])
	var raw: PackedInt32Array
	var ss: int = grid.sector_of(start)
	var gs: int = grid.sector_of(g)
	var sdx: int = absi(ss % grid.sectors_x - gs % grid.sectors_x)
	var sdy: int = absi(ss / grid.sectors_x - gs / grid.sectors_x)
	if maxi(sdx, sdy) <= 1:
		raw = _astar(mobility, start, g, false, FULL_BUDGET, safe)
	else:
		var corridor: bool = _build_corridor(mobility, ss, gs)
		raw = _astar(mobility, start, g, corridor, CORRIDOR_BUDGET, safe)
		if raw.is_empty() or raw[raw.size() - 1] != g:
			var full: PackedInt32Array = _astar(mobility, start, g, false, FULL_BUDGET, safe)
			if not full.is_empty() and (raw.is_empty() or full[full.size() - 1] == g):
				raw = full
	if raw.is_empty():
		return raw
	return smooth(mobility, start, raw)


## Sector-level A*. Marks the path's sectors and their neighbours as allowed.
## Returns false if no sector path exists (caller then searches unrestricted).
func _build_corridor(mobility: int, ss: int, gs: int) -> bool:
	var n: int = grid.sector_count()
	var sx_n: int = grid.sectors_x
	var cost_base: int = mobility * n
	var g: PackedInt32Array = PackedInt32Array()
	g.resize(n)
	g.fill(SimGrid.BIG)
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(n)
	var heap: IntHeap = IntHeap.new()
	g[ss] = 0
	heap.push(ss)
	var found: bool = false
	while not heap.is_empty():
		var s: int = heap.pop() & 0xFFFF
		if closed[s] == 1:
			continue
		closed[s] = 1
		if s == gs:
			found = true
			break
		var sx: int = s % sx_n
		var sy: int = s / sx_n
		for d: int in range(8):
			var nx: int = sx + GridDirs.DX[d]
			var ny: int = sy + GridDirs.DY[d]
			if nx < 0 or ny < 0 or nx >= sx_n or ny >= grid.sectors_y:
				continue
			var t: int = ny * sx_n + nx
			var c: int = grid.sector_cost[cost_base + t]
			if c >= SimGrid.BIG and t != gs:
				continue
			if c >= SimGrid.BIG:
				c = SimGrid.SECTOR * 4000
			var step: int = c * (SimGrid.DIAGONAL if d >= 4 else SimGrid.STRAIGHT) / 1000
			var ng: int = g[s] + step
			if ng < g[t]:
				g[t] = ng
				parent[t] = s
				var hx: int = absi(nx - gs % sx_n)
				var hy: int = absi(ny - gs / sx_n)
				var h: int = (SimGrid.STRAIGHT * absi(hx - hy) + SimGrid.DIAGONAL * mini(hx, hy)) * SimGrid.SECTOR
				heap.push(((ng + h) << 16) | t)
	if not found:
		return false
	_sector_allowed.fill(0)
	var cur: int = gs
	while cur >= 0:
		var cx: int = cur % sx_n
		var cy: int = cur / sx_n
		for oy: int in range(-1, 2):
			for ox: int in range(-1, 2):
				var ax: int = cx + ox
				var ay: int = cy + oy
				if ax >= 0 and ay >= 0 and ax < sx_n and ay < grid.sectors_y:
					_sector_allowed[ay * sx_n + ax] = 1
		cur = parent[cur]
	return true


func _heuristic(a: int, b: int) -> int:
	var dx: int = absi(a % grid.width - b % grid.width)
	var dy: int = absi(a / grid.width - b / grid.width)
	return ((SimGrid.STRAIGHT * absi(dx - dy) + SimGrid.DIAGONAL * mini(dx, dy)) * H_WEIGHT) / 1000


## Cell A*. Returns cells start(exclusive)..goal(inclusive), or the path to the
## closest expanded cell if the goal was not reached within budget.
func _astar(mobility: int, start: int, goal: int, corridor: bool, budget: int, safe: bool) -> PackedInt32Array:
	_search += 1
	var sid: int = _search
	_heap.clear()
	_g[start] = 0
	_parent[start] = -1
	_stamp[start] = sid
	_heap.push((_heuristic(start, goal) << CELL_BITS) | start)
	var best: int = start
	var best_h: int = SimGrid.BIG
	var expanded: int = 0
	var w: int = grid.width
	var hgt: int = grid.height
	var mc: PackedInt32Array = grid.move_cost[mobility]
	var use_safety: bool = safe and safety_cost.size() == grid.cell_count()
	var gx: int = goal % w
	var gy: int = goal / w
	var sxn: int = grid.sectors_x
	while not _heap.is_empty():
		var cur: int = _heap.pop() & CELL_MASK
		if _closed[cur] == sid:
			continue
		_closed[cur] = sid
		if cur == goal:
			best = goal
			break
		expanded += 1
		if expanded > budget:
			break
		var cx: int = cur % w
		var cy: int = cur / w
		var hdx: int = absi(cx - gx)
		var hdy: int = absi(cy - gy)
		var h_cur: int = SimGrid.STRAIGHT * absi(hdx - hdy) + SimGrid.DIAGONAL * mini(hdx, hdy)
		if h_cur < best_h:
			best_h = h_cur
			best = cur
		var gc: int = _g[cur]
		for d: int in range(8):
			var nx: int = cx + DX[d]
			var ny: int = cy + DY[d]
			if nx < 0 or ny < 0 or nx >= w or ny >= hgt:
				continue
			var nb: int = ny * w + nx
			var step: int = mc[nb]
			if step == 0 or _closed[nb] == sid:
				continue
			if d >= 4:
				if mc[cy * w + nx] == 0 or mc[ny * w + cx] == 0:
					continue
				step = step * SimGrid.DIAGONAL / SimGrid.STRAIGHT
			if corridor and _sector_allowed[(ny / SimGrid.SECTOR) * sxn + nx / SimGrid.SECTOR] == 0:
				continue
			if use_safety:
				step += safety_cost[nb]
			var ng: int = gc + step
			if _stamp[nb] != sid or ng < _g[nb]:
				_stamp[nb] = sid
				_g[nb] = ng
				_parent[nb] = cur
				var ex: int = absi(nx - gx)
				var ey: int = absi(ny - gy)
				var hh: int = ((SimGrid.STRAIGHT * absi(ex - ey) + SimGrid.DIAGONAL * mini(ex, ey)) * H_WEIGHT) / 1000
				_heap.push(((ng + hh) << CELL_BITS) | nb)
	expanded_last = expanded
	if best == start:
		return PackedInt32Array()
	var rev: PackedInt32Array = PackedInt32Array()
	var c: int = best
	while c != start and c >= 0:
		rev.append(c)
		c = _parent[c]
	rev.reverse()
	return rev


## Drops intermediate cells while a straight line stays passable and never
## enters terrain slower than the path it replaces (keeps units on roads).
func smooth(mobility: int, start: int, path: PackedInt32Array) -> PackedInt32Array:
	var pts: PackedInt32Array = PackedInt32Array([start])
	pts.append_array(path)
	var out: PackedInt32Array = PackedInt32Array()
	var i: int = 0
	var n: int = pts.size()
	while i < n - 1:
		var best: int = i + 1
		var j: int = mini(n - 1, i + SMOOTH_LOOKAHEAD)
		while j > i + 1:
			var min_speed: int = 1000
			for k: int in range(i, j + 1):
				min_speed = mini(min_speed, grid.speed(mobility, pts[k]))
			if line_walkable(mobility, pts[i], pts[j], min_speed):
				best = j
				break
			j -= 1
		out.append(pts[best])
		i = best
	return out


## Conservative grid line walk between cell centres: every touched cell must be
## passable with speed >= min_speed; diagonal steps also check both side cells.
func line_walkable(mobility: int, a: int, b: int, min_speed: int) -> bool:
	var w: int = grid.width
	var x0: int = a % w
	var y0: int = a / w
	var x1: int = b % w
	var y1: int = b / w
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		if grid.speed(mobility, y0 * w + x0) < min_speed:
			return false
		if x0 == x1 and y0 == y1:
			return true
		var e2: int = 2 * err
		var step_x: bool = e2 >= dy
		var step_y: bool = e2 <= dx
		if step_x and step_y:
			if grid.speed(mobility, y0 * w + x0 + sx) < min_speed:
				return false
			if grid.speed(mobility, (y0 + sy) * w + x0) < min_speed:
				return false
		if step_x:
			err += dy
			x0 += sx
		if step_y:
			err += dx
			y0 += sy
	return true
