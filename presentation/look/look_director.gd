## Owns the WorldEnvironment, sun, sky, colour-grading LUT, screen post pass,
## rain and the global weather uniforms. Each frame it picks a LookPreset from
## the sim's weather (night / rain / fog / clear) and blends towards it, so the
## look follows the same weather that drives fallout and optics. Read-only.
class_name LookDirector
extends Node

const PRESET_DIR: String = "res://presentation/look/presets/"
const BLEND_PER_S: float = 0.25

var runner: SimRunner
var camera_rig: Node3D            # RtsCamera (position = ground focus)
var base_preset: String = "golden_afternoon"

var env: Environment
var sun: DirectionalLight3D
var current: LookPreset
var _target_name: String = ""
var _target: LookPreset
var _from: LookPreset
var _t: float = 1.0
var _sky_mat: ShaderMaterial
var _post: ShaderMaterial
var _rain: GPUParticles3D
var _wet: float = 0.0
var _lut_timer: float = 0.0
var _clock: float = 0.0
var _presets: Dictionary = {}
## Current view-space wind (m/s, x east / y south) for particles.
static var wind: Vector2 = Vector2(1, 0)
var dose_grain: float = 0.0    # set by GameScene from the dose rate under the camera


func _ready() -> void:
	GraphicsSettings.load_settings()
	if GraphicsSettings.time_of_day != "auto":
		base_preset = GraphicsSettings.time_of_day
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	add_child(sun)
	var we: WorldEnvironment = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://presentation/look/shaders/sky.gdshader") as Shader
	sky.sky_material = _sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.6
	env.volumetric_fog_length = 900.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_anisotropy = 0.5
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	GraphicsSettings.apply_environment(env, sun)
	we.environment = env
	add_child(we)
	# screen post (grain / vignette) below the HUD layer
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = load("res://presentation/look/shaders/post.gdshader") as Shader
	_post.set_shader_parameter("palette_lut", retro_lut())
	apply_retro()
	rect.material = _post
	layer.add_child(rect)
	_build_rain()
	current = preset(base_preset)
	_target = current
	_target_name = base_preset
	_apply(current, true)
	RenderingServer.global_shader_parameter_set("snow_amount", 1.0 if GraphicsSettings.season == "winter" else 0.0)
	RenderingServer.global_shader_parameter_set("season", 1.0 if GraphicsSettings.season == "winter" else 0.0)


## Retro filter strengths for the current setting; pixel blocks scale with
## the window so the look holds at 1440p and 4K.
func apply_retro() -> void:
	var lvl: int = GraphicsSettings.retro
	var h: float = get_viewport().get_visible_rect().size.y if is_inside_tree() else 900.0
	var px: float = [1.0, 2.0, 3.0][lvl] * maxf(1.0, roundf(h / 900.0))
	_post.set_shader_parameter("pixel_size", px)
	_post.set_shader_parameter("palette_amount", [0.0, 0.55, 0.9][lvl])
	_post.set_shader_parameter("dither_amount", [0.0, 0.7, 1.0][lvl])
	_post.set_shader_parameter("outline_amount", [0.0, 0.35, 0.55][lvl])


## The palette cube (tools/gen_retro_lut.py): 32 tiles of 32 x 32 -> 3D texture.
static func retro_lut() -> ImageTexture3D:
	var src: Texture2D = load("res://presentation/look/retro_lut.png") as Texture2D
	var tex: ImageTexture3D = ImageTexture3D.new()
	if src == null:
		return tex
	var img: Image = src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var slices: Array[Image] = []
	for b: int in range(32):
		slices.append(img.get_region(Rect2i(b * 32, 0, 32, 32)))
	tex.create(Image.FORMAT_RGB8, 32, 32, 32, false, slices)
	return tex


func preset(name: String) -> LookPreset:
	if not _presets.has(name):
		var p: String = PRESET_DIR + name + ".tres"
		_presets[name] = load(p) as LookPreset if ResourceLoader.exists(p) else LookPreset.new()
	return _presets[name]


## Weather -> preset name.
func wanted_preset() -> String:
	if runner == null or runner.world == null:
		return base_preset
	var w: Weather = runner.world.weather
	if w.night:
		return "night"
	if w.raining:
		return "storm"
	if w.fog:
		return "dawn_mist"
	return base_preset


## Tools: keep this preset regardless of the sim weather.
var locked: bool = false


func force_preset(name: String) -> void:
	locked = true
	base_preset = name
	current = preset(name)
	_target = current
	_target_name = name
	_t = 1.0
	_apply(current, true)


var _retro_applied: int = -1


func _process(delta: float) -> void:
	_clock += delta
	if _retro_applied != GraphicsSettings.retro:
		_retro_applied = GraphicsSettings.retro
		apply_retro()
	var want: String = base_preset if locked else wanted_preset()
	if want != _target_name:
		_from = current
		_target = preset(want)
		_target_name = want
		_t = 0.0
	if _t < 1.0:
		_t = minf(1.0, _t + delta * BLEND_PER_S)
		current = _from.blend(_target, smoothstep(0.0, 1.0, _t))
		_lut_timer -= delta
		var lut_now: bool = _lut_timer <= 0.0 or _t >= 1.0
		if lut_now:
			_lut_timer = 0.5
		_apply(current, lut_now)
	_sky_mat.set_shader_parameter("clock", _clock)
	_weather(delta)


