## M6 acceptance (AI counter-battery) and M7 AI tests.
extends TestCase


static func _settings(seed_value: int, cells: int, nc_diff: int, ec_diff: int, marauders: bool, nc_ai: bool = true) -> MatchSettings:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "skirmish"
	s.match_seed = seed_value
	s.map_seed = 11
	s.map_cells = cells
	s.marauders = marauders
	s.add_player("Coalition", 0, "nc", nc_ai, nc_diff)
	s.add_player("Eastern", 1, "ec", true, ec_diff)
	return s


static var _grids: Dictionary = {}


static func _world(s: MatchSettings) -> SimWorld:
	var key: String = "%d_%d" % [s.map_seed, s.map_cells]
	if not _grids.has(key):
		_grids[key] = MapGen.generate(s.map_seed, s.map_cells, s.map_cells)
	return MatchSetup.create(s, DefLoader.load_default(), _grids[key])


## Runs until someone wins or the limit; returns summary.
static func _play(w: SimWorld, limit: int) -> Dictionary:
	var produced: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var shots: int = 0
	var t0: int = Time.get_ticks_msec()
	while w.tick < limit and w.winner_team < 0:
		w.step()
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.PRODUCED:
				produced[w.units.team[e.entity_id]] += 1
			elif e.kind == SimEvent.Type.SHOT:
				shots += 1
	var ms: int = Time.get_ticks_msec() - t0
	return {"ticks": w.tick, "winner": w.winner_team, "produced": produced, "shots": shots,
		"ms_per_tick": float(ms) / maxi(1, w.tick), "checksum": Checksum.compute(w)}


## M6 ACCEPTANCE: an SPG that keeps firing from one spot gets located (counter-
## battery radar / DF) and counter-fired by the AI.
func test_m6_acceptance_ai_counter_battery() -> void:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(500, 200))
	w.weather.next_change = 1 << 40
	w.weather.fog = false
	w.weather.raining = false
	w.players.faction[0] = "nc"
	w.players.is_ai[0] = 1
	var hq: int = SimFixture.structure(w, "hq", 0, 10, 100)
	var spgs: PackedInt32Array = PackedInt32Array([SimFixture.spawn(w, "nc_spg_155", 0, 300, 700), SimFixture.spawn(w, "nc_spg_155", 0, 300, 760)])
	SimFixture.spawn(w, "nc_cbr_radar", 0, 400, 900)
	var ec_spg: int = SimFixture.spawn(w, "ec_spg_122", 1, 3600, 800)
	var ai: CommanderAi = CommanderAi.new(0, "nc", CommanderAi.NORMAL)
	w.ai.append(ai)
	var hp0: int = w.units.hp[ec_spg]
	# the Eastern gun shells the Coalition position three times (barrage doctrine)
	for k: int in range(3):
		SimFixture.cmd(FireMissionCommand.new(PackedInt32Array([ec_spg]), 900_000, 800_000, 2), w, 1, k)
		SimFixture.run(w, 250)
	SimFixture.run(w, 600)
	var countered: bool = not w.is_unit(ec_spg) or w.units.hp[ec_spg] < hp0 or w.units.crew[ec_spg] != w.def_of(ec_spg).crew_slots \
		or w.units.damage[ec_spg] != 0
	print("    CB: ec spg alive=%s hp=%d/%d" % [w.is_unit(ec_spg), w.units.hp[ec_spg] if w.is_unit(ec_spg) else 0, hp0])
	assert_true(countered, "AI counter-battery hit the firing SPG")
	assert_true(hq > 0 and spgs.size() == 2)


## Limit 16000 ticks: the passive side's idle infantry digs in (Phase 2) and the
## street-grid villages slow the assault (won at ~14600).
func test_slow_normal_ai_beats_passive_player() -> void:
	var w: SimWorld = _world(_settings(31, 200, CommanderAi.NORMAL, -1, false))
	var r: Dictionary = _play(w, 16000)
	print("    normal vs passive: %s" % str(r))
	assert_eq(r["winner"], 0, "Normal AI destroyed the passive side's HQ")


