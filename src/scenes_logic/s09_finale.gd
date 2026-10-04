extends SceneLogic
## S09 finale glue. Phase A staging (place cards, recorder, card, doors, lights, photo, invites,
## start gate), phase B live (arrivals, positional addressing ring, exposure, Daniel's tells window,
## pressure / flee / confess model, thugs), phase C physical decision → endings → epilogue.
## Content (lines, chips, traps) is data; this file is the state machine that data can't express.

const NAMES := ["adrian", "mara", "daniel", "thomas"]
const ARRIVAL_SPACING := 12.0
const FLEE_CHECK := 4.0
const BLOCK_R := 1.2
const ARRIVE_FROM := {"adrian": "RESTAURANT:arrive", "daniel": "RESTAURANT:arrive", "mara": "RESTAURANT:kitchen_arrive", "thomas": "RESTAURANT:kitchen_arrive"}

var carrying := ""
var thomas_warned := false
var arrivals: Array = []          # [{npc, t}]
var arrived: Dictionary = {}
var seated: Dictionary = {}
var live_t := 0.0
var live_started := false
var addressed := ""
var ring: MeshInstance3D
var exposed_t := -1.0
var flee_t := 0.0
var exit_choice := ""
var _decision_lines_t := -1.0
var _ending_t := -1.0
var _tells_opened := false
var _thugs_t := -1.0
var _labels: Dictionary = {}    # stage point -> Label3D (place cards, recorder, card)
var _flight_t := 0.0


func enter() -> void:
	bus().trap_bait.connect(_on_stage)
	bus().world_beat.connect(_on_beat)
	if Services.conversation:
		Services.conversation.addressee_provider = func(): return addressed
	_apply_kitchen_noise()
	if Services.world:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		ring.mesh = tm
		ring.material_override = Graybox.mat(Color(1.0, 0.85, 0.5, 0.8), 0.8, true)
		ring.visible = false
		Services.world.add_child(ring)
	var E := ep()
	if E.holder_of("ITEM_SD_CARD") == "hero":
		E.finale.card_spot = "pocket"
	_update_lights()


func exit() -> void:
	if ring:
		ring.queue_free()
	for l in _labels.values():
		if is_instance_valid(l):
			l.queue_free()
	Presence.hearing_mult.erase("RESTAURANT")
	if Services.conversation:
		Services.conversation.addressee_provider = Callable()


# ================================================================== staging

func _on_stage(ev: String, d: Dictionary) -> void:
	if ev != "stage":
		return
	var E := ep()
	var F: FinaleState = E.finale
	match String(d.get("cmd", "")):
		"take_card":
			for n in NAMES:
				if not _placed(n) and n != carrying:
					carrying = n
					E.set_flag("carrying_card")
					bus().hint_requested.emit("Карточка: %s" % data().npc_display(n), 2.0)
					if Services.hero:
						Services.hero.carry("card")
					return
		"seat":
			var s := String(d.arg)
			if carrying == "":
				return
			var prev := String(F.seats.get(s, ""))
			F.seats[s] = carrying
			E.set_flag("seat_%s_filled" % s)
			if carrying == "adrian":
				E.set_flag("adrian_seat_known")
			bus().stage_point_changed.emit("seat_" + s, carrying)
			carrying = prev
			_after_card_move()
		"unseat":
			var s := String(d.arg)
			if carrying != "":
				return
			carrying = String(F.seats.get(s, ""))
			F.seats[s] = ""
			E.clear_flag("seat_%s_filled" % s)
			if carrying == "adrian":
				E.clear_flag("adrian_seat_known")
			_after_card_move()
		"stand":
			if carrying != "":
				F.standing.append(carrying)
				bus().stage_point_changed.emit("standing", carrying)
				carrying = ""
				_after_card_move()
		"recorder":
			F.recorder = String(d.arg)
			bus().stage_point_changed.emit("recorder", F.recorder)
			bus().sfx_requested.emit("click", null)
		"card":
			F.card_spot = String(d.arg)
			var holder := "hero" if F.card_spot == "pocket" else "world:" + F.card_spot
			E.give_item("ITEM_SD_CARD", holder)
			bus().stage_point_changed.emit("card", F.card_spot)
			if E.phase_name() == "S09_DECISION" and F.card_spot == "pocket":
				bus().music_requested.emit("SILENCE")
		"door":
			var which := String(d.arg)
			var v := String(d.v)
			if which == "terrace":
				E.set_flag("terrace_unlocked", v == "unlocked")
				if v != "unlocked":
					E.clear_flag("terrace_unlocked")
			F.doors[which] = v
			if which == "main":
				if v == "locked":
					E.set_flag("main_locked")
				else:
					E.clear_flag("main_locked")
			bus().stage_point_changed.emit("door_" + which, v)
			bus().sfx_requested.emit("door_door", null)
			_apply_kitchen_noise()
		"lights":
			F.lights = String(d.arg)
			bus().stage_point_changed.emit("lights", F.lights)
			_update_lights()
		"photo":
			F.photo_at_adrian = true
			bus().stage_point_changed.emit("photo", "adrian")
		"invite":
			var to := String(d.to)
			if not F.invited(to):
				F.invites.append({"to": to, "template": String(d.template), "t": E.clock_sec})
				bus().stage_point_changed.emit("invite_" + to, String(d.template))
				bus().hint_requested.emit("Отправлено: %s" % data().npc_display(to), 2.0)
		"start":
			try_start()
		"mara_closer":
			_seat_npc("mara", "RESTAURANT:seat_S3" if F.seat_of("mara") != "S3" else "RESTAURANT:seat_S1", true)
		"stop_daniel":
			if F.daniel_state == "fleeing":
				_daniel_stopped(String(d.get("arg", "")))
		"ending":
			do_ending(String(d.arg))
	bus().player_decision.emit("stage")
	_refresh_labels()


