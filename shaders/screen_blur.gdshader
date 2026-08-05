shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 3.5;
uniform vec4 mix_color : source_color = vec4(0.02, 0.05, 0.03, 0.5);

void fragment() {
	vec4 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
	COLOR = mix(blurred, mix_color, mix_color.a);
}
