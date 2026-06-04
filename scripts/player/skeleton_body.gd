## SkeletonBody — procedural wireframe-skeleton player body.
##
## Architecture: declarative graph of joints + bones. The mesh is generated
## from this graph at startup (and rebuilt per frame for animation).
## Replaces both the GLB body and the GLB viewmodel arms — one system,
## fully introspectable, no external assets.
##
## Visual style: emissive cyan bone-lines with slightly larger joint spheres,
## reads as a holographic X-ray skeleton. Suits the drug-induced
## dimension-hopping aesthetic.
##
## Add as a child of the player CharacterBody3D.
class_name SkeletonBody
extends Node3D

# --- Anatomical joint graph (rest pose, player-local space). --------------
# Y is up, -Z is forward. Origin at feet center.

const _DEFAULT_JOINTS: Dictionary = {
	# Spine + head
	&"hip":         Vector3( 0.000, 0.95, 0.000),
	&"spine_low":   Vector3( 0.000, 1.05, 0.000),
	&"spine_mid":   Vector3( 0.000, 1.22, 0.000),
	&"spine_top":   Vector3( 0.000, 1.42, 0.000),
	&"neck":        Vector3( 0.000, 1.55, 0.000),
	&"head":        Vector3( 0.000, 1.72, 0.000),
	&"head_top":    Vector3( 0.000, 1.85, 0.000),
	# Left arm — held up at chest level, hands forward in FPS view.
	# Hands sit ~25cm below camera (camera at y=1.7) so they read as your own.
	&"shoulder_l":  Vector3( 0.20, 1.52, 0.000),
	&"elbow_l":     Vector3( 0.19, 1.50,-0.20),
	&"wrist_l":     Vector3( 0.14, 1.46,-0.45),
	&"hand_l":      Vector3( 0.12, 1.45,-0.56),
	&"finger_l_a":  Vector3( 0.08, 1.44,-0.64),
	&"finger_l_b":  Vector3( 0.11, 1.44,-0.65),
	&"finger_l_c":  Vector3( 0.14, 1.44,-0.64),
	&"finger_l_d":  Vector3( 0.17, 1.44,-0.62),
	&"thumb_l":     Vector3( 0.19, 1.47,-0.55),
	# Right arm (mirror)
	&"shoulder_r":  Vector3(-0.20, 1.52, 0.000),
	&"elbow_r":     Vector3(-0.19, 1.50,-0.20),
	&"wrist_r":     Vector3(-0.14, 1.46,-0.45),
	&"hand_r":      Vector3(-0.12, 1.45,-0.56),
	&"finger_r_a":  Vector3(-0.08, 1.44,-0.64),
	&"finger_r_b":  Vector3(-0.11, 1.44,-0.65),
	&"finger_r_c":  Vector3(-0.14, 1.44,-0.64),
	&"finger_r_d":  Vector3(-0.17, 1.44,-0.62),
	&"thumb_r":     Vector3(-0.19, 1.47,-0.55),
	# Left leg
	&"hip_l":       Vector3( 0.10, 0.92, 0.000),
	&"knee_l":      Vector3( 0.10, 0.50, 0.02),
	&"ankle_l":     Vector3( 0.10, 0.08, 0.000),
	&"toe_l":       Vector3( 0.10, 0.02, 0.18),
	# Right leg
	&"hip_r":       Vector3(-0.10, 0.92, 0.000),
	&"knee_r":      Vector3(-0.10, 0.50, 0.02),
	&"ankle_r":     Vector3(-0.10, 0.08, 0.000),
	&"toe_r":       Vector3(-0.10, 0.02, 0.18),
}

