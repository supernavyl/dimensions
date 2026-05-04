## FinalEvent — plays when the player has survived DIMENSIONS_TO_FINAL dimensions.
## Reality collapse: rapid color flicker → white → fade to black → quit.
## Parented to current_scene by main.gd. Calls get_tree().quit() at the end.
class_name FinalEvent
extends CanvasLayer


func play() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)

	# Rapid reality-collapse flicker: 12 random colors at 80ms each.
	for i: int in range(12):
		var c := Color(randf(), randf(), randf(), 0.6)
		tween.tween_property(overlay, "color", c, 0.08)

	# Burn to white.
	tween.tween_property(overlay, "color", Color.WHITE, 0.4)
	await tween.finished
	await get_tree().create_timer(2.0).timeout

	# White to black — the dimensions end.
	var final_tween: Tween = create_tween()
	final_tween.tween_property(overlay, "color", Color.BLACK, 1.5)
	await final_tween.finished
	await get_tree().create_timer(3.0).timeout

	get_tree().quit()
