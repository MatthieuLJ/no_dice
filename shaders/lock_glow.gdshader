shader_type spatial;
render_mode cull_front, unshaded, blend_add, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.15, 0.9);
uniform float glow_outline_width : hint_range(0.005, 0.1) = 0.025;
uniform float glow_falloff_power : hint_range(0.5, 5.0) = 1.5;

void vertex() {
	VERTEX += NORMAL * glow_outline_width;
}

void fragment() {
	float view_dot = abs(dot(NORMAL, VIEW));
	float alpha_fade = pow(clamp(1.0 - view_dot, 0.0, 1.0), glow_falloff_power);
	ALBEDO = glow_color.rgb;
	ALPHA = glow_color.a * alpha_fade;
}
