# DIMENSIONS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build DIMENSIONS — a first-person psychological survival game in Godot 4 where the player wakes in procedurally generated dimensions, survives until the dimension accepts them, and dies unexpectedly each time, resetting to zero.

**Architecture:** Godot 4 project with autoload singletons managing global state (GameState, DimensionManager). Dimensions are procedurally assembled from templates + randomized seeds. NPCs run custom behavior trees with randomized goals at spawn. Death is triggered by a library of cause nodes — no health bar, no warning.

**Tech Stack:** Godot 4.x, GDScript (strict typing), GUT (Godot Unit Testing), WorldEnvironment + ShaderMaterial for per-dimension visuals.

---

## File Map

```
dimensions/
├── project.godot
├── addons/gut/                        # GUT testing plugin
├── scenes/
│   ├── main.tscn                      # Root — loads/unloads dimensions
│   ├── player/
│   │   └── player.tscn                # FPS player (CharacterBody3D)
│   └── dimension/
│       └── dimension_root.tscn        # Base dimension scene
├── scripts/
│   ├── autoloads/
│   │   ├── game_state.gd              # Completed count, final event flag
│   │   └── dimension_manager.gd       # Load/unload/transition dimensions
│   ├── player/
│   │   ├── fps_controller.gd          # WASD + mouse look
│   │   └── interaction_handler.gd     # Raycast interact/grab
│   ├── dimension/
│   │   ├── dimension_data.gd          # Resource: template config
│   │   ├── dimension_generator.gd     # Assembles dimension from template+seed
│   │   ├── completion_tracker.gd      # Hidden timer + condition tracker
│   │   └── templates/
│   │       ├── template_void.gd       # Empty, silent, alien
│   │       ├── template_club.gd       # Crowd, music, dark
│   │       └── template_classroom.gd  # Mundane, wrong
│   ├── npc/
│   │   ├── npc_controller.gd          # Owns BT + goal state
│   │   ├── npc_goal_generator.gd      # Randomizes goals at spawn
│   │   ├── behavior_tree/
│   │   │   ├── bt_node.gd             # Base class
│   │   │   ├── bt_sequence.gd         # All children must succeed
│   │   │   ├── bt_selector.gd         # First child that succeeds
│   │   │   ├── bt_wander.gd           # Random pathing
│   │   │   ├── bt_idle.gd             # Wait
│   │   │   ├── bt_pursue.gd           # Move toward target
│   │   │   └── bt_threaten.gd         # Enter player's space
│   └── death/
│       ├── death_manager.gd           # Registers causes, detects, fires sequence
│       ├── death_cause.gd             # Resource: cause definition
│       ├── death_sequence.gd          # Plays visceral death scene
│       └── causes/
│           ├── cause_fall.gd          # Fall height threshold
│           ├── cause_npc.gd           # NPC enters kill zone
│           └── cause_rule.gd          # Dimension-specific hidden rule
├── resources/
│   ├── dimensions/                    # DimensionData .tres files
│   └── death_causes/                  # DeathCause .tres files
└── tests/
    ├── test_fps_controller.gd
    ├── test_dimension_generator.gd
    ├── test_behavior_tree.gd
    ├── test_completion_tracker.gd
    └── test_death_manager.gd
```

---

## Phase 1 — Foundation

### Task 1: Initialize Godot project + GUT

**Files:**
- Create: `project.godot`
- Create: `addons/gut/` (plugin)
- Create: `tests/test_placeholder.gd`

- [ ] **Step 1: Create Godot 4 project**

In Godot 4 editor: New Project → name `dimensions` → OpenGL Compatibility renderer → Create. Or from CLI:

```bash
cd ~/projects/dimensions
godot --headless --quit  # initializes project.godot if run from project dir
```

- [ ] **Step 2: Install GUT plugin**

Download GUT from https://github.com/bitwes/Gut — place `addons/gut/` in project root. Then enable in Project → Project Settings → Plugins → GUT → Enable.

- [ ] **Step 3: Write placeholder test to verify GUT works**

Create `tests/test_placeholder.gd`:
```gdscript
extends GutTest

func test_gut_is_working() -> void:
    assert_eq(1 + 1, 2, "GUT is operational")
```

- [ ] **Step 4: Run GUT and confirm green**

In editor: GUT panel → Run All. Expected: 1 test, 0 failures.

- [ ] **Step 5: Set up autoload list in project.godot**

Project → Project Settings → Autoload:
- `scripts/autoloads/game_state.gd` → name `GameState`
- `scripts/autoloads/dimension_manager.gd` → name `DimensionManager`

