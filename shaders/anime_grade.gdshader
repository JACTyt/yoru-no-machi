shader_type canvas_item;
// Full-screen anime grade on a canvas layer: saturation/contrast, split toning, vignette,
// plus combat cues (speed lines, impact frame). Reads the finished 3D frame, transparents included.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float saturation = 1.12;
uniform float contrast = 1.04;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.55, 0.95, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform float tint_strength = 0.25;
uniform float vignette = 0.35;

// Combat cues driven from gameplay (0..1).
uniform float speed_lines = 0.0;
uniform float impact = 0.0;
uniform vec4 impact_color : source_color = vec4(1.0, 0.22, 0.32, 1.0);

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	// Split toning: cool lavender shadows, warm highlights.
	vec3 tint = mix(shadow_tint.rgb, highlight_tint.rgb, smoothstep(0.1, 0.7, luma));
	col = mix(col, col * tint * 1.2, tint_strength);
	vec2 v = uv - 0.5;
	col *= 1.0 - vignette * dot(v, v) * 1.6;

	if (speed_lines > 0.001) {
		// Radial manga speed lines, re-rolled ~18 times a second.
		vec2 c = (uv - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		float sector = floor((atan(c.y, c.x) + PI) * 38.0);
		float n = hash1(sector + floor(TIME * 18.0) * 17.31);
		float line = step(0.8, n) * smoothstep(0.22, 0.75, length(c));
		col = mix(col, vec3(1.0), line * speed_lines * 0.6);
	}
	if (impact > 0.001) {
		// Impact frame, three flat tones: ink lines/deep shadows -> black, highlights -> white, rest -> red.
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 frame = l < 0.11 ? vec3(0.02, 0.0, 0.04) : (l > 0.55 ? vec3(1.0, 0.95, 0.95) : impact_color.rgb);
		col = mix(col, frame, impact);
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
