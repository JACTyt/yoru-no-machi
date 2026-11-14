shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_strength = 0.25;
// MultiMesh props tint each instance through the instance color.
uniform bool vertex_color = false;
// Self-illumination as a multiple of the final color (signs, lamps, vending machines).
uniform float color_emission = 0.0;
// 0 plain, 1 asphalt, 2 paving (top faces), 3 glass curtain wall, 4 car paint, 5 car glass.
uniform int surface = 0;
// Hard cel specular highlight strength (car paint, glass).
uniform float gloss = 0.0;
// Facade windows: grid is laid out per face in object space, centered on the building.
uniform bool windows = false;
uniform vec3 building_size = vec3(10.0);
uniform float seed = 0.0;
uniform vec4 window_color : source_color = vec4(0.42, 0.62, 0.9, 1.0);
uniform vec4 window_lit_color : source_color = vec4(1.0, 0.84, 0.55, 1.0);
uniform vec4 store_color : source_color = vec4(0.55, 0.85, 0.95, 1.0);
// Reflected sky used by glass and car paint.
uniform vec4 sky_top : source_color = vec4(0.25, 0.48, 0.92, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.88, 0.9, 0.98, 1.0);
uniform vec4 reflect_ground : source_color = vec4(0.22, 0.21, 0.28, 1.0);

const float FLOOR_H = 3.5;
const float GROUND_H = 3.8;
const float BAY_W = 3.0;

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_pos;

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

float rect(vec2 f, vec2 lo, vec2 hi, vec2 aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, f) * (1.0 - smoothstep(hi - aa, hi + aa, f));
	return a.x * a.y;
}

