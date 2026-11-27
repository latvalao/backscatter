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
	Color(0.42, 0.41, 0.37),  # urban (trampled yard)
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
	for cy: int in range(0, grid.height, CHUNK):
		for cx: int in range(0, grid.width, CHUNK):
			var cw: int = mini(CHUNK, grid.width - cx)
			var ch: int = mini(CHUNK, grid.height - cy)
			_build_chunk(cx, cy, cw, ch)
			_build_water(cx, cy, cw, ch)
			_build_foliage(cx, cy, cw, ch)
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
			if _corner_water(gx, gy):
				y -= WATER_DROP
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
						TerrainTable.ROAD, TerrainTable.URBAN:
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
				TerrainTable.URBAN:
					_place(props, customs, "house_%d" % ((h0 >> 8) & 1), gx, gy, h0, cell_m, 1.0, true)
	var lod: float = GraphicsSettings.tree_lod_distance()
	for name2: String in species.keys():
		var xs: Array[Transform3D] = species[name2]
		var cu: PackedColorArray = customs[name2]
		_multimesh(ModelLibrary.mesh(name2), xs, cu, foliage_material, 0.0, lod + 60.0, true)
		_multimesh(ModelLibrary.mesh(name2 + "_far"), xs, cu, foliage_material, lod, 0.0, false)
	for name3: String in props.keys():
		var xs2: Array[Transform3D] = props[name3]
		var cu2: PackedColorArray = customs[name3]
		var mat: Material = foliage_material if name3 == "reeds" or name3 == "tufts" else ModelLibrary.material(4, 3)
		var far_end: float = 2600.0 if name3.begins_with("house") else (450.0 if name3 == "tufts" else 900.0)
		_multimesh(ModelLibrary.mesh(name3), xs2, cu2, mat, 0.0, far_end, name3 != "tufts")


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


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], custom: PackedColorArray, mat: Material, begin: float, end: float, shadows: bool) -> void:
	if xforms.is_empty() or mesh == null:
		return
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
