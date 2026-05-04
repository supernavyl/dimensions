## Main — root scene script. Bootstraps the first dimension and wires autoload signals.
extends Node

@onready var _player: CharacterBody3D = $Player as CharacterBody3D


func _ready() -> void:
	if _player == null:
		push_error("Main: Player node not found — check player.tscn instance in main.tscn")
		return

	GameState.final_event_triggered.connect(_on_final_event)
	DimensionManager.dimension_loaded.connect(_on_dimension_loaded)

	DimensionManager.load_next_dimension(_player)


func _on_dimension_loaded() -> void:
	var dim: Node3D = DimensionManager.get_current_dimension()
	if dim == null:
		return
	var dim_root: DimensionRoot = dim as DimensionRoot
	if dim_root == null:
		return
	var spawn_pos: Vector3 = dim_root.get_player_spawn()
	_player.global_position = spawn_pos


func _on_final_event() -> void:
	# Phase 5 wires in FinalEvent scene.
	# Stub: log and do nothing — prevents crash if fired before scene is built.
	push_warning("Main: final_event_triggered — FinalEvent scene not yet implemented (Phase 5)")


func _input(event: InputEvent) -> void:
	# Release mouse cursor when Escape is pressed.
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
