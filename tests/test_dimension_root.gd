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
