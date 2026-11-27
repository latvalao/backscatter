// Dark, still northern lakes and bog pools (docs/VISUALS.md §6.4): depth tint,
// fresnel sky reflection + SSR, soft shoreline, wind ripples, rain rings.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size_m = vec2(4000.0, 4000.0);
uniform float fog_enabled = 1.0;
uniform vec3 shallow : source_color = vec3(0.2, 0.24, 0.22);
uniform vec3 deep : source_color = vec3(0.06, 0.09, 0.11);
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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
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
	vec3 col = mix(shallow, deep, k);
	float foam = smoothstep(0.6, 0.0, depth) * (0.5 + 0.5 * n2);
	col = mix(col, vec3(0.62, 0.62, 0.56), foam * 0.35);
	vec2 uv = vec2(world_pos.x / map_size_m.x, -world_pos.z / map_size_m.y);
	float seen = texture(fog_tex, uv).r;
	col *= mix(1.0, mix(0.45, 1.0, seen), fog_enabled);
	ALBEDO = col;
	ROUGHNESS = 0.05 + wetness * 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(0.7 + k * 0.3, 0.0, 1.0);
}
