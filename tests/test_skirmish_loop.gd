## M4 ACCEPTANCE: the full skirmish loop — build FOB → capture depot → produce
## units → destroy HQ — on a procedural map against a passive dummy opponent.
## Player 0's orders come from the same command path a human uses (SkirmishAi
## issues validated SimCommands).
extends TestCase

const LIMIT: int = 15000


func test_m4_acceptance_skirmish_loop() -> void:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "skirmish"
	s.match_seed = 4242
	s.map_seed = 11
	s.map_cells = 300
	s.add_player("Attacker", 0, "nc", true)
	s.add_player("Dummy", 1, "ec", true)
	var w: SimWorld = MatchSetup.create(s, DefLoader.load_default())
	for c: AiController in w.ai:
		if c.player == 1:
			(c as SkirmishAi).aggressive = false
	var built: Dictionary = {}
	var produced: int = 0
	var captured: int = 0
	var t0: int = Time.get_ticks_msec()
	var timeline: PackedStringArray = PackedStringArray()
	while w.tick < LIMIT and w.winner_team < 0:
		w.step()
		for e: SimEvent in w.drain_events():
			match e.kind:
				SimEvent.Type.BUILT:
					if w.units.owner[e.entity_id] == 0:
						built[w.def_of(e.entity_id).role] = w.tick
						timeline.append("%d built %s" % [w.tick, w.def_of(e.entity_id).role])
				SimEvent.Type.PRODUCED:
					if w.units.owner[e.entity_id] == 0:
						produced += 1
				SimEvent.Type.CAPTURED:
					if e.value == 0:
						captured += 1
						timeline.append("%d captured depot" % w.tick)
	timeline.append("%d winner %d" % [w.tick, w.winner_team])
	print("    skirmish loop: %s | produced %d | %d ms" % [", ".join(timeline), produced, Time.get_ticks_msec() - t0])
	assert_true(built.has("barracks") and built.has("motor_pool"), "FOB built")
	assert_true(captured >= 1, "captured a depot")
	assert_true(produced >= 5, "produced units")
	assert_eq(w.winner_team, 0, "enemy HQ destroyed")
	assert_eq(w.players.defeated[1], 1)
