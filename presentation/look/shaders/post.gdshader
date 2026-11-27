// Final screen pass over the 3D world (the HUD is drawn after it, crisp):
//  1. stable pixel blocks: each block takes the mip-averaged colour under it, so
//     the image doesn't shimmer when the camera moves
//  2. ink edges where neighbouring blocks differ sharply (drawn-model look)
//  3. palette lock: ordered dither, then snap to the curated game palette
//     (retro_lut, built by tools/gen_retro_lut.py)
//  4. radiation speckle: single white blocks, like film fogged near Chernobyl,
//     rising with the dose rate under the camera
//  5. light grain and vignette
// All strengths are uniforms set by LookDirector from GraphicsSettings.retro.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler3D palette_lut : filter_nearest;
uniform float pixel_size = 2.0;
uniform float palette_amount = 0.6;
uniform float dither_amount = 0.7;
uniform float outline_amount = 0.35;
uniform float sharpen = 0.0;
uniform float speckle = 0.0;
uniform float grain = 0.03;
uniform float vignette = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0 - 0.5;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Four sharp samples spread inside the block: crisp block edges, and steadier
// than a single point sample when the camera moves.
vec3 sample_block(vec2 block, vec2 px) {
	vec2 o = block * pixel_size;
	float q = pixel_size * 0.25;
	vec3 c = textureLod(screen_tex, (o + vec2(q, q)) * px, 0.0).rgb;
	c += textureLod(screen_tex, (o + vec2(3.0 * q, q)) * px, 0.0).rgb;
	c += textureLod(screen_tex, (o + vec2(q, 3.0 * q)) * px, 0.0).rgb;
	c += textureLod(screen_tex, (o + vec2(3.0 * q, 3.0 * q)) * px, 0.0).rgb;
	return c * 0.25;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c;
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	if (pixel_size <= 1.0) {
		// full resolution: unsharp mask for crisp detail, thin ink edges
		c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
		vec3 n1 = textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), 0.0).rgb;
		vec3 n2 = textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), 0.0).rgb;
		vec3 n3 = textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), 0.0).rgb;
		vec3 n4 = textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), 0.0).rgb;
		vec3 blur = (n1 + n2 + n3 + n4) * 0.25;
		if (outline_amount > 0.0) {
			float e = abs(luma(n1) - luma(n2)) + abs(luma(n3) - luma(n4));
			c *= 1.0 - smoothstep(0.1, 0.3, e) * outline_amount * 0.5;
		}
		c = max(c + (c - blur) * sharpen, vec3(0.0));
	} else {
		c = sample_block(block, px);
		if (outline_amount > 0.0) {
			float l = luma(c);
			float e = abs(l - luma(sample_block(block + vec2(1.0, 0.0), px)))
				+ abs(l - luma(sample_block(block + vec2(0.0, 1.0), px)));
			float ink = smoothstep(0.08, 0.22, e) * outline_amount;
			c *= 1.0 - ink * 0.55;
		}
	}
	if (palette_amount > 0.0) {
		vec3 d = c + bayer4(block) * dither_amount * 0.045;
		vec3 snapped = texture(palette_lut, clamp(d, 0.0, 1.0)).rgb;
		c = mix(c, snapped, palette_amount);
	}
	vec2 v2 = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v2, v2) * vignette * 2.2;
	float n = hash(block + fract(TIME * 7.13) * 91.0) - 0.5;
	c += n * grain * (1.0 - luma(c) * 0.6);
	if (speckle > 0.0 && hash(block * 1.37 + floor(TIME * 14.0) * 3.1) > 1.0 - speckle * 0.004) {
		c = vec3(1.0, 0.98, 0.92);
	}
	COLOR = vec4(c, 1.0);
}
