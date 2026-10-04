class_name DataValidator
extends RefCounted
## Data integrity checks (ACCEPTANCE_TESTS §A). Each check returns an Array of error strings.

const FORBIDDEN := ["врёт", "лжёт", "виновен", "доказывает", "значит", "врет", "лжет"]
const LINE_BUDGET := 450
const CINE_MAX := 15.0

var D: Node


func _init(data_node: Node) -> void:
	D = data_node


static func words(s: String) -> int:
	var n := 0
	for w in s.replace("—", " ").replace("…", " ").split(" ", false):
		if w.strip_edges().replace(".", "").replace(",", "").replace("!", "").replace("?", "").replace("«", "").replace("»", "") != "":
			n += 1
	return n


# ------------------------------------------------------------ action sites

## Every action list in the data, as [site_name, actions].
func action_sites() -> Array:
	var out: Array = []
	for xid in D.exchanges:
		var x: Dictionary = D.exchanges[xid]
		if x.has("on_end"):
			out.append([xid, x.on_end])
		for nid in x.get("nodes", {}):
			var n: Dictionary = x.nodes[nid]
			var site := String(n.get("source", xid))
			if n.has("actions"):
				out.append([site, n.actions])
			for c in n.get("chips", []):
				if c.has("actions"):
					out.append([String(c.get("source", site)), c.actions])
	for tid in D.traps:
		for o in D.traps[tid].get("outcomes", []):
			out.append([String(o.get("source", tid)), o.get("do", [])])
	for iid in D.interactables:
		var it: Dictionary = D.interactables[iid]
		var site := String(it.get("source", iid))
		if it.has("actions"):
			out.append([site, it.actions])
		for v in it.get("variants", []):
			if v.has("actions"):
				out.append([String(v.get("source", site)), v.actions])
	for oid in D.overhears:
		for l in D.overhears[oid].get("lines", []):
			if typeof(l) == TYPE_DICTIONARY and l.has("actions"):
				out.append([String(D.overhears[oid].get("source", oid)), l.actions])
		if D.overhears[oid].has("actions"):
			out.append([String(D.overhears[oid].get("source", oid)), D.overhears[oid].actions])
	for sid in D.scenes:
		var s: Dictionary = D.scenes[sid]
		for k in ["enter", "exit"]:
			if s.has(k):
				out.append([sid, s[k]])
		for k in s.get("rules", []):
			out.append([String(k.get("source", sid)), k.get("do", [])])
	for cid in D.claims:
		for npc in D.claims[cid].get("overrides", {}):
			for o in D.claims[cid].overrides[npc]:
				if o.has("do"):
					out.append([cid, o.do])
	for k in D.lines_ru:
		if D.lines_ru[k].has("actions"):
			out.append([k, D.lines_ru[k].actions])
	for k in D.finale.get("actions", {}):
		out.append([k, D.finale.actions[k]])
	for k in D.chase.get("actions", {}):
		out.append([k, D.chase.actions[k]])
	return out


## fact -> [site names that grant it]
func grant_sites() -> Dictionary:
	var g: Dictionary = {}
	for s in action_sites():
		var flat: Array = []
		ActionRunner.flatten(s[1], flat)
		for a in flat:
			if a[0] == "give_fact":
				var f: String
				var site: String = s[0]
				if typeof(a[1]) == TYPE_ARRAY:
					f = String(a[1][0])
					site = String(a[1][1])
				else:
					f = String(a[1])
				if not g.has(f):
					g[f] = []
				if not g[f].has(site):
					g[f].append(site)
	return g


# ------------------------------------------------------------ AT-DATA-01

