shader_type canvas_item;

// Drug daze — fullscreen wobble, blur, chromatic separation that pulses
// with TIME. All effects scale with `intensity` (0 = clean, 1 = peak).
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float ca_strength : hint_range(0.0, 0.04) = 0.022;
uniform float wobble_amp : hint_range(0.0, 0.06) = 0.018;
uniform float wobble_speed : hint_range(0.0, 6.0) = 1.6;
uniform float blur_radius : hint_range(0.0, 0.012) = 0.006;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.9;

vec3 sample_blur(vec2 uv, float r) {
	// 9-tap cross blur. Cheap, good enough for a hazy feel.
	vec3 c = texture(SCREEN_TEXTURE, uv).rgb * 0.36;
	c += texture(SCREEN_TEXTURE, uv + vec2( r, 0.0)).rgb * 0.10;
	c += texture(SCREEN_TEXTURE, uv + vec2(-r, 0.0)).rgb * 0.10;
	c += texture(SCREEN_TEXTURE, uv + vec2(0.0,  r)).rgb * 0.10;
	c += texture(SCREEN_TEXTURE, uv + vec2(0.0, -r)).rgb * 0.10;
	c += texture(SCREEN_TEXTURE, uv + vec2( r,  r)).rgb * 0.06;
	c += texture(SCREEN_TEXTURE, uv + vec2(-r,  r)).rgb * 0.06;
	c += texture(SCREEN_TEXTURE, uv + vec2( r, -r)).rgb * 0.06;
	c += texture(SCREEN_TEXTURE, uv + vec2(-r, -r)).rgb * 0.06;
	return c;
}

void fragment() {
	float i = clamp(intensity, 0.0, 1.0);
	// Pulse — slow heartbeat-like swell so the daze doesn't feel static.
	float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed);
	float k = i * pulse;

	// Wobble — sin/cos UV warp, separate phases per axis.
	vec2 uv = SCREEN_UV;
	float wx = sin(TIME * wobble_speed + uv.y * 9.0) * wobble_amp * k;
	float wy = cos(TIME * wobble_speed * 0.7 + uv.x * 7.0) * wobble_amp * k;
	uv += vec2(wx, wy);

	// Chromatic aberration that grows with daze.
	float ca = ca_strength * k;
	vec2 dir = normalize(uv - vec2(0.5)) * ca;
	float r = sample_blur(uv + dir, blur_radius * k).r;
	float g = sample_blur(uv,        blur_radius * k).g;
	float b = sample_blur(uv - dir,  blur_radius * k).b;

	// Mix toward clean image at low intensity to keep things crisp once sober.
	vec3 daze_col = vec3(r, g, b);
	vec3 clean_col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 col = mix(clean_col, daze_col, smoothstep(0.0, 0.12, i));

	// Slight desaturation + warm cast while dazed.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(col, vec3(lum), 0.55 * k);
	desat *= mix(vec3(1.0), vec3(1.05, 0.97, 0.92), k);

	COLOR = vec4(desat, 1.0);
}