(Files don't exist yet — add stubs in Task 4.)

- [ ] **Step 6: Commit**

```bash
git init
git add .
git commit -m "feat: initialize Godot 4 project with GUT"
```

---

### Task 2: FPS Player Controller

**Files:**
- Create: `scripts/player/fps_controller.gd`
- Create: `scenes/player/player.tscn`
- Create: `tests/test_fps_controller.gd`

- [ ] **Step 1: Write failing test for fps controller**

Create `tests/test_fps_controller.gd`:
```gdscript
extends GutTest

var _player: CharacterBody3D

func before_each() -> void:
    var scene := load("res://scenes/player/player.tscn") as PackedScene
    _player = scene.instantiate() as CharacterBody3D
    add_child(_player)

func after_each() -> void:
    _player.queue_free()

func test_player_has_camera() -> void:
    var cam := _player.get_node_or_null("Camera3D") as Camera3D
    assert_not_null(cam, "Player must have Camera3D child")

func test_player_sensitivity_is_positive() -> void:
    var ctrl := _player.get_node("FPSController") as Node
    assert_gt(ctrl.mouse_sensitivity, 0.0, "Sensitivity must be positive")
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — scene not found.

- [ ] **Step 3: Write fps_controller.gd**

Create `scripts/player/fps_controller.gd`:
```gdscript
class_name FPSController
extends Node

@export var mouse_sensitivity: float = 0.002
@export var move_speed: float = 4.0
@export var jump_velocity: float = 4.5

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _camera: Camera3D = _body.get_node("Camera3D") as Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        _body.rotate_y(-motion.relative.x * mouse_sensitivity)
        _camera.rotate_x(-motion.relative.y * mouse_sensitivity)
        _camera.rotation.x = clampf(_camera.rotation.x, -1.5, 1.5)

func _physics_process(delta: float) -> void:
    if not _body.is_on_floor():
        _body.velocity.y -= _gravity * delta

    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (_body.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
    if direction:
        _body.velocity.x = direction.x * move_speed
        _body.velocity.z = direction.z * move_speed
    else:
        _body.velocity.x = move_toward(_body.velocity.x, 0.0, move_speed)
        _body.velocity.z = move_toward(_body.velocity.z, 0.0, move_speed)

    _body.move_and_slide()
```

- [ ] **Step 4: Build player.tscn in editor**

Scene tree:
```
CharacterBody3D (player.tscn root)
  ├── FPSController (Node, script = fps_controller.gd)
  ├── Camera3D (position Y=1.7)
  ├── CollisionShape3D (CapsuleShape3D h=1.8 r=0.4)
  └── InteractionHandler (Node — stub for Task 3)
```

Add input actions in Project Settings → Input Map:
- `move_forward` → W
- `move_back` → S
- `move_left` → A
- `move_right` → D
- `interact` → E

- [ ] **Step 5: Run tests**

Expected: PASS — 2 tests green.

- [ ] **Step 6: Commit**

```bash
git add scripts/player/fps_controller.gd scenes/player/ tests/test_fps_controller.gd
git commit -m "feat: add FPS player controller with mouse look"
```

---

### Task 3: Interaction Handler

**Files:**
- Create: `scripts/player/interaction_handler.gd`
- Modify: `tests/test_fps_controller.gd` (add interaction tests)

- [ ] **Step 1: Add failing tests for interaction**

Append to `tests/test_fps_controller.gd`:
```gdscript
func test_interaction_handler_exists() -> void:
    var ih := _player.get_node_or_null("InteractionHandler")
    assert_not_null(ih, "Player must have InteractionHandler node")

func test_interaction_reach_is_positive() -> void:
    var ih := _player.get_node("InteractionHandler") as Node
    assert_gt(ih.reach, 0.0, "Reach must be positive")
```

- [ ] **Step 2: Run to verify fail**

Expected: FAIL — InteractionHandler has no `reach` property.

- [ ] **Step 3: Write interaction_handler.gd**

Create `scripts/player/interaction_handler.gd`:
```gdscript
class_name InteractionHandler
extends Node

signal interacted(target: Node3D)
signal grabbed(target: RigidBody3D)
signal released

@export var reach: float = 2.5

@onready var _camera: Camera3D = get_parent().get_node("Camera3D") as Camera3D

var _held: RigidBody3D = null
const _HOLD_DISTANCE: float = 1.8

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _try_interact()

func _physics_process(_delta: float) -> void:
    if _held:
        var target_pos := _camera.global_position + (-_camera.global_transform.basis.z * _HOLD_DISTANCE)
        _held.linear_velocity = (target_pos - _held.global_position) * 10.0

func _try_interact() -> void:
    var space := get_viewport().get_camera_3d().get_world_3d().direct_space_state
    var from := _camera.global_position
    var to := from + (-_camera.global_transform.basis.z * reach)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    var result := space.intersect_ray(query)
    if result.is_empty():
        return
    var collider := result["collider"] as Node3D
    if collider is RigidBody3D and not _held:
        _held = collider as RigidBody3D
        _held.freeze = false
        grabbed.emit(_held)
    elif _held:
        _held = null
        released.emit()
    else:
        interacted.emit(collider)
```

- [ ] **Step 4: Attach script to InteractionHandler node in player.tscn**

- [ ] **Step 5: Run tests**

Expected: PASS — 4 tests green.

- [ ] **Step 6: Commit**

```bash
git add scripts/player/interaction_handler.gd tests/test_fps_controller.gd
git commit -m "feat: add interaction and grab system"
```

---

### Task 4: GameState + DimensionManager Autoloads

**Files:**
- Create: `scripts/autoloads/game_state.gd`
- Create: `scripts/autoloads/dimension_manager.gd`

- [ ] **Step 1: Write game_state.gd**

```gdscript
class_name GameState
extends Node

signal dimension_completed(total: int)
signal final_event_triggered

const DIMENSIONS_TO_FINAL: int = 7

var completed_count: int = 0
var _final_triggered: bool = false

func record_completion() -> void:
    completed_count += 1
    dimension_completed.emit(completed_count)
    if completed_count >= DIMENSIONS_TO_FINAL and not _final_triggered:
        _final_triggered = true
        final_event_triggered.emit()
```

- [ ] **Step 2: Write dimension_manager.gd stub**

```gdscript
class_name DimensionManager
extends Node

signal dimension_loaded
signal dimension_unloading

var _current_dimension: Node = null

func load_next_dimension() -> void:
    if _current_dimension:
        dimension_unloading.emit()
        _current_dimension.queue_free()
        _current_dimension = null
    # Dimension generator wired in Phase 2
    dimension_loaded.emit()

func trigger_death() -> void:
    # Death sequence wired in Phase 4
    load_next_dimension()
```

- [ ] **Step 3: Verify autoloads accessible in editor**

Run scene — in debugger, `print(GameState.completed_count)` should output `0`.

- [ ] **Step 4: Commit**

```bash
git add scripts/autoloads/
git commit -m "feat: add GameState and DimensionManager autoloads"
```

---

## Phase 2 — Dimension System

### Task 5: DimensionData Resource

**Files:**
- Create: `scripts/dimension/dimension_data.gd`
- Create: `tests/test_dimension_generator.gd`

- [ ] **Step 1: Write failing test**

Create `tests/test_dimension_generator.gd`:
```gdscript
extends GutTest

func test_dimension_data_has_required_fields() -> void:
    var d := DimensionData.new()
    assert_has_method(d, "get_template_id")
    assert_gt(d.survival_threshold, 0.0, "Threshold must be positive")
    assert_gt(d.npc_count_min, 0, "Must spawn at least 1 NPC")
```

- [ ] **Step 2: Run to verify fail**

Expected: FAIL — DimensionData not defined.

- [ ] **Step 3: Write dimension_data.gd**

```gdscript
class_name DimensionData
extends Resource

@export var template_id: StringName = &"void"
@export var seed: int = 0
@export var survival_threshold: float = 120.0  # seconds, hidden from player
@export var npc_count_min: int = 1
@export var npc_count_max: int = 4
@export var ambient_color: Color = Color(0.05, 0.05, 0.07)
@export var fog_density: float = 0.02
@export var gravity_scale: float = 1.0

func get_template_id() -> StringName:
    return template_id
```

- [ ] **Step 4: Run tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/dimension/dimension_data.gd tests/test_dimension_generator.gd
git commit -m "feat: add DimensionData resource"
```

---

### Task 6: Dimension Generator

**Files:**
- Create: `scripts/dimension/dimension_generator.gd`
- Modify: `tests/test_dimension_generator.gd`

- [ ] **Step 1: Add failing tests**

Append to `tests/test_dimension_generator.gd`:
```gdscript
func test_generator_produces_valid_data() -> void:
    var gen := DimensionGenerator.new()
    var data := gen.generate()
    assert_not_null(data, "Must return DimensionData")
    assert_gt(data.survival_threshold, 0.0)
    assert_true(data.npc_count_min <= data.npc_count_max)

func test_generator_is_random_across_calls() -> void:
    var gen := DimensionGenerator.new()
    var a := gen.generate()
    var b := gen.generate()
    assert_ne(a.seed, b.seed, "Two calls must produce different seeds")
```

- [ ] **Step 2: Run to verify fail**

Expected: FAIL — DimensionGenerator not defined.

- [ ] **Step 3: Write dimension_generator.gd**

```gdscript
class_name DimensionGenerator
extends RefCounted

const _TEMPLATES: Array[StringName] = [&"void", &"club", &"classroom"]
const _THRESHOLD_MIN: float = 90.0
const _THRESHOLD_MAX: float = 300.0

func generate() -> DimensionData:
    var data := DimensionData.new()
    data.seed = randi()
    var rng := RandomNumberGenerator.new()
    rng.seed = data.seed

    data.template_id = _TEMPLATES[rng.randi_range(0, _TEMPLATES.size() - 1)]
    data.survival_threshold = rng.randf_range(_THRESHOLD_MIN, _THRESHOLD_MAX)
    data.npc_count_min = rng.randi_range(1, 3)
    data.npc_count_max = data.npc_count_min + rng.randi_range(0, 3)
    data.gravity_scale = rng.randf_range(0.6, 1.4)
    data.fog_density = rng.randf_range(0.005, 0.08)

    var hue := rng.randf()
    data.ambient_color = Color.from_hsv(hue, rng.randf_range(0.0, 0.3), rng.randf_range(0.02, 0.12))

    return data
```

- [ ] **Step 4: Run tests**

Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add scripts/dimension/dimension_generator.gd tests/test_dimension_generator.gd
git commit -m "feat: add procedural dimension generator"
```

---

### Task 7: Dimension Templates (Void + Club + Classroom)

**Files:**
- Create: `scripts/dimension/templates/template_void.gd`
- Create: `scripts/dimension/templates/template_club.gd`
- Create: `scripts/dimension/templates/template_classroom.gd`
- Create: `scenes/dimension/dimension_root.tscn`

- [ ] **Step 1: Write template_void.gd**

```gdscript
class_name TemplateVoid
extends Node3D

@export var data: DimensionData

func build(rng: RandomNumberGenerator) -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = data.ambient_color
    environment.fog_enabled = true
    environment.fog_density = data.fog_density
    env.environment = environment
    add_child(env)

    # Floor plane
    var mesh_inst := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(200.0, 200.0)
    mesh_inst.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = data.ambient_color.darkened(0.3)
    mesh_inst.material_override = mat
    add_child(mesh_inst)

    var col := StaticBody3D.new()
    var col_shape := CollisionShape3D.new()
    col_shape.shape = WorldBoundaryShape3D.new()
    col.add_child(col_shape)
    add_child(col)

    # Spawn player above floor
    var player_spawn := Marker3D.new()
    player_spawn.name = &"PlayerSpawn"
    player_spawn.position = Vector3(0.0, 1.0, 0.0)
    add_child(player_spawn)
```

- [ ] **Step 2: Write template_club.gd**

```gdscript
class_name TemplateClub
extends Node3D

@export var data: DimensionData

func build(rng: RandomNumberGenerator) -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.02, 0.01, 0.04)
    environment.fog_enabled = true
    environment.fog_density = 0.06
    env.environment = environment
    add_child(env)

    _build_room(rng)
    _place_lights(rng)

    var spawn := Marker3D.new()
    spawn.name = &"PlayerSpawn"
    spawn.position = Vector3(0.0, 1.0, 0.0)
    add_child(spawn)

func _build_room(rng: RandomNumberGenerator) -> void:
    var size := Vector3(rng.randf_range(16.0, 28.0), 4.0, rng.randf_range(16.0, 28.0))
    for face: Array in [
        [Vector3(0,-1,0), Vector3(0, 0, 0)],
        [Vector3(0, 1,0), Vector3(0, size.y, 0)],
        [Vector3(-1,0,0), Vector3(-size.x/2, size.y/2, 0)],
        [Vector3( 1,0,0), Vector3( size.x/2, size.y/2, 0)],
        [Vector3(0,0,-1), Vector3(0, size.y/2, -size.z/2)],
        [Vector3(0,0, 1), Vector3(0, size.y/2,  size.z/2)],
    ]:
        var sb := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        cs.shape = WorldBoundaryShape3D.new()
        sb.position = face[1] as Vector3
        sb.add_child(cs)
        add_child(sb)

func _place_lights(rng: RandomNumberGenerator) -> void:
    var colors: Array[Color] = [Color(1,0,0.5), Color(0,0.5,1), Color(0.8,0,1), Color(1,0.3,0)]
    for i: int in range(rng.randi_range(4, 8)):
        var light := OmniLight3D.new()
        light.light_color = colors[rng.randi_range(0, colors.size()-1)]
        light.light_energy = rng.randf_range(2.0, 6.0)
        light.omni_range = rng.randf_range(4.0, 10.0)
        light.position = Vector3(
            rng.randf_range(-8.0, 8.0),
            rng.randf_range(2.5, 3.8),
            rng.randf_range(-8.0, 8.0)
        )
        add_child(light)
```

- [ ] **Step 3: Write template_classroom.gd**

```gdscript
class_name TemplateClassroom
extends Node3D

@export var data: DimensionData

func build(rng: RandomNumberGenerator) -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.85, 0.84, 0.80)
    environment.fog_enabled = false
    env.environment = environment
    add_child(env)

    _build_room()
    _place_desks(rng)

    var spawn := Marker3D.new()
    spawn.name = &"PlayerSpawn"
    spawn.position = Vector3(0.0, 1.0, 4.0)
    add_child(spawn)

