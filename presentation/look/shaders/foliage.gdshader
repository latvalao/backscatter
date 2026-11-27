// Foliage (docs/VISUALS.md §7): palette colour with per-instance hue/brightness
// variation (INSTANCE_CUSTOM), wind sway driven by the sim wind, seasonal tint
// (autumn gold -> bare birch + snow-laden pines), soft back-lighting, and a
// canopy dither-fade around selected units / the camera focus (readability).
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform vec4 fade_points[8];
uniform int fade_count = 0;
uniform float sway_scale = 1.0;
global uniform vec2 wind_vec;
global uniform float season;
global uniform float snow_amount;
global uniform float wetness;

varying vec3 world_pos;
varying float local_h;
varying vec3 tint;

void vertex() {
	local_h = VERTEX.y;
	float h = clamp(VERTEX.y / 16.0, 0.0, 1.2);
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float w = length(wind_vec);
	vec2 dir = w > 0.01 ? wind_vec / w : vec2(1.0, 0.0);
	float sway = (0.6 + 0.4 * sin(TIME * (0.9 + w * 0.08) + phase) + 0.15 * sin(TIME * 3.1 + phase * 3.0)) * (0.15 + w * 0.06) * h * h * sway_scale;
	vec3 off = vec3(dir.x, 0.0, dir.y) * sway;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = vec3(INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w);
}

void fragment() {
	int col = int(floor(UV.x * 16.0));
	bool leaf = col == 2 || col == 7;
	bool needle = col == 0 || col == 1;
	if (leaf && season > 0.5) {
		discard;  // winter: bare birch and aspen
	}
	vec3 c = texture(palette, UV).rgb;
	// per-instance variation: hue shift toward green/gold, brightness
	c *= 0.8 + tint.x * 0.4;
	c = mix(c, c * vec3(1.08, 1.0, 0.85), tint.y - 0.5);
	c *= mix(1.0, COLOR.r, 0.6);
	float rough = 0.9;
	if (needle || leaf) {
		BACKLIGHT = c * 0.35;
	}
	c *= mix(1.0, 0.7, wetness);
	float up = clamp((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y, 0.0, 1.0);
	c = mix(c, vec3(0.7, 0.73, 0.78), smoothstep(0.35, 0.8, up) * snow_amount * (needle ? 0.85 : 0.5));
	for (int i = 0; i < fade_count; i++) {
		vec4 fp = fade_points[i];
		float dd = length(world_pos.xz - fp.xz);
		if (dd < fp.w && local_h > 2.5) {
			float k = smoothstep(fp.w, fp.w * 0.5, dd);
			float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) * 2.0 + floor(FRAGCOORD.y) * 0.37);
			if (dither < k * 0.85) {
				discard;
			}
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	AO = COLOR.r;
	AO_LIGHT_AFFECT = 0.5;
}