## Small in-world tags so the staging reads at a glance (place cards, recorder, card).
func _refresh_labels() -> void:
	if Services.world == null:
		return
	var F: FinaleState = ep().finale
	var want: Dictionary = {}
	for s in F.seats:
		if String(F.seats[s]) != "":
			want["seat_" + s] = [data().marker("RESTAURANT:" + s) + Vector3(0, 0.82, 0), data().npc_display(String(F.seats[s]))]
	var i := 0
	for n in F.standing:
		want["stand_%d" % i] = [data().marker("RESTAURANT:stand_window") + Vector3(i * 0.4, 1.0, 0), data().npc_display(String(n)) + " (стоя)"]
		i += 1
	if F.recorder != "none":
		var m := {"vase": "RESTAURANT:vase", "basket": "RESTAURANT:basket", "shelf": "RESTAURANT:shelf"}
		want["rec"] = [data().marker(m[F.recorder]) + Vector3(0, 0.35, 0), "● REC"]
	for k in _labels.keys():
		if not want.has(k):
			_labels[k].queue_free()
			_labels.erase(k)
	for k in want:
		if not _labels.has(k):
			var l := Graybox.label3d("", 26, Color(1, 0.95, 0.85))
			l.fixed_size = true
			l.pixel_size = 0.0007
			Services.world.add_child(l)
			_labels[k] = l
		_labels[k].text = want[k][1]
		_labels[k].global_position = want[k][0]
		_labels[k].visible = ep().phase_name() == "S09_STAGING" or k == "rec"


func _placed(n: String) -> bool:
	var F: FinaleState = ep().finale
	return F.seat_of(n) != "" or F.standing.has(n)


func _after_card_move() -> void:
	var E := ep()
	if carrying == "":
		E.clear_flag("carrying_card")
		if Services.hero:
			Services.hero.carry("")
	var all := true
	for n in NAMES:
		if not _placed(n):
			all = false
	if all:
		E.set_flag("all_cards_placed")
	else:
		E.clear_flag("all_cards_placed")


func _apply_kitchen_noise() -> void:
	if String(ep().finale.doors.get("kitchen", "open")) == "open":
		Presence.hearing_mult["RESTAURANT"] = 0.55
	else:
		Presence.hearing_mult.erase("RESTAURANT")


func _update_lights() -> void:
	if Services.world == null:
		return
	var z: Zone = Services.world.zone_node("RESTAURANT")
	if z == null:
		return
	var full: bool = ep().finale.lights == "full"
	for l in z.lights_root.get_children():
		(l as OmniLight3D).light_energy = 1.8 if full else 0.7


