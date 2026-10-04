extends TestCase
## S08 Mara + S09 finale + endings: AT-GRAPH-06/07/08/11/12, AT-SOC-06/07, AT-PLAY-17..22 logic.

var d: Dictionary


func before_each() -> void:
	fresh()


func _choose(chip: String) -> void:
	settle(d.conv)
	check(d.conv.choose_id(chip), "chip %s (have %s in %s)" % [chip, d.conv.chips_visible.map(func(c): return c.id), d.conv.active_id])


func _s06_facts() -> void:
	for f in ["F_THOMAS_TOOK_BLAME", "F_ADRIAN_WAS_DRIVING", "F_RECORDING_EXISTS", "F_ADRIAN_THINKS_MARA_FORGOT", "F_THOMAS_NAME"]:
		ep().give_fact(f, "test")


# ------------------------------------------------------------------ S08

func _run_s08(choose_hired: bool, card_chip: bool) -> void:
	_s06_facts()
	d = start_scene("S08")
	place("hero", "ORCHID:hero_in")
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S08_DEFUSE")
	if choose_hired:
		_choose("CH_MARA_HIRED")
	check(wait_until(d.conv, func(): return ep().flag("mara_lowered") == true, 25.0), "defused")
	# watch the clip
	ep().set_flag("clip_playing")
	check(wait_until(d.conv, func(): return d.conv.active_id == "X_S08_STORY", 20.0), "story after the clip")
	check(ep().has_fact("F_ADRIAN_WAS_DRIVING"))
	check(wait_until(d.conv, func(): return d.conv.active_id == "X_S08_THOMAS", 40.0), "Thomas arrives after the story")
	for f in ["F_MARA_BELIEVED_SHE_DROVE", "F_DANIEL_TOLD_MARA", "F_MARA_WILL_PUBLISH"]:
		check(ep().has_fact(f), f + " is guaranteed")
	check(wait_until(d.conv, func(): return d.conv.active_id == "X_S08_ASK", 40.0), "the ask")
	check(ep().has_fact("F_ADRIAN_NEVER_ASKED"))
	check(ep().threads_pinned.has("T_TWO_STORIES"), "T_TWO_STORIES auto-pinned")
	if card_chip:
		_choose("CH_MARA_CARD")
	else:
		_choose("CH_MARA_HOUR")
	advance(d.conv, 14.0)
	check(ep().flag("plan_finale") == true)


func test_s08_card_custody_by_trust_high() -> void:
	_run_s08(true, true)
	eq(ep().holder_of("ITEM_SD_CARD"), "hero", "trust 1 -> she hands over the card")


func test_s08_card_custody_by_trust_low() -> void:
	_run_s08(false, true)
	eq(ep().holder_of("ITEM_SD_CARD"), "mara", "trust 0 -> she keeps it")


func test_s08_wary_bluff_called_still_proceeds() -> void:
	_s06_facts()
	ep().set_flag("mara_wary")
	d = start_scene("S08")
	place("hero", "ORCHID:hero_in")
	advance(d.conv, 1.0)
	eq(ep().ch("mara").trust, -1, "wary Mara starts colder")
	place("hero", "ORCHID:ring_e")
	_choose("CH_MARA_EVA")
	advance(d.conv, 5.0)
	check(ep().flag("mara_fleeing") == true or ep().flag("mara_lowered") == true)
	advance(d.conv, 20.0)
	check(ep().flag("mara_lowered") == true, "fail-forward: she stops at the door")


func test_s08_clip_guarantee_without_input() -> void:
	_s06_facts()
	d = start_scene("S08")
	place("hero", "ORCHID:hero_in")
	advance(d.conv, 70.0, 0.25)
	check(ep().has_fact("F_ADRIAN_WAS_DRIVING"), "Mara plays it herself")
	advance(d.conv, 60.0, 0.25)
	check(ep().has_fact("F_MARA_BELIEVED_SHE_DROVE") and ep().has_fact("F_DANIEL_TOLD_MARA"))


# ------------------------------------------------------------------ S09

func _to_s09(card_holder: String = "hero") -> void:
	_s06_facts()
	for f in ["F_MARA_BELIEVED_SHE_DROVE", "F_DANIEL_TOLD_MARA", "F_MARA_WILL_PUBLISH", "F_ADRIAN_NEVER_ASKED"]:
		ep().give_fact(f, "test")
	ep().give_item("ITEM_SD_CARD", card_holder)
	ep().set_flag("plan_finale")
	d = start_scene("S09")
	place("hero", "RESTAURANT:kitchen_arrive")


func _stage(cmd: Dictionary) -> void:
	bus().trap_bait.emit("stage", cmd)


