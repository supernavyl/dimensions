// alveolar_wall.gdshader — anatomically grounded alveolus interior surface.
// Source: OpenStax A&P 2e ch. 22 (NOESIS workspace:anatomy-openstax).
// Type I pneumocytes form 95% of the surface (thin, squamous);
// Type II are interspersed (cuboidal, surfactant-secreting).
// Capillaries lie immediately on the other side of the wall — one cell thick.
//
// Visual targets:
//   1. Voronoi cell-boundary pattern on the inner face (real epithelial mosaic)
//   2. Subsurface red glow from the capillary side (blood seen through SSS)
//   3. Breath-cycle pulse: subtle radial dilation, brightness wave
//   4. Cell-boundary darkening with micro-thickness variation

shader_type spatial;
render_mode cull_front, blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3  cell_color      : source_color = vec3(0.78, 0.42, 0.46);
uniform vec3  boundary_color  : source_color = vec3(0.35, 0.10, 0.14);
uniform vec3  capillary_color : source_color = vec3(0.98, 0.30, 0.32);
uniform float boundary_width  : hint_range(0.005, 0.10) = 0.025;
uniform float cell_scale      : hint_range(2.0, 40.0)  = 14.0;
uniform float sss_strength    : hint_range(0.0, 1.5)   = 0.85;
uniform float breath_period   : hint_range(1.0, 12.0)  = 5.0;
uniform float breath_amplitude: hint_range(0.0, 0.20)  = 0.05;
uniform float roughness_base  : hint_range(0.2, 1.0)   = 0.88;
uniform float emission_base   : hint_range(0.0, 0.6)   = 0.18;

// --- Voronoi on a unit sphere ---------------------------------------------
// 2D Voronoi using spherical (theta, phi) coords. Cheap, looks like an
// epithelial cell mosaic when sampled per-fragment over the alveolar wall.

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Returns vec2(distance_to_nearest_feature_point, distance_to_2nd_nearest)
// The difference (.y - .x) is the cell-boundary distance — small near walls.
vec2 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			// Tiny temporal jitter so cells wobble — subtle aliveness.
			o = 0.5 + 0.5 * sin(TIME * 0.35 + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(sqrt(d1), sqrt(d2));
}

// Map a unit-sphere position to (theta, phi) for Voronoi sampling.
vec2 sphere_uv(vec3 dir) {
	dir = normalize(dir);
	float theta = atan(dir.z, dir.x);              // longitude  [-π, π]
	float phi   = acos(clamp(dir.y, -1.0, 1.0));   // latitude   [0, π]
	return vec2(theta, phi);
}

void vertex() {
	// Breath-cycle radial pulse — push vertices outward on inhale, in on exhale.
	float phase = TIME * (TAU / breath_period);
	float pulse = 0.5 - 0.5 * cos(phase);  // 0 (exhale) .. 1 (inhale peak)
	VERTEX += NORMAL * (pulse - 0.5) * breath_amplitude;
}

void fragment() {
	// Voronoi on the original (object-space) wall direction so the cell pattern
	// stays anchored to geometry, not screen.
	vec3 obj_dir = normalize((vec4(VERTEX, 0.0) * MODEL_MATRIX).xyz);
	vec2 uv = sphere_uv(obj_dir) * cell_scale;

	vec2 vor = voronoi(uv);
	float boundary = smoothstep(boundary_width, 0.0, vor.y - vor.x);
	// Subtle per-cell color variation — every pneumocyte slightly different.
	vec2 cell_id = floor(uv) + hash22(floor(uv));
	float tint = 0.85 + 0.30 * hash22(cell_id).x;

	vec3 base = mix(cell_color * tint, boundary_color, boundary);

	// Capillary backlight — view-dependent: when looking near edge of wall,
	// the thin tissue glows red as if blood is right behind it.
	float fres = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.2);
	vec3 sss = capillary_color * fres * sss_strength;

	// Breath emission pulse.
	float phase = TIME * (TAU / breath_period);
	float pulse = 0.5 - 0.5 * cos(phase);

	ALBEDO = base + sss * 0.35;
	ROUGHNESS = roughness_base - boundary * 0.25;
	METALLIC = 0.0;
	SPECULAR = 0.08;
	EMISSION = (capillary_color * (emission_base + 0.15 * pulse)) + sss * 0.55;
	// Boundary darkens emission slightly — junctions are less translucent.
	EMISSION *= (1.0 - boundary * 0.4);
}
