// surfactant.gdshader — pulmonary surfactant fluid surface.
// Source: OpenStax A&P 2e ch. 22 (NOESIS): "secreted by type II alveolar cells,
// composed of phospholipids and proteins, reduces surface tension of alveoli."
//
// Visual targets:
//   1. Translucent fluid with refractive sheen
//   2. Slow ripple from breath pulse
//   3. Foamy bubble texture (phospholipid micelles)
//   4. Edge foam where the fluid meets the alveolar wall

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

uniform vec3  fluid_color    : source_color = vec3(0.92, 0.78, 0.74);
uniform vec3  bubble_color   : source_color = vec3(1.00, 0.92, 0.88);
uniform float bubble_scale   : hint_range(2.0, 80.0)  = 22.0;
uniform float bubble_density : hint_range(0.05, 0.85) = 0.40;
uniform float ripple_speed   : hint_range(0.0, 4.0)   = 0.6;
uniform float ripple_strength: hint_range(0.0, 0.30)  = 0.045;
uniform float fluid_alpha    : hint_range(0.10, 0.95) = 0.55;
uniform float edge_foam      : hint_range(0.0, 1.0)   = 0.7;
uniform float emission_strength : hint_range(0.0, 1.5) = 0.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Worley/cellular noise — closest-feature distance, used for bubble blobs.
float worley(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(n + g + 0.13), hash(n + g + 0.71));
			o = 0.5 + 0.5 * sin(TIME * 0.7 + 6.2831 * o);
			vec2 r = g + o - f;
			d = min(d, dot(r, r));
		}
	}
	return sqrt(d);
}

// Cheap 2D value noise for the macro ripple.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	// Surface ripple — sinusoidal Y displacement using value noise.
	vec2 wp = VERTEX.xz * 0.45 + vec2(TIME * ripple_speed * 0.3, TIME * ripple_speed * 0.21);
	float r = vnoise(wp) * 2.0 - 1.0;
	VERTEX.y += r * ripple_strength;
}

void fragment() {
	// Distance from disc origin (in object space xz) for edge foam.
	vec2 obj_xz = (vec4(VERTEX, 0.0) * MODEL_MATRIX).xz;
	float radial = length(obj_xz);
	// Disc outer radius is ~ALVEOLUS_RADIUS * 0.95 (~11.4) — fade edge foam
	// across last 12% of the disc.
	float radial_norm = smoothstep(11.4 * 0.86, 11.4 * 0.99, radial);

	// Bubble pattern via Worley.
	vec2 buv = obj_xz * (bubble_scale / 11.4);
	float w = worley(buv);
	float bubble = smoothstep(bubble_density, bubble_density * 0.45, w);

	// Mix fluid color with bubble highlights.
	vec3 base = mix(fluid_color, bubble_color, bubble * 0.65);

	// Edge foam: more bubble density + brighter near the wall.
	base = mix(base, bubble_color, radial_norm * edge_foam);

	ALBEDO = base;
	ALPHA = mix(fluid_alpha, 0.92, radial_norm * 0.6);
	ROUGHNESS = mix(0.20, 0.55, bubble);
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = base * emission_strength * (0.5 + 0.5 * bubble);
}
