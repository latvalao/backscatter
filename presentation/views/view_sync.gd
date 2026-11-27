## Spawns/despawns UnitViews from sim events, moves them each frame, applies fog
## of war for the local team (visible / ghost at last known position / hidden)
## and turns combat events into effects. Read-only with respect to the sim.
class_name ViewSync
extends Node3D

var runner: SimRunner
var effects: Effects
var local_team: int = 0
## Debug: show everything regardless of fog.
var reveal_all: bool = false
var selected: Dictionary = {}  # id -> true (set by SelectionController)
var show_labels: bool = false

var _views: Dictionary = {}   # entity id -> UnitView
var _ghosts: Dictionary = {}  # entity id -> UnitView


func _process(_delta: float) -> void:
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	for e: SimEvent in w.drain_events():
		_on_event(w, e)
	var layer: TeamVision = w.vision[local_team]
	for id: int in _views.keys():
		var v: UnitView = _views[id]
		var own: bool = v.team == local_team
		var vis: bool = reveal_all or own or layer.is_visible(id, w.tick)
		v.visible = vis
		if vis:
			v.position = runner.interpolated_position(id)
			v.rotation.y = runner.interpolated_yaw(id)
			v.set_selected(selected.has(id))
			v.refresh(w, show_labels or selected.has(id))
		_update_ghost(w, id, v, vis, own, layer)


func _update_ghost(w: SimWorld, id: int, v: UnitView, vis: bool, own: bool, layer: TeamVision) -> void:
	var want: bool = not vis and not own and not reveal_all and layer.is_known(id)
	if want and not _ghosts.has(id):
		var g: UnitView = UnitView.new()
		g.setup(id, v.team, v.def, true)
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
			_despawn(e.entity_id)
			if is_instance_valid(effects):
				var p: Vector3 = runner.curr_pos.get(e.entity_id, Vector3.ZERO)
				effects.flash(p, 4.0)
		SimEvent.Type.SHOT:
			if not (reveal_all or is_shown(e.entity_id)):
				return
			var wdef: WeaponStats = w.defs.weapons[e.value]
			if wdef.projectile_speed > 0:
				return  # drawn as an in-flight projectile
			var a: Vector3 = runner.interpolated_position(e.entity_id)
			var b: Vector3 = runner.interpolated_position(e.other_id) if e.other_id > 0 else SimRunner.sim_to_view(e.x, e.y, 0)
			effects.tracer(a, b, wdef.penetration > 50)
		SimEvent.Type.IMPACT, SimEvent.Type.MISSED:
			var wd: WeaponStats = w.defs.weapons[e.value]
			var p2: Vector3 = SimRunner.sim_to_view(e.x, e.y, 0)
			p2.y = effects.terrain.height_at(p2)
			if not wd.smoke:
				effects.flash(p2, clampf(wd.blast_radius_mm * 0.0004, 1.0, 9.0))


func _spawn(w: SimWorld, id: int) -> void:
	if _views.has(id) or not w.units.has(id):
		return
	var v: UnitView = UnitView.new()
	v.setup(id, w.units.team[id], w.def_of(id))
	add_child(v)
	_views[id] = v
	if not runner.curr_pos.has(id):
		var t: TransformStore = w.transform
		runner.curr_pos[id] = SimRunner.sim_to_view(t.x[id], t.y[id], t.z[id])
		runner.curr_heading[id] = SimRunner.heading_to_yaw(t.heading[id])
	v.position = runner.curr_pos[id]


func _despawn(id: int) -> void:
	selected.erase(id)
	if _views.has(id):
		var v: UnitView = _views[id]
		v.queue_free()
		_views.erase(id)
	if _ghosts.has(id):
		var g: UnitView = _ghosts[id]
		g.queue_free()
		_ghosts.erase(id)
