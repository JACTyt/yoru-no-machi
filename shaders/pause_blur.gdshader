shader_type canvas_item;
// Pause backdrop: blurred, desaturated and dimmed copy of the frozen frame.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 3.0;
uniform float dim = 0.5;
uniform vec4 tint : source_color = vec4(0.03, 0.04, 0.08, 1.0);
uniform float fade = 1.0;

void fragment() {
	vec3 frame = texture(screen_tex, SCREEN_UV).rgb;
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.4) * (1.0 - dim);
	c = mix(c, tint.rgb, 0.25);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * 1.2;
	COLOR = vec4(mix(frame, c, fade), 1.0);
}
