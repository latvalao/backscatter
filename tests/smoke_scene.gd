## Boots the main scene headless and runs it for a while (sim at 4×) so runtime
## errors in presentation code surface in CI. Exit 1 if the scene fails to load.
##   godot --headless --path . -s res://tests/smoke_scene.gd
extends SceneTree

const FRAMES: int = 240

var _frame: int = 0
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
	if _frame == 2:
		var runner: SimRunner = _scene.get("runner") as SimRunner
		if runner != null:
			runner.speed = 4
			runner.max_catch_up = 1
	if _frame >= FRAMES:
		var runner2: SimRunner = _scene.get("runner") as SimRunner
		print("smoke: %d frames, sim tick %d" % [_frame, runner2.world.tick if runner2 != null else -1])
		quit(0)
	return false
