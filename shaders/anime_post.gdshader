shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;
// Screen-space ink lines from depth + normal edges, blended over the frame as a transparent overlay.
// It never re-draws the scene color, so transparent materials (VRoid eyes, lashes) stay intact.
// Color grading lives in anime_grade.gdshader on a canvas layer.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

uniform bool lines_enabled = true;
uniform vec4 line_color : source_color = vec4(0.12, 0.07, 0.16, 1.0);
uniform float line_width = 1.2;
uniform float depth_threshold = 0.08;
uniform float normal_threshold = 0.45;
uniform float line_fade_distance = 120.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).x;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

vec3 view_normal(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float edge = 0.0;
	if (lines_enabled) {
		vec2 px = line_width / VIEWPORT_SIZE;
		float d0 = linear_depth(uv, INV_PROJECTION_MATRIX);
		vec3 n0 = view_normal(uv);
		vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
		for (int i = 0; i < 4; i++) {
			float d = linear_depth(uv + offs[i], INV_PROJECTION_MATRIX);
			// Relative depth jump catches silhouettes; normal change catches creases.
			edge = max(edge, step(depth_threshold, (d - d0) / max(d0, 0.001)));
			edge = max(edge, step(normal_threshold, 1.0 - dot(n0, view_normal(uv + offs[i]))));
		}
		edge *= 1.0 - smoothstep(line_fade_distance * 0.5, line_fade_distance, d0);
	}
	ALBEDO = line_color.rgb;
	ALPHA = edge * line_color.a * 0.85;
}
