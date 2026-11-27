## One lighting / atmosphere / grading preset (docs/VISUALS.md §4, §5, §8.2).
## Stored as .tres under res://presentation/look/presets/ and blended at
## runtime by LookDirector according to the sim's weather and time of day.
class_name LookPreset
extends Resource

@export var sun_elevation_deg: float = 25.0
@export var sun_azimuth_deg: float = 220.0
@export var sun_color: Color = Color(1.0, 0.9, 0.78)
@export var sun_energy: float = 1.3
@export var sky_top: Color = Color(0.45, 0.58, 0.72)
@export var sky_horizon: Color = Color(0.78, 0.8, 0.78)
@export var ground_color: Color = Color(0.25, 0.26, 0.22)
@export var ambient_energy: float = 0.7
@export var fog_color: Color = Color(0.72, 0.75, 0.74)
@export var fog_density: float = 0.00018
@export var fog_sun_scatter: float = 0.15
@export var volumetric_density: float = 0.002
@export var volumetric_albedo: Color = Color(0.85, 0.86, 0.86)
@export var bog_mist: float = 0.0
@export var exposure: float = 1.0
@export var glow: float = 0.25
@export var grade_shadows: Color = Color(0.92, 0.97, 1.08)
@export var grade_highlights: Color = Color(1.07, 1.0, 0.9)
@export var saturation: float = 0.95
@export var contrast: float = 1.05
@export var stars: float = 0.0
@export var aurora: float = 0.0
@export var grain: float = 0.035
@export var vignette: float = 0.25


func blend(other: LookPreset, t: float) -> LookPreset:
	var o: LookPreset = LookPreset.new()
	for p: Dictionary in get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var n: StringName = p["name"]
		var a: Variant = get(n)
		var b: Variant = other.get(n)
		if a is float:
			o.set(n, lerpf(float(a), float(b), t))
		elif a is Color:
			o.set(n, (a as Color).lerp(b as Color, t))
	# azimuth wraps
	o.sun_azimuth_deg = rad_to_deg(lerp_angle(deg_to_rad(sun_azimuth_deg), deg_to_rad(other.sun_azimuth_deg), t))
	return o