## AT-GRAPH-07: Adrian, Mara and Daniel must be invited. Returns true if the meeting started.
func try_start() -> bool:
	var E := ep()
	var F: FinaleState = E.finale
	if not F.invited("mara"):
		bus().hint_requested.emit("Мара ждёт сообщения. [Tab]", 3.0)
		return false
	if not F.invited("daniel"):
		run([{"line": "MARA_NO_DANIEL"}])
		return false
	if not F.invited("adrian"):
		run([{"line": "MARA_NO_ADRIAN"}])
		return false
	if not F.invited("thomas") and not thomas_warned:
		thomas_warned = true
		run([{"line": "NO_THOMAS"}])
		return false
	F.started = true
	E.set_phase_name("S09_LIVE")
	_refresh_labels()
	if carrying != "":
		F.standing.append(carrying)
		carrying = ""
		_after_card_move()
	var t := 1.0
	for inv in F.invites:
		arrivals.append({"npc": String(inv.to), "t": t, "template": String(inv.template)})
		t += ARRIVAL_SPACING
	E.set_flag("thomas_present", F.invited("thomas"))
	E.ending.thomas_present = F.invited("thomas")
	bus().music_requested.emit("FINALE_LIVE")
	bus().player_decision.emit("start_meeting")
	return true


# ================================================================== live

func _seat_marker(npc: String) -> String:
	var s: String = ep().finale.seat_of(npc)
	return "RESTAURANT:seat_" + s if s != "" else "RESTAURANT:stand_window"


func _seat_npc(npc: String, marker: String, walk: bool) -> void:
	if walk and Services.world:
		run([{"npc": [npc, "walk_to", {"marker": marker}]}])
	else:
		run([{"teleport_npc": [npc, marker]}])
	if Services.world == null:
		Presence.place(npc, "RESTAURANT", data().marker(marker))
	run([{"npc": [npc, "look", {"target": "RESTAURANT:table_center"}]}])


func _arrive(a: Dictionary) -> void:
	var npc := String(a.npc)
	var E := ep()
	var tpl := String(a.template)
	arrived[npc] = true
	run([{"spawn": [npc, ARRIVE_FROM.get(npc, "RESTAURANT:arrive")]}, {"set_schedule": [npc, ""]}])
	_seat_npc(npc, _seat_marker(npc), true)
	match npc:
		"adrian":
			run([{"line": "ARR_ADRIAN_EMO" if tpl == "she_will_be" else "ARR_ADRIAN"}])
			if tpl == "she_will_be":
				E.ch("adrian").add_stress(1)
		"daniel":
			match tpl:
				"what_you_seek":
					run([{"line": "ARR_DANIEL_CARD"}, {"flag": "daniel_card_focus"}])
				"mara_here":
					run([{"line": "ARR_DANIEL_MARA"}, {"spawn": ["brody", "LOBBY:thugs"]}, {"spawn": ["sato", "LOBBY:thugs_2"]}, {"flag": "thugs_outside"}])
				_:
					run([{"line": "ARR_DANIEL"}, {"set": ["char.daniel.suspicion", 0]}, {"stress": ["daniel", -1]}])
			if E.threat.daniel_knows_hero_met_thomas:
				E.finale.daniel_pressure -= 1
		"mara":
			run([{"line": "ARR_MARA"}])
		"thomas":
			run([{"line": "ARR_THOMAS"}])


func tick(delta: float) -> void:
	var E := ep()
	if E.finale.started:
		live_t += delta
		for a in arrivals.duplicate():
			if live_t >= float(a.t):
				arrivals.erase(a)
				_arrive(a)
		# everyone in place? (Mara puts the card on the table when seated)
		for n in arrived:
			if seated.has(n):
				continue
			var at_seat: bool = Presence.pos.has(n) and (Presence.pos[n] as Vector3).distance_to(data().marker(_seat_marker(n))) < 0.9
			if at_seat or live_t > float(_arrival_time(n)) + 7.0:
					seated[n] = true
					if Services.world and not at_seat:
						run([{"teleport_npc": [n, _seat_marker(n)]}])
					if n == "mara" and E.holder_of("ITEM_SD_CARD") == "mara":
						E.finale.card_spot = "table"
						E.give_item("ITEM_SD_CARD", "world:table")
		if not live_started and seated.has("adrian") and seated.has("mara") and seated.has("daniel"):
			live_started = true
			run([{"start_exchange": "X_S09_LIVE"}])
		_update_addressing()
		_tick_exposure(delta)
	if _ending_t >= 0.0:
		_ending_t -= delta
		if _ending_t < 0.0:
			run([{"goto_scene": "EPI"}])


