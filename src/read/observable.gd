class_name Observable
extends Node3D
## ObservablePoint (STATE_MODEL §5). STATIC = always readable; TELL = only while a window is open.
## Invisible in play (debug gizmo only). Def from observations.json:
##   caption, mode, anchor {zone,p}|{npc,part,off}, requires, scene, focus, dwell, dist

enum Mode { STATIC, TELL }

var obs_id: String = ""
var caption: String = ""
var mode: int = Mode.STATIC
var focus_radius := 0.35
var dwell := 0.4
var max_distance := 6.0
var requires: Variant = null
var scenes: Variant = null
var view := ""            # "left" | "right" | "front" | "behind": hero must stand on that side of the NPC
var window_open := false
var _window_left := 0.0


func setup(id: String, d: Dictionary) -> void:
	obs_id = id
	name = "Obs_" + id
	caption = String(d.get("caption", ""))
	mode = Mode.TELL if String(d.get("mode", "STATIC")) == "TELL" else Mode.STATIC
	focus_radius = float(d.get("focus", 0.35))
	dwell = float(d.get("dwell", 0.4))
	max_distance = float(d.get("dist", 6.0))
	requires = d.get("requires")
	scenes = d.get("scene")
	view = String(d.get("view", ""))
	add_to_group("observables")


func _ready() -> void:
	get_node("/root/Bus").tell_opened.connect(_on_tell)


func _on_tell(id: String, dur: float) -> void:
	if id == obs_id:
		open_tell(dur)


func open_tell(dur: float) -> void:
	window_open = true
	_window_left = maxf(_window_left, dur)


func _process(delta: float) -> void:
	if _window_left > 0.0:
		# windows run in real seconds; READ's slow-motion stretches them (Engine.time_scale)
		_window_left -= delta
		if _window_left <= 0.0:
			window_open = false


func readable() -> bool:
	if not is_visible_in_tree():
		return false
	var E := get_node("/root/Episode")
	if E.has_obs(obs_id):
		return false
	if scenes != null:
		if typeof(scenes) == TYPE_ARRAY and not scenes.has(E.scene_id):
			return false
		if typeof(scenes) == TYPE_STRING and scenes != E.scene_id:
			return false
	if requires != null and not Conditions.check(requires, E):
		return false
	if mode == Mode.TELL and not window_open:
		return false
	if view != "" and not _view_ok():
		return false
	return true


func _view_ok() -> bool:
	var n: Node = get_parent()
	while n and not (n is NPC):
		n = n.get_parent()
	if n == null or Services.hero == null:
		return true
	var f: Vector3 = n.facing_dir()
	var to: Vector3 = Services.hero.global_position - n.global_position
	to.y = 0
	to = to.normalized()
	var left := Vector3(f.z, 0, -f.x)
	match view:
		"left": return to.dot(left) > 0.25
		"right": return to.dot(-left) > 0.25
		"front": return to.dot(f) > 0.3
		"behind": return to.dot(f) < -0.3
	return true
