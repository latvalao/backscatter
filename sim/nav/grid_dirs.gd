# SIM: deterministic — no floats, no Nodes
## 8-neighbour offsets in a fixed order (E, W, N, S, NE, NW, SE, SW).
class_name GridDirs
extends RefCounted

const DX: Array[int] = [1, -1, 0, 0, 1, -1, 1, -1]
const DY: Array[int] = [0, 0, 1, -1, 1, 1, -1, -1]


static func is_diagonal(d: int) -> bool:
	return d >= 4


## Diagonal moves may not cut the corner of an impassable cell.
static func can_step(grid: SimGrid, mobility: int, cx: int, cy: int, d: int) -> bool:
	var nx: int = cx + DX[d]
	var ny: int = cy + DY[d]
	if not grid.in_grid(nx, ny) or not grid.passable(mobility, grid.index(nx, ny)):
		return false
	if d >= 4:
		if not grid.passable(mobility, grid.index(cx + DX[d], cy)):
			return false
		if not grid.passable(mobility, grid.index(cx, cy + DY[d])):
			return false
	return true