func _arrival_time(n: String) -> float:
	var t := 1.0
	for inv in ep().finale.invites:
		if inv.to == n:
			return t
		t += ARRIVAL_SPACING
	return t


func _update_addressing() -> void:
	if not Presence.pos.has("hero"):
		return
	var hp: Vector3 = Presence.pos.hero
	var fwd := Vector3.FORWARD
	if Services.hero:
		fwd = Services.hero.facing
	var best := ""
	var best_s := INF
	for n in arrived:
		if not Presence.is_present(n) or Presence.in_zone(n) != "RESTAURANT":
			continue
		var to: Vector3 = (Presence.pos[n] as Vector3) - hp
		to.y = 0
		var d := to.length()
		var dot := fwd.dot(to.normalized()) if d > 0.01 else 1.0
		var s := d * (1.6 - dot)
		if s < best_s:
			best_s = s
			best = n
	if best != addressed:
		for n in NAMES:
			ep().clear_flag("addressed_" + n)
		addressed = best
		if best != "":
			ep().set_flag("addressed_" + best)
	if ring:
		var show: bool = addressed != "" and Services.conversation != null and not Services.conversation.chips_visible.is_empty()
		ring.visible = show
		if show and Presence.pos.has(addressed):
			ring.global_position = (Presence.pos[addressed] as Vector3) + Vector3(0, 0.03, 0)


# ================================================================== exposure / Daniel

func _on_beat(b: String) -> void:
	if b != "BEAT_EXPOSED":
		return
	var E := ep()
	var F: FinaleState = E.finale
	if F.exposed:
		return
	F.exposed = true
	F.daniel_pressure += int(E.flag("exposure_base") if E.flag("exposure_base") != null else 2)
	if F.photo_at_adrian or E.flags.get("photo_shown_finale", false):
		F.daniel_pressure += 1
	if E.flags.get("adrian_doubts_daniel", false):
		F.daniel_pressure += 1
	F.daniel_state = "wary"
	exposed_t = 0.0
	flee_t = 0.0
	exit_choice = choose_exit()
	if E.flags.get("thugs_outside", false):
		_thugs_t = 3.0
	# the tells window: 6 s, staggered so READ (0.6×) makes it catchable
	run([{"tell": ["O_DANIEL_EXIT_GLANCE", 2.6]}, {"npc": ["daniel", "look", {"target": _exit_marker(exit_choice)}]},
		{"delay": 1.4, "do": [{"tell": ["O_DANIEL_PHONE", 2.4]}, {"npc": ["daniel", "pose", {"pose": "phone"}]}]},
		{"delay": 2.8, "do": [{"tell": ["O_DANIEL_AVOIDS_ADRIAN", 2.4]}]},
		{"delay": 4.0, "do": [{"tell": ["O_DANIEL_WEIGHT_SHIFT", 2.0]}, {"npc": ["daniel", "look", {"target": null}]}]}])


## Daniel's preferred exit: kitchen swing door unless jammed, then main doors unless locked,
## then the terrace if unlocked; "" = none (cornered).
func choose_exit() -> String:
	var D: Dictionary = ep().finale.doors
	if String(D.get("kitchen", "open")) != "jammed":
		return "kitchen"
	if String(D.get("main", "closed")) != "locked":
		return "main"
	if ep().flags.get("terrace_unlocked", false):
		return "terrace"
	return ""


func _exit_marker(e: String) -> String:
	match e:
		"kitchen": return "RESTAURANT:kitchen_door"
		"main": return "RESTAURANT:main_door"
		"terrace": return "RESTAURANT:terrace_door"
	return "RESTAURANT:table_center"