func _invite_all(with_thomas: bool = true, daniel_tpl: String = "vale_wants") -> void:
	_stage({"cmd": "invite", "to": "adrian", "template": "alone"})
	_stage({"cmd": "invite", "to": "mara", "template": "time"})
	_stage({"cmd": "invite", "to": "daniel", "template": daniel_tpl})
	if with_thomas:
		_stage({"cmd": "invite", "to": "thomas", "template": "time"})


func _cards() -> void:
	for s in ["S1", "S2", "S3", "S4"]:
		_stage({"cmd": "take_card"})
		_stage({"cmd": "seat", "arg": s})


func _start_and_arrive(with_thomas: bool = true) -> void:
	_stage({"cmd": "start"})
	if not with_thomas:
		_stage({"cmd": "start"})   # second press after the «Томаса нет» warning
	eq(ep().phase_name(), "S09_LIVE")
	place("hero", "RESTAURANT:S4")
	advance(d.conv, 60.0, 0.25)
	check(d.sm.logic.live_started, "live exchange started")


func _say(chip: String, to: String) -> void:
	d.sm.logic.addressed = to
	ep().set_flag("addressed_" + to)
	place("hero", "RESTAURANT:S4")
	settle(d.conv)
	d.sm.logic.addressed = to
	check(d.conv.choose_id(chip), "chip %s (have %s)" % [chip, d.conv.chips_visible.map(func(c): return c.id)])


func test_at_graph_07_needs_three_invites() -> void:
	_to_s09()
	var lines: Array = []
	bus().line_started.connect(func(s, t, du): lines.append(t))
	_stage({"cmd": "invite", "to": "adrian", "template": "alone"})
	_stage({"cmd": "invite", "to": "mara", "template": "time"})
	_stage({"cmd": "start"})
	advance(d.conv, 4.0)
	eq(ep().phase_name(), "S09_STAGING", "won't start without Daniel")
	check(lines.has(data().line("MARA_NO_DANIEL").text), "Mara's line plays")


func test_at_graph_06_main_chip_needs_both_facts() -> void:
	_s06_facts()
	ep().facts.erase("F_ADRIAN_THINKS_MARA_FORGOT")
	ep().give_fact("F_MARA_BELIEVED_SHE_DROVE")
	ep().give_fact("F_DANIEL_TOLD_MARA")
	ep().set_flag("plan_finale")
	d = start_scene("S09")
	place("hero", "RESTAURANT:kitchen_arrive")
	_cards()
	_invite_all()
	_start_and_arrive()
	settle(d.conv)
	var ids: Array = d.conv.available_chips(data().exchanges.X_S09_LIVE.nodes.talk).map(func(c): return c.id)
	check(not ids.has("CH_FIN_MAIN"), "MAIN hidden without F_ADRIAN_THINKS_MARA_FORGOT")
	ep().give_fact("F_ADRIAN_THINKS_MARA_FORGOT")
	ids = d.conv.available_chips(data().exchanges.X_S09_LIVE.nodes.talk).map(func(c): return c.id)
	check(ids.has("CH_FIN_MAIN"), "MAIN visible with both facts")


func test_at_soc_06_main_without_mara_retry() -> void:
	_to_s09()
	_cards()
	_invite_all()
	_start_and_arrive()
	# Mara outside hearing: standing far by the window with the kitchen door open
	Presence.place("mara", "RESTAURANT", data().marker("RESTAURANT:terrace_door") + Vector3(0.5, 0, 0))
	_say("CH_FIN_MAIN", "adrian")
	advance(d.conv, 14.0)
	check(ep().flag("main_consumed") == true, "outcome 2: Daniel cuts in")
	check(not ep().finale.exposed)
	# retry: move Mara back and repeat it in front of her
	Presence.place("mara", "RESTAURANT", data().marker("RESTAURANT:S3"))
	_say("CH_FIN_AGAIN", "adrian")
	advance(d.conv, 10.0)
	check(ep().finale.exposed, "retry path exposes Daniel")


func test_at_play_19_same_chip_different_addressee() -> void:
	_to_s09()
	_cards()
	_invite_all()
	_start_and_arrive()
	var lines: Array = []
	bus().line_started.connect(func(s, t, du): lines.append(t))
	_say("CH_FIN_MAIN", "daniel")
	advance(d.conv, 12.0)
	check(not ep().finale.exposed, "MAIN addressed to Daniel does not spring the trap")
	check(lines.has(data().line("MAIN_TO_DAN").text))


func _expose() -> void:
	_say("CH_FIN_MAIN", "adrian")
	check(wait_until(d.conv, func(): return ep().finale.exposed, 15.0), "exposed")
	advance(d.conv, 1.0)


func test_at_soc_07_pressure_confesses() -> void:
	_to_s09()
	_cards()
	_invite_all()
	_start_and_arrive()
	_expose()
	ep().finale.daniel_pressure = 5
	eq(d.sm.logic.flee_check(), "confessed")
	eq(ep().finale.daniel_state, "confessed")


