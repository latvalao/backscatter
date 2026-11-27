## Boots the menu, then a skirmish GameScene and a sandbox GameScene headless,
## running each for a while (sim at 4x) so runtime errors in presentation code
## surface in CI.
##   godot --headless --path . -s res://tests/smoke_scene.gd
extends SceneTree

const FRAMES: int = 160

var _frame: int = 0
var _phase: int = 0
var _scene: Node


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
		_scene.queue_free()
		var s2: MatchSettings = MatchSettings.new()
		s2.mode = "sandbox"
		s2.add_player("P", 0, "nc", false)
		s2.add_player("AI", 1, "ec", true)
		_start(GameScene.create_offline(s2))
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
