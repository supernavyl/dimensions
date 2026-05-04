## DimensionGenerator — produces randomized DimensionData instances.
## Call generate() each time a new dimension is needed.
class_name DimensionGenerator
extends RefCounted

const _TEMPLATES: Array[StringName] = [&"void", &"club", &"classroom"]
const _THRESHOLD_MIN: float = 90.0
const _THRESHOLD_MAX: float = 300.0
const _GRAVITY_MIN: float = 0.6
const _GRAVITY_MAX: float = 1.4
const _FOG_MIN: float = 0.005
const _FOG_MAX: float = 0.08


## Generates one randomized DimensionData with a unique seed.
func generate() -> DimensionData:
	var data: DimensionData = DimensionData.new()
	# Each call gets a globally unique integer seed.
	data.seed = randi()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = data.seed

	data.template_id = _TEMPLATES[rng.randi_range(0, _TEMPLATES.size() - 1)]
	data.survival_threshold = rng.randf_range(_THRESHOLD_MIN, _THRESHOLD_MAX)
	data.npc_count_min = rng.randi_range(1, 3)
	data.npc_count_max = data.npc_count_min + rng.randi_range(0, 3)
	data.gravity_scale = rng.randf_range(_GRAVITY_MIN, _GRAVITY_MAX)
	data.fog_density = rng.randf_range(_FOG_MIN, _FOG_MAX)

	var hue: float = rng.randf()
	data.ambient_color = Color.from_hsv(
		hue,
		rng.randf_range(0.0, 0.3),
		rng.randf_range(0.02, 0.12)
	)

	return data
