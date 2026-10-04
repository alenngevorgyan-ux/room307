class_name ThreatState
extends RefCounted
## Stealth & chase state (STATE_MODEL §6).

enum Alert { UNAWARE, CURIOUS, SEARCHING, PURSUIT, STUNNED, DOUBT, CONTAINED }

var alert: Dictionary = {}
var heat: int = 0
var grabs: int = 0
var caught_count: Dictionary = {"pavel": 0}
var daniel_knows_hero_met_thomas: bool = false


func to_dict() -> Dictionary:
	return {"alert": alert.duplicate(), "heat": heat, "grabs": grabs,
		"caught_count": caught_count.duplicate(),
		"daniel_knows_hero_met_thomas": daniel_knows_hero_met_thomas}


func from_dict(d: Dictionary) -> void:
	alert = d.get("alert", {}).duplicate()
	heat = int(d.get("heat", 0))
	grabs = int(d.get("grabs", 0))
	caught_count = {}
	for k in d.get("caught_count", {"pavel": 0}):
		caught_count[k] = int(d.caught_count[k])
	daniel_knows_hero_met_thomas = bool(d.get("daniel_knows_hero_met_thomas", false))
