class_name ConversationDirector
extends Node
## Conversation in motion (STATE_MODEL §7).
## - One exchange active at a time; NPCs keep their schedules unless a line is flagged `hold`.
## - Chips time out (SILENCE); leaving the radius for 1.5 s follows LEAVE.
## - Also owns the global line queue (subtitles + barks) so trap/overhear lines never overlap.
##
## Node kinds: line | chips | wait | branch | await | end   (every node may carry "actions")

const LEAVE_GRACE := 1.5
const TRIGGER_POLL := 0.2

var active_id: String = ""
var active: Dictionary = {}
var node_id: String = ""
var node: Dictionary = {}
var node_t: float = 0.0
var chips_visible: Array = []      # chip dicts currently offered
var chips_deadline: float = 0.0
var awaiting_reaction: Dictionary = {}   # pending chip after hero line finishes
var leave_t: float = 0.0
var waiting_lines := false
var exchange_t: float = 0.0

# line queues: the exchange channel (blocks conversation flow) and the ambient/world channel
# (background argument, overhears, barks with subtitles) which exchange lines pre-empt.
const AMBIENT_TTL := 6.0
var line_queue: Array = []         # exchange channel [{key, ctx}]
var world_queue: Array = []        # ambient channel [{key, ctx, ttl}]
var current_line: Dictionary = {}
var current_world := false
var line_t: float = 0.0

var _poll_t: float = 0.0
var auto_triggers := true
## Optional: returns the addressee npc for chips with "addressee": "@addressed" (finale positional addressing).
var addressee_provider: Callable


func _ready() -> void:
	Services.conversation = self
	get_node("/root/Bus").world_beat.connect(_on_beat)


func _exit_tree() -> void:
	if Services.conversation == self:
		Services.conversation = null


func _ep() -> Node:
	return get_node("/root/Episode")


func _data() -> Node:
	return get_node("/root/Data")


func _bus() -> Node:
	return get_node("/root/Bus")


func _process(delta: float) -> void:
	tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if chips_visible.is_empty():
		return
	for i in 4:
		var act := "chip_%d" % (i + 1)
		if InputMap.has_action(act) and event.is_action_pressed(act):
			choose(i)
			get_viewport().set_input_as_handled()
			return


func is_active() -> bool:
	return active_id != ""


## True while exchange-channel lines are queued or playing (ambient lines never block an exchange).
func busy() -> bool:
	return (not current_line.is_empty() and not current_world) or not line_queue.is_empty()


# ================================================================== tick

func tick(delta: float) -> void:
	ActionRunner.tick(delta)
	_tick_lines(delta)
	if active_id != "":
		exchange_t += delta
		_tick_exchange(delta)
	elif not _pending_beat.is_empty():
		var xid: String = _pending_beat.pop_front()
		if can_start(xid):
			start(xid)
	elif auto_triggers:
		_poll_t -= delta
		if _poll_t <= 0.0:
			_poll_t = TRIGGER_POLL
			_poll_triggers()


func _tick_lines(delta: float) -> void:
	for w in world_queue:
		w.ttl -= delta
	world_queue = world_queue.filter(func(w): return w.ttl > 0.0)
	if not current_line.is_empty():
		line_t -= delta
		if current_world and not line_queue.is_empty():
			line_t = 0.0   # exchange line pre-empts ambient chatter
		if line_t > 0.0:
			return
		current_line = {}
	var q: Dictionary
	if not line_queue.is_empty():
		q = line_queue.pop_front()
		current_world = false
	elif not world_queue.is_empty():
		q = world_queue.pop_front()
		current_world = true
	else:
		return
	var l: Dictionary = _data().line(q.key)
	current_line = l
	current_line["key"] = q.key
	line_t = float(l.dur)
	var speaker := String(l.get("speaker", ""))
	_bus().line_started.emit(speaker, String(l.get("text", "")), float(l.dur))
	if l.has("tell"):
		var tl: Dictionary = l.tell
		ActionRunner.run([{"delay": float(tl.get("at", 0.3)), "do": [{"tell": [tl.obs, float(tl.get("dur", 1.6))]}]}])
	if l.has("actions"):
		ActionRunner.run(l.actions, {"npc": speaker, "source": q.key})


## Lines queued while an exchange is active join the exchange channel (trap outcomes during a
## conversation read as part of it); otherwise, or with ctx.world, they go to the ambient channel.
func queue_line(key: String, ctx: Dictionary = {}) -> void:
	if ctx.get("world", false) or active_id == "":
		world_queue.append({"key": key, "ctx": ctx, "ttl": float(ctx.get("ttl", AMBIENT_TTL))})
	else:
		line_queue.append({"key": key, "ctx": ctx})


