# SIM: deterministic — no floats, no Nodes
## Off-map support (FEATURES 3.2 / 3.3): airstrike, heavy artillery battalion
## or paradrop on a map point. The call goes out over the radio from an
## on-net unit (HQ first), which makes a strong burst enemy DF can fix. A
## jammed caller delays the call. Limited uses per match, battlegroup-gated.
class_name SupportCommand
extends SimCommand

const KIND_AIRSTRIKE: int = 0
const KIND_ARTILLERY: int = 1
const KIND_PARADROP: int = 2
## Shells / bombs are launched this long before they land (presentation arc).
const FLIGHT_TICKS: int = 50

var kind: int
var x_mm: int
var y_mm: int


func _init(p_kind: int = 0, p_x: int = 0, p_y: int = 0) -> void:
	kind = p_kind
	x_mm = p_x
	y_mm = p_y


static func spec(world: SimWorld, k: int) -> Dictionary:
	return world.defs.support.get(DefDb.SUPPORT_KINDS[k], {})


## The unit that makes the call: own HQ on the net, else any own unit on the net.
static func caller(world: SimWorld, player: int) -> int:
	var team: int = world.team_of_player(player)
	if team < 0:
		return 0
	var any: int = 0
	for id: int in world.entities.ids():
		if not world.is_unit(id) or world.units.owner[id] != player or not world.is_on_net(id) or world.units.carrier[id] != 0:
			continue
		if world.is_structure(id) and world.def_of(id).role == "hq":
			return id
		if any == 0:
			any = id
	return any


static func uses_left(world: SimWorld, player: int, k: int) -> int:
	var s: Dictionary = spec(world, k)
	return int(s.get("uses", 0)) - world.players.support_used[player * PlayerStore.SUPPORT_KINDS + k]


func validate(world: SimWorld) -> bool:
	if kind < 0 or kind >= PlayerStore.SUPPORT_KINDS or not world.in_bounds(x_mm, y_mm):
		return false
	if player_id < 0 or player_id >= world.players.count():
		return false
	var s: Dictionary = spec(world, kind)
	if s.is_empty() or uses_left(world, player_id, kind) <= 0:
		return false
	if not world.defs.support_allowed(kind, world.players.faction[player_id], world.players.battlegroup[player_id]):
		return false
	if not world.players.can_afford(player_id, int(s.get("cost", 0)), int(s.get("mp", 0))):
		return false
	if caller(world, player_id) == 0:
		return false
	if bool(s.get("observer", false)) and not FireMissionCommand.is_observed(world, world.team_of_player(player_id), x_mm, y_mm):
		return false
	return true


func apply(world: SimWorld) -> void:
	var s: Dictionary = spec(world, kind)
	world.players.spend(player_id, int(s.get("cost", 0)), int(s.get("mp", 0)))
	world.players.support_used[player_id * PlayerStore.SUPPORT_KINDS + kind] += 1
	var c: int = caller(world, player_id)
	world.units.tx_tick[c] = world.tick
	var delay: int = int(s.get("delay_ticks", 200))
	if world.jammed[c] == 1:
		delay += int(world.defs.support.get("jam_delay_ticks", 200))
	var arrive: int = world.tick + delay
	var team: int = world.team_of_player(player_id)
	if kind == KIND_PARADROP:
		world.support_queue.append(PackedInt64Array([arrive, kind, x_mm, y_mm, player_id, int(s.get("squads", 2))]))
	else:
		var rounds: int = int(s.get("rounds", 1))
		var spacing: int = int(s.get("spacing_ticks", 5))
		var disp: int = int(s.get("dispersion_mm", 50000))
		for r: int in range(rounds):
			var ax: int = clampi(x_mm + world.rng.range_int(-disp, disp), 0, world.map_width_mm() - 1)
			var ay: int = clampi(y_mm + world.rng.range_int(-disp, disp), 0, world.map_height_mm() - 1)
			world.support_queue.append(PackedInt64Array([arrive + r * spacing - FLIGHT_TICKS, kind, ax, ay, player_id, team]))
	world.emit(SimEvent.Type.SUPPORT_CALLED, c, player_id, kind, x_mm, y_mm)


func type_id() -> StringName:
	return &"support"


func write(buf: StreamPeerBuffer) -> void:
	buf.put_u8(kind)
	buf.put_64(x_mm)
	buf.put_64(y_mm)


func read(buf: StreamPeerBuffer) -> void:
	kind = buf.get_u8()
	x_mm = buf.get_64()
	y_mm = buf.get_64()
