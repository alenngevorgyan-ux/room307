class_name ActionRunner
extends RefCounted
## One shared action vocabulary for exchanges, traps, interactables, overhears and scenes.
## An action is a one-key dictionary: {"give_fact": "F_X"}, {"stress": ["lina", 1]} ...
## {"if": cond, "then": [...], "else": [...]} branches; {"delay": 2.0, "do": [...]} defers
## (deferred actions advance via ActionRunner.tick(), called by the ConversationDirector or sims).

const VERBS := ["line", "lines", "ambient", "bark", "give_fact", "notice", "offer_thread", "pin_thread", "strike_thread",
	"flag", "unflag", "trust", "respect", "suspicion", "stress", "warmth", "fear_hit", "set_disposition",
	"set_var", "believes", "knows", "remember", "caught_lying", "set_schedule", "give_item", "take_item",
	"lead", "beat", "start_exchange", "end_exchange", "play_cine", "camera_hint", "music", "sfx",
	"teleport_npc", "spawn", "despawn", "npc", "goto_scene", "phase", "hint", "phone_msg", "s1",
	"set", "add", "decision", "trap_bait", "tell", "ending", "finale_pressure", "noise", "fade",
	"if", "delay", "log", "alert", "heat", "hero"]

static var _pending: Array = []   # [{t, actions, ctx}]
static var log_enabled := false


static func ep() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Episode")


static func bus() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Bus")


static func data() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Data")


static func reset() -> void:
	_pending.clear()


static func tick(delta: float) -> void:
	if _pending.is_empty():
		return
	var due: Array = []
	for p in _pending:
		p.t -= delta
		if p.t <= 0.0:
			due.append(p)
	for p in due:
		_pending.erase(p)
		run(p.actions, p.ctx)


static func pending_count() -> int:
	return _pending.size()


static func run(actions: Variant, ctx: Dictionary = {}) -> void:
	if actions == null:
		return
	if typeof(actions) == TYPE_DICTIONARY:
		actions = [actions]
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			push_warning("ActionRunner: bad action %s" % [a])
			continue
		run_one(a, ctx)


static func run_one(a: Dictionary, ctx: Dictionary) -> void:
	if a.has("if"):
		if Conditions.check(a["if"], ep()):
			run(a.get("then", []), ctx)
		else:
			run(a.get("else", []), ctx)
		return
	if a.has("delay"):
		_pending.append({"t": float(a.delay), "actions": a.get("do", []), "ctx": ctx})
		return
	for verb in a:
		_exec(String(verb), a[verb], ctx)


static func _npc_n(v: Variant) -> Array:
	# ["npc", n] -> [CharacterState, int]
	var c: CharacterState = ep().ch(String(v[0]))
	return [c, int(v[1]) if v.size() > 1 else 1]


