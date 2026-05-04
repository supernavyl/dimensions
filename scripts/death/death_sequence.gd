## DeathSequence — transient CanvasLayer that plays the death visual effect.
## Parented to get_tree().current_scene (Main), NOT to _current_dimension.
## Freed by DimensionManager._on_death_sequence_finished() after sequence_finished.
class_name DeathSequence
extends CanvasLayer

## Emitted when the full fade-to-black sequence has completed.
signal sequence_finished

@onready var _black: ColorRect = $Black as ColorRect
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer as AudioStreamPlayer  # Phase 5: wire death audio


## Plays the death sequence appropriate to the given cause.
## cause may be null — treated as silent with default timing.
func play(cause: DeathCause) -> void:
	if _black == null:
		push_error("DeathSequence: $Black ColorRect not found — check death_sequence.tscn")
		sequence_finished.emit()
		return

	_black.modulate.a = 0.0
	_black.show()

	# Non-silent deaths with blood get a red flash before the fade.
	if cause != null and not cause.is_silent and cause.blood_intensity > 0.0:
		_flash_red(cause.blood_intensity)

	var is_silent: bool = (cause == null or cause.is_silent)
	var fade_duration: float = 2.5 if is_silent else 0.8

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_black, "modulate:a", 1.0, fade_duration)

	await tween.finished
	await get_tree().create_timer(1.5).timeout

	sequence_finished.emit()


## Adds a temporary red overlay that fades out, conveying violent death.
func _flash_red(intensity: float) -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.0, 0.0, clampf(intensity * 0.4, 0.0, 0.7))
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)

	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.6)
	tween.tween_callback(flash.queue_free)
