## TemplateAnatomyAlveolus — psychological survival inside a single pulmonary alveolus.
## You are cell-scale. The walls breathe. The macrophages patrol.
## All anatomical facts pulled from NOESIS workspace:anatomy-openstax (OpenStax A&P 2e
## chapter 22 — Respiratory System; chapter 21 — Lymphatic & Immune System).
##
## build() is called by DimensionRoot after add_child(). data must be set first.
class_name TemplateAnatomyAlveolus
extends Node3D

## DimensionData set by DimensionRoot before build() is called.
@export var data: DimensionData

# Alveolus interior is a sphere; player walks the inside of the lower half.
# Real alveoli are 200-300 µm diameter — at game-scale we render 12m radius.
const _ALVEOLUS_RADIUS: float = 12.0
## Number of pneumocyte nuclei studded across the inner wall surface.
const _NUCLEI_COUNT: int = 48
## Number of pores-of-Kohn (alveolus-to-alveolus communicating openings).
const _PORES_OF_KOHN: int = 4
## Breath cycle in seconds (12 breaths/min resting → 5s period).
const _BREATH_PERIOD: float = 5.0
## Player spawn height above the surfactant pool.
const _SPAWN_Y: float = 1.4

# Anatomical facts surfaced diegetically (etched into the alveolar wall).
# Source: OpenStax A&P 2e ch. 21-22, retrieved via NOESIS 2026-05-17.
const _FACTS: Array[String] = [
	"the alveolar epithelium is a single cell thick.\nyou are inside that thickness.",
	"surfactant prevents collapse.\nbreathe.\nbreathe.",
	"type I pneumocytes form 95% of the surface.\ntype II make the surfactant.\ndon't touch the type II.",
	"macrophages patrol here.\nthey eat anything not the body.\nare you the body?",
	"the capillary on the other side is one cell thick.\noxygen crosses in a microsecond.\nyou are the oxygen.",
	"twelve breaths per minute. one hundred million alveoli.\nyou will not be missed.",
]


## Constructs the alveolus interior using rng seeded by DimensionRoot.
func build(rng: RandomNumberGenerator) -> void:
	_add_environment()
	_add_lighting()
	_add_alveolar_wall()
	_add_surfactant_pool()
	_add_pneumocyte_nuclei(rng)
	_add_pores_of_kohn(rng)
	_add_capillary_band()
	_add_fact_etchings(rng)
	_add_breath_pulse()
	_add_player_spawn()
	_add_post_processing(0.012)


# ── Environment ─────────────────────────────────────────────────────────────
func _add_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()

	# Warm pink-red ambient — blood seen through the one-cell wall.
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.35, 0.08, 0.10)

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.22, 0.26)
	environment.ambient_light_energy = 0.55

	# Surfactant haze — present but readable. Earlier tuning was 1.5x denser
	# than the source data and felt opaque from inside the alveolus.
	environment.fog_enabled = true
	environment.fog_density = clampf(
		(data.fog_density if data != null else 0.04) * 0.7, 0.005, 0.035
	)
	environment.fog_light_color = Color(0.55, 0.18, 0.20)
	environment.fog_sun_scatter = 0.25

	# Subsurface glow on bright surfaces (capillaries, surfactant).
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_strength = 1.3
	environment.glow_bloom = 0.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# ACES tonemap. Slightly desaturated — alive but anaesthetic.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.92
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 0.82

	# SSAO so the curved wall reads as concave.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.8

	env.environment = environment
	add_child(env)


func _add_lighting() -> void:
	# No directional sun — light leaks through the wall from the capillary side.
	var omni: OmniLight3D = OmniLight3D.new()
	omni.name = &"CapillaryLight"
	omni.light_color = Color(1.0, 0.45, 0.50)
	omni.light_energy = 2.2
	omni.omni_range = _ALVEOLUS_RADIUS * 1.6
	omni.omni_attenuation = 1.4
	omni.position = Vector3(0.0, _ALVEOLUS_RADIUS * 0.3, _ALVEOLUS_RADIUS * 0.8)
	add_child(omni)

	# Fill from opposite side, weaker.
	var fill: OmniLight3D = OmniLight3D.new()
	fill.light_color = Color(0.85, 0.30, 0.35)
	fill.light_energy = 1.1
	fill.omni_range = _ALVEOLUS_RADIUS * 1.6
	fill.position = Vector3(0.0, _ALVEOLUS_RADIUS * 0.3, -_ALVEOLUS_RADIUS * 0.8)
	add_child(fill)