func check_references() -> Array:
	var errs: Array = []
	for s in action_sites():
		var flat: Array = []
		ActionRunner.flatten(s[1], flat)
		for a in flat:
			_check_action(String(s[0]), a[0], a[1], errs)
		_check_conds_in_actions(String(s[0]), s[1], errs)
	for xid in D.exchanges:
		var x: Dictionary = D.exchanges[xid]
		var npc := String(x.get("npc", ""))
		if npc != "" and not D.characters.has(npc):
			errs.append("%s: unknown npc %s" % [xid, npc])
		var nodes: Dictionary = x.get("nodes", {})
		if not nodes.has(String(x.get("start", "start"))):
			errs.append("%s: missing start node" % xid)
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			var nexts: Array = []
			for k in ["next", "silence", "leave", "on_timeout"]:
				if n.has(k):
					nexts.append(String(n[k]))
			for b in n.get("branch", []):
				nexts.append(String(b.get("next", "")))
				_check_cond(xid + "." + nid, b.get("if"), errs)
			if n.has("line"):
				for k in (n.line if typeof(n.line) == TYPE_ARRAY else [n.line]):
					if not D.lines_ru.has(String(k)):
						errs.append("%s.%s: unknown line %s" % [xid, nid, k])
			for tl in (n.tell if typeof(n.get("tell")) == TYPE_ARRAY else [n.get("tell")]):
				if tl != null and not D.observations.has(String(tl.obs)):
					errs.append("%s.%s: tell unknown obs %s" % [xid, nid, tl.obs])
			for c in n.get("chips", []):
				if c.has("next"):
					nexts.append(String(c.next))
				for r in c.get("next_by_reaction", {}):
					nexts.append(String(c.next_by_reaction[r]))
				for b in c.get("next_if", []):
					nexts.append(String(b.get("next", "")))
				if c.has("claim") and not D.claims.has(String(c.claim)):
					errs.append("%s.%s: unknown claim %s" % [xid, nid, c.claim])
				if c.has("line") and not D.lines_ru.has(String(c.line)):
					errs.append("%s.%s: unknown hero line %s" % [xid, nid, c.line])
				_check_cond("%s.%s.%s" % [xid, nid, c.get("id", "?")], c.get("requires"), errs)
			for nx in nexts:
				if nx != "" and nx != "end" and not nodes.has(nx):
					errs.append("%s.%s: unknown next node %s" % [xid, nid, nx])
		_check_cond(xid, x.get("requires"), errs)
		_check_cond(xid + ".trigger", x.get("trigger", {}).get("cond"), errs)
	for cid in D.claims:
		var c: Dictionary = D.claims[cid]
		if c.has("line") and not D.lines_ru.has(String(c.line)):
			errs.append("%s: unknown line %s" % [cid, c.line])
		for npc in c.get("fears", {}):
			if not D.characters.has(npc):
				errs.append("%s: unknown npc %s" % [cid, npc])
		if c.has("about") and String(c.about) != "" and not D.facts.has(String(c.about)):
			errs.append("%s: unknown about fact %s" % [cid, c.about])
		for f in c.get("contradicted_by", []):
			if not D.facts.has(String(f)):
				errs.append("%s: unknown contradicted_by %s" % [cid, f])
	for tid in D.traps:
		var t: Dictionary = D.traps[tid]
		if t.has("target") and String(t.target) != "" and not D.characters.has(String(t.target)):
			errs.append("%s: unknown target %s" % [tid, t.target])
		var bait: Dictionary = t.get("bait", {})
		if bait.has("claim"):
			for c in (bait.claim if typeof(bait.claim) == TYPE_ARRAY else [bait.claim]):
				if not D.claims.has(String(c)):
					errs.append("%s: unknown bait claim %s" % [tid, c])
		for z in t.get("environment", {}).get("zones", []) if t.get("environment") != null else []:
			if not D.level.has(String(z)):
				errs.append("%s: unknown zone %s" % [tid, z])
		_check_cond(tid, t.get("requires"), errs)
		_check_cond(tid, t.get("object"), errs)
	for th in D.threads:
		_check_cond(th, D.threads[th].get("offer_when"), errs)
	for iid in D.interactables:
		var it: Dictionary = D.interactables[iid]
		if it.has("zone") and not D.level.has(String(it.zone)):
			errs.append("%s: unknown zone %s" % [iid, it.zone])
		_check_cond(iid, it.get("requires"), errs)
		_check_cond(iid, it.get("visible_if"), errs)
		for v in it.get("variants", []):
			_check_cond(iid, v.get("if"), errs)
	for oid in D.observations:
		var o: Dictionary = D.observations[oid]
		var anc: Dictionary = o.get("anchor", {})
		if anc.has("zone") and not D.level.has(String(anc.zone)):
			errs.append("%s: unknown anchor zone %s" % [oid, anc.zone])
		if anc.has("npc") and not D.characters.has(String(anc.npc)):
			errs.append("%s: unknown anchor npc %s" % [oid, anc.npc])
	for sid in D.schedules:
		var s: Dictionary = D.schedules[sid]
		if not D.characters.has(String(s.get("npc", ""))):
			errs.append("%s: unknown npc %s" % [sid, s.get("npc")])
		for p in s.get("points", []):
			var at := String(p.get("at", ""))
			if at != "" and not D.has_marker(at):
				errs.append("%s: unknown marker %s" % [sid, at])
			if p.has("tell") and not D.observations.has(String(p.tell.obs)):
				errs.append("%s: unknown tell obs %s" % [sid, p.tell.obs])
	for k in D.lines_ru:
		var sp := String(D.lines_ru[k].get("speaker", ""))
		if sp != "hero" and sp != "voice" and sp != "pa" and not D.characters.has(sp):
			errs.append("line %s: unknown speaker %s" % [k, sp])
	for zid in D.level:
		for d in D.level[zid].get("doors", []):
			if d.has("to") and D.door_zone(String(d.to)) == "":
				errs.append("%s door %s: unknown target door %s" % [zid, d.id, d.to])
	return errs


