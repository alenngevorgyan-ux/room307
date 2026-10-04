extends SceneLogic
## S02 glue: the elevator ride. Doors stay shut until the decisive exchange has played
## (min 14 s, max 35 s), the floor indicator ticks, then BEAT_S2_RIDE_DONE opens on floor 3.

var _ride_t := -1.0
var _label: Label3D


func enter() -> void:
	bus().world_beat.connect(_on_beat)


func _on_beat(b: String) -> void:
	if b == "BEAT_S2_RIDE":
		_ride_t = 0.0
		if Services.world:
			_label = Graybox.label3d("G", 60, Color(1, 0.8, 0.4))
			_label.no_depth_test = false
			Services.world.add_child(_label)
			_label.global_position = data().zone_origin("ELEV_A") + Vector3(1.3, 2.32, 0.14)


func tick(delta: float) -> void:
	if _ride_t < 0.0:
		return
	_ride_t += delta
	var conv_done: bool = Services.conversation == null or Services.conversation.active_id != "X_S02_C"
	if _label:
		_label.text = ["G", "1", "2", "3"][clampi(int(_ride_t / 9.0), 0, 3)]
		if Services.world and Services.world.camera_director:
			Services.world.camera_director.shake = 0.15
	if (_ride_t >= 14.0 and conv_done) or _ride_t >= 35.0:
		_ride_t = -1.0
		if _label:
			_label.text = "3"
		ep().beat("BEAT_S2_RIDE_DONE")


func exit() -> void:
	if _label:
		_label.queue_free()
