## Where are my units going? (Phase 8) Ground ribbons from every selected unit
## along its path to the current goal and on through its queued orders, coloured
## by order type, with end markers, final-facing arrows, attack lines to the
## target and a pulse where each new order lands. Reads sim state only.
class_name OrderLines
extends Node3D

## Grease pencil on acetate: blue for movement, red for anything offensive,
## green for embarking / unloading, amber for engineer work.
const COLORS: Dictionary = {
	OrderStore.MOVE: Color(0.3, 0.55, 1.0, 0.92),
	OrderStore.ATTACK_MOVE: Color(0.95, 0.27, 0.2, 0.92),
	OrderStore.ATTACK: Color(0.95, 0.27, 0.2, 0.95),
	OrderStore.FIRE_MISSION: Color(0.95, 0.27, 0.2, 0.95),
	OrderStore.RETREAT: Color(0.75, 0.75, 0.7, 0.8),
	OrderStore.BUILD: Color(0.88, 0.71, 0.29, 0.9),
	OrderStore.MOUNT: Color(0.4, 0.85, 0.45, 0.92),
}
const REVERSE_COLOR: Color = Color(0.3, 0.55, 1.0, 0.75)
const UNLOAD_COLOR: Color = Color(0.4, 0.85, 0.45, 0.92)
const PING_S: float = 0.7
const MAX_UNITS: int = 60

var runner: SimRunner
var views: ViewSync
var terrain: TerrainView
var cam: RtsCamera

var _mesh: ImmediateMesh
var _pings: Array[Dictionary] = []
var _w: float = 2.0
var _tris: int = 0
var _director: ScenarioDirector


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	m.disable_fog = true
	mi.material_override = m
	add_child(mi)


## A new order was given at p (ground point): show a short pulse there.
func ping(p: Vector3, c: Color) -> void:
	_pings.append({"p": p, "c": c, "t": PING_S})


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	if runner == null or runner.world == null:
		return
	_w = clampf(cam.distance * 0.0045, 0.8, 7.0)
	_tris = 0
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: SimWorld = runner.world
	var n: int = 0
	for id: int in views.selected.keys():
		if n >= MAX_UNITS or not w.is_unit(id) or w.is_structure(id) or w.units.carrier[id] != 0:
			continue
		n += 1
		_unit(w, id)
	_objectives(w)
	for i: int in range(_pings.size() - 1, -1, -1):
		var pg: Dictionary = _pings[i]
		pg["t"] = float(pg["t"]) - delta
		if float(pg["t"]) <= 0.0:
			_pings.remove_at(i)
			continue
		var k: float = 1.0 - float(pg["t"]) / PING_S
		var c: Color = pg["c"]
		c.a = 1.0 - k
		_ring(pg["p"] as Vector3, 3.0 + k * 14.0 * (_w / 2.0), c, _w * 0.6)
	if _tris == 0:
		# an empty surface is an error: draw one invisible triangle
		_v(Vector3.ZERO, Color(0, 0, 0, 0))
		_v(Vector3.ZERO, Color(0, 0, 0, 0))
		_v(Vector3.ZERO, Color(0, 0, 0, 0))
	_mesh.surface_end()


## Mission objective markers: a pulsing amber ring with a diamond inside.
func _objectives(w: SimWorld) -> void:
	if _director == null:
		for c: AiController in w.ai:
			if c is ScenarioDirector:
				_director = c as ScenarioDirector
		if _director == null:
			return
	var mk: PackedInt64Array = _director.markers
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	var col: Color = Color(UiStyle.AMBER.r, UiStyle.AMBER.g, UiStyle.AMBER.b, 0.55 + 0.35 * pulse)
	for i: int in range(0, mk.size() - 1, 2):
		var p: Vector3 = SimRunner.sim_to_view(mk[i], mk[i + 1], 0)
		_ring(p, 40.0 + 6.0 * pulse, col, _w * 1.2)
		_marker(p, col, false)


func _unit(w: SimWorld, id: int) -> void:
	var o: OrderStore = w.orders
	var kind: int = o.kind[id]
	if kind == OrderStore.NONE and o.queue_len(id) == 0:
		return
	var start: Vector3 = runner.interpolated_position(id)
	var cur: Vector3 = start
	var col: Color = _color(kind, o.flags[id])
	if kind == OrderStore.ATTACK and w.is_unit(o.target[id]):
		var tp: Vector3 = runner.interpolated_position(o.target[id])
		_segment(cur, tp, col)
		_ring(tp, 6.0, col, _w * 0.5)
		return
	if kind == OrderStore.MOUNT and w.is_unit(o.target[id]):
		_segment(cur, runner.interpolated_position(o.target[id]), col)
		return
	if kind != OrderStore.NONE:
		var goal: Vector3 = SimRunner.sim_to_view(o.goal_x[id], o.goal_y[id], 0)
		if kind == OrderStore.FIRE_MISSION:
			_dashed(cur, goal, col)
			_ring(goal, 30.0, col, _w * 0.6)
			return
		if w.def_of(id).is_air:
			_segment(cur, goal, col)
		else:
			if o.has_path(id):
				var path: PackedInt32Array = o.get_path(id)
				for pi: int in range(o.path_pos[id], path.size() - 1):
					var c2: int = path[pi]
					var p: Vector3 = SimRunner.sim_to_view(w.grid.center_x(c2), w.grid.center_y(c2), 0)
					_segment(cur, p, col)
					cur = p
			_segment(cur, goal, col)
		_head(cur, goal, col)
		cur = goal
		if (o.flags[id] & OrderStore.FLAG_UNLOAD) != 0:
			_marker(goal, col, true)
		if o.queue_len(id) == 0 and w.mobility.face[id] >= 0:
			_arrow(goal, w.mobility.face[id], col)
	var q: PackedInt64Array = o.queue.get(id, PackedInt64Array())
	for i: int in range(0, q.size() - 3, 4):
		var qc: Color = _color(int(q[i]), int(q[i + 1]))
		qc.a *= 0.7
		var qp: Vector3 = SimRunner.sim_to_view(q[i + 2], q[i + 3], 0)
		_dashed(cur, qp, qc)
		_head(cur, qp, qc)
		if (int(q[i + 1]) & OrderStore.FLAG_UNLOAD) != 0:
			_marker(qp, qc, true)
		cur = qp