# ── Geometry ────────────────────────────────────────────────────────────────
func _add_alveolar_wall() -> void:
	# Inverted sphere — the inside surface is the visible face from the player.
	# High tessellation so the per-vertex breath wobble reads smoothly.
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = &"AlveolarWall"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = _ALVEOLUS_RADIUS
	sphere.height = _ALVEOLUS_RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	mesh_inst.mesh = sphere

	# Realistic alveolar epithelium shader — Voronoi cell mosaic + capillary
	# backlight + breath pulse. Source: shaders/alveolar_wall.gdshader.
	var shader: Shader = load("res://shaders/alveolar_wall.gdshader") as Shader
	if shader != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter(&"breath_period", _BREATH_PERIOD)
		mesh_inst.material_override = smat
	else:
		# Fallback so the dimension still renders if the shader file is missing.
		var fb: StandardMaterial3D = StandardMaterial3D.new()
		fb.albedo_color = Color(0.78, 0.42, 0.46)
		fb.cull_mode = BaseMaterial3D.CULL_FRONT
		mesh_inst.material_override = fb
	add_child(mesh_inst)

	# No collider on the wall — CharacterBody3D can't ride the inside of an
	# inverted sphere efficiently. Containment is enforced by 8 thin wall
	# panels arranged radially around the lumen.
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		var panel_body: StaticBody3D = StaticBody3D.new()
		var panel_col: CollisionShape3D = CollisionShape3D.new()
		var panel_shape: BoxShape3D = BoxShape3D.new()
		panel_shape.size = Vector3(
			_ALVEOLUS_RADIUS * 0.85, _ALVEOLUS_RADIUS * 1.6, 0.2
		)
		panel_col.shape = panel_shape
		panel_body.add_child(panel_col)
		panel_body.position = Vector3(
			cos(angle) * (_ALVEOLUS_RADIUS - 0.4),
			_ALVEOLUS_RADIUS * 0.6,
			sin(angle) * (_ALVEOLUS_RADIUS - 0.4),
		)
		panel_body.rotation.y = -angle
		add_child(panel_body)


func _add_surfactant_pool() -> void:
	# Flat floor at y=0 representing the surfactant fluid layer.
	# Player walks on this; it is the bottom of the alveolar lumen.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = &"SurfactantFloor"
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(_ALVEOLUS_RADIUS * 2.0, 0.2, _ALVEOLUS_RADIUS * 2.0)
	col.shape = shape
	col.position = Vector3(0.0, -0.1, 0.0)
	body.add_child(col)
	add_child(body)

	# Visible surfactant — animated shader (bubbles, edge foam, ripple).
	# PlaneMesh tessellated so per-vertex ripple is visible.
	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = &"SurfactantSurface"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(_ALVEOLUS_RADIUS * 1.9, _ALVEOLUS_RADIUS * 1.9)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	disc.mesh = plane
	disc.position = Vector3(0.0, 0.04, 0.0)

	var sshader: Shader = load("res://shaders/surfactant.gdshader") as Shader
	if sshader != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = sshader
		disc.material_override = smat
	else:
		var fb: StandardMaterial3D = StandardMaterial3D.new()
		fb.albedo_color = Color(0.92, 0.78, 0.72, 0.55)
		fb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = fb
	add_child(disc)


func _add_pneumocyte_nuclei(rng: RandomNumberGenerator) -> void:
	# Studded along the upper hemisphere of the wall — visible cell nuclei.
	for i: int in range(_NUCLEI_COUNT):
		var theta: float = rng.randf_range(0.05, PI * 0.95)
		var phi: float = rng.randf_range(0.0, TAU)
		# Push slightly inward so the nucleus pokes into the lumen.
		var r: float = _ALVEOLUS_RADIUS - rng.randf_range(0.05, 0.35)
		var pos: Vector3 = Vector3(
			r * sin(theta) * cos(phi),
			r * cos(theta),
			r * sin(theta) * sin(phi),
		)
		# Skip nuclei below the surfactant floor.
		if pos.y < 0.5:
			continue

		var nucleus: MeshInstance3D = MeshInstance3D.new()
		var s: SphereMesh = SphereMesh.new()
		s.radius = rng.randf_range(0.18, 0.42)
		s.height = s.radius * 2.0
		s.radial_segments = 16
		s.rings = 10
		nucleus.mesh = s
		nucleus.position = pos

		var nmat: StandardMaterial3D = StandardMaterial3D.new()
		nmat.albedo_color = Color(0.45, 0.12, 0.20)
		nmat.roughness = 0.7
		nmat.emission_enabled = true
		nmat.emission = Color(0.65, 0.20, 0.28)
		nmat.emission_energy_multiplier = 0.4
		nucleus.material_override = nmat
		add_child(nucleus)