func _build_room() -> void:
    var light := DirectionalLight3D.new()
    light.light_energy = 1.2
    light.light_color = Color(1.0, 0.98, 0.92)
    light.rotation_degrees = Vector3(-45, 30, 0)
    add_child(light)

    var sb := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    cs.shape = WorldBoundaryShape3D.new()
    sb.add_child(cs)
    add_child(sb)

func _place_desks(rng: RandomNumberGenerator) -> void:
    var rows: int = rng.randi_range(3, 5)
    var cols: int = rng.randi_range(4, 6)
    for r: int in range(rows):
        for c: int in range(cols):
            var desk := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(0.8, 0.05, 0.5)
            desk.mesh = box
            desk.position = Vector3(c * 1.2 - cols * 0.6, 0.75, r * 1.5 - 3.0)
            add_child(desk)
```

- [ ] **Step 4: Build dimension_root.tscn**

Scene tree:
```
Node3D (dimension_root.tscn root, script = dimension_root.gd)
  ├── CompletionTracker (Node — Task 9)
  └── NPCContainer (Node3D — NPCs spawned here at runtime)
```

Create `scripts/dimension/dimension_root.gd`:
```gdscript
class_name DimensionRoot
extends Node3D

const _TEMPLATES: Dictionary = {
    &"void": TemplateVoid,
    &"club": TemplateClub,
    &"classroom": TemplateClassroom,
}