## Mirror faction on a symmetric map, both slot orders, so the test measures
## difficulty rather than faction or map-side balance: Hard must never lose to Easy.
func test_slow_hard_ai_never_loses_to_easy() -> void:
	for hard_slot: int in range(2):
		var s: MatchSettings = MatchSettings.new()
		s.mode = "skirmish"
		s.match_seed = 32
		s.map_seed = 11
		s.map_cells = 200
		s.add_player("P0", 0, "ec", true, CommanderAi.HARD if hard_slot == 0 else CommanderAi.EASY)
		s.add_player("P1", 1, "ec", true, CommanderAi.EASY if hard_slot == 0 else CommanderAi.HARD)
		var r: Dictionary = _play(_world(s), 9000)
		print("    hard in slot %d vs easy: %s" % [hard_slot, str(r)])
		assert_ne(r["winner"], 1 - hard_slot, "Easy beat Hard (hard in slot %d)" % hard_slot)


## M7 ACCEPTANCE (soak): AI vs AI with Marauders for 30 sim-minutes — no errors,
## both sides build and fight, the sim stays deterministic.
func test_slow_m7_acceptance_ai_soak_30_minutes() -> void:
	var w: SimWorld = _world(_settings(33, 300, CommanderAi.NORMAL, CommanderAi.NORMAL, true))
	var r: Dictionary = _play(w, 18000)
	print("    soak: %s" % str(r))
	var produced: PackedInt32Array = r["produced"]
	assert_true(produced[0] >= 6 and produced[1] >= 6, "both sides produced units")
	assert_true(int(r["shots"]) > 200, "they fought")
	assert_true(int(r["ticks"]) >= 3000, "match lasted")


func test_ai_match_is_deterministic() -> void:
	var a: SimWorld = _world(_settings(34, 200, CommanderAi.NORMAL, CommanderAi.HARD, true))
	var b: SimWorld = _world(_settings(34, 200, CommanderAi.NORMAL, CommanderAi.HARD, true))
	for i: int in range(1000):
		a.step()
		b.step()
		# the sim's own periodic checksum: no extra hashing cost
		if a.last_checksum_tick == i and a.last_checksum != b.last_checksum:
			fail("AI desync at tick %d" % i)
			return
	assert_eq(Checksum.compute(a), Checksum.compute(b))


## Co-op: two human peers + an AI opponent + Marauders over a lagged loopback.
func test_ai_in_coop_lockstep_stays_in_sync() -> void:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "skirmish"
	s.match_seed = 35
	s.map_seed = 11
	s.map_cells = 200
	s.marauders = true
	s.add_player("A", 0, "nc", false)
	s.add_player("B", 0, "nc", false)
	s.add_player("AI", 1, "ec", true, CommanderAi.NORMAL)
	var hub: LoopbackHub = LoopbackHub.new(2, 2, 9)
	var wa: SimWorld = _world(s)
	var wb: SimWorld = _world(s)
	var la: Lockstep = Lockstep.new(wa, LoopbackTransport.new(hub, 1), 0, PackedInt32Array([0, 1]))
	var lb: Lockstep = Lockstep.new(wb, LoopbackTransport.new(hub, 2), 1, PackedInt32Array([0, 1]))
	var bad: Array[int] = []
	la.desync.connect(func(t: int, _d: String) -> void: bad.append(t))
	lb.desync.connect(func(t: int, _d: String) -> void: bad.append(t))
	var frames: int = 0
	while (wa.tick < 800 or wb.tick < 800) and frames < 20000:
		frames += 1
		la.receive()
		lb.receive()
		if wa.tick < 800:
			la.try_advance()
		if wb.tick < 800:
			lb.try_advance()
	assert_eq(wa.tick, 800)
	assert_eq(Checksum.compute(wa), Checksum.compute(wb))
	assert_true(bad.is_empty())


func test_marauders_ambush_then_raid_trucks() -> void:
	var w: SimWorld = _world(_settings(36, 300, CommanderAi.NORMAL, -1, true))
	var mr: int = w.players.count() - 1
	assert_eq(w.players.faction[mr], "mr")
	var held: int = 0
	var total: int = 0
	for id: int in w.entities.ids():
		if w.units.has(id) and w.units.owner[id] == mr:
			total += 1
			if w.units.stance[id] == UnitStore.STANCE_HOLD_FIRE:
				held += 1
	assert_true(total >= 8, "camps garrisoned (%d)" % total)
	assert_eq(held, total, "hidden, holding fire")
