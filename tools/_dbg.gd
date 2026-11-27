extends SceneTree
func _initialize() -> void:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "skirmish"
	s.match_seed = 4242
	s.map_seed = 11
	s.map_cells = 300
	s.add_player("Attacker", 0, "nc", true, -1)
	s.add_player("Dummy", 1, "ec", true, -1)
	var w: SimWorld = MatchSetup.create(s, DefLoader.load_default())
	for c: AiController in w.ai:
		if c.player == 0:
			(c as SkirmishAi).aggressive = true
	var routs: int = 0
	var crews: int = 0
	while w.tick < 9000 and w.winner_team < 0:
		w.step()
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.ROUTED:
				routs += 1
		if w.tick % 1000 == 0:
			var a: PackedStringArray = PackedStringArray()
			for id: int in w.team_units[0]:
				if not w.is_structure(id):
					a.append("%s:%s%s" % [w.def_of(id).id.substr(3, 6), OrderStore.NAMES[w.orders.kind[id]], "R" if w.units.rout_until[id] > w.tick else ""])
			print(w.tick, " routs ", routs, " enemy ", w.team_units[1].size(), " | ", " ".join(a))
	quit()
