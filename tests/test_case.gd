class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tests/run_tests.gd.

var failures: Array = []
var tree: SceneTree
var current := ""


func ep() -> Node:
	return tree.root.get_node("Episode")


func data() -> Node:
	return tree.root.get_node("Data")


func bus() -> Node:
	return tree.root.get_node("Bus")


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg if msg != "" else "assertion failed"])


func eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		failures.append("%s: %s expected %s got %s" % [current, msg, str(b), str(a)])


## Fresh logic world: Episode reset, Presence cleared, directors created as needed.
func fresh() -> void:
	_cine = null
	ActionRunner.reset()
	Presence.clear()
	ep().reset()
	for c in tree.root.get_children():
		if c.has_meta("sim_node"):
			tree.root.remove_child(c)
			c.free()
	Services.clear()


func make_directors() -> Dictionary:
	var conv := ConversationDirector.new()
	conv.set_meta("sim_node", true)
	conv.set_process(false)
	conv.set_process_unhandled_input(false)
	tree.root.add_child(conv)
	var traps := TrapDirector.new()
	traps.set_meta("sim_node", true)
	tree.root.add_child(traps)
	var oh := OverhearDirector.new()
	oh.set_meta("sim_node", true)
	oh.set_process(false)
	tree.root.add_child(oh)
	_oh = oh
	var cine := CinePlayer.new()
	cine.set_meta("sim_node", true)
	cine.set_process(false)
	tree.root.add_child(cine)
	_cine = cine
	return {"conv": conv, "traps": traps, "cine": cine, "oh": oh}


var _cine: Node = null
var _oh: Node = null


## Logic-only scene run: directors + SceneManager (no 3D world). Returns {conv, traps, sm}.
func start_scene(id: String) -> Dictionary:
	var d := make_directors()
	var sm := SceneManager.new()
	sm.set_meta("sim_node", true)
	sm.autosave = false
	sm.set_process(false)
	tree.root.add_child(sm)
	d["sm"] = sm
	sm.goto_scene(id)
	return d


func place(id: String, marker: String) -> void:
	Presence.place(id, data().marker_zone(marker), data().marker(marker))
	if id == "hero":
		ep().hero_zone = data().marker_zone(marker)


func place_at(id: String, zone: String, p: Vector3) -> void:
	Presence.place(id, zone, data().zone_origin(zone) + p)


## Let lines drain and chips appear.
func settle(conv: Node, max_sec: float = 30.0) -> void:
	var t := 0.0
	while t < max_sec:
		advance(conv, 0.1)
		t += 0.1
		if conv.active_id == "" or not conv.chips_visible.is_empty():
			if not conv.busy():
				return


## Advance logic time (conversation + episode) in small steps.
func advance(conv: Node, sec: float, step: float = 0.1) -> void:
	var t := 0.0
	while t < sec:
		if conv:
			conv.tick(step)
		else:
			ActionRunner.tick(step)
		ep().tick(step)
		var sm: Node = Services.scenes
		if sm and sm.has_method("tick"):
			sm.tick(step)
		if is_instance_valid(_cine):
			_cine._process(step)
		if is_instance_valid(_oh):
			_oh.tick(step)
		t += step


## Advance until cond.call() is true (or max_sec). Returns whether it became true.
func wait_until(conv: Node, cond: Callable, max_sec: float = 60.0, step: float = 0.1) -> bool:
	var t := 0.0
	while t < max_sec:
		if cond.call():
			return true
		advance(conv, step, step)
		t += step
	return cond.call()
