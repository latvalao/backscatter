## Boots the menu, then a skirmish GameScene and a sandbox GameScene headless,
## running each for a while (sim at 4x) so runtime errors in presentation code
## surface in CI.
##   godot --headless --path . -s res://tests/smoke_scene.gd
extends SceneTree

const FRAMES: int = 160

var _frame: int = 0
var _phase: int = 0
var _scene: Node
var _save_tick: int = 0
var _save_sum: int = 0


func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	if packed == null:
		printerr("SMOKE FAIL: main.tscn did not load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frame += 1
	if _phase == 0 and _frame == 3:
		_scene.queue_free()
		var s: MatchSettings = MatchSettings.default_skirmish()
		s.map_cells = 300
		_start(GameScene.create_offline(s))
	elif _phase == 1 and _frame == FRAMES:
		_report()
		# save, then load and check the reloaded world matches at the save tick
		var sg: GameScene = _scene as GameScene
		sg.runner.speed = 0
		var path: String = sg.save_game()
		_save_tick = sg.runner.world.tick
		_save_sum = Checksum.compute(sg.runner.world)
		_scene.queue_free()
		_scene = GameScene.create_from_save(ReplayRecorder.load_file(path))
		root.add_child(_scene)
		_phase = 10
		_frame = 0
	elif _phase == 10 and _frame == FRAMES:
		var lg: GameScene = _scene as GameScene
		if lg.runner.world.tick < _save_tick or lg.lockstep == null:
			printerr("SMOKE FAIL: save did not load (tick %d of %d)" % [lg.runner.world.tick, _save_tick])
			quit(1)
			return true
		print("smoke: loaded save at tick %d, now %d" % [_save_tick, lg.runner.world.tick])
		assert(_save_sum != 0)
		_scene.queue_free()
		var s3: MatchSettings = MatchSettings.new()
		s3.mode = "sandbox"
		s3.add_player("P", 0, "nc", false)
		s3.add_player("AI", 1, "ec", true)
		_phase = 1
		_start(GameScene.create_offline(s3))
	elif _phase == 2 and _frame == FRAMES:
		_report()
		# replay viewer over what the sandbox just recorded
		var gs: GameScene = _scene as GameScene
		var data: Dictionary = gs.lockstep.recorder.to_dict()
		data["final_tick"] = gs.runner.world.tick
		_scene.queue_free()
		_scene = GameScene.create_replay(data)
		root.add_child(_scene)
		(_scene as GameScene).runner.speed = 4
		_phase += 1
		_frame = 0
	elif _phase == 3 and _frame == FRAMES / 2:
		_report()
		# a scripted mode with its mission panel
		_scene.queue_free()
		var m: MatchSettings = MatchSettings.new()
		m.mode = "containment"
		m.map_cells = 240
		m.add_player("P", 0, "nc", false)
		_start(GameScene.create_offline(m))
	elif _phase == 4 and _frame == FRAMES / 2:
		_report()
		quit(0)
		return true
	return false


func _start(g: GameScene) -> void:
	_scene = g
	root.add_child(g)
	g.runner.speed = 4
	g.runner.max_catch_up = 1
	# exercise the UI paths: select own units, open the build/produce panel
	var w: SimWorld = g.runner.world
	var mine: PackedInt32Array = PackedInt32Array()
	for id: int in w.entities.ids():
		if w.units.has(id) and w.units.owner[id] == 0:
			mine.append(id)
	g.controller._set_selection(mine)
	_phase += 1
	_frame = 0


func _report() -> void:
	var g: GameScene = _scene as GameScene
	print("smoke: %s %d frames, sim tick %d" % [g.settings.mode, _frame, g.runner.world.tick])