func clear_lines() -> void:
	line_queue.clear()
	if not current_world:
		current_line = {}
		line_t = 0.0


## Skip the currently playing line (debug / sims).
func skip_line() -> void:
	line_t = 0.0


# ================================================================== start / end

func can_start(xid: String) -> bool:
	var x: Dictionary = _data().exchanges.get(xid, {})
	if x.is_empty():
		return false
	if not Conditions.check(x.get("requires"), _ep()):
		return false
	var seen: Variant = _ep().seen_exchanges.get(xid)
	if seen != null:
		if x.get("repeatable", false):
			# re-open only after a new observation or fact (S01 rule)
			var know: int = _ep().facts.size() + _ep().observations.size()
			if know <= int(seen.get("know", 0)):
				return false
		elif x.get("once", true):
			return false
	return true


func start(xid: String, force: bool = false) -> bool:
	if active_id != "":
		if not force:
			return false
		end_active("INTERRUPT")
	if not _data().exchanges.has(xid):
		push_warning("unknown exchange " + xid)
		return false
	active_id = xid
	active = _data().exchanges[xid]
	exchange_t = 0.0
	leave_t = 0.0
	_ep().active_exchange_npc = String(active.get("npc", ""))
	_ep().seen_exchanges[xid] = {"n": int(_ep().seen_exchanges.get(xid, {}).get("n", 0)) + 1,
		"know": _ep().facts.size() + _ep().observations.size()}
	_bus().exchange_started.emit(xid)
	if not active.get("npc_keeps_schedule", true):
		_bus().npc_command.emit(String(active.npc), "hold", {"on": true})
	_bus().npc_command.emit(String(active.get("npc", "")), "face_hero", {"on": true})
	_enter(String(active.get("start", "start")))
	return true


func end_active(outcome: String = "END") -> void:
	if active_id == "":
		return
	var xid := active_id
	var npc := String(active.get("npc", ""))
	_hide_chips()
	if not active.get("npc_keeps_schedule", true):
		_bus().npc_command.emit(npc, "hold", {"on": false})
	_bus().npc_command.emit(npc, "face_hero", {"on": false})
	var on_end: Variant = active.get("on_end")
	active_id = ""
	active = {}
	node_id = ""
	node = {}
	awaiting_reaction = {}
	waiting_lines = false
	_ep().active_exchange_npc = ""
	if on_end != null:
		ActionRunner.run(on_end, {"npc": npc, "source": xid, "outcome": outcome})
	_bus().exchange_ended.emit(xid, outcome)


# ================================================================== nodes

func _enter(nid: String) -> void:
	if nid == "" or nid == "end" or not active.get("nodes", {}).has(nid):
		if nid != "" and nid != "end":
			push_warning("exchange %s: missing node %s" % [active_id, nid])
		end_active("END")
		return
	node_id = nid
	node = active.nodes[nid]
	node_t = 0.0
	waiting_lines = false
	var npc := String(active.get("npc", ""))
	if node.has("actions"):
		ActionRunner.run(node.actions, {"npc": npc, "source": node.get("source", active_id), "exchange": active_id})
		if active_id == "":
			return   # an action ended or replaced the exchange
	if node.has("end"):
		end_active(String(node.end))
		return
	if node.has("line"):
		var keys: Array = node.line if typeof(node.line) == TYPE_ARRAY else [node.line]
		for k in keys:
			queue_line(String(k), {"npc": npc})
		if node.has("tell"):
			var tells: Array = node.tell if typeof(node.tell) == TYPE_ARRAY else [node.tell]
			for tl in tells:
				if tl != null:
					ActionRunner.run([{"delay": float(tl.get("at", 0.5)), "do": [{"tell": [tl.obs, float(tl.get("dur", 1.6))]}]}])
		if node.get("hold", false):
			_bus().npc_command.emit(npc, "hold", {"on": true, "until_lines": true})
		waiting_lines = true
		return
	if node.has("branch"):
		for b in node.branch:
			if b.get("else", false) or Conditions.check(b.get("if"), _ep()):
				_enter(String(b.next))
				return
		end_active("END")
		return
	if node.has("chips"):
		_show_chips()
		return
	if node.has("wait") or node.has("await"):
		waiting_lines = true   # let pending lines finish first
		return
	_enter(String(node.get("next", "")))


