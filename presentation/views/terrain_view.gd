## Custom terrain mesh built from the SimGrid (chunked ArrayMesh with vertex
## colours per terrain type), plus MultiMesh trees and houses. The terrain shader
## darkens areas outside the local team's vision (fog of war).
class_name TerrainView
extends Node3D

const CHUNK: int = 50
const COLORS: Array[Color] = [
	Color(0.22, 0.22, 0.21),  # road
	Color(0.40, 0.44, 0.25),  # field
	Color(0.17, 0.24, 0.14),  # forest floor
	Color(0.36, 0.33, 0.20),  # bog
	Color(0.12, 0.20, 0.27),  # water
	Color(0.36, 0.34, 0.31),  # urban
	Color(0.50, 0.49, 0.47),  # rock
]

const SHADER_CODE: String = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size_m = vec2(4000.0, 4000.0);
uniform float fog_enabled = 1.0;
uniform sampler2D rad_tex : filter_linear, repeat_disable;
uniform float rad_enabled = 0.0;
uniform float rad_bands = 0.0;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = vec2(world_pos.x / map_size_m.x, -world_pos.z / map_size_m.y);
	float seen = texture(fog_tex, uv).r;
	float f = mix(1.0, mix(0.35, 1.0, seen), fog_enabled);
	vec3 col = COLOR.rgb * f;
	if (rad_enabled > 0.5) {
		float r = texture(rad_tex, uv).r;          // 0..1 = log10(µSv/h) / 7.5
		if (rad_bands > 0.5) { r = floor(r * 5.0) / 5.0; }
		float a = smoothstep(0.25, 0.45, r);
		vec3 heat = mix(vec3(0.95, 0.9, 0.2), vec3(0.95, 0.35, 0.1), smoothstep(0.45, 0.7, r));
		heat = mix(heat, vec3(0.85, 0.1, 0.6), smoothstep(0.75, 0.95, r));
		col = mix(col, heat, a * 0.65);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

var grid: SimGrid
var material: ShaderMaterial


func build(p_grid: SimGrid) -> void:
	grid = p_grid
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("map_size_m", Vector2(grid.width_mm() * 0.001, grid.height_mm() * 0.001))
	for cy: int in range(0, grid.height, CHUNK):
		for cx: int in range(0, grid.width, CHUNK):
			_build_chunk(cx, cy, mini(CHUNK, grid.width - cx), mini(CHUNK, grid.height - cy))
	_build_props()


func set_fog_texture(tex: Texture2D) -> void:
	material.set_shader_parameter("fog_tex", tex)


func set_rad_texture(tex: Texture2D) -> void:
	material.set_shader_parameter("rad_tex", tex)


func set_rad_enabled(on: bool, banded: bool) -> void:
	material.set_shader_parameter("rad_enabled", 1.0 if on else 0.0)
	material.set_shader_parameter("rad_bands", 1.0 if banded else 0.0)


func set_fog_enabled(on: bool) -> void:
	material.set_shader_parameter("fog_enabled", 1.0 if on else 0.0)


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


func _build_chunk(cx0: int, cy0: int, cw: int, ch: int) -> void:
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var vw: int = cw + 1
	for vy: int in range(ch + 1):
		for vx: int in range(cw + 1):
			var gx: int = cx0 + vx
			var gy: int = cy0 + vy
			verts.append(Vector3(gx * cell_m, corner_height(gx, gy), -gy * cell_m))
			var hl: float = corner_height(gx - 1, gy)
			var hr: float = corner_height(gx + 1, gy)
			var hd: float = corner_height(gx, gy - 1)
			var hu: float = corner_height(gx, gy + 1)
			normals.append(Vector3(hl - hr, 2.0 * cell_m, hu - hd).normalized())
			var t: int = grid.terrain[grid.index(mini(gx, grid.width - 1), mini(gy, grid.height - 1))]
			var shade: float = 0.94 + 0.06 * float((gx * 7 + gy * 13) % 5) / 4.0
			colors.append(COLORS[t] * shade)
	for y: int in range(ch):
		for x: int in range(cw):
			var i: int = y * vw + x
			# CCW seen from above (y up, -z north)
			indices.append_array(PackedInt32Array([i, i + vw, i + 1, i + 1, i + vw, i + vw + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)


func _build_props() -> void:
	var cell_m: float = SimGrid.CELL_MM * 0.001
	var trees: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	for i: int in range(grid.cell_count()):
		var t: int = grid.terrain[i]
		if t != TerrainTable.FOREST and t != TerrainTable.URBAN:
			continue
		var cx: int = grid.cell_x(i)
		var cy: int = grid.cell_y(i)
		var hsh: int = SimRng.hash3(cx, cy, 77)
		var jx: float = float(hsh & 0xFF) / 255.0 - 0.5
		var jy: float = float((hsh >> 8) & 0xFF) / 255.0 - 0.5
		var p: Vector3 = Vector3((cx + 0.5 + jx * 0.6) * cell_m, 0.0, -(cy + 0.5 + jy * 0.6) * cell_m)
		p.y = height_at(p)
		var basis: Basis = Basis(Vector3.UP, float((hsh >> 16) & 0xFF) / 255.0 * TAU)
		if t == TerrainTable.FOREST:
			var s: float = 0.8 + float((hsh >> 24) & 0x7F) / 127.0 * 0.5
			trees.append(Transform3D(basis.scaled(Vector3(s, s, s)), p))
		else:
			houses.append(Transform3D(basis, p))
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 3.0
	cone.height = 14.0
	cone.radial_segments = 6
	cone.rings = 1
	_multimesh(cone, trees, Color(0.13, 0.22, 0.14), Vector3(0, 7.0, 0))
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(7.0, 5.0, 6.0)
	_multimesh(box, houses, Color(0.52, 0.48, 0.44), Vector3(0, 2.5, 0))


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], color: Color, offset: Vector3) -> void:
	if xforms.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		var xf: Transform3D = xforms[i]
		xf.origin += offset
		mm.set_instance_transform(i, xf)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)
