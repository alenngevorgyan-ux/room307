class_name SceneLogic
extends Node
## Base for thin per-scene glue (src/scenes_logic/sNN_*.gd). Content stays in JSON;
## only what data can't express lives here. Works headless (no world required).

var scene_id := ""
var def: Dictionary = {}


func ep() -> Node:
	return get_node("/root/Episode")


func data() -> Node:
	return get_node("/root/Data")


func bus() -> Node:
	return get_node("/root/Bus")


func run(actions: Variant) -> void:
	ActionRunner.run(actions, {"source": scene_id})


func enter() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func exit() -> void:
	pass


func npc_node(id: String) -> NPC:
	return Services.world.npc(id) if Services.world else null