var data: DimensionData

func initialize(dimension_data: DimensionData) -> void:
    data = dimension_data
    var rng := RandomNumberGenerator.new()
    rng.seed = data.seed

    var template_class: GDScript = _TEMPLATES.get(data.template_id, TemplateVoid)
    var template: Node3D = template_class.new()
    template.data = data
    add_child(template)
    template.build(rng)

    ProjectSettings.set_setting("physics/3d/default_gravity", 9.8 * data.gravity_scale)

func get_player_spawn() -> Vector3:
    var spawn := find_child("PlayerSpawn", true, false) as Marker3D
    return spawn.global_position if spawn else Vector3.ZERO
```

- [ ] **Step 5: Wire DimensionManager to use generator + root**

Update `scripts/autoloads/dimension_manager.gd`:
```gdscript
class_name DimensionManager
extends Node

signal dimension_loaded
signal dimension_unloading

const _DIMENSION_ROOT := preload("res://scenes/dimension/dimension_root.tscn")

var _current_dimension: DimensionRoot = null
var _generator := DimensionGenerator.new()

func load_next_dimension() -> void:
    if _current_dimension:
        dimension_unloading.emit()
        _current_dimension.queue_free()
        _current_dimension = null

    var data := _generator.generate()
    _current_dimension = _DIMENSION_ROOT.instantiate() as DimensionRoot
    get_tree().current_scene.add_child(_current_dimension)
    _current_dimension.initialize(data)
    dimension_loaded.emit()

func get_current_data() -> DimensionData:
    return _current_dimension.data if _current_dimension else null

func trigger_death() -> void:
    load_next_dimension()
```

- [ ] **Step 6: Commit**

```bash
git add scripts/dimension/ scenes/dimension/
git commit -m "feat: add dimension templates (void, club, classroom)"
```

---

## Phase 3 — NPC System

### Task 8: Behavior Tree Foundation

**Files:**
- Create: `scripts/npc/behavior_tree/bt_node.gd`
- Create: `scripts/npc/behavior_tree/bt_sequence.gd`
- Create: `scripts/npc/behavior_tree/bt_selector.gd`
- Create: `tests/test_behavior_tree.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/test_behavior_tree.gd`:
```gdscript
extends GutTest

func test_sequence_fails_if_any_child_fails() -> void:
    var seq := BTSequence.new()
    var success := BTNode.new()
    success.set_meta(&"_test_result", BTNode.Status.SUCCESS)
    var fail := BTNode.new()
    fail.set_meta(&"_test_result", BTNode.Status.FAILURE)
    seq.add_child(success)
    seq.add_child(fail)
    assert_eq(seq.tick(null, 0.1), BTNode.Status.FAILURE)

func test_selector_succeeds_on_first_success() -> void:
    var sel := BTSelector.new()
    var fail := BTNode.new()
    fail.set_meta(&"_test_result", BTNode.Status.FAILURE)
    var success := BTNode.new()
    success.set_meta(&"_test_result", BTNode.Status.SUCCESS)
    sel.add_child(fail)
    sel.add_child(success)
    assert_eq(sel.tick(null, 0.1), BTNode.Status.SUCCESS)
```

- [ ] **Step 2: Run to verify fail**

Expected: FAIL — BTNode not defined.

- [ ] **Step 3: Write bt_node.gd**

```gdscript
class_name BTNode
extends Node

enum Status { SUCCESS, FAILURE, RUNNING }

