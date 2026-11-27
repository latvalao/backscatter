## Ad-hoc profiler: per-system cost for the M1 200-unit crossing.
##   godot --headless --path . -s res://tools/profile_m1.gd
extends SceneTree


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	var w: SimWorld = SimWorld.new(1, DefLoader.load_default(), MapGen.generate(7, 500, 500))
	w.add_player(0)
	print("map+world: %d ms" % (Time.get_ticks_msec() - t0))
	var defs: Array[String] = ["nc_rifle_sqd", "nc_mbt_2a", "nc_ifv_90", "nc_supply_truck"]
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in range(200):
		ids.append(w.spawn_unit(w.defs.unit(defs[i % 4]), 0, 0, (300 + (i % 10) * 30) * 1000, (1400 + (i / 10) * 30) * 1000, 0))
	var groups: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for i: int in range(200):
		groups[i % 4].append(ids[i])
	t0 = Time.get_ticks_msec()
	Orders.start_group(w, groups[0], OrderStore.MOVE, 0, 1_300_000, 1_700_000, false)
	Orders.start_group(w, groups[1], OrderStore.MOVE, 0, 2_900_000, 1_800_000, false)
	Orders.start_group(w, groups[2], OrderStore.MOVE, 0, 2_900_000, 2_200_000, false)
	Orders.start_group(w, groups[3], OrderStore.MOVE, 0, 2_900_000, 2_600_000, false)
	print("orders (flow fields): %d ms, %d fields, %d path requests" % [Time.get_ticks_msec() - t0, w.flow_fields.size(), w.path_requests.size()])
	var flow_users: int = 0
	for id: int in ids:
		if w.orders.flow_id[id] != 0:
			flow_users += 1
	print("units on flow fields: %d" % flow_users)
	var sys: Array[SimSystem] = [MovementSystem.new(), VisionSystem.new(), WeaponSystem.new(), ProjectileSystem.new(), MoraleSystem.new()]
	var cost: PackedInt64Array = PackedInt64Array()
	cost.resize(sys.size())
	for tick: int in range(300):
		for s: int in range(sys.size()):
			var a: int = Time.get_ticks_usec()
			sys[s].step(w, w.tick)
			cost[s] += Time.get_ticks_usec() - a
		w.tick += 1
	print("path calls: %d" % w.pathfinder.calls)
	for s: int in range(sys.size()):
		print("%s: %.2f ms/tick" % [sys[s].get_script().get_global_name(), cost[s] / 300.0 / 1000.0])
	var moving: int = 0
	for id: int in ids:
		if w.orders.kind[id] != OrderStore.NONE:
			moving += 1
	print("still moving after 300 ticks: %d, pending paths %d" % [moving, w.path_requests.size()])
	quit()
