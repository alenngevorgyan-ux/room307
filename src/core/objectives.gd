class_name Objectives
extends RefCounted
## The single current objective (data/ep01/objectives.json). Pure function of Episode state, so the
## headless SIM, the HUD and the hint director all agree. Returns {} when nothing should be shown.


static func _data() -> Node:
	return Engine.get_main_loop().root.get_node("Data")


## Objective ids in evaluation order.
static func ordered() -> Array:
	var D := _data()
	var ids: Array = D.objectives.keys()
	ids.sort_custom(func(a, b): return int(D.objectives[a].get("order", 0)) < int(D.objectives[b].get("order", 0)))
	return ids


static func current(ep: Node = null) -> Dictionary:
	var D := _data()
	for id in ordered():
		var o: Dictionary = D.objectives[id]
		if Conditions.check(o.get("when"), ep):
			return {"id": id, "text": String(o.get("text", "")), "sub": String(o.get("sub", "")), "def": o}
	return {}


static func current_id(ep: Node = null) -> String:
	return String(current(ep).get("id", ""))