func _tick_exchange(delta: float) -> void:
	node_t += delta
	# leave check (hero walked away)
	var npc := String(active.get("npc", ""))
	var rl := float(active.get("radius_leave", 6.0))
	if npc != "" and Presence.pos.has("hero") and Presence.pos.has(npc):
		if Presence.distance("hero", npc) > rl:
			leave_t += delta
			if leave_t >= LEAVE_GRACE:
				leave_t = 0.0
				_on_leave()
				return
		else:
			leave_t = 0.0
	if not awaiting_reaction.is_empty():
		if busy():
			return
		var chip := awaiting_reaction
		awaiting_reaction = {}
		_resolve_chip(chip)
		return
	if node.has("chips"):
		if not chips_visible.is_empty() and chips_deadline > 0.0 and exchange_t >= chips_deadline:
			_bus().player_decision.emit("silence")
			var sil := String(node.get("silence", ""))
			_hide_chips()
			_enter(sil)
		elif chips_visible.is_empty() and awaiting_reaction.is_empty() and not busy():
			_show_chips()
		return
	if waiting_lines:
		if busy():
			node_t = 0.0
			return
		if node.has("wait"):
			if node_t >= float(node.wait):
				_enter(String(node.get("next", "")))
			return
		if node.has("await"):
			if _await_ok(node.await):
				_enter(String(node.get("next", "")))
			elif node.has("timeout") and node_t >= float(node.timeout):
				_enter(String(node.get("on_timeout", node.get("next", ""))))
			return
		waiting_lines = false
		if node.get("hold", false):
			_bus().npc_command.emit(npc, "hold", {"on": false})
		_enter(String(node.get("next", "")))


func _await_ok(a: Variant) -> bool:
	if typeof(a) == TYPE_DICTIONARY and a.has("hero_near"):
		var hn: Array = a.hero_near
		var p: Vector3 = _data().marker(String(hn[0]))
		var r := float(hn[1]) if hn.size() > 1 else 2.0
		if not Presence.pos.has("hero"):
			return true
		return Presence.in_zone("hero") == _data().marker_zone(String(hn[0])) and (Presence.pos.hero as Vector3).distance_to(p) <= r
	if typeof(a) == TYPE_DICTIONARY and a.has("hero_zone"):
		if not Presence.zone.has("hero"):
			return true
		var zs: Variant = a.hero_zone
		return (zs is Array and zs.has(Presence.in_zone("hero"))) or Presence.in_zone("hero") == String(zs)
	return Conditions.check(a, _ep())


func _on_leave() -> void:
	_bus().player_decision.emit("leave")
	var target := String(node.get("leave", active.get("leave", "")))
	_hide_chips()
	awaiting_reaction = {}
	clear_lines()
	if target == "":
		end_active("LEAVE")
	else:
		_enter(target)


# ================================================================== chips

func available_chips(n: Dictionary = node) -> Array:
	var out: Array = []
	for c in n.get("chips", []):
		if c.get("repeat_lock", false) and _ep().seen_exchanges.has("chip:" + String(c.id)):
			continue
		if not Conditions.check(c.get("requires"), _ep()):
			continue
		out.append(c)
		if out.size() >= 4:
			break
	return out


func _show_chips() -> void:
	if busy():
		return   # chips appear after the current lines (tick retries)
	chips_visible = available_chips()
	if chips_visible.is_empty():
		_enter(String(node.get("silence", "")))
		return
	var t := float(node.get("timeout", 6.0))
	chips_deadline = exchange_t + t if t > 0.0 else 0.0
	var view: Array = []
	for c in chips_visible:
		view.append({"id": c.id, "verb": c.get("verb", ""), "label": c.get("label", "")})
	_bus().chips_shown.emit(active_id, view, t)


func _hide_chips() -> void:
	if not chips_visible.is_empty():
		chips_visible = []
		_bus().chips_cleared.emit()


## Choose a visible chip (0-based). Returns false if nothing to choose.
func choose(index: int) -> bool:
	if index < 0 or index >= chips_visible.size():
		return false
	var chip: Dictionary = chips_visible[index]
	_hide_chips()
	_bus().player_decision.emit("chip")
	if chip.get("repeat_lock", false):
		_ep().seen_exchanges["chip:" + String(chip.id)] = true
	var npc := _chip_addressee(chip)
	if chip.has("actions"):
		ActionRunner.run(chip.actions, {"npc": npc, "source": String(chip.id), "exchange": active_id})
		if active_id == "":
			return true
	var hero_key := String(chip.get("line", ""))
	if hero_key == "" and chip.has("claim"):
		hero_key = String(_data().claims.get(chip.claim, {}).get("line", ""))
	if hero_key != "":
		queue_line(hero_key, {"npc": "hero"})
	var c2 := chip.duplicate()
	c2["_addressee"] = npc
	awaiting_reaction = c2
	return true