func exit_blocked(e: String) -> bool:
	if e == "":
		return true
	if not Presence.pos.has("hero") or Presence.in_zone("hero") != "RESTAURANT":
		return false
	return (Presence.pos.hero as Vector3).distance_to(data().marker(_exit_marker(e))) <= BLOCK_R


func _tick_exposure(delta: float) -> void:
	var E := ep()
	var F: FinaleState = E.finale
	if not F.exposed:
		return
	if _thugs_t >= 0.0:
		_thugs_t -= delta
		if _thugs_t < 0.0:
			_thugs()
	if F.daniel_state in ["confessed", "escaped"]:
		if _decision_lines_t >= 0.0:
			_decision_lines_t -= delta
			if _decision_lines_t < 0.0:
				_enter_decision()
		return
	if F.daniel_state == "fleeing":
		_tick_flight(delta)
		return
	# the clock starts once the reveal lines are over: first check after the 6 s tells window
	if Services.conversation and Services.conversation.busy():
		return
	flee_t += delta
	if flee_t >= FLEE_CHECK + (2.0 if not _tells_opened else 0.0):
		_tells_opened = true
		flee_t = 0.0
		flee_check()


## AT-SOC-07: pressure ≥ 5 → confess; flee attempt blocked → cornered → confess;
## open exit and unblocked → flee (→ escaped if not stopped).
func flee_check() -> String:
	var F: FinaleState = ep().finale
	if F.daniel_state in ["confessed", "escaped", "fleeing"]:
		return F.daniel_state
	if F.daniel_pressure >= 5:
		_confess()
		return "confessed"
	exit_choice = choose_exit()
	if exit_choice == "" or exit_blocked(exit_choice):
		F.daniel_state = "cornered"
		run([{"line": "DAN_CORNERED"}])
		_confess()
		return "cornered"
	_start_flight()
	return "fleeing"


func _start_flight() -> void:
	var E := ep()
	var F: FinaleState = E.finale
	F.daniel_state = "fleeing"
	E.set_flag("daniel_fleeing")
	E.set_flag("daniel_exit_" + exit_choice)
	if E.holder_of("ITEM_SD_CARD") == "world:table":
		E.give_item("ITEM_SD_CARD", "daniel")
		E.set_flag("daniel_took_card")
	_flight_t = 0.0
	run([{"line": "DAN_FLEE"}, {"npc": ["daniel", "walk_to", {"marker": _exit_marker(exit_choice), "speed": "fast"}]}])
	bus().player_decision.emit("daniel_flees")


func _tick_flight(delta: float) -> void:
	var E := ep()
	if not Presence.pos.has("daniel"):
		_escaped()
		return
	_flight_t += delta
	# headless sims have no bodies; in game this is a failsafe if he snags on furniture
	if _flight_t >= (3.0 if Services.world == null else 9.0):
		Presence.place("daniel", "RESTAURANT", data().marker(_exit_marker(exit_choice)))
	var dp: Vector3 = Presence.pos.daniel
	# the hero reaching him (vaulting the table, cutting him off) stops him
	if Presence.distance("hero", "daniel") <= 1.0:
		_daniel_stopped("body")
		return
	if exit_blocked(exit_choice):
		_daniel_stopped("block")
		return
	if dp.distance_to(data().marker(_exit_marker(exit_choice))) < 0.9:
		_escaped()


func _daniel_stopped(how: String) -> void:
	var E := ep()
	E.clear_flag("daniel_fleeing")
	E.finale.daniel_state = "cornered"
	run([{"npc": ["daniel", "stop", {}]}, {"sfx": "impact"}, {"camera_hint": {"shake": 0.5}}, {"line": "DAN_CORNERED"}])
	if how == "chair":
		run([{"npc": ["daniel", "pose", {"pose": "open"}]}])
	if E.holder_of("ITEM_SD_CARD") == "daniel":
		E.give_item("ITEM_SD_CARD", "world:table")   # he drops it in the struggle
	bus().player_decision.emit("stop_daniel")
	_confess()


