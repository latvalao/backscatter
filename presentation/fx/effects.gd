## Combat VFX driven by SimEvents (docs/VISUALS.md §11): team-tinted tracers,
## muzzle flashes with short lights, dirt plumes and craters, in-flight shells
## with incoming markers, wind-driven smoke screens, burning wrecks with smoke
## columns. Purely cosmetic; never writes sim state.
class_name Effects
extends Node3D

const TRACER_LIFE: float = 0.16
const MAX_LIGHTS: int = 8
const MAX_WRECK_LIGHTS: int = 12
const FIRE_TIME: float = 90.0

var runner: SimRunner
var terrain: TerrainView
var local_team: int = 0

var _lines: MeshInstance3D
var _imesh: ImmediateMesh
var _tracers: Array[Dictionary] = []   # {a, b, t, c}
var _transients: Array[Dictionary] = []  # {node, t, kind, size}
var _lights: Array[OmniLight3D] = []
var _light_t: PackedFloat32Array = PackedFloat32Array()
var _smoke_nodes: Array[GPUParticles3D] = []
var _wreck_fx: Array[Dictionary] = []  # {fire, light, t}
var _soft: GradientTexture2D
var _flash_mat: StandardMaterial3D
var _smoke_screen_mat: ParticleProcessMaterial
var _column_mat: ParticleProcessMaterial
var _wind_timer: float = 0.0
var _flares: Array[Dictionary] = []  # {light, sprite, t, life, p}
var _mine_mesh: ImmediateMesh
var _mine_timer: float = 0.0
var _observed: Dictionary = {}  # projectile key -> impact point observed by the local team


func _ready() -> void:
	_imesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _imesh
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.albedo_color = Color(2.2, 2.2, 2.2)  # HDR so tracers bloom
	_lines.material_override = lm
	add_child(_lines)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_soft = GradientTexture2D.new()
	_soft.gradient = g
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(0.5, 0.0)
	_soft.width = 64
	_soft.height = 64
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mat.albedo_texture = _soft
	_flash_mat.albedo_color = Color(3.0, 1.9, 0.9)
	_flash_mat.no_depth_test = false
	for i: int in range(MAX_LIGHTS):
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.visible = false
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
		_light_t.append(0.0)
	_mine_mesh = ImmediateMesh.new()
	var mm: MeshInstance3D = MeshInstance3D.new()
	mm.mesh = _mine_mesh
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mmat: StandardMaterial3D = StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.vertex_color_use_as_albedo = true
	mm.material_override = mmat
	add_child(mm)
	_smoke_screen_mat = _smoke_process(Vector3(0, 0.25, 0), 0.6, 1.6, Color(0.82, 0.82, 0.8))
	_column_mat = _smoke_process(Vector3(0, 1.6, 0), 0.4, 1.2, Color(0.2, 0.19, 0.18))


func _smoke_process(gravity: Vector3, vel: float, grow: float, col: Color) -> ParticleProcessMaterial:
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.gravity = gravity
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = vel * 0.5
	pm.initial_velocity_max = vel
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, grow))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.15, Color(col.r, col.g, col.b, 0.75))
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	return pm


func _sprite_mesh(size: float, lit: bool, additive: bool = false) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	q.material = m
	return q


func _particles(amount: int, life: float, pm: ParticleProcessMaterial, mesh: Mesh, one_shot: bool) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 120, 80))
	p.emitting = true
	return p


func tracer(a: Vector3, b: Vector3, heavy: bool, team_col: Color = Color.WHITE) -> void:
	var c: Color = Color(1.0, 0.82, 0.45).lerp(team_col, 0.35)
	c.a = 1.0 if heavy else 0.75
	_tracers.append({"a": a, "b": b, "t": TRACER_LIFE * (1.4 if heavy else 1.0), "c": c})


func _light(p: Vector3, energy: float, rng: float, life: float, col: Color) -> void:
	var best: int = 0
	for i: int in range(MAX_LIGHTS):
		if _light_t[i] < _light_t[best]:
			best = i
	var l: OmniLight3D = _lights[best]
	l.position = p
	l.light_energy = energy
	l.omni_range = rng
	l.light_color = col
	l.visible = true
	_light_t[best] = life


