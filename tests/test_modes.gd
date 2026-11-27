## Phase 6: modes and missions start, run and keep their rules.
extends TestCase


static func _settings(mode: String, mission: String = "", seed_value: int = 5) -> MatchSettings:
	var s: MatchSettings = MatchSettings.new()
	s.mode = mode
	s.mission = mission
	s.match_seed = seed_value
	s.map_seed = 9
	s.map_cells = 220
	s.add_player("P", 0, "nc", false)
	if mode == "zone_war":
		s.add_player("AI", 1, "ec", true)
	return s


static func _director(w: SimWorld) -> ScenarioDirector:
	for c: AiController in w.ai:
		if c is ScenarioDirector:
			return c as ScenarioDirector
	return null


func test_every_mode_starts_and_runs() -> void:
	var cases: Array = [["zone_war", ""], ["containment", ""], ["operation", ""], ["mission", "first_contact"],
		["mission", "the_depot"], ["mission", "signal_discipline"]]
	for c: Array in cases:
		var w: SimWorld = MatchSetup.create(_settings(c[0], c[1]), DefLoader.load_default())
		var d: ScenarioDirector = _director(w)
		assert_true(d != null, "%s has a director" % str(c))
		assert_true(d.objectives.size() >= 1, "%s has objectives" % str(c))
		SimFixture.run(w, 300)
		assert_eq(w.winner_team, -1, "%s still running" % str(c))


func test_containment_sends_waves_and_loses_without_hq() -> void:
	var w: SimWorld = MatchSetup.create(_settings("containment"), DefLoader.load_default())
	var d: ContainmentDirector = _director(w) as ContainmentDirector
	SimFixture.run(w, ContainmentDirector.FIRST_WAVE + 20)
	assert_eq(d.wave, 1)
	assert_true(d.attackers.size() >= 5, "first assault spawned")
	w.destroy_entity(d.hq)
	SimFixture.run(w, 20)
	assert_eq(w.winner_team, 1, "command post lost")


func test_first_contact_tutorial_advances() -> void:
	var w: SimWorld = MatchSetup.create(_settings("mission", "first_contact"), DefLoader.load_default())
	var d: MissionFirstContact = _director(w) as MissionFirstContact
	for id: int in d.force:
		w.transform.x[id] = d.jx
		w.transform.y[id] = d.jy
	SimFixture.run(w, 20)
	assert_eq(d.objective_state[0], ScenarioDirector.DONE, "reached the junction")
	assert_eq(d.stage, 2, "next: board the IFV")


func test_zone_war_scores_depots() -> void:
	var w: SimWorld = MatchSetup.create(_settings("zone_war"), DefLoader.load_default())
	var d: ZoneWarDirector = _director(w) as ZoneWarDirector
	w.step()
	var dep: PackedInt32Array = ObjectiveSystem._depots(w)
	w.structures.holder_team[dep[0]] = 0
	SimFixture.run(w, 401)
	assert_true(d.vp[0] >= 4, "held depot scores")


func test_mode_matches_are_deterministic() -> void:
	var sums: Array[int] = []
	for i: int in range(2):
		var w: SimWorld = MatchSetup.create(_settings("containment", "", 77), DefLoader.load_default())
		SimFixture.run(w, ContainmentDirector.FIRST_WAVE + 200)
		sums.append(Checksum.compute(w))
	assert_eq(sums[0], sums[1])