func test_at_soc_07_blocked_cornered_confesses() -> void:
	_to_s09()
	_cards()
	_stage({"cmd": "door", "arg": "kitchen", "v": "closed"})
	_invite_all()
	_start_and_arrive()
	_expose()
	ep().finale.daniel_pressure = 2
	place("hero", "RESTAURANT:kitchen_door")
	eq(d.sm.logic.flee_check(), "cornered")
	eq(ep().finale.daniel_state, "confessed", "cornered -> confessed")


func test_at_soc_07_open_exit_escapes() -> void:
	_to_s09("mara")
	_cards()
	_invite_all()
	_start_and_arrive()
	eq(ep().finale.card_spot, "table", "Mara put the card on the table when seated")
	_expose()
	ep().finale.daniel_pressure = 2
	place("hero", "RESTAURANT:stand_window")
	eq(d.sm.logic.flee_check(), "fleeing")
	eq(ep().holder_of("ITEM_SD_CARD"), "daniel", "grabs the card on his way")
	place("daniel", "RESTAURANT:kitchen_door")
	place("hero", "RESTAURANT:stand_window")
	advance(d.conv, 0.5)
	eq(ep().finale.daniel_state, "escaped")
	# AT-GRAPH-12: the card (Mara's copy) is recoverable and endings work
	eq(ep().holder_of("ITEM_SD_CARD"), "world:table")
	check(wait_until(d.conv, func(): return ep().phase_name() == "S09_DECISION", 20.0), "decision")
	_stage({"cmd": "card", "arg": "pocket"})
	_stage({"cmd": "ending", "arg": "A_MARA"})
	eq(ep().ending.id, "A_MARA")


func _to_decision(with_thomas: bool = true) -> void:
	_to_s09()
	_cards()
	_invite_all(with_thomas)
	_start_and_arrive(with_thomas)
	_expose()
	ep().finale.daniel_pressure = 6
	d.sm.logic.flee_check()
	check(wait_until(d.conv, func(): return ep().phase_name() == "S09_DECISION", 30.0), "decision phase")


func test_ending_a() -> void:
	_to_decision()
	_stage({"cmd": "ending", "arg": "A_MARA"})
	eq(ep().ending.id, "A_MARA")
	advance(d.conv, 8.0)
	eq(ep().scene_id, "EPI")


func test_ending_b() -> void:
	_to_decision()
	_stage({"cmd": "ending", "arg": "B_THOMAS"})
	eq(ep().ending.id, "B_THOMAS")


func test_ending_c() -> void:
	_to_decision()
	_stage({"cmd": "ending", "arg": "C_DESTROY"})
	eq(ep().ending.id, "C_DESTROY")
	check(not ep().has_item("ITEM_SD_CARD"))


func test_ending_d() -> void:
	_to_decision()
	var a: CharacterState = ep().ch("adrian")
	a.trust = 0
	a.fear_hits["LOSE_MARA"] = 2
	check(ep().ending_d_available())
	_stage({"cmd": "ending", "arg": "D_ADRIAN"})
	eq(ep().ending.id, "D_ADRIAN")
	eq(ep().holder_of("ITEM_HERO_PHONE"), "adrian")


func test_at_graph_11_no_thomas_no_b() -> void:
	_to_decision(false)
	check(ep().flag("thomas_present") != true)
	_stage({"cmd": "ending", "arg": "B_THOMAS"})
	eq(ep().ending.id, "", "B unavailable without Thomas")
	_stage({"cmd": "ending", "arg": "C_DESTROY"})
	eq(ep().ending.id, "C_DESTROY", "C still works")


func test_at_graph_08_ending_d_table() -> void:
	ep().give_item("ITEM_HERO_PHONE", "hero")
	var a: CharacterState = ep().ch("adrian")
	var cases := [
		[0, 2, "confessed", true, true],
		[-1, 2, "confessed", true, false],
		[0, 1, "confessed", true, false],
		[0, 2, "wary", true, false],
		[0, 2, "escaped", true, true],
		[1, 3, "confessed", false, false],
	]
	for c in cases:
		a.trust = c[0]
		a.fear_hits["LOSE_MARA"] = c[1]
		ep().finale.daniel_state = c[2]
		ep().give_item("ITEM_HERO_PHONE", "hero" if c[3] else "sato")
		eq(ep().ending_d_available(), c[4], "case %s" % [c])


func test_epilogue_phone_and_done() -> void:
	ep().ending.id = "A_MARA"
	ep().finale.daniel_state = "confessed"
	d = start_scene("EPI")
	place("hero", "STREET:enter")
	advance(d.conv, 21.0, 0.25)
	check(d.sm.logic.answered, "auto-answers after the ring")
	advance(d.conv, 14.0, 0.25)
	eq(ep().phase_name(), "DONE")
