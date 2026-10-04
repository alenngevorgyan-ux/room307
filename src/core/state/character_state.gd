class_name CharacterState
extends RefCounted
## One object per NPC (STATE_MODEL §3). A dozen fields, no more.

enum Disposition { CALM, GUARDED, PRESSURED, HOSTILE, OPEN, GONE }

var id: String = ""
var zone: String = ""
var activity: String = ""
var schedule: String = ""
var disposition: int = Disposition.CALM
var stress: int = 0
var trust: int = 0
var respect: int = 0
var suspicion: int = 0
var knows: Array = []
var believes_hero_knows: Array = []
var fear_hits: Dictionary = {}
var caught_lying: bool = false
var caught_hero_lying: bool = false
var memory: Array = []
var start_stress: int = 0
var vars: Dictionary = {}   # per-NPC small extras (lina_state, warmth flags, mara_wary ...)


static func disposition_from_name(n: String) -> int:
	var i := Disposition.keys().find(n)
	return i if i >= 0 else Disposition.CALM


func disposition_name() -> String:
	return Disposition.keys()[disposition]


func knows_fact(f: String) -> bool:
	return knows.has(f)


func add_stress(n: int) -> void:
	stress = clampi(stress + n, 0, 3)


func add_trust(n: int) -> void:
	trust = clampi(trust + n, -2, 2)


func add_respect(n: int) -> void:
	respect = clampi(respect + n, -2, 2)


func add_suspicion(n: int) -> void:
	suspicion = clampi(suspicion + n, 0, 3)


func fear_hit(tag: String, n: int = 1) -> void:
	fear_hits[tag] = int(fear_hits.get(tag, 0)) + n


func remember(ev: String) -> void:
	if not memory.has(ev):
		memory.append(ev)


func to_dict() -> Dictionary:
	return {
		"id": id, "zone": zone, "activity": activity, "schedule": schedule,
		"disposition": disposition_name(), "stress": stress, "trust": trust,
		"respect": respect, "suspicion": suspicion, "knows": knows.duplicate(),
		"believes_hero_knows": believes_hero_knows.duplicate(),
		"fear_hits": fear_hits.duplicate(), "caught_lying": caught_lying,
		"caught_hero_lying": caught_hero_lying, "memory": memory.duplicate(),
		"start_stress": start_stress, "vars": vars.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	id = d.get("id", id)
	zone = d.get("zone", "")
	activity = d.get("activity", "")
	schedule = d.get("schedule", "")
	disposition = disposition_from_name(d.get("disposition", "CALM"))
	stress = int(d.get("stress", 0))
	trust = int(d.get("trust", 0))
	respect = int(d.get("respect", 0))
	suspicion = int(d.get("suspicion", 0))
	knows = Array(d.get("knows", []))
	believes_hero_knows = Array(d.get("believes_hero_knows", []))
	fear_hits = {}
	for k in d.get("fear_hits", {}):
		fear_hits[k] = int(d.fear_hits[k])
	caught_lying = bool(d.get("caught_lying", false))
	caught_hero_lying = bool(d.get("caught_hero_lying", false))
	memory = Array(d.get("memory", []))
	start_stress = int(d.get("start_stress", 0))
	vars = d.get("vars", {}).duplicate(true)
