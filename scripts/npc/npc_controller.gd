## NPCController — behavior-tree-driven NPC entity.
## Extends CharacterBody3D; CollisionShape3D + SkeletonBody built in _ready().
## Call setup(goal, player, rng) after add_child() to initialize the NPC.
##
## Body rendering is delegated to SkeletonBody (ADR-012). The duplicate
## per-NPC sway/breath/emission-pulse loop that lived here in v0 is now a
## single shared system on the player and every NPC.
class_name NPCController
extends CharacterBody3D

## Emitted once per lifetime when the NPC enters kill range of the player.
## Bound argument is the NPC itself so DimensionRoot can identify the source.
signal entered_kill_range(npc: NPCController)

## Distance in metres at which the NPC is considered to have reached the player.
@export var kill_range: float = 0.6

## Gravity constant — read once from ProjectSettings in _ready().
var _gravity: float = 0.0

var _player: CharacterBody3D = null
var _tree: BTNode = null
var _skeleton: SkeletonBody = null

## One-shot latch: prevents entered_kill_range from firing more than once.
var _kill_emitted: bool = false


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") as float

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.7
	capsule.radius = 0.35
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.85, 0.0)
	add_child(collision)

	_skeleton = SkeletonBody.new()
	# Show the head — NPCs are seen from outside, the camera-occlusion
	# concern that hides the player's own skull doesn't apply here.
	_skeleton.hide_head = false
	add_child(_skeleton)


## Wires the NPC to its player target and builds the behavior tree for the given goal.
func setup(goal: NPCGoalGenerator.Goal, player: CharacterBody3D, rng: RandomNumberGenerator) -> void:
	_player = player

	# Per-NPC color variation via SkeletonBody.set_style — replaces the
	# per-instance Standard­Material3D mutation that lived here.
	if _skeleton != null:
		var hue: float = rng.randf_range(0.72, 0.92)
		var sat: float = rng.randf_range(0.5, 0.9)
		var val: float = rng.randf_range(0.5, 1.0)
		var c: Color = Color.from_hsv(hue, sat, val)
		_skeleton.set_style(c, rng.randf_range(0.7, 1.4))

	_tree = _build_tree(goal, rng)
	if _tree != null:
		add_child(_tree)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _tree == null:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_tree.tick(self, delta)
	move_and_slide()

	if not _kill_emitted and global_position.distance_to(_player.global_position) <= kill_range:
		_kill_emitted = true
		entered_kill_range.emit(self)


## Builds and returns the root BTNode for the given goal.
func _build_tree(goal: NPCGoalGenerator.Goal, rng: RandomNumberGenerator) -> BTNode:
	match goal:
		NPCGoalGenerator.Goal.WANDER:
			return _make_idle_wander_tree(rng)
		NPCGoalGenerator.Goal.PURSUE:
			return _make_pursue_tree(rng)
		NPCGoalGenerator.Goal.THREATEN:
			return _make_threaten_tree(rng)
		_:
			push_warning("NPCController: unrecognised goal %d, defaulting to WANDER" % goal)
			return _make_idle_wander_tree(rng)


func _make_idle_wander_tree(rng: RandomNumberGenerator) -> BTNode:
	var wander := BTWander.new()
	wander.wander_radius = 5.0
	wander.move_speed = 1.5
	wander.init_rng(rng)
	return wander


func _make_pursue_tree(rng: RandomNumberGenerator) -> BTNode:
	var pursue := BTPursue.new()
	pursue.target = _player
	pursue.stop_distance = 1.2
	pursue.move_speed = rng.randf_range(2.0, 3.5)
	return pursue


## Applies a per-template skeletal mutation to this NPC's SkeletonBody.
## seed is derived from the dimension seed + NPC index so each NPC varies
## within the template family without disturbing the dimension rng sequence.
func mutate_skeleton(template_id: StringName, seed: int) -> void:
	if _skeleton == null or not is_instance_valid(_skeleton):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_skeleton.mutate_for_template(template_id, rng)


func _make_threaten_tree(rng: RandomNumberGenerator) -> BTNode:
	var threaten := BTThreaten.new()
	threaten.target = _player
	threaten.threat_distance = 0.8
	threaten.approach_speed = rng.randf_range(1.8, 2.8)
	threaten.init_rng(rng)
	return threaten
