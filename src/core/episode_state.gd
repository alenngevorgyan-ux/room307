extends Node
## Episode — owns all runtime state (STATE_MODEL §2). Autoload.

enum Phase { S01_WATCH, S02_CLIENT, S03_ROOM, S04_HUB, S05_VIDEO, S06_THOMAS, S07_CHASE, S08_MARA,
	S09_STAGING, S09_LIVE, S09_DECISION, EPILOGUE, DONE }
enum LeadState { NONE, ACTIVE, DONE, FAILED_DONE }

const SAVE_PATH := "user://ep01_save.json"
const MAX_PINNED := 3
const STRESS_DECAY_SEC := 45.0

var phase: int = Phase.S01_WATCH
var scene_id: String = "S01"
var beats: Dictionary = {}
var facts: Dictionary = {}
var observations: Dictionary = {}
var threads_available: Array = []
var threads_pinned: Array = []
var threads_struck: Array = []
var items: Dictionary = {}
var leads: Dictionary = {"A": LeadState.NONE, "B": LeadState.NONE, "C": LeadState.NONE}
var s1_resolution: String = ""
var flags: Dictionary = {}
var characters: Dictionary = {}
var threat: ThreatState = ThreatState.new()
var trap_state: Dictionary = {}
var finale: FinaleState = FinaleState.new()
var ending: EndingState = EndingState.new()
var clock_sec: float = 0.0
var scene_clock: float = 0.0

# runtime helpers (not story state, but saved for exactness)
var hero_zone: String = ""
var seen_exchanges: Dictionary = {}
var active_exchange_npc: String = ""
var _decay_acc: Dictionary = {}
var paused_clock: bool = false
var phone_log: Array = []   # [{from, text, t}]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset()


func _process(delta: float) -> void:
	if paused_clock:
		return
	tick(delta)


## Advance time-driven state. Sims call this directly.
func tick(delta: float) -> void:
	clock_sec += delta
	scene_clock += delta
	_tick_stress(delta)


func reset() -> void:
	phase = Phase.S01_WATCH
	scene_id = "S01"
	beats = {}
	facts = {}
	observations = {}
	threads_available = []
	threads_pinned = []
	threads_struck = []
	items = {}
	leads = {"A": LeadState.NONE, "B": LeadState.NONE, "C": LeadState.NONE}
	s1_resolution = ""
	flags = {}
	threat = ThreatState.new()
	trap_state = {}
	finale = FinaleState.new()
	ending = EndingState.new()
	clock_sec = 0.0
	scene_clock = 0.0
	hero_zone = ""
	seen_exchanges = {}
	active_exchange_npc = ""
	_decay_acc = {}
	phone_log = []
	characters = {}
	var data := _data()
	if data:
		for npc in data.characters:
			characters[npc] = _make_char(npc, data.characters[npc])
		for item_id in data.items:
			var start: Variant = data.items[item_id].get("start_holder")
			if start != null:
				items[item_id] = String(start)


func _make_char(npc: String, def: Dictionary) -> CharacterState:
	var c := CharacterState.new()
	c.id = npc
	var st: Dictionary = def.get("start", {})
	c.trust = int(st.get("trust", 0))
	c.respect = int(st.get("respect", 0))
	c.suspicion = int(st.get("suspicion", 0))
	c.stress = int(st.get("stress", 0))
	c.start_stress = c.stress
	c.disposition = CharacterState.disposition_from_name(st.get("disposition", "CALM"))
	c.knows = Array(def.get("knows", [])).duplicate()
	c.vars = def.get("vars", {}).duplicate(true)
	return c


func _data() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Data") if tree else null


func _bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Bus") if tree else null


# ------------------------------------------------------------------ phase

func phase_name() -> String:
	return Phase.keys()[phase]


func set_phase_name(n: String) -> void:
	var i := Phase.keys().find(n)
	if i >= 0:
		phase = i


# ------------------------------------------------------------------ facts / obs / threads

func has_fact(f: String) -> bool:
	return facts.has(f)


