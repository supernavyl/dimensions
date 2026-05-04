shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.02) = 0.004;

void fragment() {
    vec2 uv = SCREEN_UV;
    COLOR.r = texture(SCREEN_TEXTURE, uv + vec2(strength, 0.0)).r;
    COLOR.g = texture(SCREEN_TEXTURE, uv).g;
    COLOR.b = texture(SCREEN_TEXTURE, uv - vec2(strength, 0.0)).b;
    COLOR.a = 1.0;
}
