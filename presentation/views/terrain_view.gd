## Terrain, water, forest and world props built from the SimGrid (presentation
## only). Chunked ArrayMesh terrain with soft normals and terrain-type weights
## for the diorama shader, a water surface over lakes, MultiMesh foliage with
## near/far LOD per chunk, houses on urban cells, rocks, reeds, bog mist and a
## persistent trail map (tracks, craters, scorch) — docs/VISUALS.md §6–§7.
class_name TerrainView
extends Node3D

const CHUNK: int = 50
## Base colours per terrain type (diorama palette, §3.1).
const COLORS: Array[Color] = [
	Color(0.43, 0.41, 0.35),  # road (gravel)
	Color(0.33, 0.4, 0.22),  # field (moss / grass)
	Color(0.24, 0.27, 0.18),  # forest floor
	Color(0.27, 0.26, 0.17),  # bog / peat
	Color(0.22, 0.24, 0.2),   # lake bed
	Color(0.4, 0.42, 0.3),    # urban (gardens and trampled yards)
	Color(0.49, 0.5, 0.47),   # rock (granite)
]
const WATER_DROP: float = 1.6   # visual lake-bed depression below the surface
## Trail map resolution: metres per texel.
const TRAIL_M: float = 2.0

var grid: SimGrid
var material: ShaderMaterial
var water_material: ShaderMaterial
var foliage_material: ShaderMaterial
var _trail_img: Image
var _trail_tex: ImageTexture
var _trail_dirty: bool = false
var _trail_timer: float = 0.0
var _fade: PackedVector4Array = PackedVector4Array()
var _paved: PackedByteArray = PackedByteArray()
var _cells_img: Image
var _cells_tex: ImageTexture


func build(p_grid: SimGrid) -> void:
	grid = p_grid
	GraphicsSettings.load_settings()
	var size_m: Vector2 = Vector2(grid.width_mm() * 0.001, grid.height_mm() * 0.001)
	material = ShaderMaterial.new()
	material.shader = load("res://presentation/look/shaders/terrain.gdshader") as Shader
	material.set_shader_parameter("map_size_m", size_m)
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://presentation/look/shaders/water.gdshader") as Shader
	water_material.set_shader_parameter("map_size_m", size_m)
	foliage_material = ShaderMaterial.new()
	foliage_material.shader = load("res://presentation/look/shaders/foliage.gdshader") as Shader
	foliage_material.set_shader_parameter("palette", LookPalette.texture())
	_trail_img = Image.create(maxi(1, int(size_m.x / TRAIL_M)), maxi(1, int(size_m.y / TRAIL_M)), false, Image.FORMAT_RG8)
	_trail_tex = ImageTexture.create_from_image(_trail_img)
	material.set_shader_parameter("trail_tex", _trail_tex)
	# one pixel per cell: R = road, G = town plot, B = paved (town streets and
	# the central yards), read crisp by the terrain shader
	_paved.resize(grid.cell_count())
	var cells: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	for i: int in range(grid.cell_count()):
		var t: int = grid.terrain[i]
		var x: int = grid.cell_x(i)
		var y: int = grid.cell_y(i)
		if t == TerrainTable.ROAD and _near(x, y, TerrainTable.URBAN, 2):
			_paved[i] = 1
		cells.set_pixel(x, y, Color(1.0 if t == TerrainTable.ROAD else 0.0, 1.0 if t == TerrainTable.URBAN else 0.0, float(_paved[i]), 1.0 if t == TerrainTable.WATER else 0.0))
	_cells_img = cells
	_cells_tex = ImageTexture.create_from_image(cells)
	material.set_shader_parameter("cells_tex", _cells_tex)
	water_material.set_shader_parameter("cells_tex", _cells_tex)
	for cy: int in range(0, grid.height, CHUNK):
		for cx: int in range(0, grid.width, CHUNK):
			var cw: int = mini(CHUNK, grid.width - cx)
			var ch: int = mini(CHUNK, grid.height - cy)
			_build_chunk(cx, cy, cw, ch)
			_build_water(cx, cy, cw, ch)
			_build_foliage(cx, cy, cw, ch)
	_build_settlement()
	_build_mist()


func set_fog_texture(tex: Texture2D) -> void:
	material.set_shader_parameter("fog_tex", tex)
	water_material.set_shader_parameter("fog_tex", tex)


func set_rad_texture(tex: Texture2D) -> void:
	material.set_shader_parameter("rad_tex", tex)


func set_rad_enabled(on: bool, banded: bool) -> void:
	material.set_shader_parameter("rad_enabled", 1.0 if on else 0.0)
	material.set_shader_parameter("rad_bands", 1.0 if banded else 0.0)


func set_fog_enabled(on: bool) -> void:
	material.set_shader_parameter("fog_enabled", 1.0 if on else 0.0)
	water_material.set_shader_parameter("fog_enabled", 1.0 if on else 0.0)


