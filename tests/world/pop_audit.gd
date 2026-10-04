extends SceneTree
## Pass 2 audit: plays an autopilot ending in the real world and lists every NPC pop (appear /
## vanish / jump while on camera). Run:
##   godot --headless --path . --fixed-fps 60 -s res://tests/world/pop_audit.gd -- --autopilot=A_MARA
## main.gd starts the autopilot from the same argument and quits when the episode is done.

var pops: Array = []


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_hook.call_deferred()


func _hook() -> void:
	root.get_node("Bus").npc_popped.connect(_on_pop)


func _on_pop(npc: String, kind: String, info: Dictionary) -> void:
	var E := root.get_node("Episode")
	var line := "POP %-14s %-16s scene=%s phase=%s zone=%s sched=%s where=%s" % [npc, kind, E.scene_id, E.phase_name(),
		info.get("zone", ""), info.get("schedule", ""), " < ".join(info.get("where", []))]
	pops.append(line)
	print(line)
