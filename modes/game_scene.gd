## A running match: world + lockstep (or replay) + all presentation.
## Built by the main menu (single player, LAN/Steam lobby, replay) or directly
## by tools/tests via GameScene.create_offline().
class_name GameScene
extends Node3D

signal exit_to_menu

var settings: MatchSettings
var local_player: int = 0
var runner: SimRunner
var views: ViewSync
var controller: SelectionController
var cam: RtsCamera
var hud: Hud
var transport: NetTransport
var lockstep: Lockstep
var replay_mode: bool = false
var dosimetry: DosimetryOverlay
var signals_overlay: SignalOverlay
var _saved_replay: bool = false

static var _grid_cache: Dictionary = {}


## Offline match (you + sim-side AIs).
static func create_offline(p_settings: MatchSettings) -> GameScene:
	var g: GameScene = GameScene.new()
	g.settings = p_settings
	g.local_player = 0
	g.transport = NetTransport.new()
	return g


## Networked match after the lobby started it.
static func create_networked(p_settings: MatchSettings, p_transport: NetTransport, p_local: int) -> GameScene:
	var g: GameScene = GameScene.new()
	g.settings = p_settings
	g.local_player = p_local
	g.transport = p_transport
	return g


## Watch a saved replay.
static func create_replay(data: Dictionary) -> GameScene:
	var g: GameScene = GameScene.new()
	g.settings = MatchSettings.from_dict(data["settings"])
	g.replay_mode = true
	g.set_meta("replay", data)
	return g


static func grid_for(s: MatchSettings) -> SimGrid:
	var key: String = "%d_%d" % [s.map_seed, s.map_cells]
	if not _grid_cache.has(key):
		_grid_cache[key] = MapGen.generate(s.map_seed, s.map_cells, s.map_cells)
	return _grid_cache[key]


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var grid: SimGrid = grid_for(settings)
	runner = SimRunner.new()
	if replay_mode:
		runner.replay = ReplayPlayer.new(get_meta("replay"), grid)
		runner.world = runner.replay.world
	else:
		runner.world = MatchSetup.create(settings, DefLoader.load_default(), grid)
		var humans: PackedInt32Array = Lobby.human_players(settings)
		var delay: int = 1 if humans.size() <= 1 else 3
		lockstep = Lockstep.new(runner.world, transport, local_player, humans, delay)
		lockstep.recorder = ReplayRecorder.new(settings.to_dict())
		lockstep.control_received.connect(func(spd: int) -> void: runner.speed = spd)
		lockstep.desync.connect(_on_desync)
		runner.lockstep = lockstep
	add_child(runner)
	var world: SimWorld = runner.world
	print("match ready in %d ms (%s, %d players)" % [Time.get_ticks_msec() - t0, settings.mode, settings.players.size()])

	var terrain: TerrainView = TerrainView.new()
	add_child(terrain)
	terrain.build(world.grid)

	var fx: Effects = Effects.new()
	fx.runner = runner
	fx.terrain = terrain
	add_child(fx)

	var local_team: int = world.team_of_player(local_player) if not replay_mode else 0
	views = ViewSync.new()
	views.runner = runner
	views.effects = fx
	views.local_team = local_team
	views.reveal_all = replay_mode
	add_child(views)

	var fog: FogOverlay = FogOverlay.new()
	fog.runner = runner
	fog.terrain = terrain
	fog.local_team = local_team
	add_child(fog)

	dosimetry = DosimetryOverlay.new()
	dosimetry.runner = runner
	dosimetry.terrain = terrain
	dosimetry.local_player = local_player
	add_child(dosimetry)
	signals_overlay = SignalOverlay.new()
	signals_overlay.runner = runner
	signals_overlay.terrain = terrain
	signals_overlay.local_team = local_team
	add_child(signals_overlay)

	_environment()

	cam = RtsCamera.new()
	cam.terrain = terrain
	cam.bounds = Rect2(0, -world.grid.height_mm() * 0.001, world.grid.width_mm() * 0.001, world.grid.height_mm() * 0.001)
	add_child(cam)
	_focus_start(world, local_team)

	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	controller = SelectionController.new()
	controller.runner = runner
	controller.views = views
	controller.cam = cam
	controller.lockstep = lockstep
	controller.enabled = not replay_mode
	ui.add_child(controller)
	hud = Hud.new()
	hud.runner = runner
	hud.controller = controller
	hud.views = views
	hud.scene = self
	add_child(hud)

	var geiger: Geiger = Geiger.new()
	geiger.runner = runner
	geiger.controller = controller
	add_child(geiger)

	runner.snapshot()
	fog.setup()
	dosimetry.setup()
	terrain.set_fog_enabled(not replay_mode)
	runner.ticked.connect(_on_tick)


func _focus_start(world: SimWorld, team: int) -> void:
	var best: int = 0
	for id: int in world.entities.ids():
		if world.units.has(id) and world.units.owner[id] == local_player:
			if best == 0 or (world.is_structure(id) and not world.is_structure(best)):
				best = id
	if best > 0:
		var p: Vector3 = SimRunner.sim_to_view(world.transform.x[best], world.transform.y[best], 0)
		cam.focus(p)
	cam.rotation.y = -PI * 0.5 if team == 0 else PI * 0.5


func _on_tick(_tick: int) -> void:
	if runner.world.winner_team >= 0 and not _saved_replay:
		save_replay()


func _on_desync(tick: int, details: String) -> void:
	hud.banner("DESYNC at tick %d — match halted.\n%s" % [tick, details])
	push_error(details)


func save_replay() -> String:
	if lockstep == null or lockstep.recorder == null:
		return ""
	_saved_replay = true
	var path: String = ReplayRecorder.default_path()
	lockstep.recorder.save(path)
	var stamped: String = "user://replays/%s.replay" % Time.get_datetime_string_from_system().replace(":", "-")
	lockstep.recorder.save(stamped)
	return path


## Host: pause / speed for everyone (single-player: just local).
func set_speed(spd: int) -> void:
	if replay_mode or lockstep == null or lockstep.players.size() <= 1:
		runner.speed = spd
	elif transport.is_host():
		runner.speed = spd
		lockstep.send_control(spd)


func leave() -> void:
	save_replay()
	if transport != null:
		transport.close()
	exit_to_menu.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_P, KEY_PAUSE:
			set_speed(0 if runner.speed > 0 else 1)
		KEY_EQUAL, KEY_KP_ADD:
			set_speed(mini(8 if replay_mode else 4, maxi(1, runner.speed * 2)))
		KEY_MINUS, KEY_KP_SUBTRACT:
			set_speed(maxi(1, runner.speed / 2))
		KEY_F9:
			if lockstep == null or lockstep.players.size() <= 1:
				views.reveal_all = not views.reveal_all
		KEY_F10:
			views.show_labels = not views.show_labels
		KEY_D:
			dosimetry.toggle()
		KEY_V:
			signals_overlay.toggle()
		KEY_F12:
			hud.banner("Replay saved: " + ProjectSettings.globalize_path(save_replay()))
		KEY_ESCAPE:
			if controller.mode == SelectionController.Mode.NORMAL:
				hud.toggle_menu()


func _environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 35.0, 0.0)
	sun.light_energy = 0.9
	sun.light_color = Color(0.92, 0.93, 0.97)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1200.0
	add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.60, 0.64, 0.67)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.70)
	e.ambient_light_energy = 0.45
	e.fog_enabled = true
	e.fog_light_color = Color(0.62, 0.66, 0.69)
	e.fog_density = 0.00012
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
