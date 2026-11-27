# SIM: deterministic — no floats, no Nodes
## Illumination round: one mortar or gun lights an area for FLARE_TICKS. At
## night, targets under the flare are spotted with day optics. No observer needed.
class_name FlareCommand
extends UnitCommand

const FLARE_RADIUS_MM: int = 350000
const FLARE_TICKS: int = 450
const DELAY_TICKS: int = 40

var x_mm: int
var y_mm: int


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_x: int = 0, p_y: int = 0) -> void:
	unit_ids = p_ids
	x_mm = p_x
	y_mm = p_y


func validate(world: SimWorld) -> bool:
	return world.in_bounds(x_mm, y_mm) and _gun(world) != 0


## First owned unit with an indirect HE weapon in range that has ammo left.
func _gun(world: SimWorld) -> int:
	for id: int in owned(world):
		var def: UnitStats = world.def_of(id)
		var d: int = FixedMath.length2(x_mm - world.transform.x[id], y_mm - world.transform.y[id])
		for s: int in range(def.weapons.size()):
			var w: WeaponStats = world.defs.weapons[def.weapons[s]]
			var k: int = id * WeaponStore.MAX_WEAPONS + s
			if w.is_indirect() and not w.smoke and d >= w.range_min_mm and d <= w.range_max_mm and world.weapons.ammo[k] >= w.ammo_per_shot:
				return id
	return 0


func apply(world: SimWorld) -> void:
	var gun: int = _gun(world)
	var def: UnitStats = world.def_of(gun)
	for s: int in range(def.weapons.size()):
		var w: WeaponStats = world.defs.weapons[def.weapons[s]]
		if w.is_indirect() and not w.smoke:
			world.weapons.ammo[gun * WeaponStore.MAX_WEAPONS + s] -= w.ammo_per_shot
			break
	world.units.last_fired_tick[gun] = world.tick
	world.flares.add(x_mm, y_mm, FLARE_RADIUS_MM, world.tick + DELAY_TICKS + FLARE_TICKS)
	world.emit(SimEvent.Type.FLARE, 0, gun, 0, x_mm, y_mm)


func type_id() -> StringName:
	return &"flare"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_64(x_mm)
	buf.put_64(y_mm)


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	x_mm = buf.get_64()
	y_mm = buf.get_64()
