// Final screen pass (docs/VISUALS.md §8.2, steps 6–7): very light film grain
// (rises over high dose rates) and a light vignette. Grading is done by the
// Environment's colour-correction LUT; DOF by the camera attributes.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.03;
uniform float vignette = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = SCREEN_UV - 0.5;
	float v = 1.0 - dot(d, d) * vignette * 2.2;
	c *= v;
	float n = hash(FRAGCOORD.xy + fract(TIME * 7.13) * 91.0) - 0.5;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c += n * grain * (1.0 - lum * 0.6);
	COLOR = vec4(c, 1.0);
}
