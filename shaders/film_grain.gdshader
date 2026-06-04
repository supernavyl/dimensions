shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.15) = 0.05;
uniform float speed : hint_range(0.0, 20.0) = 8.0;

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	float t = fract(TIME * speed);
	float grain = hash(SCREEN_UV + t) * 2.0 - 1.0;
	COLOR.rgb += grain * strength;
}
