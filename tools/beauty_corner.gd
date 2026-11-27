## V0 "beauty corner" (docs/VISUALS.md §13): one 512 × 512 m hand-built scene —
## lake shore, birch/pine forest edge, misty bog, a gravel road, a ruined border
## post, an MBT-72 and an MBT-2A — rendered with the full look stack.
##   godot --path . -s res://tools/beauty_corner.gd -- [--out=shot.png] [--preset=golden_afternoon]
##        [--season=winter] [--quality=2] [--zoom=170] [--frames=60]
## Without --out it stays open as an interactive scene.
extends SceneTree

const N: int = 64

var _out: String = ""
var _preset: String = "golden_afternoon"
var _zoom: float = 150.0
var _frames: int = 60
var _frame: int = 0
var _scene: GameScene
var _pitch: float = 45.0
var _fx: float = 29.0
var _fy: float = 29.0
var _yaw: float = 0.5


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--preset="):
			_preset = a.substr(9)
		elif a.begins_with("--season="):
			GraphicsSettings.season = a.substr(9)
		elif a.begins_with("--quality="):
			GraphicsSettings.quality = a.substr(10).to_int()
		elif a.begins_with("--retro="):
			GraphicsSettings.retro = a.substr(8).to_int()
		elif a.begins_with("--zoom="):
			_zoom = a.substr(7).to_float()
		elif a.begins_with("--view="):
			var v: PackedStringArray = a.substr(7).split(",")
			_fx = v[0].to_float()
			_fy = v[1].to_float()
			_yaw = v[2].to_float()
			_pitch = v[3].to_float()
		elif a.begins_with("--frames="):
			_frames = a.substr(9).to_int()
	GraphicsSettings.load_settings()
	var defs: DefDb = DefLoader.load_default()
	var world: SimWorld = SimWorld.new(1, defs, _grid())
	world.add_player(0, "nc", false)
	world.add_player(1, "ec", true)
	world.weather.raining = false
	world.weather.fog = false
	world.weather.night = false
	world.weather.next_change = 1 << 30
	var c: int = SimGrid.CELL_MM
	world.spawn_unit(defs.units[defs.unit_index("ec_mbt_72")], 1, 1, 33 * c, 30 * c, 9000)
	world.spawn_unit(defs.units[defs.unit_index("nc_mbt_2a")], 0, 0, 27 * c, 25 * c + 3000, 30000)
	world.spawn_unit(defs.units[defs.unit_index("nc_rifle_sqd")], 0, 0, 24 * c, 29 * c, 20000)
	world.spawn_unit(defs.units[defs.unit_index("ec_ifv_2")], 1, 1, 38 * c, 36 * c, 42000)
	var st: MatchSettings = MatchSettings.new()
	st.mode = "sandbox"
	st.add_player("P", 0, "nc", false)
	st.add_player("AI", 1, "ec", true)
	_scene = GameScene.create_offline(st)
	_scene.preset_world = world
	root.add_child(_scene)


## Hand-made 64×64 cell (512 m) grid.
func _grid() -> SimGrid:
	var g: SimGrid = SimGrid.new(N, N)
	for y: int in range(N):
		for x: int in range(N):
			var i: int = g.index(x, y)
			var h: float = 12.0 + sin(x * 0.11) * 2.5 + cos(y * 0.09 + 1.0) * 3.0 + sin((x + y) * 0.05) * 2.0
			var t: int = TerrainTable.FIELD
			var lake: float = Vector2(x - 12, y - 14).length() + sin(y * 0.4) * 2.0
			if lake < 11.0:
				t = TerrainTable.WATER
				h = 8.0
			elif lake < 14.0:
				t = TerrainTable.BOG
				h = minf(h, 9.0)
			elif Vector2(x - 20, y - 40).length() < 7.0 + sin(x * 0.7) * 1.5:
				t = TerrainTable.BOG
				h = minf(h, 10.0)
			elif y > 44 or x > 50 or (y > 34 and x < 14):
				t = TerrainTable.FOREST
			elif Vector2(x - 52, y - 12).length() < 4.0:
				t = TerrainTable.ROCK
				h += 3.0
			# gravel road, gently curving south-west -> north-east
			var road_x: float = 18.0 + y * 0.55 + sin(y * 0.15) * 4.0
			if absf(x - road_x) < 1.0 and t != TerrainTable.WATER:
				t = TerrainTable.ROAD
			g.terrain[i] = t
			g.ground_mm[i] = int(h * 1000.0)
	g.rebuild_sectors()
	return g


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 2:
		_scene.runner.speed = 0
		_scene.hud.visible = false
		_scene.controller.visible = false
		_scene.views.reveal_all = true
		_scene.terrain_view().set_fog_enabled(false)
		_scene.look.force_preset(_preset)
		_scene.cam.set_distance(_zoom)
		_scene.cam.pitch_deg = _pitch
		_scene.cam.focus(Vector3(_fx * 8.0, 0, -_fy * 8.0))
		_scene.cam.rotation.y = _yaw
		_scene.cam.set_distance(_zoom)
		var post: MeshInstance3D = MeshInstance3D.new()
		post.mesh = ModelLibrary.mesh("border_post")
		post.material_override = ModelLibrary.material(4, 3)
		var p: Vector3 = Vector3(34 * 8.0 + 4.0, 0, -27 * 8.0)
		p.y = _scene.terrain_view().height_at(p)
		post.position = p
		post.rotation.y = 0.4
		_scene.add_child(post)
	if _frame == 20 and OS.get_cmdline_user_args().has("--boom"):
		var fx: Effects = _scene.views.effects
		for k: int in range(4):
			var bp: Vector3 = Vector3((26 + k * 4) * 8.0, 0, -(34 + (k % 2) * 3) * 8.0)
			bp.y = _scene.terrain_view().height_at(bp)
			fx.explosion(bp, 5.0 + k, true)
		var w: SimWorld = _scene.runner.world
		for id: int in w.entities.ids():
			if w.units.has(id) and w.def_of(id).id == "ec_ifv_2":
				var v: UnitView = _scene.views.view_of(id)
				if v != null:
					v.make_wreck(fx)
	if _out != "" and _frame >= _frames + (4 if OS.get_cmdline_user_args().has("--boom") else 0):
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved " + _out)
		quit(0)
	return false
