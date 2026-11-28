// Diorama-base terrain (docs/VISUALS.md §6.3). Vertex COLOR = blended base colour,
// UV = (forest, bog) weights, UV2 = (road, rock) weights. Painterly macro tint,
// "flocking" speckle, granite on slopes, wet bog sheen, trail map (tracks /
// craters / scorch), wetness, snow, fog of war and the dosimetry heatmap.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D rad_tex : filter_linear, repeat_disable;
uniform sampler2D trail_tex : filter_linear, repeat_disable;
uniform sampler2D cells_tex : filter_nearest, repeat_disable;
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

// smooth 0..1 step across `edge` with screen-space antialiasing
float aa(float x, float edge) {
	float w = max(fwidth(x), 0.0005);
	return smoothstep(edge - w, edge + w, x);
}

vec4 cell_at(ivec2 c, ivec2 sz) {
	return texelFetch(cells_tex, clamp(c, ivec2(0), sz - 1), 0);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.0) * 0.3 + noise(p * 4.3 + 3.0) * 0.15;
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
	// meadow: lush, dry and heathy patches, mown-looking streaks, darker
	// clumps and the odd speck of flowers, so grass never reads as flat paint
	vec3 lush = vec3(0.29, 0.41, 0.19);
	vec3 heath = vec3(0.43, 0.37, 0.24);
	col = mix(col, lush, field * smoothstep(0.35, 0.6, meso) * 0.5);
	col = mix(col, dry_grass, field * smoothstep(0.55, 0.8, macro) * 0.5);
	col = mix(col, heath, field * smoothstep(0.62, 0.85, fbm(world_pos.xz * 0.018 + 11.0)) * 0.45);
	col = mix(col, moss, field * smoothstep(0.45, 0.2, meso) * 0.35);
	float ang = meso * 3.0;
	vec2 sp = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * world_pos.xz;
	float streak = noise(sp * vec2(7.0, 1.3));
	col *= 1.0 + field * (streak - 0.5) * 0.22;
	float clump = smoothstep(0.62, 0.8, noise(world_pos.xz * 0.8 + 3.0));
	col = mix(col, col * vec3(0.72, 0.8, 0.68), field * clump * 0.6);
	float fl = step(0.992, hash(floor(world_pos.xz * 2.5))) * field * smoothstep(0.4, 0.6, meso);
	col = mix(col, mix(vec3(0.85, 0.8, 0.45), vec3(0.82, 0.82, 0.8), step(0.5, hash(floor(world_pos.xz * 2.5) + 5.0))), fl * 0.7);
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
	// streets from the per-cell texture (R road, G urban, B paved):
	// town streets get asphalt, sidewalks, curbs and lane dashes; country
	// roads stay gravel with ruts; town plots are gardens or paved yards
	ivec2 csz = textureSize(cells_tex, 0);
	vec2 gc = vec2(world_pos.x, -world_pos.z) / map_size_m * vec2(csz);
	ivec2 ci = ivec2(floor(gc));
	vec2 cf = fract(gc);
	vec4 cc = cell_at(ci, csz);
	float nE = cell_at(ci + ivec2(1, 0), csz).r;
	float nW = cell_at(ci + ivec2(-1, 0), csz).r;
	float nN = cell_at(ci + ivec2(0, 1), csz).r;
	float nS = cell_at(ci + ivec2(0, -1), csz).r;
	if (cc.r > 0.5 && cc.b > 0.5) {
		float asph_n = fbm(world_pos.xz * 0.15);
		vec3 asphalt = vec3(0.2, 0.2, 0.205) * (0.85 + 0.3 * asph_n) * (0.92 + 0.16 * fine);
		asphalt = mix(asphalt, vec3(0.27, 0.26, 0.25), smoothstep(0.66, 0.7, noise(world_pos.xz * 0.21)) * 0.6);
		float sw = 0.0;
		const float SW = 0.19;
		sw = max(sw, (1.0 - nE) * aa(cf.x, 1.0 - SW));
		sw = max(sw, (1.0 - nW) * (1.0 - aa(cf.x, SW)));
		sw = max(sw, (1.0 - nN) * aa(cf.y, 1.0 - SW));
		sw = max(sw, (1.0 - nS) * (1.0 - aa(cf.y, SW)));
		// block corners poking into an intersection
		float dNE = cell_at(ci + ivec2(1, 1), csz).r;
		float dNW = cell_at(ci + ivec2(-1, 1), csz).r;
		float dSE = cell_at(ci + ivec2(1, -1), csz).r;
		float dSW = cell_at(ci + ivec2(-1, -1), csz).r;
		sw = max(sw, (1.0 - dNE) * aa(cf.x, 1.0 - SW) * aa(cf.y, 1.0 - SW));
		sw = max(sw, (1.0 - dNW) * (1.0 - aa(cf.x, SW)) * aa(cf.y, 1.0 - SW));
		sw = max(sw, (1.0 - dSE) * aa(cf.x, 1.0 - SW) * (1.0 - aa(cf.y, SW)));
		sw = max(sw, (1.0 - dSW) * (1.0 - aa(cf.x, SW)) * (1.0 - aa(cf.y, SW)));
		vec2 slab = fract(world_pos.xz / 1.6);
		float joint = 1.0 - aa(min(min(slab.x, 1.0 - slab.x), min(slab.y, 1.0 - slab.y)), 0.04);
		vec3 walk = vec3(0.5, 0.49, 0.46) * (0.9 + 0.2 * fine) * (1.0 - joint * 0.18);
		// curb: a bright lip on the road side of the sidewalk
		float curb = 0.0;
		curb = max(curb, (1.0 - nE) * aa(cf.x, 1.0 - SW - 0.025) * (1.0 - aa(cf.x, 1.0 - SW)));
		curb = max(curb, (1.0 - nW) * aa(cf.x, SW) * (1.0 - aa(cf.x, SW + 0.025)));
		curb = max(curb, (1.0 - nN) * aa(cf.y, 1.0 - SW - 0.025) * (1.0 - aa(cf.y, 1.0 - SW)));
		curb = max(curb, (1.0 - nS) * aa(cf.y, SW) * (1.0 - aa(cf.y, SW + 0.025)));
		// lane dashes on straight stretches (not across junctions)
		float along_x = nE * nW * (1.0 - nN) * (1.0 - nS);
		float along_y = nN * nS * (1.0 - nE) * (1.0 - nW);
		float dash = along_x * (1.0 - aa(abs(cf.y - 0.5), 0.018)) * step(0.5, fract(gc.x * 2.0));
		dash = max(dash, along_y * (1.0 - aa(abs(cf.x - 0.5), 0.018)) * step(0.5, fract(gc.y * 2.0)));
		vec3 street = mix(asphalt, vec3(0.78, 0.74, 0.6), dash * 0.75 * smoothstep(0.2, 0.5, fine + 0.3));
		street = mix(street, walk, sw);
		street = mix(street, vec3(0.66, 0.65, 0.62), curb * 0.85);
		col = street;
		rough = mix(0.75, 0.9, sw);
	} else {
		// country roads: bilinear road weight from the cell texture, cut with a
		// crisp edge, so diagonal roads stay smooth instead of stair-stepped
		vec2 g2 = gc - 0.5;
		ivec2 b0 = ivec2(floor(g2));
		vec2 t2 = fract(g2);
		float rbl = mix(mix(cell_at(b0, csz).r, cell_at(b0 + ivec2(1, 0), csz).r, t2.x),
			mix(cell_at(b0 + ivec2(0, 1), csz).r, cell_at(b0 + ivec2(1, 1), csz).r, t2.x), t2.y);
		float rd = smoothstep(0.36, 0.52, rbl + (noise(world_pos.xz * 0.35) - 0.5) * 0.1);
		vec3 dirt = vec3(0.37, 0.34, 0.28) * (0.88 + 0.24 * noise(world_pos.xz * 6.0));
		col = mix(col, dirt, rd);
		float ruts = rd * smoothstep(0.35, 0.5, noise(world_pos.xz * vec2(0.6, 0.6)));
		col = mix(col, col * 0.8, ruts * 0.4);
		rough = mix(rough, 0.85, rd);
		if (cc.g > 0.5) {
			if (cc.b > 0.5) {
				// paved yard: worn concrete slabs
				vec2 sl = fract(world_pos.xz / 3.0);
				float j = 1.0 - aa(min(min(sl.x, 1.0 - sl.x), min(sl.y, 1.0 - sl.y)), 0.03);
				col = vec3(0.44, 0.43, 0.4) * (0.85 + 0.25 * meso) * (1.0 - j * 0.2);
				rough = 0.85;
			} else {
				// gardens: mown lawn with darker beds and a little bare earth
				vec3 lawn = vec3(0.3, 0.42, 0.2) * (0.9 + 0.15 * step(0.5, fract(world_pos.x * 0.5 + world_pos.z * 0.02)));
				float bed = smoothstep(0.62, 0.66, noise(world_pos.xz * 0.45));
				col = mix(lawn, vec3(0.3, 0.24, 0.17) * (0.85 + 0.3 * fine), bed * 0.85);
			}
		}
	}
	// lake shore: wet sand and mud on the banks, darker silt under the shallows
	float shw = shore_weight(world_pos.xz, map_size_m);
	float beach = smoothstep(0.22, 0.42, shw);
	col = mix(col, vec3(0.42, 0.38, 0.29) * (0.85 + 0.3 * fine), beach * (1.0 - smoothstep(0.42, 0.5, shw)) * 0.85);
	col = mix(col, vec3(0.2, 0.19, 0.15), smoothstep(0.44, 0.55, shw));
	rough = mix(rough, 0.4, smoothstep(0.38, 0.5, shw));
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
