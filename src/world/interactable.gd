class_name Interactable
extends Node3D
## InteractPoint: an object the hero can use with E (or Space when `context`).
## Def (interactables.json): zone, p, scene (str|[..]), verb, prompt, requires, blocked_if/blocked_text,
## visible_if, once, actions, variants [{if, verb, prompt, actions, once}], mesh {s, c, y}, radius, hold.
## Every visible interaction changes state or gives feedback (no fake prompts).

var iid: String = ""
var def: Dictionary = {}
var mesh_node: Node3D
var _vis_t := 0.0


func setup(id: String, d: Dictionary) -> void:
	iid = id
	def = d
	name = "I_" + id
	add_to_group("interactables")
	var m: Dictionary = d.get("mesh", {})
	if not d.get("no_mesh", false):
		var vis := Node3D.new()
		vis.name = "Visual"
		add_child(vis)
		var s := Data.vec3(m.get("s", [0.18, 0.12, 0.18]))
		mesh_node = Graybox.box_mesh(s, Graybox.color(m.get("c", "interact")), float(m.get("emit", 0.25)))
		mesh_node.position = Vector3(0, s.y / 2.0, 0) + Data.vec3(m.get("off", [0, 0, 0]))
		vis.add_child(mesh_node)
		if m.get("collide", false):
			var body := StaticBody3D.new()
			body.collision_layer = Graybox.LAYER_WORLD
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = s
			cs.shape = sh
			body.add_child(cs)
			body.position = mesh_node.position
			add_child(body)
	refresh_visibility()


func _ep() -> Node:
	return get_node("/root/Episode")


func _process(delta: float) -> void:
	_vis_t -= delta
	if _vis_t <= 0.0:
		_vis_t = 0.25
		refresh_visibility()


func refresh_visibility() -> void:
	visible = is_available()


func used() -> bool:
	return bool(_ep().flags.get("used:" + iid, false))


func scene_ok() -> bool:
	if not def.has("scene"):
		return true
	var s: Variant = def.scene
	var cur: String = _ep().scene_id
	if typeof(s) == TYPE_ARRAY:
		return s.has(cur)
	return String(s) == cur


func is_available() -> bool:
	if not is_inside_tree():
		return false
	if not scene_ok():
		return false
	if def.get("once", false) and used():
		return false
	if def.has("visible_if") and not Conditions.check(def.visible_if, _ep()):
		return false
	if def.has("variants") and _variant().is_empty():
		return false
	return true


func _variant() -> Dictionary:
	for v in def.get("variants", []):
		if v.get("once", false) and _ep().flags.get("used:%s:%s" % [iid, v.get("id", "")], false):
			continue
		if Conditions.check(v.get("if"), _ep()):
			return v
	return {}


func radius() -> float:
	return float(def.get("radius", 1.5))


func uses_context_key() -> bool:
	return bool(def.get("context", false))


## Text shown by the context prompt.
func prompt_text() -> String:
	var v := _variant()
	var verb := String(v.get("verb", def.get("verb", "Осмотреть")))
	var what := String(v.get("prompt", def.get("prompt", "")))
	if def.has("blocked_if") and Conditions.check(def.blocked_if, _ep()):
		return String(def.get("blocked_text", "Занято"))
	if def.has("requires") and not Conditions.check(def.requires, _ep()):
		return String(def.get("locked_text", what))
	return verb + ((" · " + what) if what != "" else "")


func hold_time() -> float:
	var v := _variant()
	return float(v.get("hold", def.get("hold", 0.0)))


## Returns true if something happened.
func use() -> bool:
	var E := _ep()
	var B := get_node("/root/Bus")
	if def.has("blocked_if") and Conditions.check(def.blocked_if, E):
		ActionRunner.run(def.get("blocked_actions", [{"sfx": "deny"}]), {"source": iid, "pos": global_position})
		return true
	if def.has("requires") and not Conditions.check(def.requires, E):
		ActionRunner.run(def.get("locked_actions", [{"sfx": "deny"}]), {"source": iid, "pos": global_position})
		return true
	var actions: Variant = def.get("actions", [])
	var source := String(def.get("source", iid))
	if def.has("variants"):
		var v := _variant()
		if v.is_empty():
			return false
		actions = v.get("actions", [])
		source = String(v.get("source", source))
		if v.get("once", false):
			E.flags["used:%s:%s" % [iid, v.get("id", "")]] = true
	E.flags["used:" + iid] = true
	ActionRunner.run(actions, {"source": source, "pos": global_position, "interact": iid})
	B.interact_done.emit(iid)
	B.player_decision.emit("interact")
	refresh_visibility()
	return true