## Canopy dither-fade centres (xyz + radius in w), max 8.
func set_fade_points(points: PackedVector4Array) -> void:
	_fade = points
	var arr: PackedVector4Array = points.duplicate()
	arr.resize(8)
	foliage_material.set_shader_parameter("fade_points", arr)
	foliage_material.set_shader_parameter("fade_count", mini(8, points.size()))


## Height (m) at a grid corner: average of the up-to-4 adjacent cells.
func corner_height(vx: int, vy: int) -> float:
	var total: int = 0
	var n: int = 0
	for oy: int in range(-1, 1):
		for ox: int in range(-1, 1):
			var cx: int = vx + ox
			var cy: int = vy + oy
			if grid.in_grid(cx, cy):
				total += grid.ground_mm[grid.index(cx, cy)]
				n += 1
	return total * 0.001 / maxi(1, n)


## Height (m) at a world position, bilinear over corners.
func height_at(p: Vector3) -> float:
	var gx: float = p.x / (SimGrid.CELL_MM * 0.001)
	var gy: float = -p.z / (SimGrid.CELL_MM * 0.001)
	var x0: int = clampi(floori(gx), 0, grid.width - 1)
	var y0: int = clampi(floori(gy), 0, grid.height - 1)
	var fx: float = clampf(gx - x0, 0.0, 1.0)
	var fy: float = clampf(gy - y0, 0.0, 1.0)
	var a: float = lerpf(corner_height(x0, y0), corner_height(x0 + 1, y0), fx)
	var b: float = lerpf(corner_height(x0, y0 + 1), corner_height(x0 + 1, y0 + 1), fx)
	return lerpf(a, b, fy)


func terrain_at(p: Vector3) -> int:
	var cx: int = clampi(floori(p.x / (SimGrid.CELL_MM * 0.001)), 0, grid.width - 1)
	var cy: int = clampi(floori(-p.z / (SimGrid.CELL_MM * 0.001)), 0, grid.height - 1)
	return grid.terrain[grid.index(cx, cy)]


# ------------------------------------------------------------ trail map

## Darkens a short track segment (vehicles) into the trail map.
func stamp_track(a: Vector3, b: Vector3, width_m: float, strength: float) -> void:
	var steps: int = maxi(1, int(a.distance_to(b) / TRAIL_M) + 1)
	var r: int = maxi(0, int(width_m * 0.5 / TRAIL_M))
	for i: int in range(steps + 1):
		var p: Vector3 = a.lerp(b, float(i) / steps)
		var tx: int = int(p.x / TRAIL_M)
		var ty: int = int(-p.z / TRAIL_M)
		for oy: int in range(-r, r + 1):
			for ox: int in range(-r, r + 1):
				_bump(tx + ox, ty + oy, strength, 0.0)


## Crater / scorch disc (artillery, wrecks). Persists all match.
func stamp_crater(p: Vector3, radius_m: float, scorch: float) -> void:
	var r: int = maxi(1, int(radius_m / TRAIL_M))
	var tx: int = int(p.x / TRAIL_M)
	var ty: int = int(-p.z / TRAIL_M)
	for oy: int in range(-r, r + 1):
		for ox: int in range(-r, r + 1):
			var d: float = sqrt(float(ox * ox + oy * oy)) / r
			if d <= 1.0:
				_bump(tx + ox, ty + oy, 0.6 * (1.0 - d), scorch * (1.0 - d * d))


func _bump(x: int, y: int, track: float, scorch: float) -> void:
	if x < 0 or y < 0 or x >= _trail_img.get_width() or y >= _trail_img.get_height():
		return
	var c: Color = _trail_img.get_pixel(x, y)
	c.r = minf(1.0, c.r + track)
	c.g = minf(1.0, c.g + scorch)
	_trail_img.set_pixel(x, y, c)
	_trail_dirty = true


func _process(delta: float) -> void:
	_trail_timer -= delta
	if _trail_dirty and _trail_timer <= 0.0:
		_trail_tex.update(_trail_img)
		_trail_dirty = false
		_trail_timer = 0.5


# ------------------------------------------------------------ meshes

func _is_water(cx: int, cy: int) -> bool:
	return grid.in_grid(cx, cy) and grid.terrain[grid.index(cx, cy)] == TerrainTable.WATER


func _corner_water(vx: int, vy: int) -> bool:
	return _is_water(vx - 1, vy - 1) or _is_water(vx, vy - 1) or _is_water(vx - 1, vy) or _is_water(vx, vy)


