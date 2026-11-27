## Spawns/despawns UnitViews from sim events and moves them each frame.
## Read-only with respect to the sim.
class_name ViewSync
extends Node3D

var runner: SimRunner
var _views: Dictionary = {}  # entity id -> UnitView


func _process(_delta: float) -> void:
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	for e: SimEvent in w.drain_events():
		match e.kind:
			SimEvent.Type.SPAWNED:
				_spawn(e.entity_id)
			SimEvent.Type.DESTROYED:
				_despawn(e.entity_id)
	for id: int in _views.keys():
		var v: UnitView = _views[id]
		v.position = runner.interpolated_position(id)
		if w.transform.has(id):
			# Binary angle (CCW from east) -> Godot yaw; box's long axis is local Z.
			var ang: float = float(w.transform.heading[id]) / SimConst.ANGLE_FULL * TAU
			v.rotation.y = ang - PI * 0.5


func _spawn(id: int) -> void:
	if _views.has(id):
		return
	var v: UnitView = UnitView.new()
	v.setup(id, runner.world.team[id])
	add_child(v)
	_views[id] = v
	if not runner.curr_pos.has(id):
		var t: TransformStore = runner.world.transform
		runner.curr_pos[id] = SimRunner.sim_to_view(t.x[id], t.y[id], t.z[id])


func _despawn(id: int) -> void:
	if _views.has(id):
		var v: UnitView = _views[id]
		v.queue_free()
		_views.erase(id)