// Stylised environment: sky gradient above the horizon, a flat dark city below it.
vec3 env_color(vec3 r) {
	vec3 sky = mix(sky_horizon.rgb, sky_top.rgb, smoothstep(0.0, 0.6, r.y));
	return mix(reflect_ground.rgb, sky, smoothstep(-0.03, 0.03, r.y));
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (vertex_color) {
		col *= COLOR.rgb;
	}
	vec3 emit = emission.rgb;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wv = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 refl = reflect(-wv, wn);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	if (surface == 1) {
		// Asphalt: soft grain plus darker repair patches.
		float n = noise(world_pos.xz * 0.35) * 0.6 + noise(world_pos.xz * 2.3) * 0.4;
		col *= mix(0.88, 1.07, n);
		col = mix(col, col * 0.84, smoothstep(0.7, 0.72, noise(world_pos.xz * 0.05 + 7.0)));
	} else if (surface == 2 && local_normal.y > 0.5) {
		// Paving slabs in a running bond.
		vec2 t = world_pos.xz / vec2(0.9, 0.45);
		t.x += step(1.0, mod(floor(t.y), 2.0)) * 0.5;
		vec2 aa = fwidth(t) * 0.75;
		float slab = rect(fract(t), vec2(0.03, 0.06), vec2(0.97, 0.94), aa);
		col *= mix(0.94, 1.04, hash(floor(t)));
		// Fade the joints out where they would alias (distance, grazing angles).
		float detail = 1.0 - smoothstep(0.15, 0.4, max(aa.x, aa.y));
		col = mix(col * mix(1.0, 0.78, detail), col, slab);
	} else if (surface == 3 && abs(local_normal.y) < 0.5) {
		// Glass curtain wall: reflective panels between mullions and floor slabs.
		bool side_x = abs(local_normal.x) > 0.5;
		float u = side_x ? local_pos.z : local_pos.x;
		float v = local_pos.y + building_size.y * 0.5;
		vec2 g = vec2(u / 1.6, v / 3.6);
		vec2 aa = fwidth(g) * 0.75;
		vec2 id = floor(g) + round(local_normal.xz) * 13.0 + vec2(seed);
		float pane = rect(fract(g), vec2(0.05, 0.12), vec2(0.95, 0.96), aa);
		vec3 glass = env_color(refl) * window_color.rgb * mix(0.85, 1.1, hash(id));
		glass = mix(glass, sky_horizon.rgb, fres * 0.5);
		float lit = step(0.93, hash(id.yx * 1.7));
		glass = mix(glass, window_lit_color.rgb, lit * 0.7);
		col = mix(col * 0.6, glass, pane);
		emit += pane * glass * 0.35 + pane * lit * window_lit_color.rgb * 0.3;
	} else if (surface == 4) {
		// Car paint: the classic anime horizon split, brighter toward the sky.
		float sky_side = smoothstep(-0.02, 0.02, refl.y);
		col *= mix(0.72, 1.12, sky_side);
		emit += env_color(refl) * fres * 0.35 * gloss;
	} else if (surface == 5) {
		// Tinted car glass with fixed diagonal highlight streaks.
		vec3 env = env_color(refl);
		col = mix(albedo.rgb, env * 0.55, clamp(0.12 + fres * 0.5, 0.0, 1.0) * step(-0.05, refl.y));
		float streak = step(0.93, fract((local_pos.z * 1.2 + local_pos.y * 1.8) * 0.55));
		emit += env * 0.06 + streak * vec3(0.75, 0.8, 0.9) * 0.7;
	}

	if (windows && abs(local_normal.y) < 0.5) {
		bool side_x = abs(local_normal.x) > 0.5;
		float face_w = side_x ? building_size.z : building_size.x;
		float u = (side_x ? local_pos.z : local_pos.x) + face_w * 0.5;
		float v = local_pos.y + building_size.y * 0.5;
		vec2 face_seed = round(local_normal.xz) * 17.0 + vec2(seed);

		// Upper floors: centered grid with a 0.6m margin at the corners.
		float cols = max(1.0, floor((face_w - 1.2) / BAY_W));
		float rows = max(0.0, floor((building_size.y - GROUND_H - 1.0) / FLOOR_H));
		vec2 g = vec2((u - 0.6) / (face_w - 1.2) * cols, (v - GROUND_H) / FLOOR_H);
		vec2 aa = fwidth(g) * 0.75;
		vec2 f = fract(g);
		vec2 id = floor(g);
		float frame = rect(f, vec2(0.12, 0.14), vec2(0.88, 0.86), aa);
		float glass = rect(f, vec2(0.17, 0.2), vec2(0.83, 0.8), aa);
		float lit = step(0.84, hash(id + face_seed));
		// Reflected sky instead of a flat tint, so facades pick up the time of day.
		vec3 sky_glass = env_color(refl) * window_color.rgb * mix(0.8, 1.05, f.y);
		sky_glass += 0.12 * step(0.9, fract((f.x + f.y) * 0.8 + 0.25));
		vec3 lit_glass = window_lit_color.rgb * mix(0.85, 1.1, hash(id.yx + face_seed));
		vec3 glass_col = mix(sky_glass, lit_glass, lit);
		// A thin darker band at every floor slab.
		float slab = 1.0 - smoothstep(0.0, aa.y * 2.0 + 0.02, abs(f.y - 0.02));

		// Ground floor: shop glass split into bays.
		float bays = max(1.0, floor(face_w / 2.6));
		vec2 sg = vec2(u / face_w * bays, v / GROUND_H);
		float shop = rect(fract(sg), vec2(0.06, 0.12), vec2(0.94, 0.78), fwidth(sg) * 0.75);

		if (v < GROUND_H) {
			col = mix(col * 0.8, store_color.rgb * mix(0.7, 1.0, fract(sg.y)), shop);
			emit += shop * store_color.rgb * 0.2;
		} else if (g.x > 0.0 && g.x < cols && g.y < rows) {
			col = mix(col, col * 0.85, slab);
			col = mix(col, col * 0.72, frame);
			col = mix(col, glass_col, glass);
			emit += glass * (lit * lit_glass * 0.5 + (1.0 - lit) * sky_glass * 0.15);
		}
	}
	ALBEDO = col;
	EMISSION = emit + col * color_emission;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Hard two-band cel shading; the shadow band comes from ambient light.
	float lit = step(0.0, dot(NORMAL, LIGHT)) * step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += step(0.75, rim) * lit * rim_strength * LIGHT_COLOR / PI;
	// Sharp sun glint for glossy surfaces.
	float spec = dot(NORMAL, normalize(LIGHT + VIEW));
	SPECULAR_LIGHT += step(0.992, spec) * lit * gloss * LIGHT_COLOR;
}