func muzzle_flash(p: Vector3, big: bool) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE * (4.0 if big else 1.6)
	mi.mesh = q
	mi.material_override = _flash_mat
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_transients.append({"node": mi, "t": 0.09 if not big else 0.14, "kind": "flash", "size": 1.0})
	_light(p, 6.0 if big else 2.5, 18.0 if big else 8.0, 0.08, Color(1.0, 0.72, 0.4))
	if big:
		_dust(p - Vector3(0, 1.5, 0), 2.0, Color(0.55, 0.5, 0.42), 10)


## Shell / rocket impact: flash, dirt plume, lingering dust; craters for artillery.
func explosion(p: Vector3, size_m: float, crater: bool) -> void:
	muzzle_flash(p + Vector3.UP * size_m * 0.3, size_m > 2.5)
	_light(p + Vector3.UP * 2.0, 8.0 * size_m * 0.4, size_m * 6.0, 0.2, Color(1.0, 0.6, 0.3))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 6.0 * sqrt(size_m)
	pm.initial_velocity_max = 13.0 * sqrt(size_m)
	pm.gravity = Vector3(0, -14, 0)
	pm.color = Color(0.22, 0.18, 0.13)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var dirt: GPUParticles3D = _particles(int(clampf(size_m * 10.0, 8, 48)), 1.4, pm, _sprite_mesh(0.9 * sqrt(size_m), true), true)
	dirt.position = p
	add_child(dirt)
	_transients.append({"node": dirt, "t": 2.0, "kind": "free", "size": 0.0})
	_dust(p, size_m, Color(0.5, 0.46, 0.4), int(clampf(size_m * 4.0, 4, 20)))
	if crater and terrain != null and size_m >= 1.5:
		terrain.stamp_crater(p, size_m * 0.9, 0.45)


func _dust(p: Vector3, size_m: float, col: Color, n: int) -> void:
	var pm: ParticleProcessMaterial = _smoke_process(Vector3(0, 0.4, 0), 2.0 * sqrt(size_m), 2.4, col)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size_m * 0.6
	var d: GPUParticles3D = _particles(n, 4.5, pm, _sprite_mesh(2.2 * sqrt(size_m), true), true)
	d.position = p + Vector3.UP
	add_child(d)
	_transients.append({"node": d, "t": 5.0, "kind": "free", "size": 0.0})


## Parachute illumination flare: a bright light drifting down for `life_s`.
func flare(p: Vector3, life_s: float) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(1.0, 0.93, 0.8)
	l.light_energy = 6.0
	l.omni_range = 420.0
	l.omni_attenuation = 0.6
	l.shadow_enabled = _flares.size() < 2
	add_child(l)
	var s: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(6, 6)
	s.mesh = q
	s.material_override = _flash_mat
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	_flares.append({"light": l, "sprite": s, "t": life_s, "life": life_s, "p": p})


