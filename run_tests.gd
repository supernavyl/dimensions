## Scene-based GUT headless runner — extends Node so it runs as a proper scene,
## which causes the full project to load (class_name registrations + autoloads).
extends Node

func _ready() -> void:
	var GutClass: GDScript = load("res://addons/gut/gut.gd") as GDScript
	var gut: Node = GutClass.new() as Node
	gut.log_level = 1
	gut.add_directory("res://tests/", "test_", ".gd")
	add_child(gut)

	await gut.end_run
	_report(gut)


func _report(gut: Node) -> void:
	print("\n--- GUT Results ---")
	print("Tests run:    ", gut.get_test_count())
	print("Assertions:   ", gut.get_assert_count())
	print("Passed:       ", gut.get_pass_count())
	print("Failed:       ", gut.get_fail_count())
	var failed: int = gut.get_fail_count()
	get_tree().quit(1 if failed > 0 else 0)


func _process(_delta: float) -> void:
	# Kick off test_scripts on the second frame so all nodes are fully ready.
	if Engine.get_process_frames() == 2:
		set_process(false)
		var gut: Node = get_child(0) as Node
		gut.call(&"test_scripts")
