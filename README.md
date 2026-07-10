# Dimensions

[![CI](https://github.com/supernavyl/dimensions/actions/workflows/ci.yml/badge.svg)](https://github.com/supernavyl/dimensions/actions/workflows/ci.yml)

A Godot 4 narrative action game built in GDScript: dimension-shifting
mechanics, NPC behaviour trees, a death/respawn system, and post-processing.

## Stack
- **Engine:** Godot 4.x
- **Language:** GDScript (statically typed)
- **Testing:** [GUT](https://github.com/bitwes/Gut) — headless test runner

## Running
Open the project in Godot 4.x and press play, or run headless:

```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd
```

## Running tests
On a fresh clone the class cache does not exist yet, so `gut_cmdln.gd` will
fail to resolve `class_name` types until Godot has imported the project once.
Run the import step first, then the GUT suite:

```bash
# 1. One-time warm-up: build the import/class cache
godot --path . --headless --import

# 2. Run the GUT test suite
godot --path . --headless -s addons/gut/gut_cmdln.gd
```

## Status
Playable systems vertical slice. Subsystems (NPC AI, death system,
post-processing pipeline) are implemented and exercised by the GUT suite.
