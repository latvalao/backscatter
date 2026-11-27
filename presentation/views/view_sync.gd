## Spawns/despawns UnitViews from sim events, moves them each frame, applies fog
## of war for the local team (visible / ghost at last known position / hidden)
## and turns combat events into effects. Destroyed vehicles stay as wrecks;
## vehicles leave tracks in the terrain trail map. Read-only w.r.t. the sim.
class_name ViewSync
extends Node3D

const MAX_WRECKS: int = 160

var runner: SimRunner
var effects: Effects
var local_team: int = 0
## Debug: show everything regardless of fog.
var reveal_all: bool = false
var selected: Dictionary = {}  # id -> true (set by SelectionController)
var show_labels: bool = false
## Ground point under the screen centre (camera focus) for the canopy fade.
var focus_point: Vector3 = Vector3.INF

var _views: Dictionary = {}   # entity id -> UnitView
var _ghosts: Dictionary = {}  # entity id -> UnitView
var _wrecks: Array[UnitView] = []
var _track_from: Dictionary = {}  # id -> Vector3


func _process(delta: float) -> void:
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	for e: SimEvent in w.drain_events():
		_on_event(w, e)
	var layer: TeamVision = w.vision[local_team]
	var terrain: TerrainView = effects.terrain if is_instance_valid(effects) else null
	for id: int in _views.keys():
		var v: UnitView = _views[id]
		var own: bool = v.team == local_team
		var vis: bool = reveal_all or own or layer.is_visible(id, w.tick)
		v.visible = vis
		if vis:
			v.position = runner.interpolated_position(id)
			if not v.def.is_air and terrain != null:
				v.position.y = maxf(v.position.y, terrain.height_at(v.position))
			v.rotation.y = runner.interpolated_yaw(id)
			v.set_selected(selected.has(id))
			v.refresh(w, show_labels or selected.has(id), terrain, delta)
		if terrain != null and not v.def.is_infantry and not v.def.is_structure and not v.def.is_air:
			_tracks(id, v, terrain)
		_update_ghost(w, id, v, vis, own, layer)
	if terrain != null:
		_canopy_fade(terrain)


## Tracks / ruts into the trail map (only for ground vehicles that moved).
func _tracks(id: int, v: UnitView, terrain: TerrainView) -> void:
	var p: Vector3 = v.position
	var from: Vector3 = _track_from.get(id, p)
	if from.distance_squared_to(p) < 9.0:
		if not _track_from.has(id):
			_track_from[id] = p
		return
	_track_from[id] = p
	var t: int = terrain.terrain_at(p)
	var s: float = [0.04, 0.22, 0.14, 0.45, 0.0, 0.08, 0.0][t]
	if GraphicsSettings.season == "winter":
		s = maxf(s, 0.35)
	if s <= 0.0:
		return
	var side: Vector3 = (p - from).normalized().cross(Vector3.UP) * (v.def.radius_mm * 0.00045)
	terrain.stamp_track(from + side, p + side, 1.0, s)
	terrain.stamp_track(from - side, p - side, 1.0, s)


## Canopy dither-fade around selected units and the camera focus (§7).
func _canopy_fade(terrain: TerrainView) -> void:
	var pts: PackedVector4Array = PackedVector4Array()
	if focus_point != Vector3.INF:
		pts.append(Vector4(focus_point.x, focus_point.y, focus_point.z, 30.0))
	for id: int in selected.keys():
		if pts.size() >= 8:
			break
		var v: UnitView = _views.get(id, null)
		if v != null:
			pts.append(Vector4(v.position.x, v.position.y, v.position.z, 22.0))
	terrain.set_fade_points(pts)


func _update_ghost(w: SimWorld, id: int, v: UnitView, vis: bool, own: bool, layer: TeamVision) -> void:
	var want: bool = not vis and not own and not reveal_all and layer.is_known(id)
	if want and not _ghosts.has(id):
		var g: UnitView = UnitView.new()
		g.setup(id, v.team, v.def, true, v.faction)
		add_child(g)
		_ghosts[id] = g
	if _ghosts.has(id):
		var g2: UnitView = _ghosts[id]
		g2.visible = want
		if want:
			var p: Vector3 = SimRunner.sim_to_view(layer.last_x[id], layer.last_y[id], 0)
			p.y = effects.terrain.height_at(p)
			g2.position = p


func view_of(id: int) -> UnitView:
	return _views.get(id, null)


func all_views() -> Array:
	return _views.values()


func is_shown(id: int) -> bool:
	var v: UnitView = _views.get(id, null)
	return v != null and v.visible


