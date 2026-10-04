class_name Conditions
extends RefCounted
## One condition language used by exchanges, traps, interactables, threads and scenes.
##
## A condition is:
##   null / {}                -> true
##   "TOKEN"                  -> token test (see _token)
##   ["T1", "T2"]             -> all
##   {"all": [...], "any": [...], "none": [...], "any_n": n, "of": [...],
##    "npc_state": {npc: {stress_gte, trust_gte, trust_lt, suspicion_gte, suspicion_lt, respect_gte,
##                        disposition, disposition_not, var: {k: v}, fear_gte: {tag: n}}},
##    "flags": {name: value}, "items": {ITEM: holder}, "leads_gte": n,
##    "cmp": [path, op, value], "not": cond, "chance": 0..1 (deterministic: always true in sims)}
##
## Tokens: F_* fact known, O_* observation noticed, T_* thread pinned, ITEM_* held by hero,
## BEAT_* beat happened, "flag:name" truthy flag, "offered:T_*" thread available or pinned,
## "lead:A" lead done (DONE|FAILED_DONE), "lead_active:A", "s1:PUBLIC_EXPOSE",
## "phase:S04_HUB", "scene:S04", "zone:BAR" hero zone, "struck:T_*", "ending:A_MARA",
## "!token" negation.

static func check(cond: Variant, ep: Node = null) -> bool:
	if ep == null:
		ep = Engine.get_main_loop().root.get_node("Episode")
	if cond == null:
		return true
	match typeof(cond):
		TYPE_STRING, TYPE_STRING_NAME:
			return token(String(cond), ep)
		TYPE_ARRAY:
			for c in cond:
				if not check(c, ep):
					return false
			return true
		TYPE_BOOL:
			return cond
		TYPE_DICTIONARY:
			return _dict(cond, ep)
	return true


static func _dict(d: Dictionary, ep: Node) -> bool:
	if d.has("all"):
		for c in d.all:
			if not check(c, ep):
				return false
	if d.has("any"):
		var ok := false
		for c in d.any:
			if check(c, ep):
				ok = true
				break
		if not ok:
			return false
	if d.has("none"):
		for c in d.none:
			if check(c, ep):
				return false
	if d.has("any_n"):
		var n := 0
		for c in d.get("of", []):
			if check(c, ep):
				n += 1
		if n < int(d.any_n):
			return false
	if d.has("not") and check(d["not"], ep):
		return false
	if d.has("flags"):
		for k in d.flags:
			if ep.flag(k) != d.flags[k]:
				return false
	if d.has("items"):
		for k in d.items:
			if ep.holder_of(k) != String(d.items[k]):
				return false
	if d.has("leads_gte") and ep.leads_completed() < int(d.leads_gte):
		return false
	if d.has("npc_state"):
		for npc in d.npc_state:
			if not _npc(ep.ch(npc), d.npc_state[npc]):
				return false
	if d.has("cmp"):
		var c: Array = d.cmp
		if not compare(ep.get_path_value(String(c[0])), String(c[1]), c[2]):
			return false
	return true


static func _npc(cs: CharacterState, q: Dictionary) -> bool:
	if cs == null:
		return false
	for k in q:
		var v: Variant = q[k]
		match k:
			"stress_gte":
				if cs.stress < int(v): return false
			"stress_lt":
				if cs.stress >= int(v): return false
			"trust_gte":
				if cs.trust < int(v): return false
			"trust_lt":
				if cs.trust >= int(v): return false
			"respect_gte":
				if cs.respect < int(v): return false
			"suspicion_gte":
				if cs.suspicion < int(v): return false
			"suspicion_lt":
				if cs.suspicion >= int(v): return false
			"disposition":
				if cs.disposition_name() != String(v): return false
			"disposition_not":
				if cs.disposition_name() == String(v): return false
			"caught_lying":
				if cs.caught_lying != bool(v): return false
			"caught_hero_lying":
				if cs.caught_hero_lying != bool(v): return false
			"zone":
				if cs.zone != String(v): return false
			"var":
				for vk in v:
					if cs.vars.get(vk) != v[vk]: return false
			"fear_gte":
				for tag in v:
					if int(cs.fear_hits.get(tag, 0)) < int(v[tag]): return false
			"memory":
				if not cs.memory.has(String(v)): return false
	return true