## Burning wreck: fire + light for FIRE_TIME seconds, then a thin smoke column forever.
func attach_wreck_fire(v: Node3D, large: bool) -> void:
	var fire_pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	fire_pm.direction = Vector3(0, 1, 0)
	fire_pm.spread = 15.0
	fire_pm.initial_velocity_min = 1.5
	fire_pm.initial_velocity_max = 3.0
	fire_pm.gravity = Vector3(0, 1.0, 0)
	fire_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_pm.emission_sphere_radius = 1.0
	var fg: Gradient = Gradient.new()
	fg.set_color(0, Color(3.0, 1.6, 0.5, 0.9))
	fg.set_color(1, Color(0.6, 0.15, 0.05, 0.0))
	var fgt: GradientTexture1D = GradientTexture1D.new()
	fgt.gradient = fg
	fire_pm.color_ramp = fgt
	var fire: GPUParticles3D = _particles(24, 0.8, fire_pm, _sprite_mesh(1.6, false, true), false)
	fire.position = Vector3(0, 2.0, 0)
	v.add_child(fire)
	var smoke: GPUParticles3D = _particles(28 if large else 18, 9.0, _column_mat, _sprite_mesh(3.5, true), false)
	smoke.position = Vector3(0, 2.5, 0)
	v.add_child(smoke)
	var light: OmniLight3D = null
	var lit: int = 0
	for w: Dictionary in _wreck_fx:
		if w["light"] != null:
			lit += 1
	if lit < MAX_WRECK_LIGHTS:
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = 3.0
		light.omni_range = 16.0
		light.position = Vector3(0, 3.0, 0)
		v.add_child(light)
	_wreck_fx.append({"fire": fire, "light": light, "t": FIRE_TIME})


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
			var a: Vector3 = tr["a"]
			var b: Vector3 = tr["b"]
			# a short bright bolt travelling from muzzle to target
			var f: float = 1.0 - life / TRACER_LIFE
			var head: Vector3 = a.lerp(b, clampf(f * 1.2, 0.0, 1.0))
			var tail: Vector3 = a.lerp(b, clampf(f * 1.2 - 0.35, 0.0, 1.0))
			var col: Color = tr["c"]
			_imesh.surface_set_color(Color(col.r, col.g, col.b, 0.0))
			_imesh.surface_add_vertex(tail)
			_imesh.surface_set_color(col)
			_imesh.surface_add_vertex(head)
		_draw_projectiles(w)
		_imesh.surface_end()
	for i2: int in range(_transients.size() - 1, -1, -1):
		var tr2: Dictionary = _transients[i2]
		var t: float = tr2["t"]
		t -= delta
		tr2["t"] = t
		var node: Node3D = tr2["node"]
		if t <= 0.0:
			node.queue_free()
			_transients.remove_at(i2)
		elif tr2["kind"] == "flash":
			node.scale = Vector3.ONE * (1.0 + (0.14 - t) * 6.0)
	for k: int in range(MAX_LIGHTS):
		if _light_t[k] > 0.0:
			_light_t[k] -= delta
			if _light_t[k] <= 0.0:
				_lights[k].visible = false
	for j: int in range(_wreck_fx.size() - 1, -1, -1):
		var wf: Dictionary = _wreck_fx[j]
		var fire: GPUParticles3D = wf["fire"]
		if not is_instance_valid(fire):
			_wreck_fx.remove_at(j)
			continue
		var ft: float = wf["t"]
		ft -= delta
		wf["t"] = ft
		var lt: OmniLight3D = wf["light"]
		if ft <= 0.0:
			fire.emitting = false
			if lt != null:
				lt.queue_free()
			_wreck_fx.remove_at(j)
		elif lt != null:
			lt.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.023 + j) * 0.6 + randf() * 0.4
	for fi: int in range(_flares.size() - 1, -1, -1):
		var fl: Dictionary = _flares[fi]
		var left: float = float(fl["t"]) - delta
		fl["t"] = left
		var lnode: OmniLight3D = fl["light"]
		var snode: MeshInstance3D = fl["sprite"]
		if left <= 0.0:
			lnode.queue_free()
			snode.queue_free()
			_flares.remove_at(fi)
			continue
		var k: float = 1.0 - left / float(fl["life"])
		var fp: Vector3 = fl["p"]
		fp += Vector3(LookDirector.wind.x * k * 20.0, 0.0, LookDirector.wind.y * k * 20.0)
		fp.y = (terrain.height_at(fp) if terrain != null else 0.0) + lerpf(260.0, 40.0, k)
		lnode.position = fp
		snode.position = fp
		lnode.light_energy = 6.0 * clampf(left / 4.0, 0.0, 1.0) * (0.92 + randf() * 0.08)
	_mine_timer -= delta
	if _mine_timer <= 0.0:
		_mine_timer = 0.5
		_draw_mines(w)
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_wind_timer = 1.0
		var wind: Vector2 = LookDirector.wind
		_column_mat.gravity = Vector3(wind.x * 0.35, 1.6, wind.y * 0.35)
		_smoke_screen_mat.gravity = Vector3(wind.x * 0.2, 0.25, wind.y * 0.2)
	_sync_smoke(w)


