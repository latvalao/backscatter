# SIM: deterministic — no floats, no Nodes
## Dijkstra integration field toward one goal cell over a rectangular window.
## Shared by every unit of one mobility class in a group move order.
class_name FlowField
extends RefCounted

var id: int = 0
var mobility: int = 0
var goal: int = 0
var x0: int = 0
var y0: int = 0
var w: int = 0
var h: int = 0
var cost: PackedInt32Array = PackedInt32Array()
var users: int = 0

var _grid: SimGrid
## Lazily filled best-next-cell per window cell (-2 = not computed). Derived data.
var _next: PackedInt32Array = PackedInt32Array()


func build(grid: SimGrid, p_mobility: int, p_goal: int, p_x0: int, p_y0: int, p_x1: int, p_y1: int) -> void:
	_grid = grid
	mobility = p_mobility
	goal = p_goal
	x0 = clampi(p_x0, 0, grid.width - 1)
	y0 = clampi(p_y0, 0, grid.height - 1)
	w = clampi(p_x1, 0, grid.width - 1) - x0 + 1
	h = clampi(p_y1, 0, grid.height - 1) - y0 + 1
	cost.resize(w * h)
	cost.fill(SimGrid.BIG)
	_next.resize(w * h)
	_next.fill(-2)
	var gx: int = grid.cell_x(goal) - x0
	var gy: int = grid.cell_y(goal) - y0
	if gx < 0 or gy < 0 or gx >= w or gy >= h:
		return
	var heap: IntHeap = IntHeap.new()
	var gl: int = gy * w + gx
	cost[gl] = 0
	heap.push(gl)
	var mc: PackedInt32Array = grid.move_cost[mobility]
	var gw: int = grid.width
	while not heap.is_empty():
		var key: int = heap.pop()
		var l: int = key & PathFinder.CELL_MASK
		var c: int = key >> PathFinder.CELL_BITS
		if c > cost[l]:
			continue
		var lx: int = l % w
		var ly: int = l / w
		var cx: int = lx + x0
		var cy: int = ly + y0
		# cost of stepping INTO the current cell from a neighbour
		var into: int = mc[cy * gw + cx]
		for d: int in range(8):
			var nlx: int = lx + PathFinder.DX[d]
			var nly: int = ly + PathFinder.DY[d]
			if nlx < 0 or nly < 0 or nlx >= w or nly >= h:
				continue
			var nx: int = nlx + x0
			var ny: int = nly + y0
			if mc[ny * gw + nx] == 0:
				continue
			var step: int = into
			if d >= 4:
				if mc[cy * gw + nx] == 0 or mc[ny * gw + cx] == 0:
					continue
				step = into * SimGrid.DIAGONAL / SimGrid.STRAIGHT
			var nl: int = nly * w + nlx
			var nc: int = c + step
			if nc < cost[nl]:
				cost[nl] = nc
				heap.push((nc << PathFinder.CELL_BITS) | nl)


func contains(cell: int) -> bool:
	var lx: int = cell % _grid.width - x0
	var ly: int = cell / _grid.width - y0
	return lx >= 0 and ly >= 0 and lx < w and ly < h


func cost_at(cell: int) -> int:
	var lx: int = cell % _grid.width - x0
	var ly: int = cell / _grid.width - y0
	if lx < 0 or ly < 0 or lx >= w or ly >= h:
		return SimGrid.BIG
	return cost[ly * w + lx]


func reachable(cell: int) -> bool:
	return cost_at(cell) < SimGrid.BIG


## Neighbour cell with the lowest integrated cost (fixed tie order), or -1.
func next_cell(cell: int) -> int:
	var gw: int = _grid.width
	var cx: int = cell % gw
	var cy: int = cell / gw
	var lx: int = cx - x0
	var ly: int = cy - y0
	if lx < 0 or ly < 0 or lx >= w or ly >= h:
		return -1
	var l: int = ly * w + lx
	var cached: int = _next[l]
	if cached != -2:
		return cached
	var mc: PackedInt32Array = _grid.move_cost[mobility]
	var best: int = -1
	var best_c: int = cost[l]
	for d: int in range(8):
		var nlx: int = lx + PathFinder.DX[d]
		var nly: int = ly + PathFinder.DY[d]
		if nlx < 0 or nly < 0 or nlx >= w or nly >= h:
			continue
		var c: int = cost[nly * w + nlx]
		if c >= best_c:
			continue
		var nx: int = nlx + x0
		var ny: int = nly + y0
		if mc[ny * gw + nx] == 0:
			continue
		if d >= 4 and (mc[cy * gw + nx] == 0 or mc[ny * gw + cx] == 0):
			continue
		best_c = c
		best = ny * gw + nx
	_next[l] = best
	return best
