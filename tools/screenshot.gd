## Renders the main scene for N frames and saves a screenshot.
##   godot --path . -s res://tools/screenshot.gd -- --out=/path/shot.png --frames=200 [--reveal] [--zoom=400]
extends SceneTree

var _frame: int = 0
var _scene: Node
var _out: String = "user://shot.png"
var _frames: int = 200
var _reveal: bool = false
var _zoom: float = 0.0
var _focus: String = ""
var _overlays: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--frames="):
			_frames = a.substr(9).to_int()
		elif a == "--reveal":
			_reveal = true
		elif a.begins_with("--zoom="):
			_zoom = a.substr(7).to_float()
		elif a.begins_with("--focus="):
			_focus = a.substr(8)
		elif a == "--dosimetry" or a == "--signals":
			_overlays.append(a)
	var st: MatchSettings = MatchSettings.default_skirmish()
	for a2: String in OS.get_cmdline_user_args():
		if a2 == "--sandbox":
			st = MatchSettings.new()
			st.mode = "sandbox"
			st.add_player("P", 0, "nc", false)
			st.add_player("AI", 1, "ec", true)
	_scene = GameScene.create_offline(st)
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		var runner: SimRunner = _scene.get("runner") as SimRunner
		runner.speed = 4
		var views: ViewSync = _scene.get("views") as ViewSync
		views.reveal_all = _reveal
		views.show_labels = true
		var cam: RtsCamera = _scene.get("cam") as RtsCamera
		if _zoom > 0.0:
			cam.set_distance(_zoom)
		if _focus != "":
			var parts: PackedStringArray = _focus.split(",")
			cam.focus(Vector3(parts[0].to_float(), 0, -parts[1].to_float()))
		var gs: GameScene = _scene as GameScene
		if _overlays.has("--dosimetry"):
			gs.dosimetry.toggle()
		if _overlays.has("--signals"):
			gs.signals_overlay.toggle()
		var ctl: SelectionController = _scene.get("controller") as SelectionController
		var sel: PackedInt32Array = PackedInt32Array()
		for id: int in runner.world.entities.ids():
			if runner.world.units.has(id) and runner.world.units.owner[id] == 0 and sel.size() < 6 and not runner.world.is_structure(id):
				sel.append(id)
		ctl._set_selection(sel)
	if _frame >= _frames:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved %s" % _out)
		quit(0)
	return false