func _weather(delta: float) -> void:
	var raining: bool = false
	var wind: Vector2 = Vector2(1, 0)
	if runner != null and runner.world != null:
		var w: Weather = runner.world.weather
		raining = w.raining
		var a: float = float(w.wind_dir) / SimConst.ANGLE_FULL * TAU
		# sim: CCW from east, y north -> view x east, -z north
		wind = Vector2(cos(a), -sin(a)) * (w.wind_speed * 0.001)
	_wet = move_toward(_wet, 1.0 if raining else 0.0, delta * (0.08 if raining else 0.02))
	RenderingServer.global_shader_parameter_set("wetness", _wet)
	RenderingServer.global_shader_parameter_set("wind_vec", wind)
	LookDirector.wind = wind
	if _rain != null:
		_rain.emitting = raining
		if camera_rig != null:
			var cam: Camera3D = get_viewport().get_camera_3d()
			if cam != null:
				var focus: Vector3 = camera_rig.global_position
				_rain.global_position = focus.lerp(cam.global_position, 0.35) + Vector3(0, 40, 0)
		var pm: ParticleProcessMaterial = _rain.process_material as ParticleProcessMaterial
		pm.direction = Vector3(wind.x * 0.08, -1.0, wind.y * 0.08)
	_post.set_shader_parameter("grain", (current.grain if GraphicsSettings.grain else 0.0) + dose_grain)
	_post.set_shader_parameter("speckle", 0.0 if GraphicsSettings.retro == 0 else dose_grain * 12.0)


func _apply(p: LookPreset, rebuild_lut: bool) -> void:
	sun.rotation_degrees = Vector3(-p.sun_elevation_deg, p.sun_azimuth_deg, 0.0)
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	_sky_mat.set_shader_parameter("sky_top", p.sky_top)
	_sky_mat.set_shader_parameter("sky_horizon", p.sky_horizon)
	_sky_mat.set_shader_parameter("ground_color", p.ground_color)
	_sky_mat.set_shader_parameter("sun_tint", p.sun_color)
	_sky_mat.set_shader_parameter("stars", p.stars)
	_sky_mat.set_shader_parameter("aurora", p.aurora)
	env.ambient_light_energy = p.ambient_energy
	env.ambient_light_sky_contribution = 0.85
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.fog_sun_scatter = p.fog_sun_scatter
	env.volumetric_fog_density = p.volumetric_density
	env.volumetric_fog_albedo = p.volumetric_albedo
	env.tonemap_exposure = p.exposure
	env.glow_intensity = p.glow
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	_post.set_shader_parameter("vignette", p.vignette)
	if rebuild_lut:
		env.adjustment_color_correction = build_lut(p)


## Colour-grading LUT (17³): warm highlights, cool shadows, saturation that
## rolls off in the highlights, gentle contrast curve (§3.2).
static func build_lut(p: LookPreset) -> ImageTexture3D:
	const N: int = 17
	var images: Array[Image] = []
	for b: int in range(N):
		var img: Image = Image.create(N, N, false, Image.FORMAT_RGB8)
		for g: int in range(N):
			for r: int in range(N):
				var c: Color = Color(r / float(N - 1), g / float(N - 1), b / float(N - 1))
				var l: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var tint: Color = p.grade_shadows.lerp(p.grade_highlights, smoothstep(0.15, 0.75, l))
				var o: Color = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b)
				var l2: float = o.r * 0.299 + o.g * 0.587 + o.b * 0.114
				var sat: float = p.saturation * lerpf(1.0, 0.75, smoothstep(0.65, 1.0, l2))
				o = Color(lerpf(l2, o.r, sat), lerpf(l2, o.g, sat), lerpf(l2, o.b, sat))
				o.r = clampf((o.r - 0.5) * p.contrast + 0.5, 0.0, 1.0)
				o.g = clampf((o.g - 0.5) * p.contrast + 0.5, 0.0, 1.0)
				o.b = clampf((o.b - 0.5) * p.contrast + 0.5, 0.0, 1.0)
				img.set_pixel(r, g, o)
		images.append(img)
	var tex: ImageTexture3D = ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, N, N, N, false, images)
	return tex


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 6000 if GraphicsSettings.quality >= GraphicsSettings.Quality.HIGH else 2500
	_rain.lifetime = 1.2
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-300, -120, -300), Vector3(600, 200, 600))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(260, 10, 260)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 55.0
	pm.initial_velocity_max = 65.0
	pm.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = pm
	var streak: QuadMesh = QuadMesh.new()
	streak.size = Vector2(0.05, 2.2)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.8, 0.85, 0.9, 0.35)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.material = sm
	_rain.draw_pass_1 = streak
	add_child(_rain)