func _build_chunk(cx0: int, cy0: int, cw: int, ch: int) -> void:
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var vw: int = cw + 1
	for vy: int in range(ch + 1):
		for vx: int in range(cw + 1):
			var gx: int = cx0 + vx
			var gy: int = cy0 + vy
			var y: float = corner_height(gx, gy)
			# lake bed: deeper the more of the corner's cells are water, so the
			# banks slope in gently instead of dropping off cell by cell
			# and every corner touching water sits under the waterline, so the
			# shore shader (not the 8 m cell geometry) draws the waterline
			var wn: int = 0
			var lvl: float = INF
			for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				if _is_water(gx + o.x, gy + o.y):
					wn += 1
					lvl = minf(lvl, _water_level(gx + o.x, gy + o.y))
			if wn > 0:
				var frac: float = wn / 4.0
				y = minf(y - WATER_DROP * frac, lvl - 0.3 - WATER_DROP * 0.7 * frac)
			verts.append(Vector3(gx * cell_m, y, -gy * cell_m))
			var hl: float = corner_height(gx - 1, gy)
			var hr: float = corner_height(gx + 1, gy)
			var hd: float = corner_height(gx, gy - 1)
			var hu: float = corner_height(gx, gy + 1)
			normals.append(Vector3(hl - hr, 2.0 * cell_m, hu - hd).normalized())
			# blend the up-to-4 adjacent cells
			var c: Color = Color(0, 0, 0)
			var w: Vector4 = Vector4.ZERO
			var n: int = 0
			for oy: int in range(-1, 1):
				for ox: int in range(-1, 1):
					var x: int = gx + ox
					var yy: int = gy + oy
					if not grid.in_grid(x, yy):
						continue
					var t: int = grid.terrain[grid.index(x, yy)]
					c += COLORS[t]
					n += 1
					match t:
						TerrainTable.FOREST:
							w.x += 1.0
						TerrainTable.BOG, TerrainTable.WATER:
							w.y += 1.0
						TerrainTable.ROAD:
							w.z += 1.0
						TerrainTable.ROCK:
							w.w += 1.0
			n = maxi(1, n)
			colors.append(c / n)
			uv.append(Vector2(w.x / n, w.y / n))
			uv2.append(Vector2(w.z / n, w.w / n))
	for y2: int in range(ch):
		for x2: int in range(cw):
			var i: int = y2 * vw + x2
			indices.append_array(PackedInt32Array([i, i + vw, i + 1, i + 1, i + vw, i + vw + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)


func _build_water(cx0: int, cy0: int, cw: int, ch: int) -> void:
	# Water covers lake cells plus a one-cell ring at the lake level; the banks
	# rise through it, so the visible shoreline follows the terrain contour
	# instead of the 8 m cell staircase.
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var verts: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for y: int in range(ch):
		for x: int in range(cw):
			var gx: int = cx0 + x
			var gy: int = cy0 + y
			var level: float = INF
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					if _is_water(gx + ox, gy + oy):
						level = minf(level, _water_level(gx + ox, gy + oy))
			if level == INF:
				continue
			var base: int = verts.size()
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				verts.append(Vector3((gx + c.x) * cell_m, level, -(gy + c.y) * cell_m))
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	if verts.is_empty():
		return
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = water_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Flat water level of a lake cell: its own ground height (lakes are clamped flat).
func _water_level(gx: int, gy: int) -> float:
	return grid.ground_mm[grid.index(gx, gy)] * 0.001 - 0.35


func _build_foliage(cx0: int, cy0: int, cw: int, ch: int) -> void:
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var per: int = GraphicsSettings.trees_per_cell()
	var poles: PackedVector3Array = PackedVector3Array()
	var species: Dictionary = {}  # name -> Array[Transform3D]
	var customs: Dictionary = {}   # name -> PackedColorArray
	var props: Dictionary = {}
	for y: int in range(ch):
		for x: int in range(cw):
			var gx: int = cx0 + x
			var gy: int = cy0 + y
			var t: int = grid.terrain[grid.index(gx, gy)]
			var h0: int = SimRng.hash3(gx, gy, 77)
			match t:
				TerrainTable.FOREST:
					for k: int in range(per):
						var hk: int = SimRng.hash3(gx, gy, 100 + k)
						var name: String = _species(gx, gy, hk)
						_place(species, customs, name, gx, gy, hk, cell_m, 0.75 + float((hk >> 20) & 0x3F) / 63.0 * 0.5)
				TerrainTable.FIELD:
					for k2: int in range(3):
						var ht: int = SimRng.hash3(gx, gy, 300 + k2)
						_place(props, customs, "tufts", gx, gy, ht, cell_m, 1.0 + float((ht >> 22) & 7) * 0.12)
					if (h0 & 0x7FF) < 4:
						_place(props, customs, "bales", gx, gy, h0 >> 2, cell_m, 1.0)
					elif (h0 & 0x3F) == 5 and _near(gx, gy, TerrainTable.URBAN, 3):
						_place(props, customs, "barn", gx, gy, h0, cell_m, 1.0, true)
					if (h0 & 0x3FF) < 10:
						_place(species, customs, "birch" if (h0 >> 10) & 1 == 0 else "juniper", gx, gy, h0, cell_m, 0.8)
				TerrainTable.BOG:
					if (h0 & 0xFF) < 70:
						_place(props, customs, "reeds", gx, gy, h0, cell_m, 1.0)
					elif (h0 & 0x3FF) < 90:
						_place(species, customs, "birch", gx, gy, h0, cell_m, 0.6)
				TerrainTable.ROCK:
					if (h0 & 0xFF) < 90:
						_place(props, customs, "rock_%d" % ((h0 >> 8) % 3), gx, gy, h0, cell_m, 0.8 + float((h0 >> 12) & 0xF) / 15.0 * 1.2)
				TerrainTable.ROAD:
					_road_props(props, customs, poles, gx, gy, h0, cell_m)
	_wires(poles)
	var lod: float = GraphicsSettings.tree_lod_distance()
	for name2: String in species.keys():
		var xs: Array[Transform3D] = species[name2]
		var cu: PackedColorArray = customs[name2]
		var near: MultiMesh = _multimesh(ModelLibrary.mesh(name2), xs, cu, foliage_material, 0.0, lod + 60.0, true)
		var far: MultiMesh = _multimesh(ModelLibrary.mesh(name2 + "_far"), xs, cu, foliage_material, lod, 0.0, false)
		_register("tree", [near, far], xs)
	for name3: String in props.keys():
		var xs2: Array[Transform3D] = props[name3]
		var cu2: PackedColorArray = customs[name3]
		var mat: Material = foliage_material if name3 == "reeds" or name3 == "tufts" else ModelLibrary.material(4, 3)
		var far_end: float = 2600.0 if name3.begins_with("house") or name3 == "barn" else (700.0 if name3 == "fence" else (380.0 if name3 == "tufts" else 1400.0))
		_multimesh(ModelLibrary.mesh(name3), xs2, cu2, mat, 0.0, far_end, name3 != "tufts")


func _is_road(gx: int, gy: int) -> bool:
	return grid.in_grid(gx, gy) and grid.terrain[grid.index(gx, gy)] == TerrainTable.ROAD


func _near(gx: int, gy: int, t: int, r: int) -> bool:
	for oy: int in range(-r, r + 1):
		for ox: int in range(-r, r + 1):
			if grid.in_grid(gx + ox, gy + oy) and grid.terrain[grid.index(gx + ox, gy + oy)] == t:
				return true
	return false


## Power-line poles beside the road every few cells, and the odd abandoned car.
func _road_props(props: Dictionary, customs: Dictionary, poles: PackedVector3Array, gx: int, gy: int, h0: int, cell_m: float) -> void:
	if _paved[grid.index(gx, gy)] == 1:
		# town street: cars parked along the kerb, no power poles (lamps instead)
		if (h0 & 0x7) < 2:
			var along_x: bool = _is_road(gx + 1, gy) and _is_road(gx - 1, gy)
			var side: float = 1.0 if (h0 >> 4) & 1 == 0 else -1.0
			var off: Vector2 = Vector2(0.0, side * 0.24) if along_x else Vector2(side * 0.24, 0.0)
			var cp2: Vector3 = Vector3((gx + 0.5 + off.x) * cell_m, 0.0, -(gy + 0.5 + off.y) * cell_m)
			cp2.y = height_at(cp2)
			var yaw2: float = (PI * 0.5 if along_x else 0.0) + (float((h0 >> 6) & 7) - 3.5) * 0.02
			_place_xf(props, customs, "car_%d" % ((h0 >> 9) & 1), Transform3D(Basis(Vector3.UP, yaw2), cp2), h0)
		return
	if (h0 & 0x7F) == 3:
		var cp: Vector3 = Vector3((gx + 0.5) * cell_m, 0.0, -(gy + 0.5) * cell_m)
		cp.y = height_at(cp)
		_place_xf(props, customs, "car_%d" % ((h0 >> 9) & 1), Transform3D(Basis(Vector3.UP, float((h0 >> 12) & 0xFF) / 255.0 * TAU), cp), h0)
	if (gx * 7 + gy * 3) % 6 != 0:
		return
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var nx: int = gx + d.x
		var ny: int = gy + d.y
		if not grid.in_grid(nx, ny):
			continue
		var nt: int = grid.terrain[grid.index(nx, ny)]
		if nt == TerrainTable.FIELD or nt == TerrainTable.BOG:
			var p: Vector3 = Vector3((nx + 0.5) * cell_m, 0.0, -(ny + 0.5) * cell_m)
			p.y = height_at(p)
			_place_xf(props, customs, "pole", Transform3D(Basis(Vector3.UP, float(h0 & 3) * 0.1), p), h0)
			poles.append(p)
			return


## Sagging wires between neighbouring poles.
func _wires(poles: PackedVector3Array) -> void:
	if poles.size() < 2:
		return
	var seg: PackedVector3Array = PackedVector3Array()
	for i: int in range(poles.size()):
		var best: int = -1
		var best_d: float = 80.0
		for j: int in range(poles.size()):
			if j <= i:
				continue
			var d: float = poles[i].distance_to(poles[j])
			if d > 20.0 and d < best_d:
				best_d = d
				best = j
		if best < 0:
			continue
		for k: int in [-1, 0, 1]:
			var off: Vector3 = Vector3(k * 1.1, 8.6, 0)
			var prev: Vector3 = poles[i] + off
			for s2: int in range(1, 7):
				var f: float = s2 / 6.0
				var p: Vector3 = (poles[i] + off).lerp(poles[best] + off, f)
				p.y -= sin(f * PI) * best_d * 0.025
				seg.append(prev)
				seg.append(p)
				prev = p
	if seg.is_empty():
		return
	var im: ImmediateMesh = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for v: Vector3 in seg:
		im.surface_add_vertex(v)
	im.surface_end()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = im
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.07)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 900.0
	add_child(mi)


func _place_xf(into: Dictionary, customs: Dictionary, name: String, xf: Transform3D, hk: int) -> void:
	if not into.has(name):
		var arr: Array[Transform3D] = []
		into[name] = arr
		customs[name] = PackedColorArray()
	var list: Array[Transform3D] = into[name]
	list.append(xf)
	var cl: PackedColorArray = customs[name]
	cl.append(Color(float(hk & 0x3FF) / 1023.0, float((hk >> 3) & 0xFF) / 255.0, float((hk >> 11) & 0xFF) / 255.0, 0.0))


func _species(gx: int, gy: int, hk: int) -> String:
	# patches: pine-dominated stands, spruce hollows, birch/aspen groves at edges
	var patch: int = SimRng.hash3(gx / 6, gy / 6, 5) & 0xFF
	var edge: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = gx + d.x
		var y: int = gy + d.y
		if grid.in_grid(x, y) and grid.terrain[grid.index(x, y)] != TerrainTable.FOREST:
			edge = true
	var r: int = (hk >> 4) & 0xFF
	if edge and r < 90:
		return "juniper" if r < 25 else ("aspen" if r < 40 else "birch")
	if patch < 70:
		return "birch" if r < 150 else ("aspen" if r < 175 else "pine")
	if patch < 150:
		return "pine" if r < 200 else "birch"
	return "spruce" if r < 190 else "pine"


func _place(into: Dictionary, customs: Dictionary, name: String, gx: int, gy: int, hk: int, cell_m: float, scale: float, axis_aligned: bool = false) -> void:
	var jx: float = float(hk & 0xFF) / 255.0 - 0.5
	var jy: float = float((hk >> 8) & 0xFF) / 255.0 - 0.5
	var p: Vector3 = Vector3((gx + 0.5 + jx * 0.7) * cell_m, 0.0, -(gy + 0.5 + jy * 0.7) * cell_m)
	if axis_aligned:
		p = Vector3((gx + 0.5) * cell_m, 0.0, -(gy + 0.5) * cell_m)
	p.y = height_at(p)
	var yaw: float = float((hk >> 16) & 0xFF) / 255.0 * TAU
	if axis_aligned:
		yaw = float((hk >> 16) & 3) * PI * 0.5
	var lean: Basis = Basis(Vector3(cos(yaw), 0, sin(yaw)), float((hk >> 26) & 0xF) / 15.0 * 0.06) if not axis_aligned else Basis.IDENTITY
	var basis: Basis = lean * Basis(Vector3.UP, yaw)
	if not into.has(name):
		var arr: Array[Transform3D] = []
		into[name] = arr
		customs[name] = PackedColorArray()
	var list: Array[Transform3D] = into[name]
	list.append(Transform3D(basis.scaled(Vector3(scale, scale * (0.9 + float((hk >> 12) & 0xF) / 15.0 * 0.25), scale)), p))
	var cl: PackedColorArray = customs[name]
	cl.append(Color(float(hk & 0x3FF) / 1023.0, float((hk >> 3) & 0xFF) / 255.0, float((hk >> 11) & 0xFF) / 255.0, 0.0))


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], custom: PackedColorArray, mat: Material, begin: float, end: float, shadows: bool) -> MultiMesh:
	if xforms.is_empty() or mesh == null:
		return null
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_custom_data(i, custom[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.visibility_range_begin_margin = 40.0 if begin > 0.0 else 0.0
	mmi.visibility_range_end_margin = 40.0 if end > 0.0 else 0.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## Low volumetric mist over bogs and lake shores (FogVolumes; High+ only).
func _build_mist() -> void:
	if GraphicsSettings.quality < GraphicsSettings.Quality.HIGH:
		return
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var step: int = 12
	var noise_tex: NoiseTexture3D = NoiseTexture3D.new()
	var fnl: FastNoiseLite = FastNoiseLite.new()
	fnl.frequency = 0.05
	noise_tex.noise = fnl
	noise_tex.width = 32
	noise_tex.height = 16
	noise_tex.depth = 32
	noise_tex.seamless = true
	var mat: FogMaterial = FogMaterial.new()
	mat.density = 0.035
	mat.albedo = Color(0.86, 0.87, 0.86)
	mat.height_falloff = 0.25
	mat.edge_fade = 0.6
	mat.density_texture = noise_tex
	var placed: int = 0
	for cy: int in range(0, grid.height, step):
		for cx: int in range(0, grid.width, step):
			var wet: int = 0
			for oy: int in range(step):
				for ox: int in range(step):
					var t: int = grid.terrain[grid.index(mini(cx + ox, grid.width - 1), mini(cy + oy, grid.height - 1))]
					if t == TerrainTable.BOG or t == TerrainTable.WATER:
						wet += 1
			if wet * 3 < step * step or placed >= 160:
				continue
			var fv: FogVolume = FogVolume.new()
			fv.size = Vector3(step * cell_m * 1.5, 9.0, step * cell_m * 1.5)
			fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
			fv.material = mat
			var p: Vector3 = Vector3((cx + step * 0.5) * cell_m, 0.0, -(cy + step * 0.5) * cell_m)
			p.y = height_at(p) + 1.5
			fv.position = p
			add_child(fv)
			placed += 1


## Reactor complex of the Kaarnavaara plant at a world position.
func place_plant(p: Vector3) -> void:
	var m: Mesh = ModelLibrary.mesh("plant")
	if m == null:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = ModelLibrary.material(4, 3)
	mi.position = Vector3(p.x, height_at(p), p.z)
	add_child(mi)
	# warning lights on the vent stack
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.25, 0.15)
	lamp.light_energy = 2.0
	lamp.omni_range = 40.0
	lamp.position = mi.position + Vector3(10, 83, -8)
	add_child(lamp)


# ------------------------------------------------------------ settlements

## Buildings by block: the street grid from MapGen leaves blocks of URBAN cells.
## Central blocks get prefab panel buildings and the shop, one block the church,
## the edge a water tower; the rest are houses facing the street with sheds,
## gardens, fences and the odd garage row. Street lamps along village streets.
func _build_settlement() -> void:
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(grid.cell_count())
	var blocks: Array[PackedInt32Array] = []
	var cx: float = 0.0
	var cy: float = 0.0
	var n: int = 0
	for i: int in range(grid.cell_count()):
		if grid.terrain[i] != TerrainTable.URBAN or seen[i] == 1:
			continue
		var comp: PackedInt32Array = PackedInt32Array()
		var stack: PackedInt32Array = PackedInt32Array([i])
		seen[i] = 1
		while not stack.is_empty():
			var c: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			comp.append(c)
			cx += grid.cell_x(c)
			cy += grid.cell_y(c)
			n += 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var x: int = grid.cell_x(c) + d.x
				var y: int = grid.cell_y(c) + d.y
				if grid.in_grid(x, y):
					var k: int = grid.index(x, y)
					if seen[k] == 0 and grid.terrain[k] == TerrainTable.URBAN:
						seen[k] = 1
						stack.append(k)
		blocks.append(comp)
	if n == 0:
		return
	var centre: Vector2 = Vector2(cx / n, cy / n)
	var props: Dictionary = {}
	var customs: Dictionary = {}
	var church_done: bool = false
	var tower_done: bool = false
	var far_block: int = 0
	var far_d: float = 0.0
	for bi: int in range(blocks.size()):
		var b: PackedInt32Array = blocks[bi]
		var r: Rect2i = _bounds(b)
		var mid: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
		var dist: float = mid.distance_to(centre)
		if dist > far_d and b.size() >= 4:
			far_d = dist
			far_block = bi
		var world_mid: Vector3 = Vector3(mid.x * cell_m, 0.0, -mid.y * cell_m)
		world_mid.y = height_at(world_mid)
		var long_x: bool = r.size.x >= r.size.y
		var basis: Basis = Basis(Vector3.UP, 0.0 if long_x else PI * 0.5)
		var hk: int = SimRng.hash3(r.position.x, r.position.y, 91)
		if dist < 7.0:
			for pc: int in b:
				_cells_img.set_pixel(grid.cell_x(pc), grid.cell_y(pc), Color(0.0, 1.0, 1.0, 0.0))
		if dist < 7.0 and r.size.x >= 3 and r.size.y >= 3:
			_place_xf(props, customs, "panel_block", Transform3D(basis.scaled(Vector3.ONE * clampf(maxf(r.size.x, r.size.y) * cell_m / 30.0, 0.8, 1.1)), world_mid), hk)
			continue
		if dist < 7.0:
			_place_xf(props, customs, "shop", Transform3D(basis, world_mid), hk)
			continue
		if not church_done and dist < 12.0 and b.size() >= 6:
			church_done = true
			_place_xf(props, customs, "church", Transform3D(Basis(Vector3.UP, PI * 0.5 * (hk & 3)), world_mid), hk)
			continue
		_houses(b, props, customs, cell_m, hk)
	_cells_tex.update(_cells_img)
	if not tower_done and not blocks.is_empty():
		var tb: Rect2i = _bounds(blocks[far_block])
		var tp: Vector3 = Vector3((tb.position.x + 0.5) * cell_m, 0.0, -(tb.position.y + 0.5) * cell_m)
		tp.y = height_at(tp)
		_place_xf(props, customs, "water_tower", Transform3D(Basis.IDENTITY, tp), 7)
	# street lamps along village streets
	for i2: int in range(grid.cell_count()):
		if grid.terrain[i2] != TerrainTable.ROAD:
			continue
		var x2: int = grid.cell_x(i2)
		var y2: int = grid.cell_y(i2)
		if (x2 + y2 * 2) % 4 != 0 or Vector2(x2, y2).distance_to(centre) > 18.0:
			continue
		var lp: Vector3 = Vector3((x2 + 0.15) * cell_m, 0.0, -(y2 + 0.15) * cell_m)
		lp.y = height_at(lp)
		_place_xf(props, customs, "lamp", Transform3D(Basis(Vector3.UP, float(x2 % 4) * PI * 0.5), lp), i2)
	var mat: Material = ModelLibrary.material(4, 3)
	for name: String in props.keys():
		var xs: Array[Transform3D] = props[name]
		var tree: bool = name == "birch" or name == "aspen"
		var small: bool = name == "lamp" or name == "fence" or name == "shed" or name == "hedge" or name == "garden_wall"
		var mm: MultiMesh = _multimesh(ModelLibrary.mesh(name), xs, customs[name], foliage_material if tree else mat, 0.0, 900.0 if small else 3000.0, true)
		if name.begins_with("house") or name == "shed":
			_register("house", [mm], xs)
		elif tree:
			_register("tree", [mm], xs)


func _bounds(cells: PackedInt32Array) -> Rect2i:
	var x0: int = 1 << 30
	var y0: int = 1 << 30
	var x1: int = -1
	var y1: int = -1
	for c: int in cells:
		x0 = mini(x0, grid.cell_x(c))
		y0 = mini(y0, grid.cell_y(c))
		x1 = maxi(x1, grid.cell_x(c))
		y1 = maxi(y1, grid.cell_y(c))
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Houses on block cells next to a street, facing it; sheds and gardens behind,
## fences where the block meets fields.
func _houses(b: PackedInt32Array, props: Dictionary, customs: Dictionary, cell_m: float, hk: int) -> void:
	var placed: int = 0
	for c: int in b:
		var x: int = grid.cell_x(c)
		var y: int = grid.cell_y(c)
		var h: int = SimRng.hash3(x, y, 93)
		var street: Vector2i = Vector2i.ZERO
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if grid.in_grid(x + d.x, y + d.y) and grid.terrain[grid.index(x + d.x, y + d.y)] == TerrainTable.ROAD:
				street = d
				break
		var p: Vector3 = Vector3((x + 0.5) * cell_m, 0.0, -(y + 0.5) * cell_m)
		p.y = height_at(p)
		var to_street: Vector3 = Vector3(street.x, 0, -street.y)
		if street != Vector2i.ZERO and (x + y) % 2 == 0 and h % 7 != 0:
			# front (-Z of the model) faces the street, set back behind a front garden
			var yaw: float = atan2(float(street.x), float(street.y)) + (float(h & 7) - 3.5) * 0.02
			var v: int = (h >> 3) % 4
			var sc: float = (0.72 if v < 2 else 0.8) + float((h >> 6) & 7) * 0.02
			_place_xf(props, customs, "house_%d" % v, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), p - to_street * cell_m * 0.1), h)
			_front(props, customs, p, to_street, street, cell_m, h)
			placed += 1
		elif street != Vector2i.ZERO:
			_front(props, customs, p, to_street, street, cell_m, h)
			if h % 3 == 0:
				_place(props, customs, "birch" if h % 2 == 0 else "aspen", x, y, h, cell_m, 0.5)
			elif h % 4 == 1:
				_place_xf(props, customs, "shed", Transform3D(Basis(Vector3.UP, float(h & 3) * PI * 0.5), p - to_street * cell_m * 0.2), h)
		elif h % 3 == 0:
			_place(props, customs, "birch" if h % 2 == 0 else "aspen", x, y, h, cell_m, 0.55)
		elif h % 5 == 0:
			_place_xf(props, customs, "shed", Transform3D(Basis(Vector3.UP, float(h & 3) * PI * 0.5), p), h)
		elif h % 7 == 1:
			_place_xf(props, customs, "garages", Transform3D(Basis(Vector3.UP, float(h & 1) * PI * 0.5).scaled(Vector3.ONE * 0.55), p), h)
		for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d2.x
			var ny: int = y + d2.y
			if grid.in_grid(nx, ny) and grid.terrain[grid.index(nx, ny)] == TerrainTable.FIELD:
				var fp: Vector3 = Vector3((x + 0.5 + d2.x * 0.48) * cell_m, 0.0, -(y + 0.5 + d2.y * 0.48) * cell_m)
				fp.y = height_at(fp)
				_place_xf(props, customs, "fence", Transform3D(Basis(Vector3.UP, PI * 0.5 if d2.x != 0 else 0.0), fp), h + d2.x * 7)


