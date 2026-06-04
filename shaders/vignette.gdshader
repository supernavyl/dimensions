shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 2.0) = 0.85;
uniform float softness : hint_range(0.1, 2.0) = 0.75;

void fragment() {
	COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	float v = 1.0 - dot(uv * softness, uv * softness);
	v = clamp(v, 0.0, 1.0);
	v = pow(v, strength);
	COLOR.rgb *= v;
}
