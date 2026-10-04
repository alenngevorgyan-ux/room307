extends SceneLogic
## S01 glue: the in-world title card on the rainy window, and easing the camera out on first move.

var _title: Label3D
var _moved := false


func enter() -> void:
	if Services.world:
		_title = Graybox.label3d("ROOM 307\n02:17", 110, Color(0.85, 0.9, 1.0, 0.0))
		_title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_title.no_depth_test = false
		Services.world.add_child(_title)
		_title.global_position = data().zone_origin("BAR") + Vector3(7.0, 1.7, 0.2)
		var t := _title.create_tween()
		t.tween_property(_title, "modulate:a", 0.75, 1.5)
		t.tween_interval(6.0)
		t.tween_property(_title, "modulate:a", 0.0, 3.0)
		t.tween_callback(_title.queue_free)


func tick(_delta: float) -> void:
	if _moved or Services.hero == null:
		return
	if not Services.hero.seated:
		_moved = true
		bus().camera_hint.emit({"clear": true})


func exit() -> void:
	if not _moved:
		bus().camera_hint.emit({"clear": true})