## Known minefields: own mines amber, discovered enemy mines red.
func _draw_mines(w: SimWorld) -> void:
	_mine_mesh.clear_surfaces()
	var m: MineStore = w.mines
	if m.count() == 0 or terrain == null:
		return
	var shown: PackedInt32Array = PackedInt32Array()
	for k: int in range(m.count()):
		if m.is_known(k, local_team):
			shown.append(k)
	if shown.is_empty():
		return
	_mine_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i: int in shown:
		var c: Color = Color(0.95, 0.75, 0.3) if m.team[i] == local_team else Color(1.0, 0.3, 0.25)
		var p: Vector3 = SimRunner.sim_to_view(m.x[i], m.y[i], 0)
		p.y = terrain.height_at(p) + 0.4
		for d: Vector3 in [Vector3(1.6, 0, 1.6), Vector3(1.6, 0, -1.6)]:
			_mine_mesh.surface_set_color(c)
			_mine_mesh.surface_add_vertex(p - d)
			_mine_mesh.surface_set_color(c)
			_mine_mesh.surface_add_vertex(p + d)
	_mine_mesh.surface_end()


func _draw_projectiles(w: SimWorld) -> void:
	var p: ProjectileStore = w.projectiles
	if p.count() == 0:
		_observed.clear()
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
		var dir: Vector3 = (b - a).normalized()
		if wdef.is_indirect():
			var nf: float = clampf(f + 0.01, 0.0, 1.0)
			var nxt: Vector3 = a.lerp(b, nf)
			nxt.y = terrain.height_at(nxt) + 2.0 + sin(nf * PI) * a.distance_to(b) * 0.25
			dir = (nxt - pos).normalized()
		var tail: Vector3 = pos - dir * 8.0
		_imesh.surface_set_color(Color(1.0, 0.6, 0.3, 0.0))
		_imesh.surface_add_vertex(tail)
		_imesh.surface_set_color(Color(1.0, 0.9, 0.6))
		_imesh.surface_add_vertex(pos)
		# incoming marker on the ground for the last ~3 s of indirect fire the
		# local team can see the impact point of
		var left: float = (p.impact_tick[i] - now) * SimConst.TICK_MS * 0.001
		if wdef.is_indirect() and left < 3.0 and terrain != null:
			var key: int = p.launch_tick[i] * 7919 + p.aim_x[i] * 31 + p.aim_y[i]
			if not _observed.has(key):
				_observed[key] = FireMissionCommand.is_observed(w, local_team, p.aim_x[i], p.aim_y[i])
			if _observed[key]:
				_marker(b, maxf(6.0, wdef.blast_radius_mm * 0.001), left)


func _marker(c: Vector3, r: float, left: float) -> void:
	var col: Color = Color(0.95, 0.32, 0.2, clampf(1.0 - left / 3.0, 0.2, 1.0))
	var n: int = 20
	for k: int in range(n):
		var a0: float = TAU * k / n
		var a1: float = TAU * (k + 1) / n
		var p0: Vector3 = c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1: Vector3 = c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		p0.y = terrain.height_at(p0) + 0.4
		p1.y = terrain.height_at(p1) + 0.4
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(p0)
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(p1)


func _sync_smoke(w: SimWorld) -> void:
	var s: SmokeStore = w.smoke
	while _smoke_nodes.size() < s.count():
		var pm: ParticleProcessMaterial = _smoke_screen_mat.duplicate() as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		var gp: GPUParticles3D = _particles(36, 7.0, pm, _sprite_mesh(9.0, true), false)
		add_child(gp)
		_smoke_nodes.append(gp)
	while _smoke_nodes.size() > s.count():
		var last: GPUParticles3D = _smoke_nodes.pop_back()
		last.emitting = false
		_transients.append({"node": last, "t": 7.0, "kind": "free", "size": 0.0})
	for i: int in range(s.count()):
		var p: Vector3 = SimRunner.sim_to_view(s.x[i], s.y[i], 0)
		p.y = terrain.height_at(p) + 2.0
		var r: float = s.radius[i] * 0.001
		var gp2: GPUParticles3D = _smoke_nodes[i]
		gp2.position = p
		var pm2: ParticleProcessMaterial = gp2.process_material as ParticleProcessMaterial
		pm2.emission_sphere_radius = r * 0.7
