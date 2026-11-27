// Diorama-base terrain (docs/VISUALS.md §6.3). Vertex COLOR = blended base colour,
// UV = (forest, bog) weights, UV2 = (road, rock) weights. Painterly macro tint,
// "flocking" speckle, granite on slopes, wet bog sheen, trail map (tracks /
// craters / scorch), wetness, snow, fog of war and the dosimetry heatmap.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D rad_tex : filter_linear, repeat_disable;
uniform sampler2D trail_tex : filter_linear, repeat_disable;
uniform vec2 map_size_m = vec2(4000.0, 4000.0);
uniform float fog_enabled = 1.0;
uniform float rad_enabled = 0.0;
uniform float rad_bands = 0.0;
uniform vec3 dry_grass : source_color = vec3(0.55, 0.5, 0.3);
uniform vec3 moss : source_color = vec3(0.33, 0.4, 0.24);
uniform vec3 granite : source_color = vec3(0.49, 0.5, 0.47);
uniform vec3 needles : source_color = vec3(0.36, 0.27, 0.18);
uniform vec3 mud : source_color = vec3(0.2, 0.16, 0.11);

global uniform float wetness;
global uniform float snow_amount;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.0) * 0.3 + noise(p * 4.3 + 3.0) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
}

void fragment() {
	vec2 uv = vec2(world_pos.x / map_size_m.x, -world_pos.z / map_size_m.y);
	float forest = UV.x;
	float bog = UV.y;
	float road = UV2.x;
	float rock = UV2.y;
	vec3 col = COLOR.rgb;
	float macro = fbm(world_pos.xz * 0.006);
	float meso = fbm(world_pos.xz * 0.04);
	float fine = noise(world_pos.xz * 1.7);
	float field = clamp(1.0 - forest - bog - road - rock, 0.0, 1.0);
	// painterly macro tint: dry yellow grass patches and darker moss
	col = mix(col, dry_grass, field * smoothstep(0.55, 0.8, macro) * 0.4);
	col = mix(col, moss, field * smoothstep(0.45, 0.2, meso) * 0.45);
	col = mix(col, needles, forest * smoothstep(0.4, 0.7, meso) * 0.5);
	// flocking speckle
	col *= 0.82 + 0.3 * fine;
	// granite on slopes
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float stone = clamp(smoothstep(0.18, 0.3, slope) + rock * smoothstep(0.35, 0.6, meso + fine * 0.3), 0.0, 1.0);
	col = mix(col, granite * (0.85 + 0.3 * fine), stone);
	float rough = 0.95;
	// bog: dark, with standing-water sheen in hollows
	float puddle = bog * smoothstep(0.62, 0.72, meso + fine * 0.1);
	col = mix(col, col * 0.5, bog * 0.3 + puddle * 0.5);
	rough = mix(rough, 0.35, puddle);
	// road: a crisp gravel band with darker wheel ruts instead of a soft smear
	float rd = smoothstep(0.32, 0.55, road);
	vec3 gravel = vec3(0.47, 0.44, 0.38) * (0.9 + 0.2 * noise(world_pos.xz * 6.0));
	col = mix(col, gravel, rd);
	float ruts = smoothstep(0.55, 0.9, road) * smoothstep(0.35, 0.5, noise(world_pos.xz * vec2(0.6, 0.6)));
	col = mix(col, col * 0.78, ruts * 0.4);
	rough = mix(rough, 0.85, rd);
	// trail map: tracks (R) and craters / scorch (G)
	vec2 trail = texture(trail_tex, uv).rg;
	float soft = clamp(field * 0.6 + bog + forest * 0.4, 0.2, 1.0);
	col = mix(col, mud * (0.8 + 0.4 * fine), clamp(trail.r * soft * 0.85, 0.0, 0.85));
	rough = mix(rough, 0.5, trail.r * bog);
	col = mix(col, vec3(0.06, 0.05, 0.045), clamp(trail.g * (0.7 + 0.3 * fine), 0.0, 0.9));
	// weather
	col *= mix(1.0, 0.6, wetness);
	rough = mix(rough, rough * 0.55, wetness);
	float snow = snow_amount * smoothstep(0.25, 0.05, slope) * (1.0 - trail.r * 0.9) * (1.0 - trail.g);
	snow *= smoothstep(0.2, 0.45, macro * 0.5 + 0.35 + fine * 0.2) * (1.0 - bog * 0.4);
	col = mix(col, vec3(0.7, 0.73, 0.78), clamp(snow * 1.3, 0.0, 1.0));
	// fog of war
	float seen = texture(fog_tex, uv).r;
	float f = mix(1.0, mix(0.62, 1.0, seen), fog_enabled);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), (1.0 - seen) * fog_enabled * 0.55);
	col *= f;
	if (rad_enabled > 0.5) {
		float r = texture(rad_tex, uv).r;
		if (rad_bands > 0.5) { r = floor(r * 5.0) / 5.0; }
		float a = smoothstep(0.25, 0.45, r);
		vec3 heat = mix(vec3(0.95, 0.9, 0.2), vec3(0.95, 0.35, 0.1), smoothstep(0.45, 0.7, r));
		heat = mix(heat, vec3(0.85, 0.1, 0.6), smoothstep(0.75, 0.95, r));
		col = mix(col, heat, a * 0.65);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
