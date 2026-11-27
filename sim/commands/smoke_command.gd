# SIM: deterministic — no floats, no Nodes
## Vehicle smoke launchers: a screen in front of the vehicle.
class_name SmokeCommand
extends UnitCommand

const SCREEN_DISTANCE_MM: int = 35000
const SCREEN_RADIUS_MM: int = 22000
const SCREEN_TICKS: int = 400


func _init(p_ids: PackedInt32Array = PackedInt32Array()) -> void:
	unit_ids = p_ids


func apply(world: SimWorld) -> void:
	var t: TransformStore = world.transform
	for id: int in owned(world):
		if world.units.smoke_charges[id] <= 0:
			continue
		world.units.smoke_charges[id] -= 1
		var h: int = t.heading[id]
		var sx: int = t.x[id] + (SCREEN_DISTANCE_MM * FixedMath.cos_b(h)) / FixedMath.ONE
		var sy: int = t.y[id] + (SCREEN_DISTANCE_MM * FixedMath.sin_b(h)) / FixedMath.ONE
		world.smoke.add(sx, sy, SCREEN_RADIUS_MM, world.tick + SCREEN_TICKS)
		world.emit(SimEvent.Type.SMOKE, id, 0, SCREEN_RADIUS_MM, sx, sy)


func type_id() -> StringName:
	return &"smoke"
