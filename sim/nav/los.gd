# SIM: deterministic — no floats, no Nodes
## Line of sight over the sim grid (§5.3): terrain height blocks, forest/urban/rock
## block once the ray has passed through enough of them (~50 m of forest),
## smoke blocks visual sight (thermal handled by the caller).
class_name Los
extends RefCounted

const CLEAR: int = 0
const SMOKE: int = 1
const BLOCKED: int = 2

const SAMPLE_MM: int = 8000
const OCCLUSION_LIMIT: int = 50000


static func check(world: SimWorld, ax: int, ay: int, az: int, bx: int, by: int, bz: int) -> int:
	var grid: SimGrid = world.grid
	var dx: int = bx - ax
	var dy: int = by - ay
	var dist: int = FixedMath.length2(dx, dy)
	var n: int = maxi(1, dist / SAMPLE_MM)
	var step_len: int = dist / n
	var a_cell: int = grid.cell_at(ax, ay)
	var b_cell: int = grid.cell_at(bx, by)
	var occl: int = 0
	for k: int in range(1, n):
		var px: int = ax + (dx * k) / n
		var py: int = ay + (dy * k) / n
		var c: int = grid.cell_at(px, py)
		var rz: int = az + ((bz - az) * k) / n
		if grid.ground_mm[c] > rz:
			return BLOCKED
		if c == a_cell or c == b_cell:
			continue
		var depth: int = TerrainTable.BLOCK_DEPTH_MM[grid.terrain[c]]
		if depth > 0:
			occl += (step_len * OCCLUSION_LIMIT) / depth
			if occl > OCCLUSION_LIMIT:
				return BLOCKED
	if world.smoke.count() > 0 and world.smoke.blocks(ax, ay, bx, by):
		return SMOKE
	return CLEAR


## Eye/target-height convenience between two entities.
static func between(world: SimWorld, observer: int, target: int) -> int:
	var t: TransformStore = world.transform
	var od: UnitStats = world.def_of(observer)
	var td: UnitStats = world.def_of(target)
	return check(world, t.x[observer], t.y[observer], t.z[observer] + od.eye_height_mm,
		t.x[target], t.y[target], t.z[target] + td.target_height_mm)
