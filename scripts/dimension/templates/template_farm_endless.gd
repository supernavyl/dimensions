## TemplateFarmEndless — golden-hour wheat field stretching past the horizon.
##
## Design intent: beautiful, infinite, eerie. The player can walk for
## minutes in any direction and never reach the end. Golden hour never
## fades. The wind never stops. The farm does not end.
##
## Visual stack:
##   - 500m × 500m ground plane, soft hills via vertex displacement
##   - 8,000 wheat blades via MultiMeshInstance3D (one shader, one draw call)
##   - Procedural sky with golden gradient + sun haze
##   - DirectionalLight3D low on the horizon — long shadows
##   - Volumetric-ish exponential fog tinted gold so the far ground fades
##     into the sky (no visible horizon line)
##   - Drifting pollen particles in the foreground
##   - One distant windmill silhouette for scale
class_name TemplateFarmEndless
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData

# Field extent — large enough that fog hides the edge.
const _FIELD_HALF: float = 250.0
# Wheat instance count.
const _WHEAT_COUNT: int = 8000
# Wheat-free clearing around the player spawn so the camera isn't buried.
const _CLEARING_RADIUS: float = 1.6
# Soft-hill amplitude on the ground plane.
const _HILL_AMPLITUDE: float = 1.8
const _HILL_FREQUENCY: float = 0.012
# Pollen particle count.
const _POLLEN_COUNT: int = 220


func build(rng: RandomNumberGenerator) -> void:
	_add_environment_and_sky()
	_add_sun()
	_add_ground(rng)
	_add_wheat(rng)
	_add_pollen()
	_add_distant_windmill(rng)
	_add_player_spawn()
	_add_post_processing(0.004)


# ── Sky + environment ───────────────────────────────────────────────────────
func _add_environment_and_sky() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()

	# Procedural sky — golden hour gradient.
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.46, 0.72)         # soft blue zenith
	sky_mat.sky_horizon_color = Color(0.95, 0.72, 0.45)     # peach horizon
	sky_mat.ground_horizon_color = Color(0.78, 0.62, 0.38)  # blends with field
	sky_mat.ground_bottom_color = Color(0.48, 0.35, 0.22)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.22
	sky_mat.energy_multiplier = 1.0
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky

	# Ambient from the sky so shadows aren't pitch black.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.ambient_light_sky_contribution = 0.85

	# Golden fog — hides the ground edge so the field appears endless.
	environment.fog_enabled = true
	environment.fog_density = 0.012
	environment.fog_aerial_perspective = 0.7
	environment.fog_light_color = Color(0.95, 0.72, 0.42)
	environment.fog_light_energy = 1.4
	environment.fog_sun_scatter = 0.42
	environment.fog_height = 4.0
	environment.fog_height_density = 0.6

	# Bloom for golden bloom around the sun.
	environment.glow_enabled = true
	environment.glow_intensity = 1.2
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.18
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 1.05
	environment.glow_hdr_scale = 2.0

	# ACES tonemap + warm-leaning grade.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.08
	environment.tonemap_white = 12.0

	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.12

	# SSAO disabled — open field, contributes nothing here.
	environment.ssao_enabled = false

	env.environment = environment
	add_child(env)


