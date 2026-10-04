extends TestCase
## AT-GRAPH-01: the whole episode as one SIM — S01 bar → … → epilogue — using only guaranteed or
## minimal actions, branching at the decision into each of the four endings. AT-GRAPH-10 is covered
## on the way (Room 307 is skipped entirely).

var d: Dictionary
var obj_trail: Array = []    # objective ids in the order the player would have seen them


func before_each() -> void:
	fresh()
	obj_trail = []


func _sample_objective() -> void:
	var id := Objectives.current_id()
	if obj_trail.is_empty() or obj_trail.back() != id:
		obj_trail.append(id)


func _until(cond: Callable, sec: float, what: String, step: float = 0.25) -> bool:
	var ok := wait_until(d.conv, func(): _sample_objective(); return cond.call(), sec, step)
	check(ok, "timed out waiting for: " + what + " (scene %s phase %s x %s)" % [ep().scene_id, ep().phase_name(), d.conv.active_id])
	return ok


func _choose(chip: String) -> void:
	settle(d.conv)
	check(d.conv.choose_id(chip), "chip %s (have %s in %s)" % [chip, d.conv.chips_visible.map(func(c): return c.id), d.conv.active_id])


func _scene(id: String) -> Callable:
	return func(): return ep().scene_id == id


func play_to_decision(seed_d: bool) -> void:
	d = start_scene("S01")
	if d.has("chase"):
		pass
	# S01 — observe only
	_until(_scene("S02"), 300.0, "S01 resolves by itself and Adrian takes the hero")
	eq(ep().s1_resolution, "OBSERVE_ONLY")
	# S02 — follow Adrian; silence everywhere (elevator silence: trust +1)
	place("hero", "BAR:hero_stand")
	place("adrian", "BAR:adrian_by_hero")
	_until(func(): return d.conv.active_id == "X_S02_A", 20.0, "brief")
	if seed_d:
		ep().notice("O_S2_FLAT_ON_DANGER")
	_until(func(): return d.conv.active_id == "", 30.0, "brief ends")
	place("hero", "LOBBY:adrian_mid")
	place("adrian", "LOBBY:adrian_mid")
	_until(func(): return d.conv.active_id == "X_S02_B", 5.0, "beat B")
	if seed_d:
		_choose("CH_S2_NOT_EX")
	_until(func(): return d.conv.active_id == "", 30.0, "beat B ends")
	place("hero", "ELEV_A:hero")
	_until(func(): return ep().has_item("ITEM_KEYCARD_307"), 60.0, "ride to 3")
	place("hero", "HALL_3F:arrive_elev")
	_until(_scene("S03"), 2.0, "S03")
	# S03 — skip the room entirely (AT-GRAPH-10)
	_until(func(): return ep().flag("daniel_s3_walking") == true, 60.0, "Daniel comes anyway")
	place("daniel", "HALL_3F:daniel_mid")
	place("hero", "HALL_3F:daniel_mid")
	_until(_scene("S04"), 60.0, "hub opens")
	# S04 — Lead C fails twice, Lead A via Nico's text, location via the Lina fallback
	place("hero", "SECURITY:chair")
	advance(d.conv, 0.5)
	d.sm.logic.caught("pavel")
	advance(d.conv, 3.0)
	place("hero", "SECURITY:chair")
	advance(d.conv, 0.5)
	d.sm.logic.caught("pavel")
	_until(func(): return ep().lead_done("C"), 10.0, "Lead C FAILED_DONE")
	place("hero", "BAR:nico_tables")
	place("nico", "BAR:nico_taps")
	_until(func(): return ep().ch("nico").trust >= 1, 260.0, "Nico's text")
	_until(func(): return d.conv.active_id == "", 20.0, "greet done")
	check(d.conv.talk_to("nico"), "talk to Nico")
	_choose("CH_NICO_WHO")
	_until(func(): return ep().lead_done("A"), 15.0, "Lead A")
	_until(func(): return ep().has_fact("F_THOMAS_LOCATION"), 160.0, "fallback location")
	_until(func(): return ep().flag("thomas_ready") == true, 5.0, "S06 enabled")
	place("hero", "LOADING_DOCK:enter")
	_until(_scene("S06"), 2.0, "S06")
	# S06 — stop with «Мара.», then silence; the 70 s rule delivers everything
	place("thomas", "LOADING_DOCK:thomas_edge")
	place("hero", "LOADING_DOCK:hero_block")
	_until(func(): return d.conv.active_id == "X_S06_STOP", 5.0, "stop exchange")
	_choose("CH_TH_MARA")
	_until(_scene("S07"), 200.0, "chase starts")
	for f in ["F_THOMAS_TOOK_BLAME", "F_ADRIAN_WAS_DRIVING", "F_RECORDING_EXISTS", "F_ADRIAN_THINKS_MARA_FORGOT"]:
		check(ep().has_fact(f), "S06 guaranteed " + f)
	# S07 — run straight to the banquet corridor, pursuers far behind
	var ch: Node = Services.chase
	for id in ["brody", "sato"]:
		place(id, "LAUNDRY:worker")
		if ch and ch.pursuers.has(id):
			ch.pursuers[id].zone = "LAUNDRY"
			ch.pursuers[id].pos = data().marker("LAUNDRY:worker")
	place("hero", "BCORR:mid")
	_until(_scene("S08"), 40.0, "Mara pulls the hero in")
	# S08 — silence; clip guarantee; Thomas; the plan
	place("hero", "ORCHID:hero_in")
	_until(func(): return d.conv.active_id == "X_S08_ASK", 260.0, "the ask")
	for f in ["F_MARA_BELIEVED_SHE_DROVE", "F_DANIEL_TOLD_MARA", "F_MARA_WILL_PUBLISH"]:
		check(ep().has_fact(f), "S08 guaranteed " + f)
	_choose("CH_MARA_HOUR")
	_until(func(): return ep().flag("plan_finale") == true, 20.0, "plan")
	place("hero", "RESTAURANT:kitchen_arrive")
	_until(_scene("S09"), 10.0, "finale")
	# S09 — stage, invite, start, MAIN, pressure → confession
	for s in ["S1", "S2", "S3", "S4"]:
		bus().trap_bait.emit("stage", {"cmd": "take_card"})
		bus().trap_bait.emit("stage", {"cmd": "seat", "arg": s})
	for inv in [["adrian", "alone"], ["mara", "time"], ["daniel", "vale_wants"], ["thomas", "time"]]:
		bus().trap_bait.emit("stage", {"cmd": "invite", "to": inv[0], "template": inv[1]})
	bus().trap_bait.emit("stage", {"cmd": "start"})
	eq(ep().phase_name(), "S09_LIVE")
	place("hero", "RESTAURANT:S4")
	_until(func(): return d.sm.logic.live_started, 60.0, "everyone seated")
	if seed_d:
		d.sm.logic.addressed = "adrian"
		_choose("CH_FIN_LOOK")
		_until(func(): return ep().flag("look_said") == true, 15.0, "pre-trap fear hit")
	d.sm.logic.addressed = "adrian"
	_choose("CH_FIN_MAIN")
	_until(func(): return ep().finale.exposed, 20.0, "TR_FINAL_MAIN")
	d.sm.logic.addressed = "daniel"
	_choose("CH_FIN_HOSPITAL")
	place("hero", "RESTAURANT:kitchen_door")   # BLOCK EXIT: stand in the door he glanced at
	_until(func(): return ep().finale.daniel_state in ["confessed", "escaped"], 60.0, "Daniel resolved")
	eq(ep().finale.daniel_state, "confessed", "blocked -> cornered -> confessed")
	_until(func(): return ep().phase_name() == "S09_DECISION", 30.0, "decision")


