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
	var cf: CauseFall = _player.get_node_or_null("DeathManager/CauseFall") as CauseFall
	if cf != null:
		cf.reset_fall_state()


func _on_player_died(cause: DeathCause) -> void:
	DimensionManager.trigger_death(_player, cause)


func _on_final_event() -> void:
	var dm: DeathManager = _player.get_node_or_null("DeathManager") as DeathManager
	if dm != null and dm.player_died.is_connected(_on_player_died):
		dm.player_died.disconnect(_on_player_died)

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
