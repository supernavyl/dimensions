## InteractionHandler — raycast-based interact and physics-grab system.
## Attach as a Node child of CharacterBody3D. Camera3D must be a sibling named "Camera3D".
class_name InteractionHandler
extends Node

## Emitted when the player interacts with a non-grabbable Node3D.
signal interacted(target: Node3D)
## Emitted when the player grabs a RigidBody3D.
signal grabbed(target: RigidBody3D)
## Emitted when the player releases a held object.
signal released

## Maximum raycast distance in metres.
@export var reach: float = 2.5

@onready var _camera: Camera3D = get_parent().get_node("Camera3D") as Camera3D

var _held: RigidBody3D = null

const _HOLD_DISTANCE: float = 1.8
const _PULL_SPEED: float = 10.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		_try_interact()


func _physics_process(_delta: float) -> void:
	if _held == null or not is_instance_valid(_held):
		_held = null
		return
	if _camera == null:
		return
	var target_pos: Vector3 = (
		_camera.global_position + (-_camera.global_transform.basis.z * _HOLD_DISTANCE)
	)
	_held.linear_velocity = (target_pos - _held.global_position) * _PULL_SPEED


func _try_interact() -> void:
	if _camera == null:
		return

	var space_state: PhysicsDirectSpaceState3D = (
		_camera.get_world_3d().direct_space_state
	)
	if space_state == null:
		return

	var from: Vector3 = _camera.global_position
	var to: Vector3 = from + (-_camera.global_transform.basis.z * reach)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if collider == null:
		return

	if collider is RigidBody3D and _held == null:
		_held = collider as RigidBody3D
		grabbed.emit(_held)
	elif _held != null:
		_held = null
		released.emit()
	elif collider is Node3D:
		interacted.emit(collider as Node3D)
