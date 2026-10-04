class_name FinaleState
extends RefCounted
## Finale staging + live state (STATE_MODEL §9).

var seats: Dictionary = {"S1": "", "S2": "", "S3": "", "S4": ""}
var standing: Array = []
var recorder: String = "none"        # vase | basket | shelf | none
var card_spot: String = "pocket"     # table | pocket | bar
var doors: Dictionary = {"kitchen": "open", "main": "closed", "terrace": "locked"}
var lights: String = "dim"           # dim | full
var invites: Array = []              # [{to, template, t}]
var started: bool = false
var daniel_pressure: int = 0
var daniel_state: String = "seated"  # seated | wary | fleeing | cornered | confessed | escaped
var thugs_inside: bool = false
var exposed: bool = false
var photo_at_adrian: bool = false


func invited(npc: String) -> bool:
	for i in invites:
		if i.to == npc:
			return true
	return false


func invite_template(npc: String) -> String:
	for i in invites:
		if i.to == npc:
			return i.template
	return ""


func seat_of(npc: String) -> String:
	for s in seats:
		if seats[s] == npc:
			return s
	return ""


func to_dict() -> Dictionary:
	return {"seats": seats.duplicate(), "standing": standing.duplicate(), "recorder": recorder,
		"card_spot": card_spot, "doors": doors.duplicate(), "lights": lights,
		"invites": invites.duplicate(true), "started": started,
		"daniel_pressure": daniel_pressure, "daniel_state": daniel_state,
		"thugs_inside": thugs_inside, "exposed": exposed, "photo_at_adrian": photo_at_adrian}


func from_dict(d: Dictionary) -> void:
	seats = d.get("seats", seats).duplicate()
	standing = Array(d.get("standing", []))
	recorder = d.get("recorder", "none")
	card_spot = d.get("card_spot", "pocket")
	doors = d.get("doors", doors).duplicate()
	lights = d.get("lights", "dim")
	invites = d.get("invites", []).duplicate(true)
	started = bool(d.get("started", false))
	daniel_pressure = int(d.get("daniel_pressure", 0))
	daniel_state = d.get("daniel_state", "seated")
	thugs_inside = bool(d.get("thugs_inside", false))
	exposed = bool(d.get("exposed", false))
	photo_at_adrian = bool(d.get("photo_at_adrian", false))