func _finish(ending: String) -> void:
	if ep().holder_of("ITEM_SD_CARD") != "hero":
		bus().trap_bait.emit("stage", {"cmd": "card", "arg": "pocket"})
	bus().trap_bait.emit("stage", {"cmd": "ending", "arg": ending})
	eq(ep().ending.id, ending)
	_until(_scene("EPI"), 12.0, "epilogue")
	place("hero", "STREET:enter")
	_until(func(): return ep().phase_name() == "DONE", 60.0, "cut to black")


## The one current objective walks forward through the episode — never back, never a checklist —
## and the hire hands over the episode goal (Найди Мару Вейл → Выясни, куда ушла Мара).
func _check_objective_trail() -> void:
	var order: Array = Objectives.ordered()
	# (O_TO_RESTAURANT is skipped here: the SIM teleports into the restaurant before the 3 s hold)
	var expected := ["O_BAR", "O_FOLLOW_ADRIAN", "O_FIND_MARA", "O_WHERE_MARA", "O_FIND_DRIVER", "O_STOP_THOMAS",
		"O_HEAR_THOMAS", "O_ESCAPE", "O_MARA", "O_STAGE", "O_LIVE", "O_DECIDE", ""]
	var last := -1
	for id in obj_trail:
		if id == "":
			continue
		var i := order.find(id)
		check(i >= last, "objective went backwards: %s in %s" % [id, obj_trail])
		last = maxi(last, i)
	var j := 0
	for id in obj_trail:
		if j < expected.size() and id == expected[j]:
			j += 1
	eq(j, expected.size(), "objective trail %s covers %s" % [obj_trail, expected])


func test_full_episode_ending_a() -> void:
	play_to_decision(false)
	_finish("A_MARA")
	_check_objective_trail()


func test_full_episode_ending_b() -> void:
	play_to_decision(false)
	_finish("B_THOMAS")
	_check_objective_trail()


func test_full_episode_ending_c() -> void:
	play_to_decision(false)
	_finish("C_DESTROY")
	_check_objective_trail()


func test_full_episode_ending_d_minimal_fear_route() -> void:
	play_to_decision(true)
	var a: CharacterState = ep().ch("adrian")
	check(int(a.fear_hits.get("LOSE_MARA", 0)) >= 2, "S2 + finale pre-trap fear hits (%s)" % a.fear_hits)
	check(a.trust >= 0, "trust %d" % a.trust)
	check(ep().ending_d_available(), "Ending D available")
	_finish("D_ADRIAN")
	_check_objective_trail()
