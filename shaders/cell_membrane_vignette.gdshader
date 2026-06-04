// cell_membrane_vignette.gdshader — screen-space membrane silhouette.
// You are inside a neutrophil. The cell membrane is right there at the edge
// of your vision. This shader paints the wobbly red-pink membrane contour
// as a vignette, leaving the center transparent so you can see the world.

shader_type canvas_item;
render_mode blend_mix;

uniform vec3 membrane_color  : source_color = vec3(0.95, 0.62, 0.66);
uniform vec3 deep_color      : source_color = vec3(0.55, 0.15, 0.20);
uniform float wobble_speed   : hint_range(0.0, 4.0) = 0.7;
uniform float wobble_amp     : hint_range(0.0, 0.15) = 0.045;
uniform float edge_softness  : hint_range(0.05, 0.6) = 0.32;
uniform float vignette_inset : hint_range(0.0, 0.45) = 0.18;
uniform float max_alpha      : hint_range(0.0, 1.0) = 0.85;

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

void fragment() {
	// Distance from screen center, normalized so corners are ~1.0.
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	uv.x *= 1.0;  // square distance — looks more cellular than ellipse
	float d = length(uv);

	// Animated membrane wobble — radial perturbation based on angle.
	float ang = atan(uv.y, uv.x);
	float w = vnoise(vec2(ang * 1.6, TIME * wobble_speed)) * 2.0 - 1.0;
	float w2 = vnoise(vec2(ang * 3.7 + 11.3, TIME * wobble_speed * 1.4)) * 2.0 - 1.0;
	float wobble = (w * 0.65 + w2 * 0.35) * wobble_amp;

	// Membrane silhouette starts at (1.0 - vignette_inset + wobble).
	float inner = 1.0 - vignette_inset + wobble;
	float outer = inner + edge_softness;
	float mask = smoothstep(inner, outer, d);

	// Two-tone — lighter membrane fading to deep red at the corners.
	vec3 col = mix(membrane_color, deep_color, smoothstep(inner, outer, d));
	COLOR = vec4(col, mask * max_alpha);
}