# ── Sun ─────────────────────────────────────────────────────────────────────
func _add_sun() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = &"GoldenHourSun"
	sun.light_color = Color(1.00, 0.74, 0.50)
	sun.light_energy = 1.6
	# Low angle — long shadows, raking light across the field.
	sun.rotation_degrees = Vector3(-12.0, 38.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.20
	sun.directional_shadow_split_3 = 0.50
	sun.directional_shadow_blend_splits = true
	add_child(sun)


# ── Ground plane with soft hills ────────────────────────────────────────────
func _add_ground(rng: RandomNumberGenerator) -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = &"FieldGround"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(_FIELD_HALF * 2.0, _FIELD_HALF * 2.0)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	ground.mesh = plane

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.33, 0.18)
	mat.roughness = 0.95
	mat.metallic = 0.0
	ground.material_override = mat
	add_child(ground)

	# Static collider — flat box, much simpler than a true heightfield.
	# The visual hills are subtle (~1.8m amplitude) so flat collision is OK.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = &"FieldFloor"
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(_FIELD_HALF * 2.0, 0.4, _FIELD_HALF * 2.0)
	col.shape = shape
	col.position = Vector3(0.0, -0.2, 0.0)
	body.add_child(col)
	add_child(body)

	# Use a small vertex shader on the ground to add the hills.
	var hill_shader: Shader = _build_hill_shader()
	if hill_shader != null:
		var hmat: ShaderMaterial = ShaderMaterial.new()
		hmat.shader = hill_shader
		hmat.set_shader_parameter(&"amplitude", _HILL_AMPLITUDE)
		hmat.set_shader_parameter(&"frequency", _HILL_FREQUENCY)
		ground.material_override = hmat


# Inline hill shader — kept private so we don't pollute shaders/ with a
# trivial 30-line file.
func _build_hill_shader() -> Shader:
	var src: String = """
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 ground_color : source_color = vec3(0.46, 0.33, 0.18);
uniform vec3 tint_color   : source_color = vec3(0.62, 0.46, 0.22);
uniform float amplitude   = 1.8;
uniform float frequency   = 0.012;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), u.x),
			   mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float h = vnoise(wp * frequency) - 0.5;
	float h2 = vnoise(wp * frequency * 3.1) - 0.5;
	VERTEX.y += (h + h2 * 0.35) * amplitude;
}

void fragment() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = vnoise(wp * 0.04);
	ALBEDO = mix(ground_color, tint_color, t);
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
"""
	var shader: Shader = Shader.new()
	shader.code = src
	return shader


# ── Wheat field ─────────────────────────────────────────────────────────────
func _add_wheat(rng: RandomNumberGenerator) -> void:
	var mm_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_inst.name = &"WheatField"
	# Don't cast shadows from individual blades — too noisy.
	mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false
	multimesh.mesh = _make_wheat_blade_mesh()
	multimesh.instance_count = _WHEAT_COUNT

	for i: int in range(_WHEAT_COUNT):
		var x: float = rng.randf_range(-_FIELD_HALF, _FIELD_HALF)
		var z: float = rng.randf_range(-_FIELD_HALF, _FIELD_HALF)
		# Skip inside clearing.
		if Vector2(x, z).length() < _CLEARING_RADIUS:
			x += _CLEARING_RADIUS * 2.0
			z += _CLEARING_RADIUS * 2.0
		var y: float = 0.0
		var height_scale: float = rng.randf_range(0.85, 1.25)
		var rot: float = rng.randf_range(0.0, TAU)
		var xform: Transform3D = Transform3D(Basis(), Vector3(x, y, z))
		xform.basis = Basis(Vector3.UP, rot)
		xform.basis = xform.basis.scaled(Vector3(1.0, height_scale, 1.0))
		multimesh.set_instance_transform(i, xform)
	mm_inst.multimesh = multimesh

	var shader: Shader = load("res://shaders/wheat.gdshader") as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		multimesh.mesh.surface_set_material(0, mat)
	add_child(mm_inst)


# Single wheat blade mesh — a tapered quad for cheap silhouette + a tiny
# head cylinder for the grain.
func _make_wheat_blade_mesh() -> Mesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const _BLADE_W: float = 0.045
	const _BLADE_H: float = 1.10
	# Front face (two triangles).
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-_BLADE_W, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3( _BLADE_W, 0.0, 0.0))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-_BLADE_W * 0.25, _BLADE_H, 0.0))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3( _BLADE_W, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3( _BLADE_W * 0.25, _BLADE_H, 0.0))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-_BLADE_W * 0.25, _BLADE_H, 0.0))
	# Back face (reversed winding).
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3( _BLADE_W, 0.0, 0.0))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-_BLADE_W, 0.0, 0.0))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-_BLADE_W * 0.25, _BLADE_H, 0.0))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3( _BLADE_W * 0.25, _BLADE_H, 0.0))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-_BLADE_W, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3( _BLADE_W, 0.0, 0.0))
	st.generate_normals()
	st.index()
	return st.commit()


