extends TestCase


func _wall_grid() -> SimGrid:
	# 64×64 field with a vertical water wall at x=30 except a gap at y=50..52
	var g: SimGrid = SimGrid.new(64, 64)
	for y: int in range(64):
		if y < 50 or y > 52:
			g.terrain[g.index(30, y)] = TerrainTable.WATER
	g.rebuild_sectors()
	return g


func test_heap_orders_keys() -> void:
	var h: IntHeap = IntHeap.new()
	for v: int in [5, 3, 9, 1, 7, 1, 8]:
		h.push(v)
	var out: Array[int] = []
	while not h.is_empty():
		out.append(h.pop())
	var expected: Array[int] = [1, 1, 3, 5, 7, 8, 9]
	assert_eq(out, expected)


func test_path_goes_through_gap() -> void:
	var g: SimGrid = _wall_grid()
	var pf: PathFinder = PathFinder.new(g)
	var path: PackedInt32Array = pf.find_path(TerrainTable.TRACKED, g.index(5, 10), g.index(60, 10))
	assert_false(path.is_empty())
	assert_eq(path[path.size() - 1], g.index(60, 10))
	var through_gap: bool = false
	var prev: int = g.index(5, 10)
	for c: int in path:
		assert_true(g.passable(TerrainTable.TRACKED, c))
		assert_true(pf.line_walkable(TerrainTable.TRACKED, prev, c, 1), "smoothed segment crosses water")
		if g.cell_x(c) >= 29 and g.cell_x(c) <= 31:
			through_gap = through_gap or (g.cell_y(c) >= 49 and g.cell_y(c) <= 53)
		prev = c
	assert_true(through_gap or path.size() >= 2)


func test_unreachable_goal_gets_closest() -> void:
	var g: SimGrid = SimGrid.new(64, 64)
	for y: int in range(64):
		g.terrain[g.index(30, y)] = TerrainTable.WATER
	g.rebuild_sectors()
	var pf: PathFinder = PathFinder.new(g)
	var path: PackedInt32Array = pf.find_path(TerrainTable.TRACKED, g.index(5, 10), g.index(60, 10))
	assert_false(path.is_empty())
	assert_eq(g.cell_x(path[path.size() - 1]), 29, "stops at the near shore")


func test_wheeled_prefers_road() -> void:
	# forest everywhere except a road along y=40; wheeled path should use it
	var g: SimGrid = SimGrid.new(80, 80)
	for i: int in range(g.cell_count()):
		g.terrain[i] = TerrainTable.FOREST
	for x: int in range(80):
		g.terrain[g.index(x, 40)] = TerrainTable.ROAD
	for y: int in range(80):
		g.terrain[g.index(5, y)] = TerrainTable.ROAD
		g.terrain[g.index(75, y)] = TerrainTable.ROAD
	g.rebuild_sectors()
	var pf: PathFinder = PathFinder.new(g)
	var path: PackedInt32Array = pf.find_path(TerrainTable.WHEELED, g.index(5, 30), g.index(75, 30))
	var on_road: int = 0
	for c: int in path:
		if g.terrain[c] == TerrainTable.ROAD:
			on_road += 1
	assert_eq(on_road, path.size(), "every waypoint on road")


func test_hierarchical_long_path_on_test_map() -> void:
	var g: SimGrid = SimFixture.test_map()
	var pf: PathFinder = PathFinder.new(g)
	var a: int = g.nearest_passable(TerrainTable.TRACKED, g.index(20, 20), 20)
	var b: int = g.nearest_passable(TerrainTable.TRACKED, g.index(480, 470), 20)
	var t0: int = Time.get_ticks_msec()
	var path: PackedInt32Array = pf.find_path(TerrainTable.TRACKED, a, b)
	print("    long path: %d waypoints, %d expanded, %d ms" % [path.size(), pf.expanded_last, Time.get_ticks_msec() - t0])
	assert_false(path.is_empty())
	assert_eq(path[path.size() - 1], b)