## Front-garden boundary along the street edge of a plot: hedge, low wall or
## picket fence, with a gap for the gate.
func _front(props: Dictionary, customs: Dictionary, p: Vector3, to_street: Vector3, street: Vector2i, cell_m: float, h: int) -> void:
	var kind: int = (h >> 9) % 3
	var name: String = ["hedge", "garden_wall", "fence"][kind]
	var yaw: float = 0.0 if street.y != 0 else PI * 0.5
	var fp: Vector3 = p + to_street * cell_m * 0.44
	fp.y = height_at(fp)
	_place_xf(props, customs, name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.05, 1.0, 1.0)), fp), h)


# ------------------------------------------------------------ battle damage

var _damageable: Array[Dictionary] = []   # {kind, mms: Array[MultiMesh], xforms, alive: PackedByteArray}
var _debris: Dictionary = {}              # mesh name -> {mm: MultiMesh, xforms: Array[Transform3D]}
var _burning: int = 0


func _register(kind: String, mms: Array, xforms: Array[Transform3D]) -> void:
	var list: Array[MultiMesh] = []
	for m: Variant in mms:
		if m != null:
			list.append(m as MultiMesh)
	if list.is_empty():
		return
	var alive: PackedByteArray = PackedByteArray()
	alive.resize(xforms.size())
	alive.fill(1)
	var lo: Vector3 = Vector3.INF
	var hi: Vector3 = -Vector3.INF
	for xf: Transform3D in xforms:
		lo = lo.min(xf.origin)
		hi = hi.max(xf.origin)
	_damageable.append({"kind": kind, "mms": list, "xforms": xforms, "alive": alive, "lo": lo, "hi": hi})


