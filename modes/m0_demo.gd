## M0 demo scene: 100 wandering placeholder units on a 4×4 km plane, driven by
## the deterministic sim through SpawnDebugUnitCommand. HUD shows tick + checksum.
extends Node3D

const SEED: int = 20261127
const UNITS: int = 100

var _runner: SimRunner
var _label: Label


func _ready() -> void:
	var world: SimWorld = SimWorld.new(SEED)
	var setup: SimRng = SimRng.new(SEED)
	var cx: int = world.map_width_mm / 2
	var cy: int = world.map_height_mm / 2
	for i: int in range(UNITS):
		var c: SpawnDebugUnitCommand = SpawnDebugUnitCommand.new(
			cx + setup.range_int(-300_000, 300_000),
			cy + setup.range_int(-300_000, 300_000),
			i % 2, setup.range_int(300, 1200), setup.range_int(10, 40))
		c.player_id = i % 2
		c.sequence = i
		c.tick = 0
		world.queue_command(c)

	_runner = SimRunner.new()
	_runner.world = world
	add_child(_runner)

	var views: ViewSync = ViewSync.new()
	views.runner = _runner
	add_child(views)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4000.0, 4000.0)
	ground.mesh = plane
	ground.position = Vector3(2000.0, 0.0, -2000.0)
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.32, 0.36, 0.30)
	ground.material_override = gmat
	add_child(ground)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.8
	add_child(sun)

	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.66, 0.68)
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var cam: RtsCamera = RtsCamera.new()
	cam.position = Vector3(2000.0, 0.0, -2000.0)
	add_child(cam)

	var hud: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(12.0, 8.0)
	hud.add_child(_label)
	add_child(hud)


func _process(_delta: float) -> void:
	var w: SimWorld = _runner.world
	_label.text = "tick %d   entities %d   checksum@%d %08x   [1-4 speed, P pause]   %d FPS" % [
		w.tick, w.entities.count(), w.last_checksum_tick, w.last_checksum, Engine.get_frames_per_second()]


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_P:
			_runner.speed = 0 if _runner.speed > 0 else 1
		KEY_1:
			_runner.speed = 1
		KEY_2:
			_runner.speed = 2
		KEY_3, KEY_4:
			_runner.speed = 4