func choose_id(chip_id: String) -> bool:
	for i in chips_visible.size():
		if chips_visible[i].id == chip_id:
			return choose(i)
	return false


func _chip_addressee(chip: Dictionary) -> String:
	var a := String(chip.get("addressee", active.get("npc", "")))
	if a == "@addressed" and addressee_provider.is_valid():
		return String(addressee_provider.call())
	return a


func _resolve_chip(chip: Dictionary) -> void:
	var next := String(chip.get("next", ""))
	if chip.has("claim"):
		var npc := String(chip._addressee)
		var res := SocialResolver.speak_claim(String(chip.claim), npc)
		var by: Dictionary = chip.get("next_by_reaction", {})
		if res.trap != "" and by.has("TRAP:" + res.trap):
			next = String(by["TRAP:" + res.trap])
		elif by.has(res.reaction):
			next = String(by[res.reaction])
		elif by.has("*"):
			next = String(by["*"])
	elif chip.has("next_if"):
		for b in chip.next_if:
			if b.get("else", false) or Conditions.check(b.get("if"), _ep()):
				next = String(b.next)
				break
	if active_id != "":
		_enter(next)


# ================================================================== triggers

var _pending_beat: Array = []   # beat-triggered exchanges waiting for the active one to end


func _on_beat(b: String) -> void:
	for xid in _data().exchanges:
		var x: Dictionary = _data().exchanges[xid]
		var trg: Dictionary = x.get("trigger", {})
		if trg.get("type", "") == "beat" and String(trg.get("beat", "")) == b and can_start(xid):
			if active_id == "":
				start(xid)
			elif int(x.get("priority", 0)) > int(active.get("priority", 0)):
				start(xid, true)
			elif not _pending_beat.has(xid):
				_pending_beat.append(xid)
			return


func _poll_triggers() -> void:
	var best := ""
	var best_pri := -999
	for xid in _data().exchanges:
		var x: Dictionary = _data().exchanges[xid]
		var trg: Dictionary = x.get("trigger", {})
		var ty := String(trg.get("type", "manual"))
		if ty in ["manual", "talk", "beat"]:
			continue
		if x.has("scene") and String(x.scene) != _ep().scene_id:
			continue
		var npc := String(x.get("npc", ""))
		var ok := false
		match ty:
			"npc_enters_radius":
				if Presence.is_present(npc) and Presence.pos.has("hero"):
					ok = Presence.distance("hero", npc) <= float(trg.get("radius", 3.0))
			"zone":
				ok = Presence.in_zone("hero") == String(trg.get("zone", ""))
			"hero_near":
				var m := String(trg.get("marker", ""))
				if Presence.pos.has("hero") and _data().has_marker(m):
					ok = Presence.in_zone("hero") == _data().marker_zone(m) \
						and (Presence.pos.hero as Vector3).distance_to(_data().marker(m)) <= float(trg.get("radius", 3.0))
			"cond":
				ok = true
		if ok and Conditions.check(trg.get("cond"), _ep()) and can_start(xid):
			var pri := int(x.get("priority", 0))
			if pri > best_pri:
				best = xid
				best_pri = pri
	if best != "":
		start(best)


## Hero pressed E on an NPC: open the best available talk exchange. Returns true if one started.
func talk_to(npc: String) -> bool:
	if active_id != "":
		if String(active.get("npc", "")) == npc:
			return false
		# talking to someone else replaces a low-priority exchange
		if int(active.get("priority", 0)) > 0:
			return false
		end_active("SWITCH")
	var best := ""
	var best_pri := -999
	for xid in _data().exchanges:
		var x: Dictionary = _data().exchanges[xid]
		if String(x.get("npc", "")) != npc:
			continue
		if String(x.get("trigger", {}).get("type", "")) != "talk":
			continue
		if x.has("scene") and String(x.scene) != _ep().scene_id:
			continue
		if not Conditions.check(x.get("trigger", {}).get("cond"), _ep()):
			continue
		if can_start(xid) and int(x.get("priority", 0)) > best_pri:
			best = xid
			best_pri = int(x.get("priority", 0))
	if best == "":
		return false
	return start(best)


func has_talk(npc: String) -> bool:
	for xid in _data().exchanges:
		var x: Dictionary = _data().exchanges[xid]
		if String(x.get("npc", "")) == npc and String(x.get("trigger", {}).get("type", "")) == "talk" \
				and (not x.has("scene") or String(x.scene) == _ep().scene_id) \
				and Conditions.check(x.get("trigger", {}).get("cond"), _ep()) and can_start(xid):
			return true
	return false