# ── Pollen particles ────────────────────────────────────────────────────────
func _add_pollen() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = &"Pollen"
	particles.amount = _POLLEN_COUNT
	particles.lifetime = 14.0
	particles.preprocess = 10.0
	particles.local_coords = false
	particles.position = Vector3(0.0, 2.0, 0.0)
	particles.visibility_aabb = AABB(
		Vector3(-30.0, 0.0, -30.0), Vector3(60.0, 8.0, 60.0)
	)

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(28.0, 4.0, 28.0)
	mat.gravity = Vector3(0.05, -0.02, 0.04)  # gentle horizontal drift
	mat.initial_velocity_min = 0.10
	mat.initial_velocity_max = 0.45
	mat.damping_min = 0.0
	mat.damping_max = 0.2
	mat.scale_min = 0.012
	mat.scale_max = 0.030
	mat.color = Color(1.0, 0.95, 0.7)
	particles.process_material = mat

	var pmesh: SphereMesh = SphereMesh.new()
	pmesh.radius = 1.0
	pmesh.height = 2.0
	pmesh.radial_segments = 6
	pmesh.rings = 3
	particles.draw_pass_1 = pmesh

	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.albedo_color = Color(1.0, 0.94, 0.66, 0.92)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.92, 0.55)
	pmat.emission_energy_multiplier = 1.8
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmesh.material = pmat

	add_child(particles)


# ── Distant windmill silhouette ─────────────────────────────────────────────
func _add_distant_windmill(rng: RandomNumberGenerator) -> void:
	# Single silhouette far away — gives the endless field a scale anchor.
	# A simple body + four blade arms; no animation needed (it's a silhouette).
	var root: Node3D = Node3D.new()
	root.name = &"DistantWindmill"
	# Far from the spawn — outside the camera's near distance but inside
	# the fog so it reads as a haze-tinted silhouette.
	var angle: float = rng.randf_range(0.0, TAU)
	var dist: float = rng.randf_range(90.0, 140.0)
	root.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.16, 0.12)
	dark.roughness = 1.0

	# Tower — tapered cylinder.
	var tower: MeshInstance3D = MeshInstance3D.new()
	var tower_mesh: CylinderMesh = CylinderMesh.new()
	tower_mesh.top_radius = 1.2
	tower_mesh.bottom_radius = 2.6
	tower_mesh.height = 12.0
	tower_mesh.radial_segments = 12
	tower.mesh = tower_mesh
	tower.material_override = dark
	tower.position.y = 6.0
	root.add_child(tower)

	# Hub.
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_mesh: SphereMesh = SphereMesh.new()
	hub_mesh.radius = 1.2
	hub_mesh.height = 2.4
	hub.mesh = hub_mesh
	hub.material_override = dark
	hub.position.y = 12.0
	root.add_child(hub)

	# Four blades.
	for i: int in range(4):
		var blade: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.6, 6.5, 0.2)
		blade.mesh = bm
		blade.material_override = dark
		blade.position = Vector3(0.0, 12.0, 0.0)
		blade.rotation_degrees = Vector3(0.0, 0.0, float(i) * 90.0 + 18.0)
		# Offset along the blade axis after rotation.
		var off: Vector3 = Vector3(0.0, 3.25, 0.0).rotated(
			Vector3.FORWARD, deg_to_rad(float(i) * 90.0 + 18.0)
		)
		blade.position += off
		root.add_child(blade)

	add_child(root)


# ── Common to every template ───────────────────────────────────────────────
func _add_player_spawn() -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, 1.2, 0.0)
	add_child(spawn)


func _add_post_processing(strength: float) -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 5
	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = load("res://shaders/chromatic_aberration.gdshader") as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"strength", strength)
		overlay.material = mat
	canvas.add_child(overlay)
	add_child(canvas)