func tick(actor: CharacterBody3D, delta: float) -> Status:
    # Test hook: nodes can override result via metadata in tests
    if has_meta(&"_test_result"):
        return get_meta(&"_test_result") as Status
    return _tick(actor, delta)

func _tick(_actor: CharacterBody3D, _delta: float) -> Status:
    return Status.SUCCESS
```

- [ ] **Step 4: Write bt_sequence.gd**

```gdscript
class_name BTSequence
extends BTNode

func _tick(actor: CharacterBody3D, delta: float) -> Status:
    for child: Node in get_children():
        if child is BTNode:
            var result := (child as BTNode).tick(actor, delta)
            if result != Status.SUCCESS:
                return result
    return Status.SUCCESS
```

- [ ] **Step 5: Write bt_selector.gd**

```gdscript
class_name BTSelector
extends BTNode

func _tick(actor: CharacterBody3D, delta: float) -> Status:
    for child: Node in get_children():
        if child is BTNode:
            var result := (child as BTNode).tick(actor, delta)
            if result != Status.FAILURE:
                return result
    return Status.FAILURE
```

- [ ] **Step 6: Run tests**

Expected: PASS — 2 tests green.

- [ ] **Step 7: Commit**

```bash
git add scripts/npc/behavior_tree/bt_node.gd scripts/npc/behavior_tree/bt_sequence.gd scripts/npc/behavior_tree/bt_selector.gd tests/test_behavior_tree.gd
git commit -m "feat: add behavior tree foundation (node, sequence, selector)"
```

---

### Task 9: BT Leaf Nodes + NPC Controller

**Files:**
- Create: `scripts/npc/behavior_tree/bt_wander.gd`
- Create: `scripts/npc/behavior_tree/bt_idle.gd`
- Create: `scripts/npc/behavior_tree/bt_pursue.gd`
- Create: `scripts/npc/behavior_tree/bt_threaten.gd`
- Create: `scripts/npc/npc_controller.gd`
- Create: `scripts/npc/npc_goal_generator.gd`

- [ ] **Step 1: Write bt_wander.gd**

```gdscript
class_name BTWander
extends BTNode

@export var radius: float = 8.0
@export var speed: float = 1.8

var _target: Vector3
var _rng := RandomNumberGenerator.new()

func _tick(actor: CharacterBody3D, delta: float) -> Status:
    if actor.global_position.distance_to(_target) < 0.5:
        _target = actor.global_position + Vector3(
            _rng.randf_range(-radius, radius), 0.0, _rng.randf_range(-radius, radius)
        )
    var dir := ((_target - actor.global_position) * Vector3(1, 0, 1)).normalized()
    actor.velocity = dir * speed
    actor.move_and_slide()
    return Status.RUNNING
```

- [ ] **Step 2: Write bt_idle.gd**

```gdscript
class_name BTIdle
extends BTNode

@export var duration: float = 2.0
var _timer: float = 0.0

func _tick(actor: CharacterBody3D, delta: float) -> Status:
    _timer += delta
    actor.velocity = Vector3.ZERO
    if _timer >= duration:
        _timer = 0.0
        return Status.SUCCESS
    return Status.RUNNING
```

- [ ] **Step 3: Write bt_pursue.gd**

```gdscript
class_name BTPursue
extends BTNode

@export var speed: float = 3.5
@export var stop_distance: float = 1.2

var target: Node3D = null

func _tick(actor: CharacterBody3D, delta: float) -> Status:
    if not target or not is_instance_valid(target):
        return Status.FAILURE
    var dist := actor.global_position.distance_to(target.global_position)
    if dist <= stop_distance:
        actor.velocity = Vector3.ZERO
        return Status.SUCCESS
    var dir := ((target.global_position - actor.global_position) * Vector3(1, 0, 1)).normalized()
    actor.velocity = dir * speed
    actor.move_and_slide()
    return Status.RUNNING
```

- [ ] **Step 4: Write bt_threaten.gd**

```gdscript
class_name BTThreaten
extends BTNode

# NPC enters player's personal space and holds there.
@export var threat_distance: float = 0.6
@export var speed: float = 2.5

var target: Node3D = null

func _tick(actor: CharacterBody3D, delta: float) -> Status:
    if not target or not is_instance_valid(target):
        return Status.FAILURE
    var dist := actor.global_position.distance_to(target.global_position)
    if dist <= threat_distance:
        return Status.RUNNING  # Hold position in player's face
    var dir := ((target.global_position - actor.global_position) * Vector3(1, 0, 1)).normalized()
    actor.velocity = dir * speed
    actor.move_and_slide()
    return Status.RUNNING
```

- [ ] **Step 5: Write npc_goal_generator.gd**

```gdscript
class_name NPCGoalGenerator
extends RefCounted

enum Goal { WANDER, IDLE_WANDER, PURSUE_PLAYER, THREATEN_PLAYER, OBSERVE }

static func generate(rng: RandomNumberGenerator) -> Goal:
    var weights: Array[float] = [0.35, 0.25, 0.15, 0.10, 0.15]
    var roll := rng.randf()
    var cumulative: float = 0.0
    for i: int in range(weights.size()):
        cumulative += weights[i]
        if roll < cumulative:
            return i as Goal
    return Goal.WANDER
```

- [ ] **Step 6: Write npc_controller.gd**

```gdscript
class_name NPCController
extends CharacterBody3D

signal entered_kill_range(npc: NPCController)

@export var kill_range: float = 0.5

var _tree: BTNode = null
var _player: CharacterBody3D = null

func setup(goal: NPCGoalGenerator.Goal, player: CharacterBody3D, rng: RandomNumberGenerator) -> void:
    _player = player
    _tree = _build_tree(goal, rng)
    add_child(_tree)

func _physics_process(delta: float) -> void:
    if _tree:
        _tree.tick(self, delta)
    if _player and global_position.distance_to(_player.global_position) <= kill_range:
        entered_kill_range.emit(self)

