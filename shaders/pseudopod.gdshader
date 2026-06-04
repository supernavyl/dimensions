// pseudopod.gdshader — first-person neutrophil pseudopod hands.
// Source: OpenStax A&P 2e ch. 21 (NOESIS): neutrophils are spherical granulocytes
// with cytoplasmic granules containing vasoactive mediators. They extend
// pseudopods toward chemotactic gradients to engulf bacteria (phagocytosis).
//
// Visual targets:
//   1. Translucent membrane (SSS-like)
//   2. Visible internal granules as small dark spots embedded in cytoplasm
//   3. Organic wobble — surface normal + position perturbation via noise
//   4. Extension on reach: a uniform extend_amount stretches the tip

shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley;

uniform vec3  membrane_color : source_color = vec3(0.95, 0.78, 0.74);
uniform vec3  granule_color  : source_color = vec3(0.42, 0.10, 0.16);
uniform vec3  nucleus_glow   : source_color = vec3(0.55, 0.20, 0.30);
uniform float wobble_speed   : hint_range(0.2, 4.0)   = 1.6;
uniform float wobble_amp     : hint_range(0.0, 0.10)  = 0.025;
uniform float extend_amount  : hint_range(0.0, 1.5)   = 0.0;
uniform float granule_density: hint_range(2.0, 60.0)  = 18.0;
uniform float granule_size   : hint_range(0.02, 0.30) = 0.10;
uniform float membrane_alpha : hint_range(0.30, 1.0)  = 0.78;
uniform float sss_strength   : hint_range(0.0, 1.5)   = 0.85;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// 3D value noise — used for both vertex wobble and granule placement.
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i + vec3(0,0,0));
	float n100 = hash(i + vec3(1,0,0));
	float n010 = hash(i + vec3(0,1,0));
	float n110 = hash(i + vec3(1,1,0));
	float n001 = hash(i + vec3(0,0,1));
	float n101 = hash(i + vec3(1,0,1));
	float n011 = hash(i + vec3(0,1,1));
	float n111 = hash(i + vec3(1,1,1));
	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

void vertex() {
	// Organic wobble — perturb vertex along normal using slow 3D noise.
	float n = vnoise3(VERTEX * 3.0 + vec3(TIME * wobble_speed, 0.0, TIME * wobble_speed * 0.7));
	VERTEX += NORMAL * (n - 0.5) * 2.0 * wobble_amp;

	// Extension on reach — stretch tip (vertices with high local Z) outward.
	// Assumes pseudopod is modeled along -Z (forward in camera space).
	float tip = smoothstep(0.0, 1.2, -VERTEX.z);
	VERTEX.z -= tip * extend_amount;
}

void fragment() {
	// Granules — embedded dark spots inside the cytoplasm. Sample noise at
	// the world-ish coord so they don't slide as the pseudopod wobbles.
	vec3 gp = VERTEX * granule_density;
	float g = vnoise3(gp);
	float g2 = vnoise3(gp + vec3(7.13, 3.91, 11.27));
	float granule = smoothstep(0.55 - granule_size, 0.55, max(g, g2));
	granule *= smoothstep(0.0, 0.35, 1.0 - granule_size);

	// Subsurface red glow at grazing angles — light catches the thin
	// membrane edge.
	float fres = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.0);
	vec3 sss = nucleus_glow * fres * sss_strength;

	vec3 base = mix(membrane_color, granule_color, granule);
	ALBEDO = base + sss * 0.4;
	ALPHA = mix(membrane_alpha, 1.0, granule * 0.7);
	ROUGHNESS = mix(0.30, 0.65, granule);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	EMISSION = sss * 0.65 + granule_color * granule * 0.1;
}
