## M3: command codec, lockstep over a lossy-latency loopback, desync detection,
## replay record/playback.
extends TestCase


func _settings() -> MatchSettings:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "skirmish"
	s.match_seed = 99
	s.map_seed = 5
	s.map_cells = 160
	s.add_player("A", 0, "nc", false)
	s.add_player("B", 1, "ec", false)
	return s


static var _grid: SimGrid = null


func _grid_for(s: MatchSettings) -> SimGrid:
	if _grid == null:
		_grid = MapGen.generate(s.map_seed, s.map_cells, s.map_cells)
	return _grid


func test_codec_roundtrip_all_commands() -> void:
	var cmds: Array[SimCommand] = [
		SpawnUnitCommand.new("nc_mbt_2a", 123456, 654321, 999),
		MoveCommand.new(PackedInt32Array([3, 5, 9]), 1_000_000, 2_000_000, MoveCommand.MODE_REVERSE, true, true),
		StopCommand.new(PackedInt32Array([1])),
		AttackCommand.new(PackedInt32Array([4, 6]), 77),
		FireMissionCommand.new(PackedInt32Array([8]), 5000, 6000, 12, true),
		SmokeCommand.new(PackedInt32Array([2])),
		StanceCommand.new(PackedInt32Array([2]), UnitStore.STANCE_HOLD_FIRE),
		BuildCommand.new(PackedInt32Array([11]), "barracks", 40, 41),
		ProduceCommand.new(31, "nc_rifle_sqd", 3),
		CancelProductionCommand.new(31),
		RallyCommand.new(31, 70000, 80000),
	]
	for i: int in range(cmds.size()):
		cmds[i].player_id = i % 4
		cmds[i].sequence = 1000 + i
		cmds[i].tick = 5000 + i
	var bytes: PackedByteArray = CommandCodec.encode(cmds)
	var back: Array[SimCommand] = CommandCodec.decode(bytes)
	assert_eq(back.size(), cmds.size())
	assert_eq(CommandCodec.encode(back), bytes, "re-encoding is byte-identical")
	var mv: MoveCommand = back[1] as MoveCommand
	assert_eq(mv.unit_ids, PackedInt32Array([3, 5, 9]))
	assert_true(mv.queue and mv.safe)
	assert_eq(mv.mode, MoveCommand.MODE_REVERSE)
	assert_eq((back[7] as BuildCommand).structure, "barracks")
	assert_eq(back[10].tick, 5010)


## Two peers on a laggy loopback, both issuing commands; lockstep must keep
## their worlds bit-identical, and a replay must reproduce the result.
func test_two_peers_stay_in_sync_and_replay_matches() -> void:
	var s: MatchSettings = _settings()
	var hub: LoopbackHub = LoopbackHub.new(2, 3, 7)
	var ta: LoopbackTransport = LoopbackTransport.new(hub, 1)
	var tb: LoopbackTransport = LoopbackTransport.new(hub, 2)
	var wa: SimWorld = MatchSetup.create(s, DefLoader.load_default(), _grid_for(s))
	var wb: SimWorld = MatchSetup.create(s, DefLoader.load_default(), _grid_for(s))
	var players: PackedInt32Array = PackedInt32Array([0, 1])
	var la: Lockstep = Lockstep.new(wa, ta, 0, players, 3)
	var lb: Lockstep = Lockstep.new(wb, tb, 1, players, 3)
	la.recorder = ReplayRecorder.new(s.to_dict())
	var desyncs: Array[int] = []
	la.desync.connect(func(t: int, _d: String) -> void: desyncs.append(t))
	lb.desync.connect(func(t: int, _d: String) -> void: desyncs.append(t))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var frames: int = 0
	while (wa.tick < 400 or wb.tick < 400) and frames < 20000:
		frames += 1
		la.receive()
		lb.receive()
		# each peer issues orders at its own pace (independent of the other)
		for pair: Array in [[la, wa, 0], [lb, wb, 1]]:
			var ls: Lockstep = pair[0]
			var w: SimWorld = pair[1]
			var me: int = pair[2]
			if rng.randi_range(0, 30) == 0:
				var mine: PackedInt32Array = PackedInt32Array()
				for id: int in w.entities.ids():
					if w.units.owner[id] == me and w.mobility.has(id):
						mine.append(id)
				if not mine.is_empty():
					ls.submit(MoveCommand.new(mine, rng.randi_range(100_000, 1_200_000), rng.randi_range(100_000, 1_200_000)))
			# uneven frame pacing: sometimes a peer skips advancing this frame
			if rng.randi_range(0, 3) != 0 and w.tick < 400:
				ls.try_advance()
	assert_eq(wa.tick, 400, "peer A finished")
	assert_eq(wb.tick, 400, "peer B finished")
	assert_eq(Checksum.compute(wa), Checksum.compute(wb), "identical end state")
	assert_true(desyncs.is_empty(), "no desync reported")
	assert_true(la.stalls > 0, "latency forced some waiting")
	# replay through a file
	var path: String = "user://test_replays/sync.replay"
	assert_eq(la.recorder.save(path), OK)
	var rp: ReplayPlayer = ReplayPlayer.new(ReplayRecorder.load_file(path), _grid_for(s))
	assert_true(rp.verify(), "replay reproduces every checksum")
	assert_eq(Checksum.compute(rp.world), Checksum.compute(wa), "replay ends in the same state")


func test_desync_is_detected() -> void:
	var s: MatchSettings = _settings()
	var hub: LoopbackHub = LoopbackHub.new(1)
	var ta: LoopbackTransport = LoopbackTransport.new(hub, 1)
	var tb: LoopbackTransport = LoopbackTransport.new(hub, 2)
	var wa: SimWorld = MatchSetup.create(s, DefLoader.load_default(), _grid_for(s))
	var wb: SimWorld = MatchSetup.create(s, DefLoader.load_default(), _grid_for(s))
	var players: PackedInt32Array = PackedInt32Array([0, 1])
	var la: Lockstep = Lockstep.new(wa, ta, 0, players)
	var lb: Lockstep = Lockstep.new(wb, tb, 1, players)
	var hits: Array[int] = []
	la.desync.connect(func(t: int, _d: String) -> void: hits.append(t))
	# corrupt peer B's state
	wb.players.supply[1] += 1
	for i: int in range(200):
		la.receive()
		lb.receive()
		la.try_advance()
		lb.try_advance()
	assert_false(hits.is_empty(), "mismatch reported")
	assert_true(la.desynced)
	assert_true(DirAccess.dir_exists_absolute("user://desync"), "dump written")


func test_replay_detects_tampering() -> void:
	var s: MatchSettings = _settings()
	var w: SimWorld = MatchSetup.create(s, DefLoader.load_default(), _grid_for(s))
	var ls: Lockstep = Lockstep.new(w, NetTransport.new(), 0, PackedInt32Array([0]), 1)
	ls.recorder = ReplayRecorder.new(s.to_dict())
	var mine: PackedInt32Array = PackedInt32Array()
	for id: int in w.entities.ids():
		if w.units.owner[id] == 0 and w.mobility.has(id):
			mine.append(id)
	ls.submit(MoveCommand.new(mine, 600_000, 600_000))
	for i: int in range(120):
		ls.try_advance()
	var data: Dictionary = ls.recorder.to_dict()
	assert_true(ReplayPlayer.new(data, _grid_for(s)).verify())
	var sums: Dictionary = data["checksums"]
	sums[100] = int(sums[100]) ^ 1
	var bad: ReplayPlayer = ReplayPlayer.new(data, _grid_for(s))
	assert_false(bad.verify())
	assert_eq(bad.mismatch_tick, 100)
