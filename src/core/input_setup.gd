class_name InputSetup
extends RefCounted
## Registers the input map at runtime (GAMEPLAY_SPEC "Controls").

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_fwd": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"run": [KEY_SHIFT], "fast_walk": [KEY_CAPSLOCK], "crouch": [KEY_CTRL, KEY_C],
	"context": [KEY_SPACE], "interact": [KEY_E], "read": [KEY_F],
	"chip_1": [KEY_1], "chip_2": [KEY_2], "chip_3": [KEY_3], "chip_4": [KEY_4],
	"phone": [KEY_TAB], "threads": [KEY_Q], "pause": [KEY_ESCAPE],
	"phone_up": [KEY_UP], "phone_down": [KEY_DOWN], "phone_ok": [KEY_ENTER],
}
const PAD_BUTTONS := {
	"context": [JOY_BUTTON_A], "interact": [JOY_BUTTON_X], "crouch": [JOY_BUTTON_B],
	"fast_walk": [JOY_BUTTON_LEFT_STICK], "phone": [JOY_BUTTON_BACK], "threads": [JOY_BUTTON_RIGHT_SHOULDER],
	"pause": [JOY_BUTTON_START], "chip_1": [JOY_BUTTON_DPAD_UP], "chip_2": [JOY_BUTTON_DPAD_RIGHT],
	"chip_3": [JOY_BUTTON_DPAD_DOWN], "chip_4": [JOY_BUTTON_DPAD_LEFT],
}


static var _installed := false


static func install() -> void:
	if _installed:
		return
	_installed = true
	for a in KEYS:
		_ensure(a)
		for k in KEYS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for a in PAD_BUTTONS:
		_ensure(a)
		for b in PAD_BUTTONS[a]:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			InputMap.action_add_event(a, e)
	_ensure("read")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("read", rmb)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_fwd", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("read", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis("run", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	for a in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		_ensure(a)
	_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)


static func _ensure(a: String) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.25)


static func _axis(a: String, axis: int, v: float) -> void:
	_ensure(a)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	InputMap.action_add_event(a, e)