func _add_pores_of_kohn(rng: RandomNumberGenerator) -> void:
	# Dark holes in the wall — communicating openings to adjacent alveoli.
	# Purely visual; they look like wells of black at cellular scale.
	for i: int in range(_PORES_OF_KOHN):
		var phi: float = rng.randf_range(0.0, TAU)
		var theta: float = rng.randf_range(PI * 0.25, PI * 0.65)
		var r: float = _ALVEOLUS_RADIUS - 0.05
		var pos: Vector3 = Vector3(
			r * sin(theta) * cos(phi),
			r * cos(theta),
			r * sin(theta) * sin(phi),
		)
		var pore: MeshInstance3D = MeshInstance3D.new()
		var s: SphereMesh = SphereMesh.new()
		s.radius = rng.randf_range(0.7, 1.4)
		s.height = s.radius * 2.0
		s.radial_segments = 24
		s.rings = 12
		pore.mesh = s
		pore.position = pos

		var pmat: StandardMaterial3D = StandardMaterial3D.new()
		pmat.albedo_color = Color(0.02, 0.0, 0.0)
		pmat.roughness = 1.0
		pmat.emission_enabled = true
		pmat.emission = Color.BLACK
		pore.material_override = pmat
		add_child(pore)


func _add_capillary_band() -> void:
	# A thick translucent torus wrapping the alveolus equator — the surrounding
	# capillary network seen from inside.
	var torus_inst: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = _ALVEOLUS_RADIUS - 0.6
	torus.outer_radius = _ALVEOLUS_RADIUS + 0.6
	torus.rings = 96
	torus.ring_segments = 12
	torus_inst.mesh = torus
	torus_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	torus_inst.position = Vector3(0.0, _ALVEOLUS_RADIUS * 0.35, 0.0)

	var tmat: StandardMaterial3D = StandardMaterial3D.new()
	tmat.albedo_color = Color(0.95, 0.18, 0.22, 0.45)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.28, 0.30)
	tmat.emission_energy_multiplier = 1.2
	torus_inst.material_override = tmat
	add_child(torus_inst)


# ── Diegetic facts (NOESIS-sourced) ─────────────────────────────────────────
func _add_fact_etchings(rng: RandomNumberGenerator) -> void:
	# Place a subset of facts as Label3D nodes etched into the alveolar wall.
	# Subtle — the player has to look for them.
	var picks: Array[String] = _FACTS.duplicate()
	picks.shuffle()
	var count: int = min(3, picks.size())
	for i: int in range(count):
		var phi: float = rng.randf_range(0.0, TAU)
		var theta: float = rng.randf_range(PI * 0.3, PI * 0.7)
		var r: float = _ALVEOLUS_RADIUS - 0.4
		var pos: Vector3 = Vector3(
			r * sin(theta) * cos(phi),
			r * cos(theta),
			r * sin(theta) * sin(phi),
		)
		var lbl: Label3D = Label3D.new()
		lbl.text = picks[i]
		lbl.font_size = 14
		lbl.modulate = Color(0.92, 0.78, 0.78, 0.85)
		lbl.outline_modulate = Color(0.1, 0.02, 0.04, 0.9)
		lbl.outline_size = 6
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = false
		lbl.shaded = false
		lbl.position = pos
		lbl.pixel_size = 0.006
		add_child(lbl)


# ── Breath pulse (animated wall ambient) ────────────────────────────────────
func _add_breath_pulse() -> void:
	# AnimationPlayer that pulses the CapillaryLight energy on a breath cycle —
	# inhale brightens, exhale dims. Period from _BREATH_PERIOD.
	var anim_player: AnimationPlayer = AnimationPlayer.new()
	anim_player.name = &"BreathPulse"

	var lib: AnimationLibrary = AnimationLibrary.new()
	var anim: Animation = Animation.new()
	anim.length = _BREATH_PERIOD
	anim.loop_mode = Animation.LOOP_LINEAR

	var track_idx: int = anim.add_track(Animation.TYPE_VALUE)
	# Path is relative to the AnimationPlayer's root_node (default: parent ".").
	# So the sibling light is just "CapillaryLight".
	anim.track_set_path(track_idx, NodePath("CapillaryLight:light_energy"))
	# Lower peak so the inhale doesn't wash the screen to bright red.
	anim.track_insert_key(track_idx, 0.0, 1.4)
	anim.track_insert_key(track_idx, _BREATH_PERIOD * 0.45, 2.2)  # inhale peak
	anim.track_insert_key(track_idx, _BREATH_PERIOD * 0.55, 2.2)
	anim.track_insert_key(track_idx, _BREATH_PERIOD, 1.4)

	lib.add_animation(&"breathe", anim)
	anim_player.add_animation_library(&"", lib)
	add_child(anim_player)
	anim_player.play(&"breathe")


# ── Common to every template ───────────────────────────────────────────────
func _add_player_spawn() -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = &"PlayerSpawn"
	spawn.position = Vector3(0.0, _SPAWN_Y, 0.0)
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
