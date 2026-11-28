// Dark, still northern lakes and bog pools (docs/VISUALS.md §6.4): depth tint,
// fresnel sky reflection + SSR, soft shoreline, wind ripples, rain rings.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D cells_tex : filter_nearest, repeat_disable;
uniform vec2 map_size_m = vec2(4000.0, 4000.0);
uniform float fog_enabled = 1.0;
uniform vec3 shallow : source_color = vec3(0.24, 0.31, 0.29);
uniform vec3 deep : source_color = vec3(0.07, 0.12, 0.15);
uniform vec3 sky_tint : source_color = vec3(0.62, 0.68, 0.72);
global uniform float wetness;
global uniform vec2 wind_vec;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}


// Smooth lake mask from the per-cell water flag (cells_tex alpha): a wide
// blur of bilinear taps (rounds the 8 m cell grid off), then wobbled with
// noise near the water so shores curve naturally.
float water_bilerp(vec2 g, ivec2 sz) {
	ivec2 b = ivec2(floor(g));
	vec2 t = fract(g);
	float a00 = texelFetch(cells_tex, clamp(b, ivec2(0), sz - 1), 0).a;
	float a10 = texelFetch(cells_tex, clamp(b + ivec2(1, 0), ivec2(0), sz - 1), 0).a;
	float a01 = texelFetch(cells_tex, clamp(b + ivec2(0, 1), ivec2(0), sz - 1), 0).a;
	float a11 = texelFetch(cells_tex, clamp(b + ivec2(1, 1), ivec2(0), sz - 1), 0).a;
	return mix(mix(a00, a10, t.x), mix(a01, a11, t.x), t.y);
}

float shore_weight(vec2 wxz, vec2 map_m) {
	ivec2 sz = textureSize(cells_tex, 0);
	vec2 g = vec2(wxz.x, -wxz.y) / map_m * vec2(sz) - 0.5;
	float w = water_bilerp(g, sz) * 0.36;
	w += water_bilerp(g + vec2(0.8, 0.0), sz) * 0.16;
	w += water_bilerp(g - vec2(0.8, 0.0), sz) * 0.16;
	w += water_bilerp(g + vec2(0.0, 0.8), sz) * 0.16;
	w += water_bilerp(g - vec2(0.0, 0.8), sz) * 0.16;
	float near = smoothstep(0.02, 0.25, w) * (1.0 - smoothstep(0.75, 0.98, w));
	return w + ((noise(wxz * 0.045) - 0.5) * 0.3 + (noise(wxz * 0.3 + 7.0) - 0.5) * 0.08) * near;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float sw = shore_weight(world_pos.xz, map_size_m);
	if (sw < 0.5) {
		discard;
	}
	float edge = smoothstep(0.5, 0.75, sw);   // 0 at the waterline, 1 well offshore
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vp.xyz /= vp.w;
	float depth = clamp(-vp.z - (-VERTEX.z), 0.0, 40.0);
	float k = 1.0 - exp(-depth * 0.35);
	vec2 flow = wind_vec * TIME * 0.05;
	float n1 = noise(world_pos.xz * 0.35 + flow);
	float n2 = noise(world_pos.xz * 0.9 - flow * 1.7);
	float rain = 0.0;
	if (wetness > 0.05) {
		vec2 cell = floor(world_pos.xz * 0.8);
		float t = fract(TIME * 0.9 + hash(cell));
		float r = length(fract(world_pos.xz * 0.8) - 0.5);
		rain = smoothstep(0.06, 0.0, abs(r - t * 0.5)) * (1.0 - t) * wetness;
	}
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.06 + (n2 - 0.5) * 0.04 + rain * 0.3, 1.0, (n2 - n1) * 0.06 + rain * 0.3));
	NORMAL = (VIEW_MATRIX * vec4(nrm, 0.0)).xyz;
	// tint from the smooth distance to shore, not the (cell-shaped) bed depth
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, edge));
	// broad wind streaks and cat's-paws so open water isn't a flat disc
	float streak = noise(vec2(world_pos.x * 0.02 + world_pos.z * 0.05, world_pos.z * 0.012) + flow * 0.3);
	col *= 0.9 + 0.22 * smoothstep(0.35, 0.75, streak);
	// sky reflection, stronger at grazing angles
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_tint * 0.55, 0.12 + fres * 0.45);
	// foam line along the shore
	float foam = (1.0 - smoothstep(0.0, 0.06, sw - 0.5)) * (0.55 + 0.45 * n2) * (1.0 - k * 0.0);
	col = mix(col, vec3(0.72, 0.74, 0.72), foam * 0.55);
	vec2 uv = vec2(world_pos.x / map_size_m.x, -world_pos.z / map_size_m.y);
	float seen = texture(fog_tex, uv).r;
	col *= mix(1.0, mix(0.45, 1.0, seen), fog_enabled);
	ALBEDO = col;
	ROUGHNESS = 0.05 + wetness * 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(0.8 + edge * 0.2, 0.0, 1.0);
}
