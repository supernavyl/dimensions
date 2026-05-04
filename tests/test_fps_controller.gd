## Tests for FPSController and InteractionHandler player components.
extends GutTest

var _player: CharacterBody3D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	if scene == null:
		push_error("test_fps_controller: could not load player.tscn")
		return
	_player = scene.instantiate() as CharacterBody3D
	add_child(_player)


func after_each() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
	_player = null


func test_player_has_camera() -> void:
	var cam: Camera3D = _player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(cam, "Player must have Camera3D child")


func test_player_sensitivity_is_positive() -> void:
	var ctrl: FPSController = _player.get_node_or_null("FPSController") as FPSController
	assert_not_null(ctrl, "Player must have FPSController child")
	assert_gt(ctrl.mouse_sensitivity, 0.0, "Sensitivity must be positive")


func test_interaction_handler_exists() -> void:
	var ih: Node = _player.get_node_or_null("InteractionHandler")
	assert_not_null(ih, "Player must have InteractionHandler node")


func test_interaction_reach_is_positive() -> void:
	var ih: InteractionHandler = _player.get_node_or_null("InteractionHandler") as InteractionHandler
	assert_not_null(ih, "InteractionHandler must exist")
	assert_gt(ih.reach, 0.0, "Reach must be positive")
