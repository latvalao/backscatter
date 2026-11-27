## Quality presets (docs/VISUALS.md §12) and accessibility toggles, saved to
## user://graphics.cfg. Applied by LookDirector / TerrainView / RtsCamera.
class_name GraphicsSettings
extends RefCounted

enum Quality { LOW, MEDIUM, HIGH, ULTRA }
const NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
const PATH: String = "user://graphics.cfg"

static var quality: int = Quality.HIGH
static var tilt_shift: bool = true
static var grain: bool = true
static var season: String = "autumn"   # autumn | winter
static var time_of_day: String = "auto" # auto | golden_afternoon | overcast | dawn_mist | dusk | night | storm
## Volumes 0..1 for the Master / Effects / Ambient / Radio buses.
static var volumes: Dictionary = {"Master": 0.8, "Effects": 0.9, "Ambient": 0.6, "Radio": 0.8}
## Rebound keys: action -> keycode (see KeyBindings.ACTIONS).
static var keys: Dictionary = {}
static var _loaded: bool = false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	quality = int(cf.get_value("gfx", "quality", quality))
	tilt_shift = bool(cf.get_value("gfx", "tilt_shift", tilt_shift))
	grain = bool(cf.get_value("gfx", "grain", grain))
	season = str(cf.get_value("gfx", "season", season))
	time_of_day = str(cf.get_value("gfx", "time_of_day", time_of_day))
	var vol: Variant = cf.get_value("audio", "volumes", volumes)
	if typeof(vol) == TYPE_DICTIONARY:
		volumes = vol
	var k: Variant = cf.get_value("input", "keys", keys)
	if typeof(k) == TYPE_DICTIONARY:
		keys = k


static func save_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("gfx", "quality", quality)
	cf.set_value("gfx", "tilt_shift", tilt_shift)
	cf.set_value("gfx", "grain", grain)
	cf.set_value("gfx", "season", season)
	cf.set_value("gfx", "time_of_day", time_of_day)
	cf.set_value("audio", "volumes", volumes)
	cf.set_value("input", "keys", keys)
	cf.save(PATH)


## Creates the audio buses if needed and applies the saved volumes.
static func apply_audio() -> void:
	for bus: String in ["Effects", "Ambient", "Radio"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for bus2: String in volumes.keys():
		var i: int = AudioServer.get_bus_index(bus2)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, float(volumes[bus2]))))


static func cycle_quality() -> void:
	quality = (quality + 1) % 4
	save_settings()


## Foliage instances per forest cell.
static func trees_per_cell() -> int:
	return [1, 2, 2, 3][quality]


## Distance (m) where trees switch to the far mesh.
static func tree_lod_distance() -> float:
	return [350.0, 550.0, 750.0, 1000.0][quality]


static func apply_environment(e: Environment, sun: DirectionalLight3D) -> void:
	e.ssao_enabled = true
	e.ssao_radius = 2.5
	e.ssao_intensity = 1.6
	e.ssil_enabled = quality >= Quality.MEDIUM
	e.ssr_enabled = quality >= Quality.HIGH
	e.ssr_max_steps = 48
	e.volumetric_fog_enabled = quality >= Quality.HIGH
	e.sdfgi_enabled = quality >= Quality.ULTRA
	if sun != null:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= Quality.MEDIUM else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = [800.0, 1200.0, 1600.0, 2200.0][quality]
		sun.shadow_blur = 1.5