# --- Bones (joint pairs) --------------------------------------------------
const _DEFAULT_BONES: Array[Array] = [
	# Spine
	[&"hip", &"spine_low"], [&"spine_low", &"spine_mid"],
	[&"spine_mid", &"spine_top"], [&"spine_top", &"neck"],
	[&"neck", &"head"], [&"head", &"head_top"],
	# Clavicles
	[&"spine_top", &"shoulder_l"], [&"spine_top", &"shoulder_r"],
	# Left arm
	[&"shoulder_l", &"elbow_l"], [&"elbow_l", &"wrist_l"],
	[&"wrist_l", &"hand_l"],
	[&"hand_l", &"finger_l_a"], [&"hand_l", &"finger_l_b"],
	[&"hand_l", &"finger_l_c"], [&"hand_l", &"finger_l_d"],
	[&"hand_l", &"thumb_l"],
	# Right arm
	[&"shoulder_r", &"elbow_r"], [&"elbow_r", &"wrist_r"],
	[&"wrist_r", &"hand_r"],
	[&"hand_r", &"finger_r_a"], [&"hand_r", &"finger_r_b"],
	[&"hand_r", &"finger_r_c"], [&"hand_r", &"finger_r_d"],
	[&"hand_r", &"thumb_r"],
	# Pelvis
	[&"hip", &"hip_l"], [&"hip", &"hip_r"],
	# Left leg
	[&"hip_l", &"knee_l"], [&"knee_l", &"ankle_l"], [&"ankle_l", &"toe_l"],
	# Right leg
	[&"hip_r", &"knee_r"], [&"knee_r", &"ankle_r"], [&"ankle_r", &"toe_r"],
]

# --- Visual style ---------------------------------------------------------
@export var bone_color: Color = Color(0.45, 0.85, 1.0)
@export var bone_radius: float = 0.012
@export var joint_radius: float = 0.022
@export var emission_strength: float = 3.5
## Hide head + head_top so the camera doesn't see a glowing skull from inside.
@export var hide_head: bool = true

var _bone_meshes: Dictionary = {}    # bone_id (String) -> MeshInstance3D
var _joint_meshes: Dictionary = {}   # joint_name (StringName) -> MeshInstance3D
var _live_joints: Dictionary = {}    # joint_name -> Vector3 (current animated pose)
## Mutable rest pose. Initialized from _DEFAULT_JOINTS at _ready, edited by mutation
## methods (stretch_limb, multiply_appendage). Animation reads rest from here.
var _joint_rest: Dictionary = {}
## Mutable bone connectivity. Initialized from _DEFAULT_BONES at _ready, edited by
## multiply_appendage. _process iterates over this.
var _bones: Array[Array] = []
var _daze: DrugDaze
var _t: float = 0.0
var _shared_material: StandardMaterial3D


func _ready() -> void:
	# Try to find DrugDaze for animation coupling.
	var parent_body: Node = get_parent()
	if parent_body != null:
		_daze = parent_body.get_node_or_null("DrugDaze") as DrugDaze

	# Initialize mutable rest pose + bones from canonical defaults.
	for jname: StringName in _DEFAULT_JOINTS:
		_joint_rest[jname] = (_DEFAULT_JOINTS[jname] as Vector3)
		_live_joints[jname] = (_DEFAULT_JOINTS[jname] as Vector3)
	for bone: Array in _DEFAULT_BONES:
		_bones.append([bone[0], bone[1]])

	_shared_material = _make_material()
	_build_joints()
	_build_bones()


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = bone_color
	mat.emission_enabled = true
	mat.emission = bone_color
	mat.emission_energy_multiplier = emission_strength
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Soft glow blend so the skeleton feels holographic, not solid.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.92
	return mat


func _build_joints() -> void:
	for jname: StringName in _joint_rest:
		if hide_head and (jname == &"head" or jname == &"head_top" or jname == &"neck"):
			continue
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = joint_radius
		sphere.height = joint_radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		mi.mesh = sphere
		mi.material_override = _shared_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = _live_joints[jname]
		_joint_meshes[jname] = mi
		add_child(mi)


func _build_bones() -> void:
	for bone: Array in _bones:
		var a: StringName = bone[0]
		var b: StringName = bone[1]
		if hide_head and (a == &"head" or b == &"head" or a == &"head_top" or b == &"head_top"):
			continue
		var bone_id: String = String(a) + "->" + String(b)
		var mi := MeshInstance3D.new()
		mi.mesh = _make_bone_mesh()
		mi.material_override = _shared_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bone_meshes[bone_id] = mi
		add_child(mi)
		_position_bone(mi, _live_joints[a], _live_joints[b])


func _make_bone_mesh() -> CylinderMesh:
	# Unit-length cylinder along Y; we scale + reorient at place time.
	var cyl := CylinderMesh.new()
	cyl.top_radius = bone_radius
	cyl.bottom_radius = bone_radius
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	return cyl


