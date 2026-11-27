# SIM: deterministic — no floats, no Nodes
## Navigation / terrain grid (8 m cells). Static for a match (built from the map).
## Also holds the derived sector cost table used by hierarchical pathfinding.
class_name SimGrid
extends RefCounted

const CELL_MM: int = 8000
const SECTOR: int = 64
const BIG: int = 0x3FFFFFFF
const STRAIGHT: int = 1000
const DIAGONAL: int = 1414

var width: int = 0
var height: int = 0
## Ground height per cell (mm).
var ground_mm: PackedInt32Array = PackedInt32Array()
var terrain: PackedByteArray = PackedByteArray()

var sectors_x: int = 0
var sectors_y: int = 0
## Straight step cost into each cell per mobility class, [mobility][cell]; 0 = impassable.
## Derived in rebuild_sectors(); read-only hot-path table for A* / flow fields.
var move_cost: Array[PackedInt32Array] = []
## Average cost to cross a sector, [mobility * sector_count + sector]; BIG = mostly impassable.
var sector_cost: PackedInt32Array = PackedInt32Array()


func _init(p_width: int = 1, p_height: int = 1) -> void:
	width = p_width
	height = p_height
	ground_mm.resize(width * height)
	terrain.resize(width * height)
	terrain.fill(TerrainTable.FIELD)


func cell_count() -> int:
	return width * height


func width_mm() -> int:
	return width * CELL_MM


func height_mm() -> int:
	return height * CELL_MM


func index(cx: int, cy: int) -> int:
	return cy * width + cx


func in_grid(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height


func cell_x(i: int) -> int:
	return i % width


func cell_y(i: int) -> int:
	return i / width


func cell_at(x_mm: int, y_mm: int) -> int:
	var cx: int = clampi(x_mm / CELL_MM, 0, width - 1)
	var cy: int = clampi(y_mm / CELL_MM, 0, height - 1)
	return cy * width + cx


func center_x(i: int) -> int:
	return (i % width) * CELL_MM + CELL_MM / 2


func center_y(i: int) -> int:
	return (i / width) * CELL_MM + CELL_MM / 2


func terrain_at(x_mm: int, y_mm: int) -> int:
	return terrain[cell_at(x_mm, y_mm)]


func ground_at(x_mm: int, y_mm: int) -> int:
	return ground_mm[cell_at(x_mm, y_mm)]


func speed(mobility: int, i: int) -> int:
	return TerrainTable.SPEED[mobility * TerrainTable.COUNT + terrain[i]]


func passable(mobility: int, i: int) -> bool:
	return speed(mobility, i) > 0


func passable_at(mobility: int, x_mm: int, y_mm: int) -> bool:
	if x_mm < 0 or y_mm < 0 or x_mm >= width_mm() or y_mm >= height_mm():
		return false
	return passable(mobility, cell_at(x_mm, y_mm))


## Cost to step into cell i (straight or diagonal). 0 if impassable.
func step_cost(mobility: int, i: int, diagonal: bool) -> int:
	var s: int = speed(mobility, i)
	if s <= 0:
		return 0
	return ((DIAGONAL if diagonal else STRAIGHT) * 1000) / s


## Nearest passable cell to i within max_r rings (Chebyshev), scanning rings in a
## fixed order. Returns -1 if none.
func nearest_passable(mobility: int, i: int, max_r: int) -> int:
	if passable(mobility, i):
		return i
	var cx: int = cell_x(i)
	var cy: int = cell_y(i)
	for r: int in range(1, max_r + 1):
		var best: int = -1
		var best_d: int = BIG
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var nx: int = cx + dx
				var ny: int = cy + dy
				if not in_grid(nx, ny):
					continue
				var j: int = index(nx, ny)
				if passable(mobility, j):
					var d: int = dx * dx + dy * dy
					if d < best_d:
						best_d = d
						best = j
		if best >= 0:
			return best
	return -1


func sector_of(i: int) -> int:
	return ((i / width) / SECTOR) * sectors_x + (i % width) / SECTOR


func sector_count() -> int:
	return sectors_x * sectors_y


## Recompute derived sector costs. Call after editing terrain.
func rebuild_sectors() -> void:
	sectors_x = (width + SECTOR - 1) / SECTOR
	sectors_y = (height + SECTOR - 1) / SECTOR
	var n: int = sectors_x * sectors_y
	sector_cost.resize(n * TerrainTable.MOBILITY_COUNT)
	move_cost.clear()
	for mob: int in range(TerrainTable.MOBILITY_COUNT):
		var mc: PackedInt32Array = PackedInt32Array()
		mc.resize(width * height)
		for i: int in range(width * height):
			mc[i] = step_cost(mob, i, false)
		move_cost.append(mc)
	for mob: int in range(TerrainTable.MOBILITY_COUNT):
		for sy: int in range(sectors_y):
			for sx: int in range(sectors_x):
				var total: int = 0
				var passable_n: int = 0
				var cells: int = 0
				for cy: int in range(sy * SECTOR, mini((sy + 1) * SECTOR, height)):
					for cx: int in range(sx * SECTOR, mini((sx + 1) * SECTOR, width)):
						cells += 1
						var c: int = step_cost(mob, index(cx, cy), false)
						if c > 0:
							passable_n += 1
							total += c
				var cost: int = BIG
				if passable_n * 5 >= cells and passable_n > 0:
					# average step cost x sector width, penalised by how blocked it is
					cost = (total / passable_n) * SECTOR * cells / passable_n
				sector_cost[mob * n + sy * sectors_x + sx] = cost
