// "Scale-model weathering" uber-shader (docs/VISUALS.md §6.2).
// Albedo from the palette atlas (UV = swatch). Vertex colour carries baked data:
// R ambient occlusion (wash), G curvature (dry-brush edge highlight),
// B dirt mask (height grime / mud), A rust mask.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform int palette_row = -1;      // >= 0 overrides the model's row (structures take the owner's camo)
uniform int camo_style = 3;        // 0 splinter (Coalition), 1 three-tone (Eastern), 2 patchy (Marauders), 3 none
uniform float edge_highlight = 0.45;
uniform float wash = 0.8;
uniform vec3 dust_color : source_color = vec3(0.42, 0.37, 0.28);
uniform vec3 mud_color : source_color = vec3(0.22, 0.18, 0.12);
uniform vec3 rust_color : source_color = vec3(0.55, 0.29, 0.18);

global uniform float wetness;
global uniform float snow_amount;

instance uniform float mud_amount = 0.0;
instance uniform float burn = 0.0;
instance uniform float contamination = 0.0;
instance uniform float build_alpha = 1.0;

varying vec3 obj_pos;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec3 swatch(int col, float row_v) {
	return texture(palette, vec2((float(col) + 0.5) / 16.0, row_v)).rgb;
}

void vertex() {
	obj_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float row_v = palette_row >= 0 ? (float(palette_row) + 0.5) / 8.0 : UV.y;
	int col = int(floor(UV.x * 16.0));
	vec3 albedo = swatch(col, row_v);
	// procedural camouflage on the base camo swatch
	if (col == 0 && camo_style < 3) {
		if (camo_style == 0) {
			vec3 q = vec3(obj_pos.x * 0.55 + obj_pos.z * 0.35, obj_pos.y * 0.9 + obj_pos.x * 0.2, obj_pos.z * 0.45 - obj_pos.x * 0.3);
			float n = vnoise(floor(q * 3.0) / 3.0 * 1.7 + 3.1);
			albedo = n > 0.58 ? swatch(1, row_v) : (n < 0.22 ? swatch(2, row_v) : albedo);
		} else if (camo_style == 1) {
			float n1 = vnoise(obj_pos * 0.8 + 1.7) * 0.7 + vnoise(obj_pos * 2.1) * 0.3;
			float n2 = vnoise(obj_pos * 1.1 + 9.3);
			albedo = n1 > 0.6 ? swatch(2, row_v) : albedo;
			albedo = n2 > 0.74 ? swatch(1, row_v) : albedo;
		} else {
			float n3 = vnoise(obj_pos * 0.6 + 4.0);
			albedo = mix(albedo, swatch(2, row_v), smoothstep(0.55, 0.6, n3));
		}
	}
	float ao = COLOR.r;
	float edge = COLOR.g;
	float dirt = COLOR.b;
	// subtle low-frequency surface noise (breaks flat colour without textures)
	float sn = vnoise(world_pos * 0.9) * 0.6 + vnoise(world_pos * 3.7) * 0.4;
	albedo *= 0.9 + 0.2 * sn;
	// wash (panel shading) and dry-brush edge highlight
	albedo *= mix(1.0, ao, wash * 0.55);
	albedo = mix(albedo, albedo * 1.55 + vec3(0.05), edge * edge_highlight);
	// rust streaks, dust and mud on the lower hull
	albedo = mix(albedo, rust_color * (0.7 + 0.5 * sn), COLOR.a * 0.8);
	albedo = mix(albedo, dust_color, clamp(dirt * 0.45 * (1.0 - wetness * 0.5), 0.0, 1.0));
	albedo = mix(albedo, mud_color, clamp(dirt * mud_amount * (0.6 + 0.4 * sn), 0.0, 1.0));
	// contamination: faint grey-yellow dust, never glow
	albedo = mix(albedo, vec3(0.55, 0.53, 0.42), contamination * 0.22 * smoothstep(0.4, 0.7, vnoise(world_pos * 6.0)));
	float rough = col == 10 ? 0.18 : (col == 3 ? 0.5 : 0.82);
	float metal = col == 3 ? 0.35 : 0.0;
	// weather
	albedo *= mix(1.0, 0.62, wetness);
	rough = mix(rough, rough * 0.45, wetness);
	float up = clamp(world_normal.y, 0.0, 1.0);
	float snow = smoothstep(0.55, 0.85, up) * smoothstep(0.0, 0.25, snow_amount + (sn - 0.5) * 0.3) * snow_amount * 1.6;
	albedo = mix(albedo, vec3(0.7, 0.72, 0.76), clamp(snow, 0.0, 1.0));
	// destroyed: charred, with dying embers
	vec3 emit = vec3(0.0);
	if (burn > 0.0) {
		float charm = smoothstep(0.0, 0.6, burn) * (0.8 + 0.2 * sn);
		albedo = mix(albedo, vec3(0.07, 0.06, 0.05), charm);
		rough = mix(rough, 0.95, charm);
		float ember = smoothstep(0.72, 0.9, vnoise(world_pos * 2.3 + vec3(0.0, TIME * 0.3, 0.0))) * smoothstep(0.75, 1.0, burn);
		emit = vec3(1.0, 0.35, 0.08) * ember * 2.5 * (1.0 - edge * 0.5);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = mix(1.0, ao, 0.7);
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = emit;
	if (build_alpha < 0.999) {
		// under construction: screen-door dissolve keeps the opaque pipeline
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) + hash(floor(world_pos * 2.0)) * 0.5);
		if (d > build_alpha) {
			discard;
		}
	}
}
