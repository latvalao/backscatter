# SIM: deterministic — no floats, no Nodes
## Indirect fire on a map point (§5.3). Requires a friendly spotter with line of
## sight to the point (pre-planned grids arrive with Barrage Doctrine, M6).
class_name FireMissionCommand
extends UnitCommand

const SPOTTER_HEIGHT_MM: int = 1000
## A signal fix this tight is a valid artillery target (§5.5).
const MAX_FIX_RADIUS_MM: int = 150000

var x_mm: int
var y_mm: int
var rounds: int
var smoke: bool


func _init(p_ids: PackedInt32Array = PackedInt32Array(), p_x: int = 0, p_y: int = 0,
		p_rounds: int = 4, p_smoke: bool = false) -> void:
	unit_ids = p_ids
	x_mm = p_x
	y_mm = p_y
	rounds = p_rounds
	smoke = p_smoke


func validate(world: SimWorld) -> bool:
	if rounds <= 0 or rounds > 100 or not world.in_bounds(x_mm, y_mm):
		return false
	if _artillery(world).is_empty():
		return false
	var team: int = world.team_of_player(player_id)
	return is_observed(world, team, x_mm, y_mm) or world.signals[team].targetable(x_mm, y_mm, MAX_FIX_RADIUS_MM) \
		or is_barrage(world)


## Eastern Barrage Doctrine (§3.2): pre-planned fire on unobserved map grids.
func is_barrage(world: SimWorld) -> bool:
	return world.players.faction[player_id] == "ec"


## Owned units with an indirect weapon of the right kind in range of the point.
func _artillery(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in owned(world):
		var def: UnitStats = world.def_of(id)
		var d: int = FixedMath.length2(x_mm - world.transform.x[id], y_mm - world.transform.y[id])
		for wi: int in def.weapons:
			var w: WeaponStats = world.defs.weapons[wi]
			if w.is_indirect() and w.smoke == smoke and d >= w.range_min_mm and d <= w.range_max_mm:
				out.append(id)
				break
	return out


## Some friendly unit can see the ground at (x, y).
static func is_observed(world: SimWorld, team: int, x: int, y: int) -> bool:
	var t: TransformStore = world.transform
	var gz: int = world.grid.ground_at(x, y) + SPOTTER_HEIGHT_MM
	for id: int in world.entities.ids():
		if not world.is_unit(id) or world.units.team[id] != team:
			continue
		var ranges: Vector2i = VisionSystem.observer_ranges(world, id)
		var r: int = maxi(ranges.x, ranges.y)
		var dx: int = x - t.x[id]
		var dy: int = y - t.y[id]
		if dx * dx + dy * dy > r * r:
			continue
		var def: UnitStats = world.def_of(id)
		if Los.check(world, t.x[id], t.y[id], t.z[id] + def.eye_height_mm, x, y, gz) != Los.BLOCKED:
			return true
	return false


func apply(world: SimWorld) -> void:
	var flags: int = OrderStore.FLAG_SMOKE if smoke else 0
	var team: int = world.team_of_player(player_id)
	if is_barrage(world) and not is_observed(world, team, x_mm, y_mm) and not world.signals[team].targetable(x_mm, y_mm, MAX_FIX_RADIUS_MM):
		flags |= OrderStore.FLAG_BARRAGE
	for id: int in _artillery(world):
		world.orders.queue.erase(id)
		Orders.start(world, id, OrderStore.FIRE_MISSION, flags, x_mm, y_mm, 0)
		world.orders.rounds[id] = rounds
		world.mobility.speed[id] = 0


func type_id() -> StringName:
	return &"fire_mission"


func write(buf: StreamPeerBuffer) -> void:
	write_ids(buf)
	buf.put_64(x_mm)
	buf.put_64(y_mm)
	buf.put_u8(rounds)
	buf.put_u8(int(smoke))


func read(buf: StreamPeerBuffer) -> void:
	read_ids(buf)
	x_mm = buf.get_64()
	y_mm = buf.get_64()
	rounds = buf.get_u8()
	smoke = buf.get_u8() != 0