func give_fact(f: String, source: String = "") -> bool:
	if facts.has(f):
		return false
	facts[f] = {"source": source, "t": clock_sec}
	_bus().fact_learned.emit(f, source)
	evaluate_threads()
	return true


func has_obs(o: String) -> bool:
	return observations.has(o)


func notice(o: String) -> bool:
	if observations.has(o):
		return false
	observations[o] = {"t": clock_sec}
	_bus().observation_noticed.emit(o)
	_bus().player_decision.emit("notice")
	evaluate_threads()
	return true


func evaluate_threads() -> void:
	var data := _data()
	if data == null:
		return
	for tid in data.threads:
		if threads_available.has(tid) or threads_pinned.has(tid) or threads_struck.has(tid):
			continue
		var t: Dictionary = data.threads[tid]
		if t.has("offer_when") and Conditions.check(t.offer_when, self):
			offer_thread(tid)


func offer_thread(tid: String) -> void:
	if threads_available.has(tid) or threads_pinned.has(tid) or threads_struck.has(tid):
		return
	threads_available.append(tid)
	_bus().thread_offered.emit(tid)
	var t: Dictionary = _data().threads.get(tid, {})
	if t.get("auto_pin", false) and threads_pinned.size() < MAX_PINNED:
		pin_thread(tid)


## Pins an offered thread. A fourth pin replaces the oldest.
func pin_thread(tid: String) -> bool:
	if not threads_available.has(tid):
		return false
	threads_available.erase(tid)
	if threads_pinned.size() >= MAX_PINNED:
		var old: String = threads_pinned.pop_front()
		threads_available.append(old)
	threads_pinned.append(tid)
	_bus().thread_pinned.emit(tid)
	_bus().player_decision.emit("pin")
	return true


func strike_thread(tid: String) -> void:
	threads_available.erase(tid)
	threads_pinned.erase(tid)
	if not threads_struck.has(tid):
		threads_struck.append(tid)
	_bus().thread_struck.emit(tid)


# ------------------------------------------------------------------ items

func give_item(item: String, holder: String = "hero") -> void:
	if items.get(item, "") == holder:
		return
	items[item] = holder
	_bus().item_changed.emit(item, holder)


func take_item(item: String) -> void:
	if not items.has(item):
		return
	items[item] = "world:none"
	_bus().item_changed.emit(item, "world:none")


func has_item(item: String) -> bool:
	return items.get(item, "") == "hero"


func holder_of(item: String) -> String:
	return String(items.get(item, ""))


# ------------------------------------------------------------------ flags / beats / leads

func flag(name: String) -> Variant:
	return flags.get(name)


func set_flag(name: String, value: Variant = true) -> void:
	if flags.get(name) == value:
		return
	flags[name] = value
	_bus().flag_changed.emit(name, value)


func clear_flag(name: String) -> void:
	if flags.has(name):
		flags.erase(name)
		_bus().flag_changed.emit(name, null)


func beat(b: String) -> void:
	if beats.has(b):
		return
	beats[b] = true
	_bus().world_beat.emit(b)


func set_lead(lead: String, state: int) -> void:
	var cur: int = leads.get(lead, LeadState.NONE)
	# DONE / FAILED_DONE are terminal
	if cur in [LeadState.DONE, LeadState.FAILED_DONE] and state != cur:
		return
	if cur == state:
		return
	leads[lead] = state
	_bus().lead_changed.emit(lead, state)


func lead_done(lead: String) -> bool:
	return leads.get(lead, LeadState.NONE) in [LeadState.DONE, LeadState.FAILED_DONE]


func leads_completed() -> int:
	var n := 0
	for l in leads:
		if lead_done(l):
			n += 1
	return n


static func lead_from_name(n: String) -> int:
	return LeadState.keys().find(n)


# ------------------------------------------------------------------ characters

func ch(npc: String) -> CharacterState:
	return characters.get(npc)


