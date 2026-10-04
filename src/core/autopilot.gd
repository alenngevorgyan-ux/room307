class_name Autopilot
extends Node
## In-engine integration run (debug): plays the episode in the real 3D world — NPC bodies, navmesh,
## physics, doors, CINEs, chase — with scripted "player" decisions, and reports every step.
## Start:  godot --headless --path . --fixed-fps 60 -- --autopilot=A_MARA   (or B_THOMAS, C_DESTROY, D_ADRIAN)
## Exits with code 0 when the epilogue reaches DONE, 1 on a timeout (the failing step is printed).

var ending := "A_MARA"
var t := 0.0
var failed := false


func _ep() -> Node:
	return get_node("/root/Episode")


func _bus() -> Node:
	return get_node("/root/Bus")


func log_step(s: String) -> void:
	print("[autopilot %6.1fs] %s" % [t, s])


func _process(delta: float) -> void:
	t += delta


func wait_s(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func wait_for(cond: Callable, max_sec: float, what: String) -> bool:
	var start := t
	while not cond.call():
		if t - start > max_sec:
			log_step("TIMEOUT waiting for: %s (scene %s phase %s x %s)" % [what, _ep().scene_id, _ep().phase_name(),
				Services.conversation.active_id if Services.conversation else ""])
			failed = true
			return false
		await get_tree().process_frame
	return true


func hero_to(marker: String) -> void:
	Services.world.place_hero(marker, false)
	await get_tree().physics_frame
	await get_tree().physics_frame


func choose(chip: String, max_sec: float = 20.0) -> bool:
	var conv: ConversationDirector = Services.conversation
	if not await wait_for(func(): return conv.chips_visible.any(func(c): return c.id == chip), max_sec, "chip " + chip):
		return false
	conv.choose_id(chip)
	log_step("chip " + chip)
	return true


## Stay ~2 m behind an NPC (same zone) until cond is true.
func follow_until(npc: String, cond: Callable, max_sec: float, what: String) -> bool:
	var start := t
	while not cond.call():
		if t - start > max_sec:
			log_step("TIMEOUT following %s: %s" % [npc, what])
			failed = true
			return false
		var n: NPC = Services.world.npc(npc)
		if n and n.spawned:
			Services.hero.teleport_to(n.global_position - n.facing_dir() * 1.8, n.current_zone)
		await wait_s(0.4)
	return true


func stage(cmd: Dictionary) -> void:
	_bus().trap_bait.emit("stage", cmd)


## Playtest finding 5: any NPC appearing / vanishing / jumping on camera fails the run.
func _on_pop(npc: String, kind: String, info: Dictionary) -> void:
	log_step("NPC POP %s %s (zone %s) at %s" % [npc, kind, info.get("zone", ""), " < ".join(info.get("where", []))])
	failed = true


func run() -> void:
	_bus().npc_popped.connect(_on_pop)
	log_step("start, ending %s" % ending)
	var E := _ep()
	var conv: ConversationDirector = Services.conversation
	# S01 — the camera bluff with Selin present -> PUBLIC_EXPOSE
	await wait_s(2.0)
	await hero_to("BAR:hale_c")
	await wait_s(0.5)
	conv.talk_to("hale")
	if not await choose("CH_HALE_CAMERAS"): return
	if not await wait_for(func(): return E.scene_id == "S02", 60.0, "S01 → S02"): return
	log_step("S01 resolution %s" % E.s1_resolution)
	# S02 — follow Adrian (hero stays close behind him), elevator silence
	if ending == "D_ADRIAN":
		E.notice("O_S2_FLAT_ON_DANGER")
	if not await wait_for(func(): return conv.active_id == "X_S02_A", 20.0, "brief"): return
	var follow_t := 0.0
	while E.scene_id == "S02" and not E.flags.get("s2_riding", false):
		await wait_s(0.5)
		follow_t += 0.5
		if follow_t > 120.0:
			log_step("TIMEOUT following Adrian")
			failed = true
			return
		var a: NPC = Services.world.npc("adrian")
		if a == null or not a.spawned:
			continue
		if ending == "D_ADRIAN" and conv.active_id == "X_S02_B" and conv.chips_visible.any(func(c): return c.id == "CH_S2_NOT_EX"):
			conv.choose_id("CH_S2_NOT_EX")
			log_step("chip CH_S2_NOT_EX")
		if a.current_zone == "LOBBY" and a.global_position.distance_to(get_node("/root/Data").marker("LOBBY:adrian_elev")) < 1.2:
			await hero_to("ELEV_A:hero")
			break
		# stay ~2 m behind him, same zone
		var p: Vector3 = a.global_position - a.facing_dir() * 2.0
		Services.hero.teleport_to(p, a.current_zone)
	if not await wait_for(func(): return E.has_item("ITEM_KEYCARD_307"), 60.0, "keycard on 3"): return
	await hero_to("HALL_3F:arrive_elev")
	if not await wait_for(func(): return E.scene_id == "S03", 5.0, "S03"): return
	# S03 — look at the room a bit, then leave: Daniel
	await hero_to("ROOM_307:enter")
	for id in ["I_307_BAG", "I_307_GLASSES", "I_307_SHOE_A"]:
		var it := Services.world.get_node_or_null("I_" + id) as Interactable
		if it:
			it.use()
	await wait_s(1.0)
	await hero_to("HALL_3F:door_307")
	if not await wait_for(func(): return conv.active_id == "X_S03_DANIEL" or E.scene_id == "S04", 60.0, "Daniel encounter"): return
	if not await wait_for(func(): return E.scene_id == "S04", 90.0, "hub opens"): return
	log_step("hub")
	# S04 — Lead B (Eva 615), Lead A (Nico), location from Nico's Volvo line
	await hero_to("ROOF_SMOKING:behind_hvac")
	if not await choose("CH_EVA_615", 25.0): return
	if not await follow_until("eva", func(): return E.lead_done("B"), 30.0, "Lead B"): return
	await hero_to("BAR:nico_tables")
	E.ch("nico").trust = 1
	if not await follow_until("nico", func(): return E.seen_exchanges.has("X_S04_NICO_GREET") and conv.active_id == "", 40.0, "Nico greeting"): return
	conv.talk_to("nico")
	if not await choose("CH_NICO_WHO"): return
	if not await follow_until("nico", func(): return conv.active_id == "", 25.0, "Nico done"): return
	conv.talk_to("nico")
	await choose("CH_NICO_VOLVO", 10.0)
	await follow_until("nico", func(): return E.has_fact("F_THOMAS_LOCATION"), 20.0, "Volvo line")
	if not await wait_for(func(): return E.flags.get("thomas_ready", false), 120.0, "S06 enabled"): return
	await hero_to("LAUNDRY:door_dock")
	await hero_to("LOADING_DOCK:enter")
	if not await wait_for(func(): return E.scene_id == "S06", 5.0, "S06"): return
	# S06 — stop him with «Мара.», then silence
	if not await wait_for(func(): return conv.active_id == "X_S06_STOP" or conv.active_id == "X_S06_TALK", 60.0, "Thomas stop window"): return
	if conv.active_id == "X_S06_STOP":
		await choose("CH_TH_MARA", 15.0)
	if not await wait_for(func(): return E.scene_id == "S07", 240.0, "chase starts"): return
	log_step("chase")
	# S07 — run the kitchen route by doors (teleport hops), then to the banquet corridor
	for m in ["LAUNDRY:enter", "SCORR:mid", "SERVICE_STAIR:l2", "BCORR:mid"]:
		await hero_to(m)
		await wait_s(1.5)
	if not await wait_for(func(): return E.scene_id == "S08", 60.0, "Mara pull → S08"): return
	# S08 — honest, watch the clip, story, Thomas, the ask
	if not await choose("CH_MARA_HIRED", 20.0): return
	if not await wait_for(func(): return E.flags.get("mara_lowered", false), 30.0, "Mara lowers"): return
	E.set_flag("clip_playing")
	if not await wait_for(func(): return conv.active_id == "X_S08_ASK", 200.0, "the ask"): return
	if not await choose("CH_MARA_HOUR"): return
	if not await wait_for(func(): return E.flags.get("plan_finale", false), 30.0, "plan"): return
	await hero_to("RESTAURANT:kitchen_arrive")
	if not await wait_for(func(): return E.scene_id == "S09", 5.0, "S09"): return
	# S09 — staging, invites, start
	for s in ["S1", "S2", "S3", "S4"]:
		stage({"cmd": "take_card"})
		stage({"cmd": "seat", "arg": s})
	stage({"cmd": "recorder", "arg": "vase"})
	stage({"cmd": "door", "arg": "kitchen", "v": "closed"})
	for inv in [["adrian", "alone"], ["mara", "time"], ["daniel", "vale_wants"], ["thomas", "time"]]:
		stage({"cmd": "invite", "to": inv[0], "template": inv[1]})
	stage({"cmd": "start"})
	await hero_to("RESTAURANT:S4")
	var fin: Node = Services.scenes.logic
	if not await wait_for(func(): return fin.live_started, 90.0, "everyone seated"): return
	if ending == "D_ADRIAN":
		fin.addressed = "adrian"
		await choose("CH_FIN_LOOK", 20.0)
		await wait_for(func(): return E.flags.get("look_said", false), 20.0, "look")
	fin.addressed = "adrian"
	if not await choose("CH_FIN_MAIN", 25.0): return
	if not await wait_for(func(): return E.finale.exposed, 25.0, "exposed"): return
	log_step("Daniel exposed")
	await hero_to("RESTAURANT:kitchen_door")   # block the exit he glanced at
	if not await wait_for(func(): return E.finale.daniel_state in ["confessed", "escaped"], 60.0, "Daniel resolved"): return
	log_step("Daniel %s" % E.finale.daniel_state)
	if not await wait_for(func(): return E.phase_name() == "S09_DECISION", 40.0, "decision"): return
	stage({"cmd": "card", "arg": "pocket"})
	stage({"cmd": "ending", "arg": ending})
	log_step("ending %s" % E.ending.id)
	if not await wait_for(func(): return E.scene_id == "EPI", 20.0, "epilogue"): return
	if not await wait_for(func(): return E.phase_name() == "DONE", 60.0, "cut to black"): return
	log_step("DONE — %s, Daniel %s, recorded %s, decisions %d, control %.0f%%" % [E.ending.id, E.finale.daniel_state,
		E.ending.recorded, get_node("/root/Debug").telemetry.decisions.size(), get_node("/root/Debug").telemetry.control_ratio() * 100.0])