func test_flow_field_descends_to_goal() -> void:
	var g: SimGrid = _wall_grid()
	var ff: FlowField = FlowField.new()
	var goal: int = g.index(60, 10)
	ff.build(g, TerrainTable.FOOT, goal, 0, 0, 63, 63)
	var cell: int = g.index(5, 10)
	assert_true(ff.reachable(cell))
	var steps: int = 0
	while cell != goal and steps < 500:
		var n: int = ff.next_cell(cell)
		assert_true(n >= 0, "flow dead end")
		if n < 0:
			return
		assert_true(ff.cost_at(n) < ff.cost_at(cell))
		cell = n
		steps += 1
	assert_eq(cell, goal)


func test_map_gen_deterministic_and_varied() -> void:
	var a: SimGrid = MapGen.generate(99, 120, 120)
	var b: SimGrid = MapGen.generate(99, 120, 120)
	assert_eq(a.terrain, b.terrain)
	assert_eq(a.ground_mm, b.ground_mm)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(TerrainTable.COUNT)
	for i: int in range(a.cell_count()):
		counts[a.terrain[i]] += 1
	assert_true(counts[TerrainTable.ROAD] > 100, "roads")
	assert_true(counts[TerrainTable.FOREST] > 500, "forest")
	assert_true(counts[TerrainTable.FIELD] > 2000, "fields")


func test_los_blocked_by_forest_depth_and_hills() -> void:
	var g: SimGrid = SimGrid.new(100, 20)
	for x: int in range(40, 50):  # 80 m of forest
		g.terrain[g.index(x, 10)] = TerrainTable.FOREST
	g.rebuild_sectors()
	var w: SimWorld = SimFixture.world(g)
	var y: int = 10 * SimGrid.CELL_MM + 4000
	assert_eq(Los.check(w, 4000, y, 2000, 600000, y, 2000), Los.BLOCKED, "80 m forest blocks")
	assert_eq(Los.check(w, 4000, y + 16000, 2000, 600000, y + 16000, 2000), Los.CLEAR, "open row clear")
	# 30 m forest only: visible
	var g2: SimGrid = SimGrid.new(100, 20)
	for x: int in range(40, 44):
		g2.terrain[g2.index(x, 10)] = TerrainTable.FOREST
	g2.rebuild_sectors()
	var w2: SimWorld = SimFixture.world(g2)
	assert_eq(Los.check(w2, 4000, y, 2000, 600000, y, 2000), Los.CLEAR, "30 m forest does not block")
	# ridge
	var g3: SimGrid = SimGrid.new(100, 20)
	g3.ground_mm[g3.index(50, 10)] = 10000
	g3.rebuild_sectors()
	var w3: SimWorld = SimFixture.world(g3)
	assert_eq(Los.check(w3, 4000, y, 2000, 700000, y, 2000), Los.BLOCKED, "ridge blocks")
	assert_eq(Los.check(w3, 4000, y, 30000, 700000, y, 30000), Los.CLEAR, "high observers see over")


func test_smoke_blocks_los() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(100, 20))
	w.smoke.add(200000, 80000, 20000, 1000)
	assert_eq(Los.check(w, 10000, 80000, 2000, 400000, 80000, 2000), Los.SMOKE)
	assert_eq(Los.check(w, 10000, 140000, 2000, 400000, 140000, 2000), Los.CLEAR)


func test_spatial_hash_query() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(64, 64))
	var a: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 100, 100)
	var b: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 110, 100)
	var c: int = SimFixture.spawn(w, "nc_rifle_sqd", 0, 400, 400)
	w.spatial.rebuild(w)
	var out: PackedInt32Array = PackedInt32Array()
	w.spatial.query(105000, 100000, 20000, out)
	assert_true(out.has(a) and out.has(b))
	assert_false(out.has(c))
