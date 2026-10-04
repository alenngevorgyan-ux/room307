class_name EndingState
extends RefCounted
## STATE_MODEL §10.

var id: String = ""                 # A_MARA | B_THOMAS | C_DESTROY | D_ADRIAN
var daniel_outcome: String = ""     # confessed | escaped | exposed_silent
var recorded: String = "none"       # none | muffled | clear
var thomas_present: bool = false
var adrian_relationship: int = 0
var mara_trust: int = 0


func to_dict() -> Dictionary:
	return {"id": id, "daniel_outcome": daniel_outcome, "recorded": recorded,
		"thomas_present": thomas_present, "adrian_relationship": adrian_relationship,
		"mara_trust": mara_trust}


func from_dict(d: Dictionary) -> void:
	id = d.get("id", "")
	daniel_outcome = d.get("daniel_outcome", "")
	recorded = d.get("recorded", "none")
	thomas_present = bool(d.get("thomas_present", false))
	adrian_relationship = int(d.get("adrian_relationship", 0))
	mara_trust = int(d.get("mara_trust", 0))