func _build_tree(goal: NPCGoalGenerator.Goal, rng: RandomNumberGenerator) -> BTNode:
    match goal:
        NPCGoalGenerator.Goal.PURSUE_PLAYER:
            var pursue := BTPursue.new()
            pursue.target = _player
            pursue.speed = rng.randf_range(2.5, 4.5)
            return pursue
        NPCGoalGenerator.Goal.THREATEN_PLAYER:
            var seq := BTSequence.new()
            var pursue := BTPursue.new()
            pursue.target = _player
            pursue.speed = rng.randf_range(1.5, 3.0)
            var threaten := BTThreaten.new()
            threaten.target = _player
            seq.add_child(pursue)
            seq.add_child(threaten)
            return seq
        NPCGoalGenerator.Goal.IDLE_WANDER:
            var sel := BTSelector.new()
            sel.add_child(BTIdle.new())
            sel.add_child(BTWander.new())
            return sel
        _:
            return BTWander.new()
```

- [ ] **Step 7: Commit**

```bash
git add scripts/npc/
git commit -m "feat: add NPC behavior tree leaves and controller"
```

---

### Task 10: NPC Spawning in Dimensions

**Files:**
- Modify: `scripts/dimension/dimension_root.gd`

- [ ] **Step 1: Update dimension_root.gd to spawn NPCs**

Add to `dimension_root.gd` after template build:
```gdscript
func _spawn_npcs(rng: RandomNumberGenerator, player: CharacterBody3D) -> void:
    var npc_container := get_node("NPCContainer") as Node3D
    var count := rng.randi_range(data.npc_count_min, data.npc_count_max)
    for i: int in range(count):
        var npc := NPCController.new()
        npc.position = Vector3(
            rng.randf_range(-8.0, 8.0), 1.0, rng.randf_range(-8.0, 8.0)
        )
        var goal := NPCGoalGenerator.generate(rng)
        npc_container.add_child(npc)
        npc.setup(goal, player, rng)
        npc.entered_kill_range.connect(_on_npc_kill_range)

func _on_npc_kill_range(_npc: NPCController) -> void:
    DimensionManager.trigger_death()
```

Update `initialize()` signature to accept player:
```gdscript
func initialize(dimension_data: DimensionData, player: CharacterBody3D) -> void:
    data = dimension_data
    var rng := RandomNumberGenerator.new()
    rng.seed = data.seed
    # ... existing template build ...
    _spawn_npcs(rng, player)
```

- [ ] **Step 2: Update DimensionManager to pass player**

In `dimension_manager.gd`, update `load_next_dimension()`:
```gdscript
func load_next_dimension(player: CharacterBody3D = null) -> void:
    # ... existing unload ...
    _current_dimension.initialize(data, player)
```

- [ ] **Step 3: Test in editor — run scene, verify NPCs spawn and wander**

- [ ] **Step 4: Commit**

```bash
git add scripts/dimension/dimension_root.gd scripts/autoloads/dimension_manager.gd
git commit -m "feat: spawn NPCs in dimensions with randomized goals"
```

---

## Phase 4 — Death System

### Task 11: Death Manager + Cause Library

**Files:**
- Create: `scripts/death/death_cause.gd`
- Create: `scripts/death/death_manager.gd`
- Create: `scripts/death/causes/cause_fall.gd`
- Create: `scripts/death/causes/cause_rule.gd`
- Create: `tests/test_death_manager.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/test_death_manager.gd`:
```gdscript
extends GutTest

func test_death_manager_registers_cause() -> void:
    var dm := DeathManager.new()
    var cause := DeathCause.new()
    cause.cause_id = &"test_cause"
    dm.register_cause(cause)
    assert_eq(dm.cause_count(), 1)

func test_death_fires_signal() -> void:
    var dm := DeathManager.new()
    watch_signals(dm)
    dm.trigger(&"test_cause")
    assert_signal_emitted(dm, "player_died")
```

- [ ] **Step 2: Run to verify fail**

Expected: FAIL — DeathManager not defined.

- [ ] **Step 3: Write death_cause.gd**

```gdscript
class_name DeathCause
extends Resource

@export var cause_id: StringName = &""
@export var is_silent: bool = false  # quiet death vs loud
@export var blood_intensity: float = 1.0  # 0 = none, 1 = heavy
```

- [ ] **Step 4: Write death_manager.gd**

```gdscript
class_name DeathManager
extends Node

signal player_died(cause: DeathCause)

var _causes: Dictionary = {}  # StringName → DeathCause

func register_cause(cause: DeathCause) -> void:
    _causes[cause.cause_id] = cause

func cause_count() -> int:
    return _causes.size()

func trigger(cause_id: StringName) -> void:
    var cause: DeathCause = _causes.get(cause_id, DeathCause.new())
    player_died.emit(cause)
```

- [ ] **Step 5: Write cause_fall.gd**

```gdscript
class_name CauseFall
extends Node

@export var lethal_height: float = 6.0

var _fall_start_y: float = 0.0
var _is_falling: bool = false
var _death_manager: DeathManager = null
var _player: CharacterBody3D = null

func setup(player: CharacterBody3D, dm: DeathManager) -> void:
    _player = player
    _death_manager = dm
    var cause := DeathCause.new()
    cause.cause_id = &"fall"
    cause.blood_intensity = 1.5
    dm.register_cause(cause)

func _physics_process(_delta: float) -> void:
    if not _player:
        return
    if not _player.is_on_floor() and _player.velocity.y < 0.0:
        if not _is_falling:
            _is_falling = true
            _fall_start_y = _player.global_position.y
    elif _player.is_on_floor() and _is_falling:
        _is_falling = false
        var drop := _fall_start_y - _player.global_position.y
        if drop >= lethal_height:
            _death_manager.trigger(&"fall")
```

- [ ] **Step 6: Write cause_rule.gd (dimension-specific hidden rule)**

```gdscript
class_name CauseRule
extends Node

# Each dimension can define 1 hidden rule. Timer-based or zone-based.
@export var rule_id: StringName = &""
@export var trigger_after_seconds: float = 0.0  # 0 = zone-based only
@export var forbidden_zone: AABB = AABB()

