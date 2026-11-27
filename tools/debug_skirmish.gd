## Debug: runs the M2 20v20 and reports survivors + casualty timeline.
extends SceneTree


func _initialize() -> void:
	var nc: Array[String] = ["nc_mbt_2a", "nc_mbt_2a", "nc_mbt_2a", "nc_ifv_90", "nc_ifv_90", "nc_ifv_90", "nc_ifv_90",
		"nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd",
		"nc_atgm_team", "nc_atgm_team", "nc_atgm_team", "nc_recon_team", "nc_recon_team", "nc_mortar_team", "nc_mortar_team"]
	var ec: Array[String] = ["ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2",
		"ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle",
		"ec_rpg_team", "ec_rpg_team", "ec_rpg_team", "ec_recon_sqd", "ec_mortar_team", "ec_mortar_team"]
	var g: SimGrid = SimGrid.new(300, 120)
	g.rebuild_sectors()
	var w: SimWorld = SimWorld.new(1234, DefLoader.load_default(), g)
	w.add_player(0)
	w.add_player(1)
	var side: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for i: int in range(20):
		side[0].append(w.spawn_unit(w.defs.unit(nc[i]), 0, 0, (600 + (i / 5) * 40) * 1000, (300 + (i % 5) * 80) * 1000, 0))
		side[1].append(w.spawn_unit(w.defs.unit(ec[i]), 1, 1, (1800 - (i / 5) * 40) * 1000, (300 + (i % 5) * 80) * 1000, 32768))
	Orders.start_group(w, side[0], OrderStore.ATTACK_MOVE, 0, 1200_000, 480_000, false)
	Orders.start_group(w, side[1], OrderStore.ATTACK_MOVE, 0, 1200_000, 480_000, false)
	var shots: int = 0
	for t: int in range(6000):
		w.step()
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.SHOT:
				shots += 1
		if t % 300 == 299:
			var a: PackedInt32Array = PackedInt32Array([0, 0])
			for s: int in range(2):
				for id: int in side[s]:
					if w.is_unit(id):
						a[s] += 1
			print("t=%4d  NC %2d  EC %2d  shots %d" % [t + 1, a[0], a[1], shots])
	for s: int in range(2):
		for id: int in side[s]:
			if w.is_unit(id):
				var d: UnitStats = w.def_of(id)
				print("  %s #%d at (%d,%d) order=%s supp=%d morale=%d members=%d hp=%d" % [d.id, id,
					w.transform.x[id] / 1000, w.transform.y[id] / 1000, OrderStore.NAMES[w.orders.kind[id]],
					w.units.suppression[id], w.units.morale[id], w.units.members_alive[id], w.units.hp[id]])
	quit()