func _check_conds_in_actions(site: String, actions: Variant, errs: Array) -> void:
	if actions == null:
		return
	if typeof(actions) == TYPE_DICTIONARY:
		actions = [actions]
	for a in actions:
		if typeof(a) == TYPE_DICTIONARY and a.has("if"):
			_check_cond(site, a["if"], errs)
			_check_conds_in_actions(site, a.get("then", []), errs)
			_check_conds_in_actions(site, a.get("else", []), errs)
		elif typeof(a) == TYPE_DICTIONARY and a.has("delay"):
			_check_conds_in_actions(site, a.get("do", []), errs)


func _check_cond(site: String, cond: Variant, errs: Array) -> void:
	var toks: Array = []
	Conditions.tokens_of(cond, toks)
	for t in toks:
		var s := String(t)
		if s.begins_with("offered:") or s.begins_with("struck:"):
			s = s.substr(s.find(":") + 1)
		if s.begins_with("F_") and not D.facts.has(s):
			errs.append("%s: unknown fact %s" % [site, s])
		elif s.begins_with("O_") and not D.observations.has(s):
			errs.append("%s: unknown obs %s" % [site, s])
		elif s.begins_with("T_") and not D.threads.has(s):
			errs.append("%s: unknown thread %s" % [site, s])
		elif s.begins_with("ITEM_") and not D.items.has(s):
			errs.append("%s: unknown item %s" % [site, s])