static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL: return false
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
		TYPE_STRING, TYPE_STRING_NAME: return String(v) != ""
	return true


static func compare(a: Variant, op: String, b: Variant) -> bool:
	if typeof(a) != typeof(b) and not (typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]):
		if op == "==": return false
		if op == "!=": return true
		if a == null: a = 0
		if b == null: b = 0
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		a = float(a)
		b = float(b)
	match op:
		"==": return a == b
		"!=": return a != b
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
		"in": return typeof(b) == TYPE_ARRAY and b.has(a)
	return false


static func token(t: String, ep: Node) -> bool:
	if t.begins_with("!"):
		return not token(t.substr(1), ep)
	if t.begins_with("F_"):
		return ep.has_fact(t)
	if t.begins_with("O_"):
		return ep.has_obs(t)
	if t.begins_with("T_"):
		return ep.threads_pinned.has(t)
	if t.begins_with("ITEM_"):
		return ep.has_item(t)
	if t.begins_with("BEAT_"):
		return ep.beats.has(t)
	var c := t.find(":")
	if c < 0:
		push_warning("unknown condition token " + t)
		return false
	var kind := t.substr(0, c)
	var arg := t.substr(c + 1)
	match kind:
		"flag":
			return truthy(ep.flag(arg))
		"offered":
			return ep.threads_available.has(arg) or ep.threads_pinned.has(arg)
		"struck":
			return ep.threads_struck.has(arg)
		"lead":
			return ep.lead_done(arg)
		"lead_active":
			return ep.leads.get(arg, 0) == ep.LeadState.ACTIVE
		"s1":
			return ep.s1_resolution == arg
		"phase":
			return ep.phase_name() == arg
		"scene":
			return ep.scene_id == arg
		"zone":
			return ep.hero_zone == arg
		"ending":
			return ep.ending.id == arg
		"seen":
			return ep.seen_exchanges.has(arg)
		"holder":
			# holder:ITEM_X:npc
			var p := arg.split(":")
			return p.size() == 2 and ep.holder_of(p[0]) == p[1]
		"hears":
			# hears:listener:speaker (same zone, within listener's hearing radius)
			var p := arg.split(":")
			return p.size() == 2 and Presence.hears(p[0], p[1])
		"near":
			# near:a:b:metres
			var p := arg.split(":")
			return p.size() == 3 and Presence.distance(p[0], p[1]) <= float(p[2])
		"far":
			var p := arg.split(":")
			return p.size() == 3 and Presence.distance(p[0], p[1]) > float(p[2])
		"present":
			return Presence.is_present(arg)
		"npc_zone":
			var p := arg.split(":")
			return p.size() == 2 and Presence.in_zone(p[0]) == p[1]
		"item_at":
			# item_at:ITEM_X:holder
			var p := arg.split(":", true, 1)
			return p.size() == 2 and ep.holder_of(p[0]) == p[1]
		"trap":
			return ep.trap_state.get(arg, {}).get("fired", false)
	push_warning("unknown condition token " + t)
	return false


## Collects every id-like token referenced by a condition (for the validator).
static func tokens_of(cond: Variant, out: Array) -> void:
	match typeof(cond):
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(cond).trim_prefix("!")
			out.append(s)
		TYPE_ARRAY:
			for c in cond:
				tokens_of(c, out)
		TYPE_DICTIONARY:
			for k in ["all", "any", "none", "of"]:
				if cond.has(k):
					tokens_of(cond[k], out)
			if cond.has("not"):
				tokens_of(cond["not"], out)
			if cond.has("items"):
				for i in cond.items:
					out.append(String(i))