func _color(kind: int, flags: int) -> Color:
	if (flags & OrderStore.FLAG_UNLOAD) != 0:
		return UNLOAD_COLOR
	if (flags & OrderStore.FLAG_REVERSE) != 0:
		return REVERSE_COLOR
	return COLORS.get(kind, Color(0.8, 0.8, 0.8, 0.7))


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height_at(p) + 0.7, p.z)


func _v(p: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(p)


func _quad(a: Vector3, b: Vector3, c: Color, width: float) -> void:
	var d: Vector3 = b - a
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	var n: Vector3 = Vector3(-d.z, 0.0, d.x).normalized()
	# hand-drawn stroke: slight wander and pressure changes along the line
	var wa: float = width * (0.85 + 0.3 * sin(a.x * 0.11 + a.z * 0.07))
	var wb: float = width * (0.85 + 0.3 * sin(b.x * 0.11 + b.z * 0.07))
	var oa: Vector3 = n * (sin(a.x * 0.045 - a.z * 0.06) * width * 0.35)
	var ob: Vector3 = n * (sin(b.x * 0.045 - b.z * 0.06) * width * 0.35)
	var a1: Vector3 = _ground(a) + oa
	var b1: Vector3 = _ground(b) + ob
	var sa: Vector3 = n * wa * 0.5
	var sb: Vector3 = n * wb * 0.5
	_v(a1 - sa, c)
	_v(a1 + sa, c)
	_v(b1 + sb, c)
	_v(a1 - sa, c)
	_v(b1 + sb, c)
	_v(b1 - sb, c)
	_tris += 2


func _quad_flat(a: Vector3, b: Vector3, c: Color, width: float) -> void:
	var d: Vector3 = b - a
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	var side: Vector3 = Vector3(-d.z, 0.0, d.x).normalized() * width * 0.5
	var a1: Vector3 = _ground(a)
	var b1: Vector3 = _ground(b)
	_v(a1 - side, c)
	_v(a1 + side, c)
	_v(b1 + side, c)
	_v(a1 - side, c)
	_v(b1 + side, c)
	_v(b1 - side, c)
	_tris += 2


## Ribbon from a to b, split so it follows the ground.
func _segment(a: Vector3, b: Vector3, c: Color) -> void:
	var len: float = Vector2(b.x - a.x, b.z - a.z).length()
	var steps: int = clampi(int(len / 24.0) + 1, 1, 60)
	for s: int in range(steps):
		_quad(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), c, _w)


func _dashed(a: Vector3, b: Vector3, c: Color) -> void:
	var len: float = Vector2(b.x - a.x, b.z - a.z).length()
	var dash: float = maxf(6.0, _w * 4.0)
	var steps: int = clampi(int(len / dash), 1, 120)
	for s: int in range(0, steps, 2):
		_quad(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), c, _w * 0.8)


func _ring(p: Vector3, r: float, c: Color, width: float) -> void:
	for i: int in range(24):
		var a0: float = TAU * i / 24.0
		var a1: float = TAU * (i + 1) / 24.0
		_quad(p + Vector3(cos(a0) * r, 0, sin(a0) * r), p + Vector3(cos(a1) * r, 0, sin(a1) * r), c, width)


## End-of-order marker: a diamond (a square for unload points).
func _marker(p: Vector3, c: Color, square: bool) -> void:
	var r: float = maxf(3.0, _w * 2.2)
	var pts: Array[Vector3] = []
	for i: int in range(4):
		var a: float = TAU * i / 4.0 + (PI / 4.0 if square else 0.0)
		pts.append(p + Vector3(cos(a) * r, 0, sin(a) * r))
	for i2: int in range(4):
		_quad(pts[i2], pts[(i2 + 1) % 4], c, _w * 0.7)


## Grease-pencil arrowhead at the end of a leg (direction from `from`).
func _head(from: Vector3, to: Vector3, c: Color) -> void:
	var d: Vector3 = to - from
	d.y = 0.0
	if d.length() < 1.0:
		return
	d = d.normalized()
	var sz: float = maxf(5.0, _w * 3.2)
	var side: Vector3 = Vector3(-d.z, 0, d.x)
	_quad(to, to - d * sz + side * sz * 0.6, c, _w)
	_quad(to, to - d * sz - side * sz * 0.6, c, _w)


## Final facing set with a right-drag.
func _arrow(p: Vector3, angle: int, c: Color) -> void:
	var yaw: float = SimRunner.heading_to_yaw(angle)
	var dir: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var tip: Vector3 = p + dir * maxf(10.0, _w * 6.0)
	_quad(p, tip, c, _w * 0.7)
	var back: Vector3 = tip - dir * maxf(4.0, _w * 2.5)
	var side: Vector3 = Vector3(-dir.z, 0, dir.x) * maxf(3.0, _w * 2.0)
	_quad(tip, back + side, c, _w * 0.7)
	_quad(tip, back - side, c, _w * 0.7)
