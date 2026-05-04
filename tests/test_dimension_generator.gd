## Tests for DimensionData resource and DimensionGenerator.
extends GutTest


func test_dimension_data_has_required_fields() -> void:
	var d: DimensionData = DimensionData.new()
	assert_has_method(d, "get_template_id")
	assert_gt(d.survival_threshold, 0.0, "Default threshold must be positive")
	assert_gt(d.npc_count_min, 0, "Default npc_count_min must be at least 1")


func test_dimension_data_has_rule_fields() -> void:
	var d: DimensionData = DimensionData.new()
	# NEXUS contract: rule_id and rule_param must exist
	assert_eq(d.rule_id, &"", "Default rule_id must be empty StringName")
	assert_true(d.rule_param.is_empty(), "Default rule_param must be empty Dictionary")


func test_generator_produces_valid_data() -> void:
	var gen: DimensionGenerator = DimensionGenerator.new()
	var data: DimensionData = gen.generate()
	assert_not_null(data, "generate() must return DimensionData")
	assert_gt(data.survival_threshold, 0.0, "Threshold must be positive")
	assert_true(
		data.npc_count_min <= data.npc_count_max,
		"npc_count_min must not exceed npc_count_max"
	)


func test_generator_is_random_across_calls() -> void:
	var gen: DimensionGenerator = DimensionGenerator.new()
	var a: DimensionData = gen.generate()
	var b: DimensionData = gen.generate()
	assert_ne(a.seed, b.seed, "Two consecutive calls must produce different seeds")


func test_generator_threshold_is_positive() -> void:
	var gen: DimensionGenerator = DimensionGenerator.new()
	var data: DimensionData = gen.generate()
	assert_gt(data.survival_threshold, 0.0, "Generated threshold must be positive")
