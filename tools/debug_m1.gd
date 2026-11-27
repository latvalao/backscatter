## Debug: runs the M1 crossing and reports per-group outcomes.
extends SceneTree


func _initialize() -> void:
	var w: SimWorld = SimWorld.new(1, DefLoader.load_default(), MapGen.generate(7, 500, 500))
	w.add_player(0)
	var defs: Array[String] = ["nc_rifle_sqd", "nc_mbt_2a", "nc_ifv_90", "nc_supply_truck"]
	var gx: Array[int] = [1_300_000, 2_900_000, 2_900_000, 2_900_000]
	var gy: Array[int] = [1_700_000, 1_800_000, 2_200_000, 2_600_000]
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in range(200):
		ids.append(w.spawn_unit(w.defs.unit(defs[i % 4]), 0, 0, (300 + (i % 10) * 30) * 1000, (1400 + (i / 10) * 30) * 1000, 0))
	for d: int in range(4):
		var grp: PackedInt32Array = PackedInt32Array()
		for i: int in range(200):
			if i % 4 == d:
				grp.append(ids[i])
		Orders.start_group(w, grp, OrderStore.MOVE, 0, gx[d], gy[d], false)
	var limit: int = 9000
	for t: int in range(limit):
		w.step()
		if t % 1000 == 999:
			var moving: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
			for i: int in range(200):
				if w.orders.kind[ids[i]] != OrderStore.NONE:
					moving[i % 4] += 1
			print("t=%d moving per group %s" % [t + 1, moving])
	for d: int in range(4):
		var far: int = 0
		var sumd: int = 0
		for i: int in range(200):
			if i % 4 != d:
				continue
			var id: int = ids[i]
			var dd: int = FixedMath.length2(w.transform.x[id] - gx[d], w.transform.y[id] - gy[d])
			sumd += dd
			if dd > 250_000:
				far += 1
				if far <= 4:
					var c: int = w.grid.cell_at(w.transform.x[id], w.transform.y[id])
					print("  far %s #%d at (%d,%d) m terrain=%s order=%s repaths=%d flow=%d" % [defs[d], id,
						w.transform.x[id] / 1000, w.transform.y[id] / 1000, TerrainTable.NAMES[w.grid.terrain[c]],
						OrderStore.NAMES[w.orders.kind[id]], w.orders.repaths[id], w.orders.flow_id[id]])
		print("%s: far=%d avg dist %d m" % [defs[d], far, sumd / 50000])
	quit()
