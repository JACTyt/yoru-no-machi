shader_type sky;
// Painted anime sky: deep blue zenith, pale horizon, cel-shaded cumulus drifting slowly, crisp sun.

uniform vec3 top_color : source_color = vec3(0.13, 0.33, 0.82);
uniform vec3 mid_color : source_color = vec3(0.38, 0.62, 0.97);
uniform vec3 horizon_color : source_color = vec3(0.9, 0.9, 0.97);
uniform vec3 ground_color : source_color = vec3(0.36, 0.34, 0.44);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 cloud_shade : source_color = vec3(0.6, 0.66, 0.88);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.86);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_speed = 0.006;

// Sine-free hash: stable on large inputs (no per-pixel noise from float precision).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col;
	if (d.y >= 0.0) {
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.22, d.y));
		col = mix(col, top_color, smoothstep(0.2, 0.85, d.y));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.06, -d.y));
	}

	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float sun_dot = dot(d, sun_dir);
	if (LIGHT0_ENABLED) {
		col += sun_color * pow(max(sun_dot, 0.0), 24.0) * 0.18;
	}

	// The radiance cubemap only needs the gradient; clouds are for the visible background.
	if (!AT_CUBEMAP_PASS && d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.15) * 0.9 + TIME * cloud_speed * vec2(1.0, 0.35);
		float n = fbm(uv);
		float density = smoothstep(cloud_cover, cloud_cover + 0.035, n);
		// Cel lighting: compare against a sample shifted toward the sun.
		float toward_sun = fbm(uv + normalize(sun_dir.xz + vec2(0.001)) * 0.08);
		float lit = step(toward_sun, n + 0.015);
		vec3 cloud = mix(cloud_shade, cloud_light, lit);
		// Silver lining on edges facing the sun.
		cloud += sun_color * 0.15 * (1.0 - smoothstep(cloud_cover, cloud_cover + 0.06, n)) * max(sun_dot, 0.0);
		float fade = smoothstep(0.0, 0.18, d.y);
		col = mix(col, cloud, density * fade);
	}

	if (LIGHT0_ENABLED) {
		col = mix(col, sun_color * 1.6, smoothstep(0.9993, 0.9996, sun_dot));
	}
	COLOR = col;
}