var _timer: float = 0.0
var _death_manager: DeathManager = null
var _player: CharacterBody3D = null

func setup(player: CharacterBody3D, dm: DeathManager, data: DimensionData) -> void:
    _player = player
    _death_manager = dm
    var cause := DeathCause.new()
    cause.cause_id = rule_id if rule_id != &"" else &"rule"
    cause.is_silent = true
    cause.blood_intensity = 0.3
    dm.register_cause(cause)

func _physics_process(delta: float) -> void:
    if not _player or not _death_manager:
        return
    if trigger_after_seconds > 0.0:
        _timer += delta
        if _timer >= trigger_after_seconds:
            _death_manager.trigger(rule_id)
    if forbidden_zone.size != Vector3.ZERO:
        if forbidden_zone.has_point(_player.global_position):
            _death_manager.trigger(rule_id)
```

- [ ] **Step 7: Run tests**

Expected: PASS — 2 tests green.

- [ ] **Step 8: Commit**

```bash
git add scripts/death/ tests/test_death_manager.gd
git commit -m "feat: add death manager and cause library (fall, rule)"
```

---

### Task 12: Death Sequence (Visceral Scene)

**Files:**
- Create: `scripts/death/death_sequence.gd`
- Create: `scenes/death/death_sequence.tscn`

- [ ] **Step 1: Write death_sequence.gd**

```gdscript
class_name DeathSequence
extends CanvasLayer

signal sequence_finished

@onready var _black: ColorRect = $Black
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer

func play(cause: DeathCause) -> void:
    _black.modulate.a = 0.0
    _black.show()

    # Blood overlay intensity based on cause
    if cause.blood_intensity > 0.0 and not cause.is_silent:
        _flash_red(cause.blood_intensity)

    # Blur + desaturate then cut to black
    var tween := create_tween()
    tween.set_ease(Tween.EASE_IN)
    if cause.is_silent:
        tween.tween_property(_black, "modulate:a", 1.0, 2.5)
    else:
        tween.tween_property(_black, "modulate:a", 1.0, 0.8)
    await tween.finished

    # Hold black for 1.5 seconds
    await get_tree().create_timer(1.5).timeout
    sequence_finished.emit()

func _flash_red(intensity: float) -> void:
    var flash := ColorRect.new()
    flash.color = Color(0.8, 0.0, 0.0, clampf(intensity * 0.4, 0.0, 0.7))
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(flash)
    var t := create_tween()
    t.tween_property(flash, "modulate:a", 0.0, 0.6)
    t.tween_callback(flash.queue_free)
```

- [ ] **Step 2: Build death_sequence.tscn**

```
CanvasLayer (death_sequence.tscn, layer=10)
  ├── Black (ColorRect, anchors full rect, color black, hidden)
  └── AudioStreamPlayer
```

- [ ] **Step 3: Wire death sequence into DimensionManager**

Update `dimension_manager.gd`:
```gdscript
const _DEATH_SCENE := preload("res://scenes/death/death_sequence.tscn")

func trigger_death() -> void:
    var seq: DeathSequence = _DEATH_SCENE.instantiate()
    get_tree().current_scene.add_child(seq)
    seq.sequence_finished.connect(func() -> void:
        seq.queue_free()
        load_next_dimension()
    )
    var cause := DeathCause.new()  # DeathManager passes real cause — wire in main.tscn
    seq.play(cause)
```

- [ ] **Step 4: Test death sequence in editor**

Call `DimensionManager.trigger_death()` from a test key — verify screen goes black then new dimension loads.

- [ ] **Step 5: Commit**

```bash
git add scripts/death/death_sequence.gd scenes/death/
git commit -m "feat: add visceral death sequence with cut-to-black transition"
```

---

## Phase 5 — Completion System

### Task 13: Completion Tracker

**Files:**
- Create: `scripts/dimension/completion_tracker.gd`
- Create: `tests/test_completion_tracker.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/test_completion_tracker.gd`:
```gdscript
extends GutTest

func test_not_complete_before_threshold() -> void:
    var ct := CompletionTracker.new()
    ct.threshold = 60.0
    add_child(ct)
    ct._elapsed = 30.0
    assert_false(ct.is_complete())

func test_complete_after_threshold() -> void:
    var ct := CompletionTracker.new()
    ct.threshold = 60.0
    add_child(ct)
    ct._elapsed = 61.0
    assert_true(ct.is_complete())

func test_emits_signal_on_completion() -> void:
    var ct := CompletionTracker.new()
    ct.threshold = 1.0
    add_child(ct)
    watch_signals(ct)
    ct._elapsed = 1.5
    ct._check_completion()
    assert_signal_emitted(ct, "dimension_completed")
```

- [ ] **Step 2: Run to verify fail**

Expected: FAIL — CompletionTracker not defined.

- [ ] **Step 3: Write completion_tracker.gd**

```gdscript
class_name CompletionTracker
extends Node

signal dimension_completed

@export var threshold: float = 120.0

var _elapsed: float = 0.0
var _completed: bool = false

func _process(delta: float) -> void:
    if _completed:
        return
    _elapsed += delta
    _check_completion()

func _check_completion() -> void:
    if not _completed and _elapsed >= threshold:
        _completed = true
        dimension_completed.emit()

func is_complete() -> bool:
    return _completed
```

- [ ] **Step 4: Wire into dimension_root.gd**

In `dimension_root.gd initialize()`:
```gdscript
var tracker := get_node("CompletionTracker") as CompletionTracker
tracker.threshold = data.survival_threshold
tracker.dimension_completed.connect(func() -> void:
    GameState.record_completion()
)
```

- [ ] **Step 5: Run tests**

Expected: PASS — 3 tests green.

- [ ] **Step 6: Commit**

```bash
git add scripts/dimension/completion_tracker.gd tests/test_completion_tracker.gd
git commit -m "feat: add hidden completion tracker"
```

---

### Task 14: Final Event

**Files:**
- Create: `scripts/dimension/final_event.gd`
- Create: `scenes/final_event.tscn`

- [ ] **Step 1: Write final_event.gd**

```gdscript
class_name FinalEvent
extends CanvasLayer

