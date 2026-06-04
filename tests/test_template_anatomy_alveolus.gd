## Smoke tests for TemplateAnatomyAlveolus.
## Verifies the template registers, instantiates, builds without errors,
## and produces a PlayerSpawn marker as required by DimensionRoot contract.
extends GutTest


func test_template_class_is_loadable() -> void:
	var t: TemplateAnatomyAlveolus = TemplateAnatomyAlveolus.new()
	assert_not_null(t, "TemplateAnatomyAlveolus.new() must return non-null")
	t.queue_free()


func test_build_produces_player_spawn() -> void:
	var t: TemplateAnatomyAlveolus = TemplateAnatomyAlveolus.new()
	var d: DimensionData = DimensionData.new()
	d.template_id = &"anatomy_alveolus"
	d.seed = 12345
	d.fog_density = 0.04
	t.data = d
	add_child_autofree(t)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = d.seed
	t.build(rng)

	var spawn: Marker3D = t.find_child("PlayerSpawn", true, false) as Marker3D
	assert_not_null(spawn, "build() must add a PlayerSpawn Marker3D")
	assert_gt(spawn.position.y, 0.0, "PlayerSpawn must be above the surfactant floor")


func test_build_is_deterministic_for_same_seed() -> void:
	var d: DimensionData = DimensionData.new()
	d.template_id = &"anatomy_alveolus"
	d.seed = 42

	var a: TemplateAnatomyAlveolus = TemplateAnatomyAlveolus.new()
	a.data = d
	add_child_autofree(a)
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	a.build(rng_a)
	var nuclei_a: int = _count_nuclei(a)

	var b: TemplateAnatomyAlveolus = TemplateAnatomyAlveolus.new()
	b.data = d
	add_child_autofree(b)
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 42
	b.build(rng_b)
	var nuclei_b: int = _count_nuclei(b)

	assert_eq(nuclei_a, nuclei_b, "Same seed must produce the same nucleus count")


func _count_nuclei(template: Node3D) -> int:
	var n: int = 0
	for child in template.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh:
			var s: SphereMesh = child.mesh as SphereMesh
			# Nuclei radius range is 0.18..0.42 — distinguishes them from the wall
			# sphere (12.0) and pores (0.7..1.4).
			if s.radius >= 0.15 and s.radius <= 0.45:
				n += 1
	return n


func test_generator_can_select_anatomy_alveolus() -> void:
	# Probabilistic — with 5 templates and 200 trials, P(never picking anatomy)
	# is (4/5)^200 ≈ 3.5e-20. Essentially deterministic in practice.
	var gen: DimensionGenerator = DimensionGenerator.new()
	var hit: bool = false
	for i: int in range(200):
		var data: DimensionData = gen.generate()
		if data.template_id == &"anatomy_alveolus":
			hit = true
			break
	assert_true(hit, "DimensionGenerator must be able to select anatomy_alveolus")
