# SIM: deterministic — no floats, no Nodes
## Tick phase 9f: delivers queued off-map support. Bombs and heavy shells are
## launched FLIGHT_TICKS before impact from the caller's map edge (so they show
## in flight); paradrops land as fresh squads.
class_name SupportSystem
extends SimSystem


func step(world: SimWorld, tick: int) -> void:
	if world.support_queue.is_empty():
		return
	var keep: Array[PackedInt64Array] = []
	for e: PackedInt64Array in world.support_queue:
		if e[0] > tick:
			keep.append(e)
			continue
		var kind: int = e[1]
		var player: int = e[4]
		if kind == SupportCommand.KIND_PARADROP:
			_paradrop(world, player, e[2], e[3], e[5])
		else:
			var s: Dictionary = SupportCommand.spec(world, kind)
			var wi: int = world.defs.weapon_index(str(s.get("weapon", "")))
			if wi < 0:
				continue
			# from the friendly side of the map (west for team 0, east otherwise)
			var sx: int = 0 if e[5] == 0 else world.map_width_mm() - 1
			world.projectiles.launch(wi, 0, 0, e[5], sx, e[3], e[2], e[3], tick, tick + SupportCommand.FLIGHT_TICKS, 1000)
	world.support_queue = keep


func _paradrop(world: SimWorld, player: int, x: int, y: int, squads: int) -> void:
	if player < 0 or player >= world.players.count():
		return
	var fac: String = world.players.faction[player]
	var def_i: int = world.defs.unit_index("nc_rifle_sqd" if fac == "nc" else "ec_motor_rifle")
	if def_i < 0:
		return
	for k: int in range(squads):
		var ox: int = (k - squads / 2) * 25000
		world.spawn_unit(world.defs.units[def_i], world.team_of_player(player), player,
			clampi(x + ox, 0, world.map_width_mm() - 1), y, 16384)
