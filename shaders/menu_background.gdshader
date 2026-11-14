shader_type canvas_item;
// Moody night backdrop: gradient sky, moon haze, three parallax skyline layers, drifting fog.

uniform vec4 top_color : source_color = vec4(0.015, 0.02, 0.05, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.06, 0.09, 0.15, 1.0);
uniform vec4 fog_color : source_color = vec4(0.42, 0.52, 0.68, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.78, 0.5, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Height of the skyline at x for one layer; occasional thin spires.
float skyline(float x, float seed, float base, float var_h, float width) {
	float cell = floor(x / width);
	float h = base + hash(vec2(cell, seed)) * var_h;
	float cx = fract(x / width);
	if (hash(vec2(cell, seed + 7.0)) > 0.86) {
		h += (1.0 - abs(cx - 0.5) * 2.0) * var_h * 1.2 * step(0.4, cx) * step(cx, 0.6);
	}
	return h;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y);
	float y = 1.0 - UV.y;

	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);
	float haze = exp(-length(p - vec2(0.0, 0.3)) * 2.6);
	col += glow_color.rgb * haze * 0.22;

	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float x = p.x * (1.0 + fi * 0.6) + TIME * 0.004 * (fi + 1.0) + fi * 13.0;
		float h = skyline(x, fi, 0.3 - fi * 0.08, 0.2 - fi * 0.04, 0.07 + fi * 0.035);
		if (y < h) {
			// Far layers fade into fog; near layer is almost black.
			vec3 layer = mix(fog_color.rgb * 0.35, vec3(0.01, 0.012, 0.02), (fi + 1.0) / 3.0);
			vec2 wg = vec2(x * 140.0, y * 140.0);
			float lit = step(0.94, hash(floor(wg) + fi * 31.0)) * step(0.3, fract(wg.x)) * step(0.3, fract(wg.y));
			layer += window_color.rgb * lit * (0.35 - fi * 0.1) * (0.8 + 0.2 * sin(TIME * 0.7 + hash(floor(wg)) * 40.0));
			col = layer;
		}
		// Fog band sitting on each layer.
		float band = fbm(vec2(x * 4.0 - TIME * 0.03, y * 6.0 + fi * 5.0));
		col = mix(col, fog_color.rgb * 0.5, band * smoothstep(h + 0.12, h - 0.05, y) * 0.22);
	}

	float mist = fbm(p * 2.5 + vec2(TIME * 0.015, TIME * 0.004));
	col += fog_color.rgb * mist * smoothstep(0.45, 1.0, UV.y) * 0.12;

	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * 1.4;
	COLOR = vec4(col, 1.0);
}