func _tick_stress(delta: float) -> void:
	for npc in characters:
		var c: CharacterState = characters[npc]
		if npc == active_exchange_npc or c.stress <= c.start_stress:
			_decay_acc[npc] = 0.0
			continue
		_decay_acc[npc] = float(_decay_acc.get(npc, 0.0)) + delta
		if _decay_acc[npc] >= STRESS_DECAY_SEC:
			_decay_acc[npc] = 0.0
			c.stress = maxi(c.start_stress, c.stress - 1)


# ------------------------------------------------------------------ endings

func ending_d_available() -> bool:
	var a := ch("adrian")
	if a == null:
		return false
	return a.trust >= 0 and int(a.fear_hits.get("LOSE_MARA", 0)) >= 2 \
		and finale.daniel_state in ["confessed", "escaped"] \
		and has_item("ITEM_HERO_PHONE")


# ------------------------------------------------------------------ generic paths (used by "cmp" and "set")

func get_path_value(path: String) -> Variant:
	var p := path.split(".")
	match p[0]:
		"finale":
			return finale.get(p[1])
		"threat":
			return threat.get(p[1])
		"ending":
			return ending.get(p[1])
		"flag":
			return flag(p[1])
		"char":
			var c := ch(p[1])
			return c.get(p[2]) if c else null
		"clock":
			return clock_sec
		"scene_clock":
			return scene_clock
		"leads":
			return leads_completed()
	return get(path)


func set_path_value(path: String, v: Variant) -> void:
	var p := path.split(".")
	match p[0]:
		"finale":
			finale.set(p[1], v)
		"threat":
			threat.set(p[1], v)
		"ending":
			ending.set(p[1], v)
		"char":
			var c := ch(p[1])
			if c:
				c.set(p[2], v)
		_:
			set(path, v)


# ------------------------------------------------------------------ save / load

func to_dict() -> Dictionary:
	var chars: Dictionary = {}
	for npc in characters:
		chars[npc] = characters[npc].to_dict()
	return {
		"phase": phase_name(), "scene_id": scene_id, "beats": beats.duplicate(),
		"facts": facts.duplicate(true), "observations": observations.duplicate(true),
		"threads_available": threads_available.duplicate(), "threads_pinned": threads_pinned.duplicate(),
		"threads_struck": threads_struck.duplicate(),
		"items": items.duplicate(), "leads": leads.duplicate(), "s1_resolution": s1_resolution,
		"flags": flags.duplicate(true), "characters": chars, "threat": threat.to_dict(),
		"trap_state": trap_state.duplicate(true), "finale": finale.to_dict(), "ending": ending.to_dict(),
		"clock_sec": clock_sec, "scene_clock": scene_clock, "hero_zone": hero_zone,
		"seen_exchanges": seen_exchanges.duplicate(), "phone_log": phone_log.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	set_phase_name(d.get("phase", "S01_WATCH"))
	scene_id = d.get("scene_id", "S01")
	beats = d.get("beats", {}).duplicate()
	facts = d.get("facts", {}).duplicate(true)
	observations = d.get("observations", {}).duplicate(true)
	threads_available = Array(d.get("threads_available", []))
	threads_pinned = Array(d.get("threads_pinned", []))
	threads_struck = Array(d.get("threads_struck", []))
	items = d.get("items", {}).duplicate()
	leads = {}
	for l in d.get("leads", {}):
		leads[l] = int(d.leads[l])
	s1_resolution = d.get("s1_resolution", "")
	flags = d.get("flags", {}).duplicate(true)
	for npc in d.get("characters", {}):
		var c := CharacterState.new()
		c.from_dict(d.characters[npc])
		characters[npc] = c
	threat.from_dict(d.get("threat", {}))
	trap_state = d.get("trap_state", {}).duplicate(true)
	finale.from_dict(d.get("finale", {}))
	ending.from_dict(d.get("ending", {}))
	clock_sec = float(d.get("clock_sec", 0.0))
	scene_clock = float(d.get("scene_clock", 0.0))
	hero_zone = d.get("hero_zone", "")
	seen_exchanges = d.get("seen_exchanges", {}).duplicate()
	phone_log = d.get("phone_log", []).duplicate(true)


func save_game(path: String = SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "  "))


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	from_dict(d)
	return true
