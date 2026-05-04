## Tests for DimensionRoot — initialize(), tracker wiring, spawn fallback.
extends GutTest

var _root: DimensionRoot

func before_each() -> void:
	_root = DimensionRoot.new()
	add_child_autofree(_root)

func _make_data(threshold: float = 30.0) -> DimensionData:
	var d: DimensionData = DimensionData.new()
	d.template_id = &"void"
	d.seed = 12345
	d.survival_threshold = threshold
	d.npc_count_min = 1
	d.npc_count_max = 2
	d.gravity_scale = 1.0
	d.fog_density = 0.02
	d.ambient_color = Color(0.05, 0.05, 0.07)
	return d

func test_get_data_returns_null_before_initialize() -> void:
	assert_null(_root.get_data())

func test_get_data_returns_data_after_initialize() -> void:
	var data: DimensionData = _make_data()
	_root.initialize(data, null)
	assert_eq(_root.get_data(), data)

func test_tracker_added_as_child() -> void:
	_root.initialize(_make_data(), null)
	var found: bool = false
	for child: Node in _root.get_children():
		if child is CompletionTracker:
			found = true
			break
	assert_true(found, "CompletionTracker not found as child of DimensionRoot")

func test_tracker_threshold_matches_data() -> void:
	var data: DimensionData = _make_data(77.5)
	_root.initialize(data, null)
	for child: Node in _root.get_children():
		if child is CompletionTracker:
			assert_eq(child.threshold, 77.5)
			return
	fail_test("CompletionTracker not found")

func test_player_spawn_fallback_returns_zero() -> void:
	_root.initialize(_make_data(), null)
	# Void template has a PlayerSpawn; skip template setup by calling get_player_spawn
	# before any template child has a Marker3D named PlayerSpawn.
	# Use a bare DimensionRoot without calling initialize to test raw fallback:
	var bare: DimensionRoot = DimensionRoot.new()
	add_child_autofree(bare)
	assert_eq(bare.get_player_spawn(), Vector3.ZERO)

func test_initialize_is_idempotent_on_data() -> void:
	var d1: DimensionData = _make_data(30.0)
	var d2: DimensionData = _make_data(60.0)
	_root.initialize(d1, null)
	# Re-initializing with d2 should not crash; data should be the last set
	# (DimensionRoot does not protect against re-init in Phase 2 — testing current behavior)
	_root.initialize(d2, null)
	assert_eq(_root.get_data(), d2)

func test_unknown_template_id_falls_back_gracefully() -> void:
	var data: DimensionData = _make_data()
	data.template_id = &"nonexistent_template"
	# Should not crash — should fall back to TemplateVoid
	_root.initialize(data, null)
	assert_not_null(_root.get_data())


# ---------------------------------------------------------------------------
# _spawn_npcs — null player guard (safe without physics scene)
# ---------------------------------------------------------------------------

func test_spawn_npcs_skips_npc_container_when_player_null() -> void:
	# All existing tests pass null — verify that no NPCContainer is created.
	_root.initialize(_make_data(), null)
	var found: bool = false
	for child: Node in _root.get_children():
		if child is Node3D and child.name == "NPCContainer":
			found = true
			break
	assert_false(found)


func test_spawn_npcs_creates_npc_container_when_player_provided() -> void:
	# Provide a real CharacterBody3D so _spawn_npcs proceeds past the null guard.
	var player := CharacterBody3D.new()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO

	# npc_count_min/max = 1/1 so exactly one NPC is spawned.
	var data: DimensionData = _make_data()
	data.npc_count_min = 1
	data.npc_count_max = 1
	_root.initialize(data, player)

	var found: bool = false
	for child: Node in _root.get_children():
		if child is Node3D and child.name == "NPCContainer":
			found = true
			break
	assert_true(found)


func test_spawn_npcs_npc_count_matches_min_when_min_equals_max() -> void:
	var player := CharacterBody3D.new()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO

	var data: DimensionData = _make_data()
	data.npc_count_min = 2
	data.npc_count_max = 2
	_root.initialize(data, player)

	var npc_container: Node = null
	for child: Node in _root.get_children():
		if child is Node3D and child.name == "NPCContainer":
			npc_container = child
			break

	assert_not_null(npc_container)
	assert_eq(npc_container.get_child_count(), 2)


func test_spawn_npcs_npcs_are_npc_controller_instances() -> void:
	var player := CharacterBody3D.new()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO

	var data: DimensionData = _make_data()
	data.npc_count_min = 1
	data.npc_count_max = 1
	_root.initialize(data, player)

	var npc_container: Node = null
	for child: Node in _root.get_children():
		if child is Node3D and child.name == "NPCContainer":
			npc_container = child
			break

	assert_not_null(npc_container)
	assert_true(npc_container.get_child(0) is NPCController)


func test_spawn_npcs_all_npcs_outside_minimum_spawn_distance() -> void:
	var player := CharacterBody3D.new()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO

	var data: DimensionData = _make_data()
	data.npc_count_min = 3
	data.npc_count_max = 3
	_root.initialize(data, player)

	var npc_container: Node = null
	for child: Node in _root.get_children():
		if child is Node3D and child.name == "NPCContainer":
			npc_container = child
			break

	assert_not_null(npc_container)
	for child: Node in npc_container.get_children():
		var npc := child as NPCController
		if npc == null:
			continue
		var dist: float = npc.position.distance_to(player.global_position)
		# _SPAWN_MIN_DIST = 2.0 — every NPC must be at least 2m from the player.
		assert_true(dist >= 2.0)
