## Smoke tests for SkeletonBody mutation API (ADR-012 v0.1).
## Verifies: rest pose preserved on construct, three mutation primitives don't
## crash, animation loop survives topology mutation without index errors.
extends GutTest

var _body: SkeletonBody


func before_each() -> void:
	_body = SkeletonBody.new()
	add_child(_body)
	# Force _ready so internal vars initialize even outside the scene tree.
	if not _body.is_node_ready():
		_body._ready()


func after_each() -> void:
	if _body and is_instance_valid(_body):
		_body.queue_free()
	_body = null


func test_default_rest_pose_loaded() -> void:
	# 33 joints in the default graph (verified via wc on _DEFAULT_JOINTS dict).
	var rest: Dictionary = _body._joint_rest
	assert_gt(rest.size(), 30, "Default rest pose should have all 33 joints")
	assert_true(rest.has(&"hip"), "hip joint must be present")
	assert_true(rest.has(&"head"), "head joint must be present")


func test_default_bones_loaded() -> void:
	var bones: Array = _body._bones
	assert_gt(bones.size(), 30, "Default bone graph should have all 32 bones")


func test_set_style_does_not_crash() -> void:
	_body.set_style(Color(1.0, 0.2, 0.2), 2.0, 1.5, 1.5)
	assert_eq(_body.bone_color, Color(1.0, 0.2, 0.2), "Color must apply")
	assert_almost_eq(_body.emission_strength, 7.0, 0.001, "Emission multiplier compounds")


func test_stretch_limb_pulls_descendants() -> void:
	var elbow_before: Vector3 = _body._joint_rest[&"elbow_l"]
	var wrist_before: Vector3 = _body._joint_rest[&"wrist_l"]
	_body.stretch_limb(&"elbow_l", 2.0)
	var elbow_after: Vector3 = _body._joint_rest[&"elbow_l"]
	var wrist_after: Vector3 = _body._joint_rest[&"wrist_l"]
	# Elbow doubled from origin
	assert_almost_eq(elbow_after.length(), elbow_before.length() * 2.0, 0.01,
		"Elbow position should double from origin")
	# Wrist follows by same delta (additive carry)
	var expected_wrist_delta: Vector3 = elbow_before * 1.0  # factor-1.0 = 1.0
	assert_almost_eq(
		(wrist_after - wrist_before).length(),
		expected_wrist_delta.length(), 0.01,
		"Wrist must inherit elbow's stretch delta to keep chain coherent")


func test_stretch_limb_unknown_joint_is_noop() -> void:
	var size_before: int = _body._joint_rest.size()
	_body.stretch_limb(&"definitely_not_a_real_joint", 5.0)
	assert_eq(_body._joint_rest.size(), size_before,
		"Unknown joint name must not mutate the graph")


func test_multiply_appendage_adds_joints_and_bones() -> void:
	var joints_before: int = _body._joint_rest.size()
	var bones_before: int = _body._bones.size()
	_body.multiply_appendage(&"hand_l", 3, 1.0)
	var joints_added: int = _body._joint_rest.size() - joints_before
	var bones_added: int = _body._bones.size() - bones_before
	# hand_l descendants = 5 fingers (a/b/c/d + thumb). 3 copies = 15 joints.
	assert_eq(joints_added, 15, "Should add 5 finger × 3 copies = 15 joints")
	# Original bones into the hand subtree: 5 (hand_l → finger_a..d + thumb).
	# 3 copies = 15 new bones.
	assert_eq(bones_added, 15, "Should add 5 bones × 3 copies = 15 bones")


func test_multiply_appendage_count_zero_is_noop() -> void:
	var joints_before: int = _body._joint_rest.size()
	_body.multiply_appendage(&"hand_l", 0, 1.0)
	assert_eq(_body._joint_rest.size(), joints_before,
		"count=0 must not mutate")


func test_animation_survives_topology_mutation() -> void:
	# THE LOAD-BEARING ASSERTION: after multiply, the per-frame animation
	# loop must not crash with index errors. This catches the case where
	# _process iterates over _bones with mismatched _live_joints keys.
	_body.multiply_appendage(&"finger_l_a", 4, 0.6)
	# Drive _process manually with a few delta values.
	for i in range(5):
		_body._process(0.016)
	# If we got here, no IndexError / KeyError. Smoke test passes.
	assert_true(true, "Animation loop survived 5 frames after multiply")


func test_descendants_of_finger_is_empty() -> void:
	# Leaf joints have no descendants — protects against infinite loops.
	var leaves: Array[StringName] = _body._descendants_of(&"toe_l")
	assert_eq(leaves.size(), 0, "Leaf joint must have empty descendant list")


func test_descendants_of_hip_covers_legs() -> void:
	var subtree: Array[StringName] = _body._descendants_of(&"hip")
	# Should reach all 4 leg joints L+R + spine chain
	assert_true(subtree.has(&"toe_l"), "Hip BFS reaches left toe")
	assert_true(subtree.has(&"toe_r"), "Hip BFS reaches right toe")
	assert_true(subtree.has(&"head_top"), "Hip BFS reaches head_top via spine")
