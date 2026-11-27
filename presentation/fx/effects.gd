## Combat effects driven by SimEvents: tracers, impact flashes, in-flight
## projectiles and smoke clouds. Purely cosmetic.
class_name Effects
extends Node3D

const TRACER_LIFE: float = 0.18
const FLASH_LIFE: float = 0.45

var runner: SimRunner
var terrain: TerrainView

var _lines: MeshInstance3D
var _imesh: ImmediateMesh
var _tracers: Array[Dictionary] = []   # {a: Vector3, b: Vector3, t: float, c: Color}
var _flashes: Array[Dictionary] = []   # {node: MeshInstance3D, t: float, size: float}
var _smoke_nodes: Array[MeshInstance3D] = []
var _smoke_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D


func _ready() -> void:
	_imesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _imesh
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	_lines.material_override = lm
	add_child(_lines)
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.albedo_color = Color(0.78, 0.78, 0.76, 0.55)
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1.0, 0.75, 0.35, 0.9)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func tracer(a: Vector3, b: Vector3, heavy: bool) -> void:
	_tracers.append({"a": a + Vector3.UP * 1.8, "b": b + Vector3.UP * 1.0, "t": TRACER_LIFE,
		"c": Color(1.0, 0.85, 0.4) if heavy else Color(1.0, 0.95, 0.6, 0.7)})


func flash(p: Vector3, size_m: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = _flash_mat
	mi.position = p + Vector3.UP * 1.0
	mi.scale = Vector3.ONE * size_m
	add_child(mi)
	_flashes.append({"node": mi, "t": FLASH_LIFE, "size": size_m})


func _process(delta: float) -> void:
	if runner == null or runner.world == null:
		return
	_imesh.clear_surfaces()
	var w: SimWorld = runner.world
	var any: bool = not _tracers.is_empty() or w.projectiles.count() > 0
	if any:
		_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i: int in range(_tracers.size() - 1, -1, -1):
			var tr: Dictionary = _tracers[i]
			var life: float = tr["t"]
			life -= delta
			if life <= 0.0:
				_tracers.remove_at(i)
				continue
			tr["t"] = life
			var col: Color = tr["c"]
			_imesh.surface_set_color(col)
			_imesh.surface_add_vertex(tr["a"])
			_imesh.surface_set_color(col)
			_imesh.surface_add_vertex(tr["b"])
		_draw_projectiles(w)
		_imesh.surface_end()
	for i: int in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		var life: float = f["t"]
		life -= delta
		var node: MeshInstance3D = f["node"]
		if life <= 0.0:
			node.queue_free()
			_flashes.remove_at(i)
			continue
		f["t"] = life
		var size_m: float = f["size"]
		node.scale = Vector3.ONE * size_m * (1.0 + (FLASH_LIFE - life) * 1.5)
	_sync_smoke(w)


func _draw_projectiles(w: SimWorld) -> void:
	var p: ProjectileStore = w.projectiles
	var now: float = w.tick - 1 + runner.alpha()
	for i: int in range(p.count()):
		var span: float = maxf(1.0, float(p.impact_tick[i] - p.launch_tick[i]))
		var f: float = clampf((now - p.launch_tick[i]) / span, 0.0, 1.0)
		var a: Vector3 = SimRunner.sim_to_view(p.src_x[i], p.src_y[i], 0)
		var b: Vector3 = SimRunner.sim_to_view(p.aim_x[i], p.aim_y[i], 0)
		var pos: Vector3 = a.lerp(b, f)
		var wdef: WeaponStats = w.defs.weapons[p.weapon[i]]
		var arc: float = 0.0
		if wdef.is_indirect():
			arc = sin(f * PI) * a.distance_to(b) * 0.25
		pos.y = terrain.height_at(pos) + 2.0 + arc
		var tail: Vector3 = pos - (b - a).normalized() * 6.0
		_imesh.surface_set_color(Color(1.0, 0.6, 0.3))
		_imesh.surface_add_vertex(tail)
		_imesh.surface_set_color(Color(1.0, 0.9, 0.6))
		_imesh.surface_add_vertex(pos)


func _sync_smoke(w: SimWorld) -> void:
	var s: SmokeStore = w.smoke
	while _smoke_nodes.size() < s.count():
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 1.0
		sm.height = 1.2
		mi.mesh = sm
		mi.material_override = _smoke_mat
		add_child(mi)
		_smoke_nodes.append(mi)
	while _smoke_nodes.size() > s.count():
		var last: MeshInstance3D = _smoke_nodes.pop_back()
		last.queue_free()
	for i: int in range(s.count()):
		var p: Vector3 = SimRunner.sim_to_view(s.x[i], s.y[i], 0)
		p.y = terrain.height_at(p) + 4.0
		var r: float = s.radius[i] * 0.001
		var mi: MeshInstance3D = _smoke_nodes[i]
		mi.position = p
		mi.scale = Vector3(r, r * 0.6, r)
