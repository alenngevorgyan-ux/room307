class_name Doorway
extends Node3D
## A transition point. Hero: walk into it (auto) or press E/Space. Teleport behind a 0.25 s fade.
## NPCs route through doorways too (they simply appear at the target's spawn point).

signal traversed(door_id: String, who: String)

var door_id: String = ""
var zone_id: String = ""
var def: Dictionary = {}
var normal := Vector3.FORWARD     # pointing INTO the room
var target_id: String = ""


func setup(d: Dictionary, zid: String, n: Vector3) -> void:
	def = d
	door_id = String(d.id)
	zone_id = zid
	normal = n
	target_id = String(d.get("to", ""))
	add_to_group("doorways")


func spawn_point() -> Vector3:
	return global_position + normal * float(def.get("spawn_in", 1.1))


func label() -> String:
	return String(def.get("label", "Дверь"))


func is_locked() -> bool:
	if def.get("locked_if") is bool:
		return bool(def.locked_if)
	if def.has("locked_if") and Conditions.check(def.locked_if, get_node("/root/Episode")):
		return true
	if def.has("open_if") and not Conditions.check(def.open_if, get_node("/root/Episode")):
		return true
	return false


func auto() -> bool:
	return bool(def.get("auto", true)) and not is_locked()


func resolved_target_id() -> String:
	if def.has("to_by_flag"):
		var tb: Dictionary = def.to_by_flag
		var v: Variant = get_node("/root/Episode").flag(String(tb.flag))
		return String(tb.map.get(String(v), tb.map.get("default", target_id)))
	return target_id


func target() -> Doorway:
	if Services.world == null:
		return null
	return Services.world.door(resolved_target_id())
