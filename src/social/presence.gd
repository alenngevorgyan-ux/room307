class_name Presence
extends RefCounted
## Who is where. NPC nodes and the hero update this every physics frame; logic sims set it directly.
## "Hearing" = same zone and within the listener's hearing radius (zones are acoustically separate).

const DEFAULT_HEARING := 6.0

static var pos: Dictionary = {}     # id -> Vector3 ("hero" included)
static var zone: Dictionary = {}    # id -> zone id
static var present: Dictionary = {} # id -> true while spawned in the world
static var hearing_mult: Dictionary = {}   # zone -> multiplier (e.g. kitchen noise in the restaurant)


static func clear() -> void:
	pos.clear()
	zone.clear()
	present.clear()
	hearing_mult.clear()


static func place(id: String, zone_id: String, p: Vector3 = Vector3.ZERO) -> void:
	pos[id] = p
	zone[id] = zone_id
	present[id] = true


static func remove(id: String) -> void:
	pos.erase(id)
	zone.erase(id)
	present.erase(id)


static func is_present(id: String) -> bool:
	return present.has(id)


static func distance(a: String, b: String) -> float:
	if not pos.has(a) or not pos.has(b):
		return INF
	if zone.get(a, "") != zone.get(b, ""):
		return INF
	return (pos[a] as Vector3).distance_to(pos[b])


static func hearing_radius(listener: String) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var data := tree.root.get_node_or_null("Data")
	if data:
		return float(data.character(listener).get("hearing", DEFAULT_HEARING))
	return DEFAULT_HEARING


static func hears(listener: String, speaker: String) -> bool:
	if not present.has(listener) or not present.has(speaker):
		return false
	var m := float(hearing_mult.get(zone.get(listener, ""), 1.0))
	return distance(listener, speaker) <= hearing_radius(listener) * m


## Everyone (except `exclude`) who can hear `speaker`.
static func audience_of(speaker: String, exclude: Array = []) -> Array:
	var out: Array = []
	for id in present:
		if id == speaker or id == "hero" or exclude.has(id):
			continue
		if hears(id, speaker):
			out.append(id)
	return out


static func in_zone(id: String) -> String:
	return String(zone.get(id, ""))