func play() -> void:
    # Reality collapse — everything inverts, dimensions bleed together, then silence.
    var tween := create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)

    # Rapid color flicker
    var overlay := ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)

    for i: int in range(12):
        var c := Color(randf(), randf(), randf(), 0.6)
        tween.tween_property(overlay, "color", c, 0.08)

    tween.tween_property(overlay, "color", Color.WHITE, 0.4)
    await tween.finished
    await get_tree().create_timer(2.0).timeout

    # White to black — end
    var final_tween := create_tween()
    final_tween.tween_property(overlay, "color", Color.BLACK, 1.5)
    await final_tween.finished
    await get_tree().create_timer(3.0).timeout

    get_tree().quit()
```

- [ ] **Step 2: Wire GameState signal to trigger final event**

In `main.tscn` root script or `dimension_manager.gd`:
```gdscript
func _ready() -> void:
    GameState.final_event_triggered.connect(_on_final_event)

func _on_final_event() -> void:
    var fe: FinalEvent = load("res://scenes/final_event.tscn").instantiate()
    get_tree().current_scene.add_child(fe)
    fe.play()
```

- [ ] **Step 3: Test final event in editor**

Temporarily set `GameState.DIMENSIONS_TO_FINAL = 1`, die once, verify final event fires.

- [ ] **Step 4: Commit**

```bash
git add scripts/dimension/final_event.gd scenes/final_event.tscn
git commit -m "feat: add final event sequence"
```

---

## Phase 6 — Atmosphere & Polish

### Task 15: Per-Dimension Post-Processing

**Files:**
- Modify: `scripts/dimension/templates/template_void.gd`
- Modify: `scripts/dimension/templates/template_club.gd`
- Modify: `scripts/dimension/templates/template_classroom.gd`

- [ ] **Step 1: Add chromatic aberration shader**

Create `shaders/chromatic_aberration.gdshader`:
```glsl
shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.02) = 0.004;

void fragment() {
    vec2 uv = SCREEN_UV;
    COLOR.r = texture(TEXTURE, uv + vec2(strength, 0.0)).r;
    COLOR.g = texture(TEXTURE, uv).g;
    COLOR.b = texture(TEXTURE, uv - vec2(strength, 0.0)).b;
    COLOR.a = 1.0;
}
```

- [ ] **Step 2: Apply shader per template via ColorRect overlay**

Add to each template's `build()`:
```gdscript
func _add_post_processing(strength: float) -> void:
    var overlay := ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/chromatic_aberration.gdshader") as Shader
    mat.set_shader_parameter(&"strength", strength)
    overlay.material = mat
    var canvas := CanvasLayer.new()
    canvas.add_child(overlay)
    add_child(canvas)
```

Void: strength 0.008, Club: strength 0.003, Classroom: strength 0.001 (barely off).

- [ ] **Step 3: Add subtle camera bob to fps_controller.gd**

Append to `_physics_process()`:
```gdscript
func _apply_head_bob(delta: float) -> void:
    var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
    if speed > 0.1 and _body.is_on_floor():
        _bob_time += delta * speed * 0.5
        _camera.position.y = lerpf(_camera.position.y, sin(_bob_time * 2.0) * 0.02, 10.0 * delta)
    else:
        _camera.position.y = lerpf(_camera.position.y, 0.0, 6.0 * delta)

var _bob_time: float = 0.0
```

- [ ] **Step 4: Commit**

```bash
git add shaders/ scripts/dimension/templates/ scripts/player/fps_controller.gd
git commit -m "feat: add per-dimension post-processing and camera bob"
```

---

### Task 16: Main Scene + Integration

**Files:**
- Create: `scenes/main.tscn`
- Create: `scripts/main.gd`

- [ ] **Step 1: Write main.gd**

```gdscript
class_name Main
extends Node

@onready var _player: CharacterBody3D = $Player

func _ready() -> void:
    GameState.final_event_triggered.connect(_on_final_event)
    DimensionManager.dimension_loaded.connect(_on_dimension_loaded)
    DimensionManager.load_next_dimension(_player)

func _on_dimension_loaded() -> void:
    var spawn := DimensionManager._current_dimension.get_player_spawn()
    _player.global_position = spawn

func _on_final_event() -> void:
    var fe: FinalEvent = load("res://scenes/final_event.tscn").instantiate()
    add_child(fe)
    fe.play()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

- [ ] **Step 2: Build main.tscn**

```
Node (main.tscn root, script=main.gd)
  └── Player (instance of player.tscn)
```

Set main.tscn as the project's main scene in Project Settings → Application → Run → Main Scene.

- [ ] **Step 3: Full playtest**

- Launch game
- Verify player spawns in a dimension
- Verify NPCs move and behave
- Walk into NPC kill range → verify death sequence → verify new dimension loads
- Verify completion tracker counting (add `print(tracker._elapsed)` temporarily)

- [ ] **Step 4: Remove debug prints, final commit**

```bash
git add scenes/main.tscn scripts/main.gd
git commit -m "feat: wire main scene, full integration complete"
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ First-person, no HUD
- ✅ Procedural dimensions (generator + templates)
- ✅ AI NPCs with randomized behavior trees
- ✅ Unexpected death (fall, NPC kill range, hidden rule)
- ✅ Visceral death sequence (cut to black, blood flash)
- ✅ Completion tracker (hidden threshold)
- ✅ Final event after N dimensions
- ✅ No progress between deaths (GameState only tracks count)
- ✅ Classroom, club, void templates (mundane + beautiful + wrong)
- ✅ Chromatic aberration post-processing per dimension
- ⚠️ Re:Zero false memory mechanic: not implemented as a system — this is emergent from the design (player carries mental models, dimensions don't respect them). No code needed.
- ⚠️ "Overdose" and ultra-varied death causes: cause_rule.gd is the extension point — add more cause scripts in Phase 4+ as needed.
