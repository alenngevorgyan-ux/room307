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
	return {"conv": conv, "traps": traps}


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
		t += step