func _on_event(w: SimWorld, e: SimEvent) -> void:
	match e.kind:
		SimEvent.Type.SPAWNED:
			_spawn(w, e.entity_id)
		SimEvent.Type.DESTROYED:
			_destroyed(e.entity_id)
		SimEvent.Type.SHOT:
			if not (reveal_all or is_shown(e.entity_id)):
				return
			var wdef: WeaponStats = w.defs.weapons[e.value]
			var shooter: UnitView = _views.get(e.entity_id, null)
			var muzzle: Vector3 = runner.interpolated_position(e.entity_id) + Vector3.UP * 1.8
			if shooter != null and shooter.model != null and shooter.model.has_meta("muzzle") and not shooter.def.is_infantry:
				var turret: Node3D = shooter.model.get_node_or_null("Turret") as Node3D
				var m: Vector3 = shooter.model.get_meta("muzzle")
				if turret != null:
					var local: Vector3 = m - turret.position
					muzzle = turret.global_transform * local
				else:
					muzzle = shooter.model.global_transform * m
			var team_col: Color = UnitView.TEAM_COLORS[w.units.team[e.entity_id] % 4] if w.units.has(e.entity_id) else Color.WHITE
			if wdef.penetration > 50 or wdef.is_indirect():
				effects.muzzle_flash(muzzle, wdef.is_indirect() or wdef.penetration > 300)
			if wdef.projectile_speed > 0:
				return  # drawn as an in-flight projectile
			var b: Vector3 = runner.interpolated_position(e.other_id) + Vector3.UP if e.other_id > 0 else SimRunner.sim_to_view(e.x, e.y, 0)
			effects.tracer(muzzle, b, wdef.penetration > 50, team_col)
		SimEvent.Type.IMPACT, SimEvent.Type.MISSED:
			var wd: WeaponStats = w.defs.weapons[e.value]
			var p2: Vector3 = SimRunner.sim_to_view(e.x, e.y, 0)
			p2.y = effects.terrain.height_at(p2)
			if not wd.smoke:
				effects.explosion(p2, clampf(wd.blast_radius_mm * 0.0004, 0.8, 9.0), wd.is_indirect())


func _spawn(w: SimWorld, id: int) -> void:
	if _views.has(id) or not w.units.has(id):
		return
	var v: UnitView = UnitView.new()
	var owner: int = w.units.owner[id]
	var fac: String = w.players.faction[owner] if owner >= 0 and owner < w.players.count() else ""
	v.setup(id, w.units.team[id], w.def_of(id), false, fac)
	add_child(v)
	_views[id] = v
	if not runner.curr_pos.has(id):
		var t: TransformStore = w.transform
		runner.curr_pos[id] = SimRunner.sim_to_view(t.x[id], t.y[id], t.z[id])
		runner.curr_heading[id] = SimRunner.heading_to_yaw(t.heading[id])
	v.position = runner.curr_pos[id]
	if not v.def.is_air and is_instance_valid(effects):
		v.position.y = maxf(v.position.y, effects.terrain.height_at(v.position))


## Vehicles become persistent wrecks; infantry and structures are removed.
func _destroyed(id: int) -> void:
	var v: UnitView = _views.get(id, null)
	var p: Vector3 = runner.curr_pos.get(id, Vector3.ZERO)
	if is_instance_valid(effects):
		effects.explosion(p, 3.0 if v == null or v.def.is_infantry else 5.0, false)
	if v != null and not v.def.is_infantry and not v.def.is_air and is_instance_valid(effects) and (v.visible or reveal_all):
		_views.erase(id)
		selected.erase(id)
		_track_from.erase(id)
		if v.def.is_structure:
			effects.terrain.stamp_crater(p, maxf(v.def.footprint_w, v.def.footprint_h) * 4.0, 0.8)
			v.queue_free()
		else:
			effects.terrain.stamp_crater(p, 5.0, 0.7)
			v.make_wreck(effects)
			_wrecks.append(v)
			if _wrecks.size() > MAX_WRECKS:
				var old: UnitView = _wrecks.pop_front()
				old.queue_free()
		_free_ghost(id)
		return
	_despawn(id)


func _free_ghost(id: int) -> void:
	if _ghosts.has(id):
		var g: UnitView = _ghosts[id]
		g.queue_free()
		_ghosts.erase(id)


func _despawn(id: int) -> void:
	selected.erase(id)
	_track_from.erase(id)
	if _views.has(id):
		var v: UnitView = _views[id]
		v.queue_free()
		_views.erase(id)
	_free_ghost(id)
