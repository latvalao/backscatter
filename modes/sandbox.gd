## M1/M2 sandbox: procedural 4×4 km map, a Coalition battle group (you) and an
## Eastern battle group driven by a scripted placeholder opponent (real AI is M7).
## Everything goes through SimCommands, so this is lockstep-ready.
extends Node3D

const MAP_SEED: int = 7
const MATCH_SEED: int = 20261127
const NC_FORCE: Array[String] = ["nc_mbt_2a", "nc_mbt_2a", "nc_mbt_2a", "nc_mbt_2a", "nc_ifv_90", "nc_ifv_90",
	"nc_ifv_90", "nc_ifv_90", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd",
	"nc_rifle_sqd", "nc_atgm_team", "nc_atgm_team", "nc_recon_team", "nc_recon_team", "nc_mortar_team",
	"nc_mortar_team", "nc_spg_155", "nc_spg_155", "nc_supply_truck", "nc_supply_truck"]
const EC_FORCE: Array[String] = ["ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72",
	"ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_motor_rifle", "ec_motor_rifle",
	"ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle",
	"ec_rpg_team", "ec_rpg_team", "ec_rpg_team", "ec_recon_sqd", "ec_recon_sqd", "ec_mortar_team", "ec_mortar_team",
	"ec_spg_122", "ec_spg_122"]

var runner: SimRunner
var views: ViewSync
var controller: SelectionController
var cam: RtsCamera
var _enemy: LocalCommandSink
var _enemy_ids: PackedInt32Array = PackedInt32Array()
var _enemy_phase: int = 0


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var grid: SimGrid = MapGen.generate(MAP_SEED, 500, 500)
	var world: SimWorld = SimWorld.new(MATCH_SEED, DefLoader.load_default(), grid)
	world.add_player(0)
	world.add_player(1)
	print("map generated in %d ms" % (Time.get_ticks_msec() - t0))

	runner = SimRunner.new()
	runner.world = world
	add_child(runner)

	var terrain: TerrainView = TerrainView.new()
	add_child(terrain)
	terrain.build(grid)

	var fx: Effects = Effects.new()
	fx.runner = runner
	fx.terrain = terrain
	add_child(fx)

	views = ViewSync.new()
	views.runner = runner
	views.effects = fx
	add_child(views)

	var fog: FogOverlay = FogOverlay.new()
	fog.runner = runner
	fog.terrain = terrain
	add_child(fog)

	_environment()

	cam = RtsCamera.new()
	cam.terrain = terrain
	cam.bounds = Rect2(0, -grid.height_mm() * 0.001, grid.width_mm() * 0.001, grid.height_mm() * 0.001)
	add_child(cam)
	cam.focus(Vector3(700, 0, -2000))
	cam.rotation.y = -PI * 0.5  # look east

	var player: LocalCommandSink = LocalCommandSink.new(world, 0)
	_enemy = LocalCommandSink.new(world, 1)
	_spawn_forces(player)

	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	controller = SelectionController.new()
	controller.runner = runner
	controller.views = views
	controller.cam = cam
	controller.sink = player
	ui.add_child(controller)
	var hud: Hud = Hud.new()
	hud.runner = runner
	hud.controller = controller
	hud.views = views
	add_child(hud)

	world.step()  # apply spawns
	runner.snapshot()
	fog.setup()
	runner.ticked.connect(_on_tick)


func _spawn_forces(player: LocalCommandSink) -> void:
	for i: int in range(NC_FORCE.size()):
		var x: int = (500 + (i / 6) * 60) * 1000
		var y: int = (1850 + (i % 6) * 60) * 1000
		player.submit(SpawnUnitCommand.new(NC_FORCE[i], x, y, 0))
	for i: int in range(EC_FORCE.size()):
		var x: int = (3500 - (i / 7) * 60) * 1000
		var y: int = (1800 + (i % 7) * 60) * 1000
		_enemy.submit(SpawnUnitCommand.new(EC_FORCE[i], x, y, SimConst.ANGLE_HALF))


## Scripted placeholder opponent: waits, then advances in two echelons.
func _on_tick(tick: int) -> void:
	var w: SimWorld = runner.world
	if _enemy_ids.is_empty() and tick > 2:
		for id: int in w.entities.ids():
			if w.units.has(id) and w.units.owner[id] == 1:
				_enemy_ids.append(id)
	var alive: PackedInt32Array = PackedInt32Array()
	var arty: PackedInt32Array = PackedInt32Array()
	for id: int in _enemy_ids:
		if w.is_unit(id):
			if w.def_of(id).role == "artillery" or w.def_of(id).role == "indirect":
				arty.append(id)
			else:
				alive.append(id)
	if _enemy_phase == 0 and tick >= 900:
		_enemy.submit(MoveCommand.new(alive, 2_300_000, 2_000_000, MoveCommand.MODE_ATTACK_MOVE))
		_enemy_phase = 1
	elif _enemy_phase == 1 and tick >= 3000:
		_enemy.submit(MoveCommand.new(alive, 900_000, 2_000_000, MoveCommand.MODE_ATTACK_MOVE))
		_enemy_phase = 2
	# barrage whatever the enemy team can see, every 40 s
	if tick % 400 == 200 and not arty.is_empty():
		var vis: PackedInt32Array = w.visible_enemies[1]
		if not vis.is_empty():
			var tgt: int = vis[0]
			_enemy.submit(FireMissionCommand.new(arty, w.transform.x[tgt], w.transform.y[tgt], 4))


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_P:
			runner.speed = 0 if runner.speed > 0 else 1
		KEY_EQUAL, KEY_KP_ADD:
			runner.speed = mini(4, maxi(1, runner.speed * 2))
		KEY_MINUS, KEY_KP_SUBTRACT:
			runner.speed = maxi(1, runner.speed / 2)
		KEY_F9:
			views.reveal_all = not views.reveal_all
		KEY_F10:
			views.show_labels = not views.show_labels


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
