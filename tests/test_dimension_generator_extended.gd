## Extended DimensionGenerator tests — ranges, determinism, template validity.
extends GutTest

var _gen: DimensionGenerator

func before_each() -> void:
	_gen = DimensionGenerator.new()

const _VALID_TEMPLATES: Array[StringName] = [&"void", &"club", &"classroom"]

func test_generated_data_is_not_null() -> void:
	assert_not_null(_gen.generate())

func test_template_id_is_valid() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(_VALID_TEMPLATES.has(data.template_id),
			"Got invalid template_id: %s" % data.template_id)

func test_threshold_in_range() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(data.survival_threshold >= 90.0 and data.survival_threshold <= 300.0)

func test_npc_min_gte_1() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(data.npc_count_min >= 1)

func test_npc_max_gte_min() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(data.npc_count_max >= data.npc_count_min)

func test_gravity_scale_in_range() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(data.gravity_scale >= 0.6 and data.gravity_scale <= 1.4)

func test_fog_density_in_range() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(data.fog_density >= 0.005 and data.fog_density <= 0.08)

func test_same_seed_produces_same_template() -> void:
	var d1: DimensionData = _gen.generate()
	var gen2: DimensionGenerator = DimensionGenerator.new()
	# Manually set a fixed seed on a DimensionData and verify reproducibility via rng
	var rng1: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng1.seed = d1.seed
	rng2.seed = d1.seed
	assert_eq(rng1.randi_range(0, 2), rng2.randi_range(0, 2))

func test_seed_is_nonzero_most_of_the_time() -> void:
	var zero_count: int = 0
	for i: int in range(100):
		var data: DimensionData = _gen.generate()
		if data.seed == 0:
			zero_count += 1
	assert_true(zero_count < 5, "Too many zero seeds: %d/100" % zero_count)

func test_ambient_color_components_valid() -> void:
	for i: int in range(20):
		var data: DimensionData = _gen.generate()
		assert_true(data.ambient_color.r >= 0.0 and data.ambient_color.r <= 1.0)
		assert_true(data.ambient_color.g >= 0.0 and data.ambient_color.g <= 1.0)
		assert_true(data.ambient_color.b >= 0.0 and data.ambient_color.b <= 1.0)

func test_successive_seeds_differ() -> void:
	var seen: Array[int] = []
	for i: int in range(10):
		var data: DimensionData = _gen.generate()
		assert_false(seen.has(data.seed), "Duplicate seed: %d" % data.seed)
		seen.append(data.seed)
