// Northern sky: gradient + sun disc and halo, stars and aurora borealis at night.
shader_type sky;
render_mode use_half_res_pass;

uniform vec3 sky_top : source_color = vec3(0.42, 0.56, 0.72);
uniform vec3 sky_horizon : source_color = vec3(0.88, 0.8, 0.66);
uniform vec3 ground_color : source_color = vec3(0.3, 0.27, 0.2);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.85, 0.65);
uniform float stars = 0.0;
uniform float aurora = 0.0;
uniform float clock = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.0, 0.55, y));
	col = mix(col, ground_color, smoothstep(0.0, -0.08, y));
	// sun halo + disc
	float sd = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
	col += sun_tint * (pow(sd, 8.0) * 0.25 + pow(sd, 64.0) * 0.5) * LIGHT0_ENERGY;
	col += sun_tint * smoothstep(0.9993, 0.9997, sd) * 6.0 * LIGHT0_ENERGY;
	if (!AT_CUBEMAP_PASS && y > 0.0) {
		// stars
		vec2 sp = EYEDIR.xz / (EYEDIR.y + 0.4) * 180.0;
		float st = step(0.9965, hash2(floor(sp))) * smoothstep(0.02, 0.2, y);
		col += vec3(0.9, 0.92, 1.0) * st * stars * (0.5 + 0.5 * hash2(floor(sp) + 3.0));
		// aurora: curtains along a wavy band in the north (-z)
		if (aurora > 0.0) {
			vec2 ap = EYEDIR.xz / (EYEDIR.y + 0.25);
			float band = ap.y + 1.4 + sin(ap.x * 1.3 + clock * 0.05) * 0.35 + noise2(ap * 2.0 + clock * 0.02) * 0.3;
			float curtain = exp(-band * band * 6.0);
			float rays = noise2(vec2(ap.x * 14.0 + clock * 0.1, 0.0)) * 0.7 + 0.3;
			float h = smoothstep(0.03, 0.25, y) * smoothstep(0.75, 0.3, y);
			vec3 ac = mix(vec3(0.15, 0.95, 0.55), vec3(0.35, 0.55, 0.95), smoothstep(0.0, 0.5, y));
			col += ac * curtain * rays * h * aurora * 0.9;
		}
	}
	COLOR = col;
}
