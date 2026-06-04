## Main — root scene script. Bootstraps the first dimension and wires autoload signals.
extends Node

@onready var _player: CharacterBody3D = $Player as CharacterBody3D


func _ready() -> void:
	if _player == null:
		push_error("Main: Player node not found — check player.tscn instance in main.tscn")
		return

	GameState.final_event_triggered.connect(_on_final_event)
	DimensionManager.dimension_loaded.connect(_on_dimension_loaded)

	var dm := DeathManager.new()
	dm.name = "DeathManager"
	_player.add_child(dm)

	var cause_fall := CauseFall.new()
	cause_fall.name = "CauseFall"
	dm.add_child(cause_fall)
	cause_fall.setup(_player, dm)

	dm.player_died.connect(_on_player_died)

	_add_global_post_processing()

	var daze := DrugDaze.new()
	daze.name = "DrugDaze"
	_player.add_child(daze)

	# Audio coupling — tinnitus + heartbeat that ride daze intensity.
	var daze_audio := DazeAudio.new()
	daze_audio.name = "DazeAudio"
	_player.add_child(daze_audio)

	# Single procedural skeleton — replaces both the GLB body and the GLB
	# viewmodel arms. Self-illuminating cyan bone-lines, X-ray aesthetic.
	# When you look down you see your own skeleton; arms-up FPS pose visible
	# when you look forward. No external models, no light dependency.
	var skeleton := SkeletonBody.new()
	skeleton.name = "SkeletonBody"
	_player.add_child(skeleton)

	DimensionManager.load_next_dimension(_player)
	# Skip the wake-up daze when running headless screenshot harness — we want
	# clean unobscured shots for tuning the model.
	if OS.get_environment("DIM_SHOT") == "":
		_wake_up_sequence(daze, 2.2, 12.0)


## Holds black, fades up while the daze peaks, then runs the daze decay.
## fade_in is the black-to-clear time; daze_secs is the total drug-effect
## duration starting at the moment the fade begins.
func _wake_up_sequence(daze: DrugDaze, fade_in: float, daze_secs: float) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 8  # above post-FX, below death (10)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.0, 0.0, 0.0, 1.0)
	# Critical: do not eat mouse motion / clicks while fading.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	add_child(canvas)

	# Daze starts immediately — shake/blur happen behind the black so it's
	# already disorienting the moment vision arrives.
	daze.begin(daze_secs)

	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(rect, "color", Color(0.0, 0.0, 0.0, 0.0), fade_in)
	tween.tween_callback(canvas.queue_free)


func _add_global_post_processing() -> void:
	# Layer 6: renders above per-dimension chromatic aberration (layer 5)
	# and below DeathSequence (10) and FinalEvent (20).
	var canvas := CanvasLayer.new()
	canvas.layer = 6

	var grain_overlay := ColorRect.new()
	grain_overlay.name = "GrainOverlay"
	grain_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grain_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grain_mat := ShaderMaterial.new()
	grain_mat.shader = load("res://shaders/film_grain.gdshader") as Shader
	grain_mat.set_shader_parameter(&"strength", 0.045)
	grain_mat.set_shader_parameter(&"speed", 8.0)
	grain_overlay.material = grain_mat
	canvas.add_child(grain_overlay)

	var vignette_overlay := ColorRect.new()
	vignette_overlay.name = "VignetteOverlay"
	vignette_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = load("res://shaders/vignette.gdshader") as Shader
	vignette_mat.set_shader_parameter(&"strength", 1.1)
	vignette_mat.set_shader_parameter(&"softness", 0.65)
	vignette_overlay.material = vignette_mat
	canvas.add_child(vignette_overlay)

	add_child(canvas)


func _on_dimension_loaded() -> void:
	var dim: Node3D = DimensionManager.get_current_dimension()
	if dim == null:
		return
	var dim_root: DimensionRoot = dim as DimensionRoot
	if dim_root == null:
		return
	var spawn_pos: Vector3 = dim_root.get_player_spawn()
	_player.global_position = spawn_pos
	var cf: CauseFall = _player.get_node_or_null("DeathManager/CauseFall") as CauseFall
	if cf != null:
		cf.reset_fall_state()
	# Re-capture mouse after every dimension load — protects against
	# focus loss or stray Escape during transition.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Play per-dimension ambient audio if available.
	var data: DimensionData = DimensionManager.get_current_data()
	if data != null:
		var ambient_path: String = "res://audio/ambient/%s.ogg" % data.template_id
		AmbientAudio.play(ambient_path)


func _on_player_died(cause: DeathCause) -> void:
	DimensionManager.trigger_death(_player, cause)


func _on_final_event() -> void:
	var dm: DeathManager = _player.get_node_or_null("DeathManager") as DeathManager
	if dm != null and dm.player_died.is_connected(_on_player_died):
		dm.player_died.disconnect(_on_player_died)

	AmbientAudio.stop()

	var packed: PackedScene = load("res://scenes/final_event.tscn") as PackedScene
	if packed == null:
		push_error("Main: failed to load final_event.tscn")
		return
	var fe: FinalEvent = packed.instantiate() as FinalEvent
	if fe == null:
		push_error("Main: final_event.tscn root is not FinalEvent")
		return
	add_child(fe)
	fe.play()


func _input(event: InputEvent) -> void:
	# Release mouse cursor when Escape is pressed.
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