func _position_bone(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 1e-4:
		mi.visible = false
		return
	mi.visible = true
	var midpoint: Vector3 = (a + b) * 0.5
	mi.position = midpoint
	# Default cylinder is along +Y; rotate so it points along dir.
	var up := Vector3(0, 1, 0)
	var d := dir.normalized()
	var dot: float = up.dot(d)
	if dot > 0.9999:
		mi.basis = Basis()
	elif dot < -0.9999:
		mi.basis = Basis(Vector3(1, 0, 0), PI)
	else:
		var axis: Vector3 = up.cross(d).normalized()
		var angle: float = up.angle_to(d)
		mi.basis = Basis(axis, angle)
	mi.scale = Vector3(1.0, length, 1.0)


# --- Per-frame animation: subtle breath sway + DrugDaze tremor ------------

func _process(delta: float) -> void:
	_t += delta
	var k: float = _daze.current_intensity if _daze != null else 0.0

	# Recompute live joint positions from rest pose + breath + tremor.
	for jname: StringName in _joint_rest:
		var rest: Vector3 = _joint_rest[jname]
		# Breath — subtle expansion at chest, slight rise on whole upper body.
		var breath: float = sin(_t * 1.3) * 0.006
		var height_factor: float = clampf(rest.y - 0.95, 0.0, 1.0)
		var breath_offset := Vector3(0.0, breath * height_factor, 0.0)
		# Daze tremor — bigger on extremities (high y or far from spine).
		var dist_from_spine: float = absf(rest.x) + absf(rest.z)
		var tremor_amp: float = 0.012 * k * (0.5 + dist_from_spine * 1.5)
		var tremor := Vector3(
			sin(_t * 13.0 + rest.x * 7.0) * tremor_amp,
			cos(_t * 11.0 + rest.y * 5.0) * tremor_amp,
			sin(_t * 17.0 + rest.z * 9.0) * tremor_amp,
		)
		_live_joints[jname] = rest + breath_offset + tremor

	# Update joint sphere positions.
	for jname: StringName in _joint_meshes:
		var mi: MeshInstance3D = _joint_meshes[jname]
		mi.position = _live_joints[jname]

	# Re-orient bones to follow live joints.
	for bone: Array in _bones:
		var a: StringName = bone[0]
		var b: StringName = bone[1]
		if hide_head and (a == &"head" or b == &"head" or a == &"head_top" or b == &"head_top"):
			continue
		var bone_id: String = String(a) + "->" + String(b)
		var mi: MeshInstance3D = _bone_meshes.get(bone_id)
		if mi == null:
			continue
		_position_bone(mi, _live_joints[a], _live_joints[b])


# --- Mutation API (ADR-012 v0.1) -----------------------------------------
# Three primitives the rest of the game can use to morph the body per dimension.
# Every mutator edits _joint_rest and/or _bones, then calls _rebuild() to
# regenerate the meshes. Animation continues from the new rest pose next frame.


## Hot-swap visual style. All multipliers are relative to the original exports
## so callers compose without reading current state. Pass null-equivalents
## (1.0 mults, default color) to reset.
func set_style(color: Color, emission_mult: float = 1.0,
		joint_radius_mult: float = 1.0, bone_radius_mult: float = 1.0) -> void:
	bone_color = color
	emission_strength = emission_strength * emission_mult
	joint_radius = joint_radius * joint_radius_mult
	bone_radius = bone_radius * bone_radius_mult
	_rebuild()


## Move a joint outward from its parent in the rest pose by `factor` (1.0 = no
## change, 2.0 = doubled distance from origin). Children inherit the offset
## additively so chains stretch coherently. Joint must exist or call is no-op.
func stretch_limb(joint_name: StringName, factor: float) -> void:
	if not _joint_rest.has(joint_name):
		return
	var pos: Vector3 = _joint_rest[joint_name]
	var delta: Vector3 = pos * (factor - 1.0)
	_joint_rest[joint_name] = pos + delta
	# Pull all descendants by the same vector so the chain stays connected.
	for descendant: StringName in _descendants_of(joint_name):
		_joint_rest[descendant] = (_joint_rest[descendant] as Vector3) + delta
	_rebuild()


## Duplicate the subtree rooted at `parent_joint` `count` times around the
## parent in a horizontal fan with total angular spread `spread_rad`.
## New joints get suffixes _m1, _m2, ... and inherit DrugDaze tremor automatically.
## Use case: extra fingers, centipede legs, eye-cluster spawning.
func multiply_appendage(parent_joint: StringName, count: int, spread_rad: float = 1.2) -> void:
	if not _joint_rest.has(parent_joint) or count <= 0:
		return
	var subtree: Array[StringName] = _descendants_of(parent_joint)
	if subtree.is_empty():
		return
	var origin: Vector3 = _joint_rest[parent_joint]
	for m: int in range(count):
		var t: float = -spread_rad * 0.5 + spread_rad * (float(m) + 0.5) / float(count)
		var rot: Basis = Basis(Vector3.UP, t)
		var suffix: String = "_m%d" % (m + 1)
		# Duplicate every descendant joint with a name suffix + rotation.
		for descendant: StringName in subtree:
			var rel: Vector3 = (_joint_rest[descendant] as Vector3) - origin
			var new_name := StringName(String(descendant) + suffix)
			_joint_rest[new_name] = origin + rot * rel
			_live_joints[new_name] = _joint_rest[new_name]
		# Clone every bone whose endpoints are both inside the subtree (or
		# attach to parent_joint) with the suffix renaming.
		for bone: Array in _bones.duplicate():
			var a: StringName = bone[0]
			var b: StringName = bone[1]
			var a_in: bool = a in subtree or a == parent_joint
			var b_in: bool = b in subtree
			if a_in and b_in:
				var na := a if a == parent_joint else StringName(String(a) + suffix)
				var nb := StringName(String(b) + suffix)
				_bones.append([na, nb])
	_rebuild()


## Tear down all joint + bone meshes and rebuild from current _joint_rest /
## _bones. O(joints + bones); call after any mutation. Idempotent.
func _rebuild() -> void:
	for mi: MeshInstance3D in _joint_meshes.values():
		if is_instance_valid(mi):
			mi.queue_free()
	for mi: MeshInstance3D in _bone_meshes.values():
		if is_instance_valid(mi):
			mi.queue_free()
	_joint_meshes.clear()
	_bone_meshes.clear()
	_shared_material = _make_material()
	_build_joints()
	_build_bones()


## Resets the rest pose and live joints back to the canonical default skeleton.
## Call before applying per-dimension mutations so previous mutations do not stack.
func reset_pose() -> void:
	_joint_rest.clear()
	_live_joints.clear()
	_bones.clear()
	for jname: StringName in _DEFAULT_JOINTS:
		_joint_rest[jname] = (_DEFAULT_JOINTS[jname] as Vector3)
		_live_joints[jname] = (_DEFAULT_JOINTS[jname] as Vector3)
	for bone: Array in _DEFAULT_BONES:
		_bones.append([bone[0], bone[1]])
	_rebuild()


## Resets the pose and applies a template-appropriate skeletal mutation.
## rng must be seeded by the caller for reproducibility across dimension transitions.
##
## void      — spindly: elongated spine and forearms.
## club      — dysmorphic: tripled finger fans from each hand.
## classroom — wrong proportions: legs far too long.
## isekai    — alien: two extra arms branching from each shoulder.
func mutate_for_template(template_id: StringName, rng: RandomNumberGenerator) -> void:
	reset_pose()
	# Clear any per-template extras left over from the previous dimension
	# (e.g. PseudopodRig spawned by the anatomy_alveolus template).
	_clear_per_template_extras()
	# Default: skeleton visible. Anatomy template overrides this.
	visible = true
	match template_id:
		&"void":
			stretch_limb(&"spine_mid", rng.randf_range(1.18, 1.32))
			stretch_limb(&"elbow_l", rng.randf_range(1.25, 1.42))
			stretch_limb(&"elbow_r", rng.randf_range(1.25, 1.42))
		&"club":
			multiply_appendage(&"hand_l", 2, rng.randf_range(0.5, 0.9))
			multiply_appendage(&"hand_r", 2, rng.randf_range(0.5, 0.9))
		&"classroom":
			stretch_limb(&"knee_l", rng.randf_range(1.3, 1.55))
			stretch_limb(&"knee_r", rng.randf_range(1.3, 1.55))
		&"isekai":
			multiply_appendage(&"shoulder_l", 2, rng.randf_range(0.7, 1.1))
			multiply_appendage(&"shoulder_r", 2, rng.randf_range(0.7, 1.1))
		&"anatomy_alveolus":
			# Cellular scale: the human skeleton is wrong. Hide it.
			# No first-person hands — user feedback ruled them out.
			visible = false
			if not _is_player_skeleton():
				# NPC → alveolar macrophage blob in place of the skeleton.
				_attach_macrophage_body()
		&"farm_endless":
			# Endless wheat field — keep the player skeleton hidden
			# (you are an observer at golden hour, not a body to look at).
			# NPCs stay default-visible as scarecrow-like silhouettes.
			if _is_player_skeleton():
				visible = false


## True when this SkeletonBody is the player's (parent has a Camera3D).
## False for NPCs (no camera).
func _is_player_skeleton() -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	return parent.get_node_or_null("Camera3D") is Camera3D


## Removes any nodes added by per-template extras (PseudopodRig on camera,
## MacrophageBody on self) so a subsequent template starts clean.
func _clear_per_template_extras() -> void:
	# Player-side: prior PseudopodRig under Camera3D.
	var parent: Node = get_parent()
	if parent != null:
		var camera: Camera3D = parent.get_node_or_null("Camera3D") as Camera3D
		if camera != null:
			for child in camera.get_children():
				if child is PseudopodRig:
					(child as PseudopodRig).queue_free()
	# NPC-side: prior MacrophageBody under self.
	for child in get_children():
		if child.name == &"MacrophageBody":
			child.queue_free()


## Spawns a PseudopodRig under the player's Camera3D for the anatomy
## dimension. No-op if a rig is already present.
func _attach_pseudopod_rig() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var camera: Camera3D = parent.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		# Should not happen — _is_player_skeleton() gates this call.
		return
	for child in camera.get_children():
		if child is PseudopodRig:
			return
	var rig: PseudopodRig = PseudopodRig.new()
	camera.add_child(rig)


## Spawns an alveolar-macrophage body in place of an NPC skeleton for the
## anatomy dimension. Source: OpenStax A&P 2e ch. 21 — macrophages are the
## resident phagocytic surveillance cells of the alveolar surface. Larger
## and more granular than neutrophils, amoeboid.
func _attach_macrophage_body() -> void:
	const _MACROPHAGE_HEIGHT: float = 0.85
	for child in get_children():
		if child.name == &"MacrophageBody":
			return
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.name = &"MacrophageBody"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.radial_segments = 40
	sphere.rings = 22
	blob.mesh = sphere
	blob.position = Vector3(0.0, _MACROPHAGE_HEIGHT, 0.0)
	# Slight scale jitter so each macrophage reads as an individual.
	var jitter: float = 0.85 + randf() * 0.35
	blob.scale = Vector3.ONE * jitter

	var shader: Shader = load("res://shaders/pseudopod.gdshader") as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		# Macrophage-specific tuning vs. the player's pseudopod:
		# darker membrane, denser granules, slower wobble, no extension.
		mat.set_shader_parameter(&"membrane_color", Color(0.62, 0.35, 0.40))
		mat.set_shader_parameter(&"granule_color", Color(0.18, 0.06, 0.10))
		mat.set_shader_parameter(&"nucleus_glow", Color(0.85, 0.30, 0.35))
		mat.set_shader_parameter(&"wobble_speed", 0.8)
		mat.set_shader_parameter(&"wobble_amp", 0.045)
		mat.set_shader_parameter(&"granule_density", 26.0)
		mat.set_shader_parameter(&"granule_size", 0.18)
		mat.set_shader_parameter(&"membrane_alpha", 0.88)
		mat.set_shader_parameter(&"sss_strength", 0.6)
		blob.material_override = mat
	else:
		var fb: StandardMaterial3D = StandardMaterial3D.new()
		fb.albedo_color = Color(0.55, 0.22, 0.26)
		fb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blob.material_override = fb
	add_child(blob)


## Returns all joint names downstream of `root` in the bone graph (BFS).
func _descendants_of(root: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var queue: Array[StringName] = [root]
	var seen: Dictionary = {root: true}
	while not queue.is_empty():
		var here: StringName = queue.pop_front()
		for bone: Array in _bones:
			if bone[0] == here and not seen.has(bone[1]):
				seen[bone[1]] = true
				out.append(bone[1])
				queue.append(bone[1])
	return out
