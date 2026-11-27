## Line-of-sight tool (Phase 1.5): hold L. Shows what the first selected unit
## would see from the cursor point (green ground fan) plus its sight and weapon
## range rings. Uses the sim's own Los.check (read-only), computed a few rays per
## frame so the game never hitches.
class_name LosTool
extends Node3D

const RAYS: int = 48
const SAMPLES: int = 22
const RAYS_PER_FRAME: int = 8
const TARGET_H_MM: int = 2000

var runner: SimRunner
var controller: SelectionController
var terrain: TerrainView

var _mesh: ImmediateMesh
var _mi: MeshInstance3D
var _origin: Vector3 = Vector3.INF
var _range_m: float = 2000.0
var _weapon_m: float = 0.0
var _vis: PackedByteArray = PackedByteArray()
var _next_ray: int = RAYS
var _eye_mm: int = 2000


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.material_override = m
	add_child(_mi)
	_vis.resize(RAYS * SAMPLES)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if runner == null or runner.world == null or not Input.is_key_pressed(KEY_L) or not controller.enabled:
		_origin = Vector3.INF
		return
	var gp: Variant = controller.cam.ground_point(controller.get_viewport().get_mouse_position())
	if gp == null:
		return
	var p: Vector3 = gp
	if _origin == Vector3.INF or Vector2(p.x - _origin.x, p.z - _origin.z).length() > 8.0:
		_begin(p)
	var w: SimWorld = runner.world
	var o: Vector2i = SimRunner.view_to_sim(_origin)
	var oz: int = w.grid.ground_at(o.x, o.y) + _eye_mm
	var done: int = 0
	while _next_ray < RAYS and done < RAYS_PER_FRAME:
		var a: float = TAU * _next_ray / RAYS
		for s: int in range(SAMPLES):
			var d: float = _range_m * (s + 1) / SAMPLES
			var bx: int = clampi(o.x + int(cos(a) * d * 1000.0), 0, w.map_width_mm() - 1)
			var by: int = clampi(o.y + int(sin(a) * d * 1000.0), 0, w.map_height_mm() - 1)
			var bz: int = w.grid.ground_at(bx, by) + TARGET_H_MM
			_vis[_next_ray * SAMPLES + s] = 1 if Los.check(w, o.x, o.y, oz, bx, by, bz) != Los.BLOCKED else 0
		_next_ray += 1
		done += 1
	_draw_fan()


func _begin(p: Vector3) -> void:
	_origin = p
	_next_ray = 0
	_vis.fill(0)
	_eye_mm = 2000
	_range_m = 2000.0
	_weapon_m = 0.0
	var w: SimWorld = runner.world
	if not controller.selection.is_empty() and w.is_unit(controller.selection[0]):
		var id: int = controller.selection[0]
		var def: UnitStats = w.def_of(id)
		_eye_mm = def.eye_height_mm
		var r: Vector2i = VisionSystem.observer_ranges(w, id)
		_range_m = clampf(maxi(r.x, r.y) * 0.001, 300.0, 3500.0)
		for wi: int in def.weapons:
			var ws: WeaponStats = w.defs.weapons[wi]
			if not ws.is_indirect():
				_weapon_m = maxf(_weapon_m, ws.range_max_mm * 0.001)


func _point(a: float, d: float) -> Vector3:
	var p: Vector3 = _origin + Vector3(cos(a) * d, 0.0, -sin(a) * d)
	p.y = terrain.height_at(p) + 0.8
	return p


func _draw_fan() -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var green: Color = Color(0.35, 0.95, 0.5, 0.28)
	for r: int in range(mini(_next_ray, RAYS)):
		var r2: int = (r + 1) % RAYS
		if r2 >= _next_ray and r2 != 0:
			continue
		var a0: float = TAU * r / RAYS
		var a1: float = TAU * (r + 1) / RAYS
		for s: int in range(SAMPLES):
			if _vis[r * SAMPLES + s] == 0 or _vis[r2 * SAMPLES + s] == 0:
				continue
			var d0: float = _range_m * s / SAMPLES
			var d1: float = _range_m * (s + 1) / SAMPLES
			var q: Array[Vector3] = [_point(a0, d0), _point(a0, d1), _point(a1, d1), _point(a1, d0)]
			for v: Vector3 in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				_mesh.surface_set_color(green)
				_mesh.surface_add_vertex(v)
	_mesh.surface_end()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_ring(_range_m, Color(0.5, 1.0, 0.6, 0.8))
	if _weapon_m > 0.0:
		_ring(_weapon_m, Color(1.0, 0.75, 0.3, 0.95))
	_mesh.surface_end()


func _ring(r: float, c: Color) -> void:
	for i: int in range(64):
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(_point(TAU * i / 64.0, r))
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(_point(TAU * (i + 1) / 64.0, r))