## A blast of radius r at p: trees inside fall (stumps and fallen trunks stay),
## houses become ruins, a crater rim is left, and woods or fields may burn.
func damage(p: Vector3, r: float, fx: Effects) -> void:
	var r2: float = r * r
	var felled: int = 0
	var house_fire: bool = false
	for set: Dictionary in _damageable:
		var lo: Vector3 = set["lo"]
		var hi: Vector3 = set["hi"]
		if p.x < lo.x - r or p.x > hi.x + r or p.z < lo.z - r or p.z > hi.z + r:
			continue
		var xs: Array[Transform3D] = set["xforms"]
		var alive: PackedByteArray = set["alive"]
		var kind: String = set["kind"]
		for i: int in range(xs.size()):
			if alive[i] == 0:
				continue
			var o: Vector3 = xs[i].origin
			var d2: float = (o.x - p.x) * (o.x - p.x) + (o.z - p.z) * (o.z - p.z)
			if d2 > r2 * (0.6 if kind == "house" else 1.0):
				continue
			alive[i] = 0
			for mm: MultiMesh in set["mms"]:
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), o))
			if kind == "tree":
				felled += 1
				var away: float = atan2(o.x - p.x, o.z - p.z)
				_add_debris("fallen_tree" if (i % 3) != 0 else "stump", Transform3D(Basis(Vector3.UP, away + PI).scaled(Vector3.ONE * 0.8), o))
			else:
				_add_debris("house_ruin", Transform3D(xs[i].basis, o))
				if fx != null and not house_fire and _burning < 40:
					house_fire = true
					_burning += 1
					fx.burn_at(o, false)
	if r >= 5.0:
		var cp: Vector3 = Vector3(p.x, height_at(p), p.z)
		_add_debris("crater", Transform3D(Basis(Vector3.UP, fposmod(p.x * 0.37, TAU)).scaled(Vector3(r / 5.0, 1.0, r / 5.0)), cp))
	if fx != null and _burning < 40 and (felled >= 2 or (r >= 9.0 and terrain_at(p) == TerrainTable.FIELD and fposmod(p.x + p.z, 3.0) < 1.0)):
		_burning += 1
		fx.burn_at(Vector3(p.x, height_at(p), p.z), felled >= 4)


func _add_debris(name: String, xf: Transform3D) -> void:
	if not _debris.has(name):
		var mesh: Mesh = ModelLibrary.mesh(name)
		if mesh == null:
			return
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = foliage_material if name == "fallen_tree" else ModelLibrary.material(4, 3)
		add_child(mmi)
		var empty: Array[Transform3D] = []
		_debris[name] = {"mm": mm, "xforms": empty}
	var e: Dictionary = _debris[name]
	var xs: Array[Transform3D] = e["xforms"]
	xs.append(xf)
	var mm2: MultiMesh = e["mm"]
	mm2.instance_count = xs.size()
	for i: int in range(xs.size()):
		mm2.set_instance_transform(i, xs[i])
		mm2.set_instance_custom_data(i, Color(float(i % 7) / 7.0, 0.5, 0.5, 0.0))
