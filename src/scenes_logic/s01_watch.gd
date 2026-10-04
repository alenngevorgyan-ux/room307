extends SceneLogic
## S01 glue: the opening card (place + time, no exposition), and easing the camera out on first move.

var _moved := false


func enter() -> void:
	if Services.hud and Services.hud.has_method("show_opening"):
		Services.hud.show_opening("THE VESPER", "02:17")


func tick(_delta: float) -> void:
	if _moved or Services.hero == null:
		return
	if not Services.hero.seated:
		_moved = true
		bus().camera_hint.emit({"clear": true})


func exit() -> void:
	if not _moved:
		bus().camera_hint.emit({"clear": true})
