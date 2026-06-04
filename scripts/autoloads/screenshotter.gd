## Screenshotter — drives the camera through preset angles, writes
## /tmp/dim_screen_<label>.png at each, then quits.
## Active only when DIM_SHOT env var is set.
extends Node

const _OUT_DIR: String = "/tmp"

# Each entry: (label, delay_seconds, camera_pitch_radians, camera_yaw_offset_radians)
# Pitch: negative = look down. Yaw: 0 = forward. All applied AFTER FPSController.
const _SHOTS: Array = [
	["00_forward",        1.0,   0.0,    0.0],
	["01_lookdown_45",    1.7,  -0.78,   0.0],
	["02_lookdown_60",    2.4,  -1.05,   0.0],
	["03_lookdown_90",    3.1,  -1.40,   0.0],
	["04_look_left",      3.8,   0.0,   -0.6],
	["05_look_right",     4.5,   0.0,    0.6],
	["06_lookdown_left",  5.2,  -0.9,   -0.4],
	["07_lookdown_right", 5.9,  -0.9,    0.4],
]

var _enabled: bool = false
var _t: float = 0.0
var _idx: int = 0
var _player: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	_enabled = OS.get_environment("DIM_SHOT") != ""
	if not _enabled:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not _enabled or _idx >= _SHOTS.size():
		return
	_t += delta
	var entry: Array = _SHOTS[_idx]
	if _t < float(entry[1]):
		return

	if _player == null:
		_player = get_tree().get_first_node_in_group("players") as CharacterBody3D
	if _player == null:
		var scene: Node = get_tree().current_scene
		if scene != null:
			_player = scene.get_node_or_null("Player") as CharacterBody3D
	if _player != null and _camera == null:
		_camera = _player.get_node_or_null("Camera3D") as Camera3D

	if _camera != null:
		_camera.rotation.x = float(entry[2])
		_player.rotation.y = float(entry[3])

	# Render one frame after rotation, then capture.
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		var path: String = "%s/dim_screen_%s.png" % [_OUT_DIR, entry[0]]
		img.save_png(path)
		print("[shot] ", path)

	_idx += 1
	if _idx >= _SHOTS.size():
		await get_tree().create_timer(0.3).timeout
		get_tree().quit()