func _check_action(site: String, verb: String, v: Variant, errs: Array) -> void:
	if not ActionRunner.VERBS.has(verb):
		errs.append("%s: unknown verb %s" % [site, verb])
		return
	var first: String = str(v[0]) if typeof(v) == TYPE_ARRAY and v.size() > 0 else str(v)
	match verb:
		"line", "lines", "ambient":
			for k in (v if typeof(v) == TYPE_ARRAY else [v]):
				if not D.lines_ru.has(String(k)):
					errs.append("%s: unknown line %s" % [site, k])
		"give_fact":
			if not D.facts.has(first):
				errs.append("%s: unknown fact %s" % [site, first])
		"notice":
			if not D.observations.has(first):
				errs.append("%s: unknown obs %s" % [site, first])
		"offer_thread", "pin_thread", "strike_thread":
			if not D.threads.has(first):
				errs.append("%s: unknown thread %s" % [site, first])
		"give_item", "take_item":
			if not D.items.has(first):
				errs.append("%s: unknown item %s" % [site, first])
		"start_exchange":
			if not D.exchanges.has(first):
				errs.append("%s: unknown exchange %s" % [site, first])
		"play_cine":
			if not D.cines.has(first):
				errs.append("%s: unknown cine %s" % [site, first])
		"set_schedule":
			if not D.characters.has(first):
				errs.append("%s: unknown npc %s" % [site, first])
			if String(v[1]) != "" and not D.schedules.has(String(v[1])):
				errs.append("%s: unknown schedule %s" % [site, v[1]])
		"trust", "respect", "suspicion", "stress", "warmth", "fear_hit", "set_disposition", "set_var", "believes", "knows", "remember":
			if not D.characters.has(first):
				errs.append("%s: unknown npc %s" % [site, first])
		"teleport_npc", "spawn":
			if first != "hero" and not D.characters.has(first):
				errs.append("%s: unknown npc %s" % [site, first])
			if v.size() > 1 and String(v[1]) != "" and not D.has_marker(String(v[1])):
				errs.append("%s: unknown marker %s" % [site, v[1]])
		"despawn":
			if not D.characters.has(first):
				errs.append("%s: unknown npc %s" % [site, first])
		"goto_scene":
			if not D.scenes.has(first):
				errs.append("%s: unknown scene %s" % [site, first])
		"lead":
			if not ["A", "B", "C"].has(first):
				errs.append("%s: bad lead %s" % [site, first])


# ------------------------------------------------------------ AT-DATA-02 / 03

func check_required_facts() -> Array:
	var errs: Array = []
	var g := grant_sites()
	for f in D.facts:
		var fd: Dictionary = D.facts[f]
		if not fd.get("required", false):
			continue
		var sites: Array = g.get(f, [])
		var guaranteed: Array = fd.get("guaranteed_by", [])
		var has_g := false
		for s in guaranteed:
			if sites.has(String(s)):
				has_g = true
		if sites.size() < 2 and not has_g:
			errs.append("%s: required fact has %d grant sites and none guaranteed" % [f, sites.size()])
	return errs


func check_sources_exist() -> Array:
	var errs: Array = []
	var g := grant_sites()
	for f in D.facts:
		var sites: Array = g.get(f, [])
		for s in D.facts[f].get("sources", []):
			if not sites.has(String(s)):
				errs.append("%s: source '%s' has no grant site (have %s)" % [f, s, sites])
		for s in D.facts[f].get("guaranteed_by", []):
			if not sites.has(String(s)):
				errs.append("%s: guaranteed_by '%s' has no grant site" % [f, s])
	return errs


# ------------------------------------------------------------ AT-DATA-04

func _node_line_dur(n: Dictionary) -> float:
	if not n.has("line"):
		return 0.0
	var t := 0.0
	for k in (n.line if typeof(n.line) == TYPE_ARRAY else [n.line]):
		t += float(D.line(String(k)).dur)
	return t


func _chip_nexts(n: Dictionary) -> Array:
	var out: Array = []
	for c in n.get("chips", []):
		var hero_dur := 0.0
		var key := String(c.get("line", ""))
		if key == "" and c.has("claim"):
			key = String(D.claims.get(c.claim, {}).get("line", ""))
		if key != "":
			hero_dur = float(D.line(key).dur)
		var ns: Array = []
		if c.has("next"):
			ns.append(String(c.next))
		for r in c.get("next_by_reaction", {}):
			ns.append(String(c.next_by_reaction[r]))
		for b in c.get("next_if", []):
			ns.append(String(b.next))
		for x in ns:
			out.append([x, hero_dur])
	for k in ["silence", "leave"]:
		if n.has(k):
			out.append([String(n[k]), 0.0])
	return out


