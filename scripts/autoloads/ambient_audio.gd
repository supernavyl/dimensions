## AmbientAudio — global ambient drone manager.
## Crossfades between per-dimension ambient tracks.
## Gracefully does nothing if the audio file is missing (pre-asset-download state).
extends Node

const _FADE_TIME: float = 1.5

var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active: AudioStreamPlayer = null
var _tween: Tween = null


func _ready() -> void:
	_player_a = _make_player()
	_player_b = _make_player()
	add_child(_player_a)
	add_child(_player_b)
	_active = _player_a


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambient"
	p.volume_db = -80.0
	p.autoplay = false
	return p


## Crossfade to a new ambient track.
## path should be "res://audio/ambient/void.ogg" etc.
## Silently skips if the file doesn't exist.
func play(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fade_out(_active)
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		_fade_out(_active)
		return

	var incoming: AudioStreamPlayer = _player_b if _active == _player_a else _player_a
	incoming.stream = stream
	incoming.play()

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_active, "volume_db", -80.0, _FADE_TIME)
	_tween.tween_property(incoming, "volume_db", -24.0, _FADE_TIME)

	_active = incoming


func _fade_out(player: AudioStreamPlayer) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", -80.0, _FADE_TIME)
	_tween.tween_callback(player.stop)


## Immediately silence all ambient (used on death/FinalEvent).
func stop() -> void:
	_player_a.stop()
	_player_b.stop()
