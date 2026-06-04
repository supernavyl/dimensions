## DazeAudio — drives tinnitus + heartbeat that ride DrugDaze intensity.
## Add as a child of the Player. Auto-resolves the DrugDaze sibling.
class_name DazeAudio
extends Node

## Heartbeat interval in seconds when fully dazed (intensity = 1.0).
@export var heartbeat_period_peak: float = 0.62
## Heartbeat interval when intensity = 0.
@export var heartbeat_period_calm: float = 1.05
## Tinnitus loudness ceiling at peak daze (dB).
@export var tinnitus_db_peak: float = -12.0
## Heartbeat loudness ceiling at peak daze (dB).
@export var heartbeat_db_peak: float = -8.0
## Below this intensity, tinnitus is silent.
@export var tinnitus_threshold: float = 0.05

var _daze: DrugDaze
var _tinnitus_player: AudioStreamPlayer
var _heart_player: AudioStreamPlayer
var _heart_timer: float = 0.0


func _ready() -> void:
	_daze = get_parent().get_node_or_null("DrugDaze") as DrugDaze

	_tinnitus_player = AudioStreamPlayer.new()
	_tinnitus_player.stream = ProcAudio.tinnitus(2.0, 0.22)
	_tinnitus_player.volume_db = -80.0
	_tinnitus_player.bus = &"Master"
	add_child(_tinnitus_player)
	_tinnitus_player.play()

	_heart_player = AudioStreamPlayer.new()
	_heart_player.stream = ProcAudio.heartbeat(0.9)
	_heart_player.volume_db = -80.0
	_heart_player.bus = &"Master"
	add_child(_heart_player)


func _process(delta: float) -> void:
	var k: float = 0.0
	if _daze != null:
		k = _daze.current_intensity

	# Tinnitus: silent below threshold, otherwise scale to peak dB.
	if k <= tinnitus_threshold:
		_tinnitus_player.volume_db = -80.0
	else:
		var t: float = (k - tinnitus_threshold) / (1.0 - tinnitus_threshold)
		# Smooth easing from -55 dB (faint) to peak.
		_tinnitus_player.volume_db = lerpf(-55.0, tinnitus_db_peak, t)

	# Heartbeat — period and volume both ride k. Always at least faint.
	var period: float = lerpf(heartbeat_period_calm, heartbeat_period_peak, k)
	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = period
		_heart_player.volume_db = lerpf(-30.0, heartbeat_db_peak, k)
		_heart_player.play()
