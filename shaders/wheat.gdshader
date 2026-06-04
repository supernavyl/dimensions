// wheat.gdshader — wind-animated golden wheat blades.
// Used by a MultiMeshInstance3D so a single shader animates thousands of
// instances cheaply. Wind sway is computed from world position so adjacent
// blades sway in correlated waves, not independently — looks like a real
// gust passing across the field.

shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_disabled;

uniform vec3  base_color   : source_color = vec3(0.78, 0.62, 0.22);
uniform vec3  tip_color    : source_color = vec3(1.00, 0.88, 0.42);
uniform float wind_speed   : hint_range(0.0, 4.0)   = 0.8;
uniform float wind_strength: hint_range(0.0, 0.6)   = 0.22;
uniform float wind_scale   : hint_range(0.05, 2.0)  = 0.18;
uniform float gust_strength: hint_range(0.0, 0.4)   = 0.16;
uniform float gust_speed   : hint_range(0.0, 1.0)   = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	// World position of THIS blade's base (instance origin).
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	// Tip mask: 1.0 at the top of the blade (UV.y high), 0 at the root.
	// The blade mesh should be modeled with UV.y running base→tip.
	// Fallback: use raw vertex Y above 0.
	float tip = clamp(VERTEX.y / 1.5, 0.0, 1.0);

	// High-frequency per-blade jitter — each blade slightly different.
	float local = vnoise(world_origin.xz * 4.7 + TIME * wind_speed);

	// Low-frequency gust traveling across the field — visible wave fronts.
	vec2 gust_dir = vec2(0.72, 0.69);  // wind blows roughly +x +z
	float gust = vnoise(world_origin.xz * wind_scale - gust_dir * TIME * gust_speed);

	// Sway only the tip; root stays anchored.
	float sway = (local - 0.5) * wind_strength + (gust - 0.5) * gust_strength;
	VERTEX.x += sway * tip;
	VERTEX.z += sway * 0.6 * tip;
	// Tiny vertical droop on heavy gust so it doesn't read as a flat shear.
	VERTEX.y -= abs(sway) * 0.3 * tip;
}

void fragment() {
	float tip = clamp(VERTEX.y / 1.5, 0.0, 1.0);
	vec3 col = mix(base_color, tip_color, tip);
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.85, tip);
	METALLIC = 0.0;
	SPECULAR = 0.15;
	// Subtle golden self-glow so the field reads warm even in shadow.
	EMISSION = tip_color * 0.04 * tip;
}