func check_chip_chains() -> Array:
	var errs: Array = []
	for xid in D.exchanges:
		var nodes: Dictionary = D.exchanges[xid].get("nodes", {})
		var seen: Dictionary = {}
		var stack: Array = [[String(D.exchanges[xid].get("start", "start")), 0]]
		while not stack.is_empty():
			var it: Array = stack.pop_back()
			var nid: String = it[0]
			var chain: int = it[1]
			if not nodes.has(nid):
				continue
			var key := "%s#%d" % [nid, chain]
			if seen.has(key):
				continue
			seen[key] = true
			var n: Dictionary = nodes[nid]
			if n.has("chips"):
				chain += 1
				if chain > 2:
					errs.append("%s: node %s is the 3rd chip window in a row" % [xid, nid])
					continue
				for e in _chip_nexts(n):
					stack.append([e[0], 0 if e[1] >= 2.0 else chain])
			else:
				var reset: bool = _node_line_dur(n) >= 2.0 or n.has("await") or n.has("wait") or n.get("movement", false)
				var c2: int = 0 if reset else chain
				var ns: Array = []
				for k in ["next", "on_timeout", "leave"]:
					if n.has(k):
						ns.append(String(n[k]))
				for b in n.get("branch", []):
					ns.append(String(b.next))
				for x in ns:
					stack.append([x, c2])
	return errs


# ------------------------------------------------------------ AT-DATA-05..08

func check_cines() -> Array:
	var errs: Array = []
	for s in action_sites():
		var flat: Array = []
		ActionRunner.flatten(s[1], flat)
		for a in flat:
			if a[0] == "play_cine":
				var c: Dictionary = D.cines.get(String(a[1]), {})
				if c.is_empty():
					errs.append("%s: unknown cine %s" % [s[0], a[1]])
				elif float(c.get("dur", 0)) > CINE_MAX:
					errs.append("%s: cine %s is %.1fs > 15s" % [s[0], a[1], float(c.dur)])
	for cid in D.cines:
		if float(D.cines[cid].get("dur", 0)) > CINE_MAX:
			errs.append("cine %s is %.1fs > 15s" % [cid, float(D.cines[cid].dur)])
	return errs


func check_captions() -> Array:
	var errs: Array = []
	for oid in D.observations:
		var cap := String(D.observations[oid].get("caption", ""))
		if cap == "":
			errs.append("%s: empty caption" % oid)
		if words(cap) > 8:
			errs.append("%s: caption has %d words" % [oid, words(cap)])
		var low := cap.to_lower()
		for w in FORBIDDEN:
			if low.contains(w):
				errs.append("%s: caption contains forbidden word «%s»" % [oid, w])
	return errs


func check_chip_and_hero_lengths() -> Array:
	var errs: Array = []
	for xid in D.exchanges:
		for nid in D.exchanges[xid].get("nodes", {}):
			for c in D.exchanges[xid].nodes[nid].get("chips", []):
				if words(String(c.get("label", ""))) > 4:
					errs.append("%s.%s: chip '%s' > 4 words" % [xid, nid, c.get("label")])
	for k in D.lines_ru:
		var l: Dictionary = D.lines_ru[k]
		if String(l.get("speaker", "")) == "hero" and not l.get("anchor", false) and words(String(l.text)) > 8:
			errs.append("hero line %s has %d words" % [k, words(String(l.text))])
	return errs


func check_silence_leave() -> Array:
	var errs: Array = []
	for xid in D.exchanges:
		for nid in D.exchanges[xid].get("nodes", {}):
			var n: Dictionary = D.exchanges[xid].nodes[nid]
			if n.has("chips"):
				if not n.has("silence"):
					errs.append("%s.%s: chip node lacks silence" % [xid, nid])
				if not n.has("leave"):
					errs.append("%s.%s: chip node lacks leave" % [xid, nid])
	return errs


func check_line_budget() -> Array:
	if D.lines_ru.size() > LINE_BUDGET:
		return ["line budget exceeded: %d > %d" % [D.lines_ru.size(), LINE_BUDGET]]
	return []


func run_all() -> Dictionary:
	return {
		"AT-DATA-01": D.load_errors + check_references(),
		"AT-DATA-02": check_required_facts(),
		"AT-DATA-03": check_sources_exist(),
		"AT-DATA-04": check_chip_chains(),
		"AT-DATA-05": check_cines(),
		"AT-DATA-06": check_captions(),
		"AT-DATA-07": check_chip_and_hero_lengths(),
		"AT-DATA-08": check_silence_leave(),
		"LINE-BUDGET": check_line_budget(),
	}