static func _exec(verb: String, v: Variant, ctx: Dictionary) -> void:
	var E := ep()
	var B := bus()
	if log_enabled:
		print("  [action] ", verb, " ", v)
	match verb:
		"line", "lines", "ambient":
			var keys: Array = v if typeof(v) == TYPE_ARRAY else [v]
			var c2 := ctx.duplicate()
			if verb == "ambient":
				c2["world"] = true
			for k in keys:
				if Services.conversation:
					Services.conversation.queue_line(String(k), c2)
				else:
					B.line_requested.emit(String(k), c2)
		"bark":
			if typeof(v) == TYPE_ARRAY:
				B.bark_requested.emit(String(v[0]), String(v[1]))
			else:
				var l: Dictionary = data().line(String(v))
				B.bark_requested.emit(String(l.get("speaker", "")), String(l.get("text", "")))
		"give_fact":
			if typeof(v) == TYPE_ARRAY:
				E.give_fact(String(v[0]), String(v[1]))
			else:
				E.give_fact(String(v), String(ctx.get("source", "")))
		"notice":
			E.notice(String(v))
		"offer_thread":
			E.offer_thread(String(v))
		"pin_thread":
			E.offer_thread(String(v))
			E.pin_thread(String(v))
		"strike_thread":
			E.strike_thread(String(v))
		"flag":
			if typeof(v) == TYPE_ARRAY:
				E.set_flag(String(v[0]), v[1])
			else:
				E.set_flag(String(v), true)
		"unflag":
			E.clear_flag(String(v))
		"trust", "warmth":
			var r := _npc_n(v)
			if r[0]: r[0].add_trust(r[1])
		"respect":
			var r := _npc_n(v)
			if r[0]: r[0].add_respect(r[1])
		"suspicion":
			var r := _npc_n(v)
			if r[0]: r[0].add_suspicion(r[1])
		"stress":
			var r := _npc_n(v)
			if r[0]: r[0].add_stress(r[1])
		"fear_hit":
			var c: CharacterState = E.ch(String(v[0]))
			if c: c.fear_hit(String(v[1]), int(v[2]) if v.size() > 2 else 1)
		"set_disposition":
			var c: CharacterState = E.ch(String(v[0]))
			if c: c.disposition = CharacterState.disposition_from_name(String(v[1]))
		"set_var":
			var c: CharacterState = E.ch(String(v[0]))
			if c: c.vars[String(v[1])] = v[2]
		"believes":
			var c: CharacterState = E.ch(String(v[0]))
			if c and not c.believes_hero_knows.has(String(v[1])):
				c.believes_hero_knows.append(String(v[1]))
		"knows":
			var c: CharacterState = E.ch(String(v[0]))
			if c and not c.knows.has(String(v[1])):
				c.knows.append(String(v[1]))
		"remember":
			var c: CharacterState = E.ch(String(v[0]))
			if c: c.remember(String(v[1]))
		"caught_lying":
			var c: CharacterState = E.ch(String(v))
			if c: c.caught_lying = true
		"set_schedule":
			var c: CharacterState = E.ch(String(v[0]))
			if c: c.schedule = String(v[1])
			B.npc_command.emit(String(v[0]), "schedule", {"id": String(v[1])})
		"give_item":
			if typeof(v) == TYPE_ARRAY:
				E.give_item(String(v[0]), String(v[1]))
			else:
				E.give_item(String(v), "hero")
		"take_item":
			if typeof(v) == TYPE_ARRAY:
				E.give_item(String(v[0]), String(v[1]))
			else:
				E.take_item(String(v))
		"lead":
			E.set_lead(String(v[0]), E.lead_from_name(String(v[1])))
		"beat":
			E.beat(String(v))
		"start_exchange":
			if Services.conversation:
				Services.conversation.start(String(v), true)
		"end_exchange":
			if Services.conversation:
				Services.conversation.end_active(String(v) if v != null else "END")
		"play_cine":
			B.cine_requested.emit(String(v))
		"camera_hint":
			B.camera_hint.emit(v if typeof(v) == TYPE_DICTIONARY else {"target": v})
		"music":
			B.music_requested.emit(String(v))
		"sfx":
			B.sfx_requested.emit(String(v), ctx.get("pos"))
		"teleport_npc":
			if data().has_marker(String(v[1])):
				Presence.place(String(v[0]), data().marker_zone(String(v[1])), data().marker(String(v[1])))
			B.npc_command.emit(String(v[0]), "teleport", {"marker": String(v[1])})
		"spawn":
			Presence.present[String(v[0])] = true
			if v.size() > 1 and data().has_marker(String(v[1])):
				Presence.place(String(v[0]), data().marker_zone(String(v[1])), data().marker(String(v[1])))
			# optional 3rd element "cut": the camera cuts here (scene start) — place instantly
			B.npc_command.emit(String(v[0]), "spawn", {"marker": String(v[1]) if v.size() > 1 else "",
				"cut": v.size() > 2 and String(v[2]) == "cut"})
		"despawn":
			Presence.remove(String(v))
			B.npc_command.emit(String(v), "despawn", {})
		"npc":
			B.npc_command.emit(String(v[0]), String(v[1]), v[2] if v.size() > 2 else {})
		"goto_scene":
			if Services.scenes:
				Services.scenes.goto_scene(String(v))
			else:
				B.scene_requested.emit(String(v))
		"phase":
			E.set_phase_name(String(v))
		"hint":
			if typeof(v) == TYPE_ARRAY:
				B.hint_requested.emit(String(v[0]), float(v[1]))
			else:
				B.hint_requested.emit(String(v), 3.0)
		"phone_msg":
			E.phone_log.append({"from": String(v[0]), "text": String(v[1]), "t": E.clock_sec})
			B.phone_message.emit(String(v[0]), String(v[1]))
		"s1":
			E.s1_resolution = String(v)
		"set":
			E.set_path_value(String(v[0]), v[1])
		"add":
			var cur: Variant = E.get_path_value(String(v[0]))
			E.set_path_value(String(v[0]), int(cur if cur != null else 0) + int(v[1]))
		"decision":
			B.player_decision.emit(String(v))
		"trap_bait":
			var d: Dictionary = v[1] if typeof(v) == TYPE_ARRAY and v.size() > 1 else {}
			B.trap_bait.emit(String(v[0]) if typeof(v) == TYPE_ARRAY else String(v), d)
		"tell":
			B.tell_opened.emit(String(v[0]), float(v[1]) if v.size() > 1 else 1.6)
		"ending":
			E.ending.id = String(v)
			B.ending_reached.emit(String(v))
		"finale_pressure":
			E.finale.daniel_pressure += int(v)
		"noise":
			B.noise.emit(data().marker(String(v[0])), float(v[1]), "action")
		"fade":
			B.fade_requested.emit(float(v))
		"log":
			print("[log] ", v)
		"alert":
			E.threat.alert[String(v[0])] = int(ThreatState.Alert.keys().find(String(v[1])))
		"heat":
			E.threat.heat = clampi(E.threat.heat + int(v), 0, 3)
		"hero":
			B.npc_command.emit("hero", String(v[0]), v[1] if v.size() > 1 else {})
		_:
			push_warning("ActionRunner: unknown verb '%s'" % verb)


## Collects (verb, value) pairs from an action list, recursing into if/delay (validator use).
static func flatten(actions: Variant, out: Array) -> void:
	if actions == null:
		return
	if typeof(actions) == TYPE_DICTIONARY:
		actions = [actions]
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if a.has("if"):
			flatten(a.get("then", []), out)
			flatten(a.get("else", []), out)
			continue
		if a.has("delay"):
			flatten(a.get("do", []), out)
			continue
		for k in a:
			out.append([String(k), a[k]])
