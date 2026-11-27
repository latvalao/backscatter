## Signal overlay (§5.5/§8): own emitters' detectability rings, enemy DF bearing
## lines and fix ellipses (circles) from the local team's signals intelligence.
class_name SignalOverlay
extends Node3D

var runner: SimRunner
var terrain: TerrainView
var local_team: int = 0
var enabled: bool = false

var _mesh: ImmediateMesh
var _mi: MeshInstance3D
var _timer: float = 0.0


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_mi.material_override = m
	add_child(_mi)


func toggle() -> void:
	enabled = not enabled
	if not enabled:
		_mesh.clear_surfaces()


func _process(delta: float) -> void:
	if not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	_mesh.clear_surfaces()
	var w: SimWorld = runner.world
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var any: bool = false
	# own emissions: how far enemy DF (quality 1) could hear each emitter
	for id: int in w.team_units[local_team]:
		var s: int = SignalSystem.emission(w, id)
		if s <= 0:
			continue
		var c: Color = Color(0.3, 0.9, 1.0, 0.5)
		if w.def_of(id).emitter_kind == UnitStats.EMIT_JAMMER:
			c = Color(1.0, 0.4, 1.0, 0.7)
		_circle(w.transform.x[id], w.transform.y[id], s * SignalSystem.RANGE_PER_STRENGTH_MM, c)
		any = true
	# enemy bearings and fixes
	var intel: SignalIntel = w.signals[local_team]
	for i: int in range(intel.b_emitter.size()):
		var a: Vector3 = _p(intel.b_src_x[i], intel.b_src_y[i])
		var ang: int = intel.b_angle[i]
		var len_mm: int = 3_000_000
		var bx: int = int(intel.b_src_x[i]) + len_mm * FixedMath.cos_b(ang) / FixedMath.ONE
		var by: int = int(intel.b_src_y[i]) + len_mm * FixedMath.sin_b(ang) / FixedMath.ONE
		_line(a, _p(bx, by), Color(1.0, 0.85, 0.3, 0.35))
		any = true
	for em: int in intel.fixes():
		var r: int = intel.fix_r[em]
		var col: Color = Color(1.0, 0.25, 0.2) if r <= FireMissionCommand.MAX_FIX_RADIUS_MM else Color(1.0, 0.6, 0.3, 0.6)
		_circle(intel.fix_x[em], intel.fix_y[em], r, col)
		any = true
	if not any:
		_line(Vector3.ZERO, Vector3(0.01, 0, 0), Color(0, 0, 0, 0))
	_mesh.surface_end()


func _p(x: int, y: int) -> Vector3:
	var v: Vector3 = SimRunner.sim_to_view(x, y, 0)
	v.y = terrain.height_at(v) + 3.0
	return v


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)


func _circle(x: int, y: int, r: int, c: Color) -> void:
	var n: int = 32
	for k: int in range(n):
		var a0: float = TAU * k / n
		var a1: float = TAU * (k + 1) / n
		_line(_p(x + int(r * cos(a0)), y + int(r * sin(a0))), _p(x + int(r * cos(a1)), y + int(r * sin(a1))), c)
