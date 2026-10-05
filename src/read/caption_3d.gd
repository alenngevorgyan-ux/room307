class_name Caption3D
extends Label3D
## Handwritten-style world caption near a noticed observation. Fades over 2.5 s. Never glows.

const LIFE := 2.8


func show_caption(text_ru: String, at: Vector3) -> void:
	text = text_ru
	font_size = 34               # a small note near the thing itself — the player interprets
	pixel_size = 0.0034
	modulate = Color(0.97, 0.94, 0.82, 0.0)
	outline_size = 10
	outline_modulate = Color(0.05, 0.04, 0.03, 0.85)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	global_position = at + Vector3(0, 0.28, 0)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(self, "global_position:y", at.y + 0.42, LIFE)
	t.tween_interval(LIFE - 0.9)
	t.tween_property(self, "modulate:a", 0.0, 0.65)
	t.tween_callback(queue_free)