func _escaped() -> void:
	var E := ep()
	var F: FinaleState = E.finale
	E.clear_flag("daniel_fleeing")
	F.daniel_state = "escaped"
	E.ending.daniel_outcome = "escaped"
	run([{"despawn": "daniel"}])
	if E.holder_of("ITEM_SD_CARD") == "daniel":
		E.set_flag("card_is_copy")
		run([{"line": "DAN_ESCAPED"}])
		E.give_item("ITEM_SD_CARD", "world:table")
		F.card_spot = "table"
	_decision_lines_t = 4.0


func _confess() -> void:
	var E := ep()
	var F: FinaleState = E.finale
	F.daniel_state = "confessed"
	E.ending.daniel_outcome = "confessed"
	run([{"line": "DAN_CONFESS"}, {"line": "ADR_TO_DAN"}, {"give_fact": ["F_DANIEL_CONFESSED", "S09"]}])
	match F.recorder:
		"vase": E.ending.recorded = "clear"
		"basket": E.ending.recorded = "muffled"
		_: E.ending.recorded = "none"
	if E.holder_of("ITEM_SD_CARD") == "daniel":
		E.give_item("ITEM_SD_CARD", "world:table")
	_decision_lines_t = 12.0


func _thugs() -> void:
	var E := ep()
	if not E.flags.get("thugs_outside", false):
		return
	if String(E.finale.doors.get("main", "closed")) == "locked":
		return
	E.finale.thugs_inside = true
	run([{"teleport_npc": ["brody", "RESTAURANT:thug_in"]}, {"teleport_npc": ["sato", "RESTAURANT:thug_in_2"]}, {"line": "THUGS_IN"}])
	if E.ch("thomas") and E.ch("thomas").trust >= 0 and E.flags.get("thomas_present", false):
		run([{"line": "THOMAS_BLOCKS"}, {"npc": ["thomas", "walk_to", {"marker": "RESTAURANT:thug_in"}]}])
	elif E.flags.get("adrian_doubts_daniel", false):
		run([{"line": "ADR_OUT"}, {"delay": 2.5, "do": [{"despawn": "brody"}, {"despawn": "sato"}]}])
	else:
		run([{"line": "ADR_STAY"}])


func _enter_decision() -> void:
	var E := ep()
	if E.phase_name() == "S09_DECISION":
		return
	E.set_phase_name("S09_DECISION")
	if Services.conversation:
		Services.conversation.end_active("RESOLVED")
	E.ending.adrian_relationship = E.ch("adrian").trust + E.ch("adrian").respect
	E.ending.mara_trust = E.ch("mara").trust
	bus().music_requested.emit("SILENCE" if E.has_item("ITEM_SD_CARD") else "FINALE_LIVE")
	bus().sfx_requested.emit("chime", null)


# ================================================================== endings

func do_ending(id: String) -> void:
	var E := ep()
	if E.ending.id != "" or E.phase_name() != "S09_DECISION":
		return
	match id:
		"A_MARA":
			run([{"take_item": ["ITEM_SD_CARD", "mara"]}, {"line": "A_MARA"}, {"npc": ["mara", "walk_to", {"marker": "RESTAURANT:kitchen_door", "speed": "walk"}]}])
		"B_THOMAS":
			if not E.flags.get("thomas_present", false):
				return
			run([{"take_item": ["ITEM_SD_CARD", "thomas"]}, {"line": "B_THOMAS"}])
		"C_DESTROY":
			run([{"take_item": "ITEM_SD_CARD"}, {"sfx": "crash"}, {"line": "C_MARA"}])
		"D_ADRIAN":
			if not E.ending_d_available():
				return
			run([{"take_item": ["ITEM_HERO_PHONE", "adrian"]}, {"line": "D_ADR"}, {"give_item": ["ITEM_SD_CARD", "world:table"]}, {"npc": ["adrian", "pose", {"pose": "ear"}]}])
	E.ending.id = id
	E.ending.adrian_relationship = E.ch("adrian").trust + E.ch("adrian").respect
	E.ending.mara_trust = E.ch("mara").trust
	bus().ending_reached.emit(id)
	bus().player_decision.emit("ending")
	E.set_phase_name("S09_DECISION")
	_ending_t = 7.5
