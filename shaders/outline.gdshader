shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.06, 0.04, 0.1, 1.0);
uniform float thickness = 0.03;
// 1.0 for box meshes (expand along each axis, no gaps at hard edges), 0.0 for rounded meshes.
uniform float box_hull = 0.0;

void vertex() {
	VERTEX += mix(normalize(VERTEX), sign(VERTEX), box_hull) * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
