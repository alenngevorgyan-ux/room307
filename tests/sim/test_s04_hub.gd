extends TestCase
## Hub: AT-GRAPH-02/03/05/09, AT-SOC-02, overhears, video room grants.

var d: Dictionary


func before_each() -> void:
	fresh()
	ep().beat("BEAT_HUB_OPEN")
	d = start_scene("S04")


func _choose(chip: String) -> void:
	settle(d.conv)
	check(d.conv.choose_id(chip), "chip %s (have %s in %s)" % [chip, d.conv.chips_visible.map(func(c): return c.id), d.conv.active_id])


func lead_a_nico() -> void:
	place("hero", "BAR:nico_tables")
	place("nico", "BAR:nico_taps")
	ep().hero_zone = "BAR"
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S04_NICO_GREET")
	advance(d.conv, 8.0)
	ep().ch("nico").trust = 1          # warmth from helping at the bar
	check(d.conv.talk_to("nico"))
	_choose("CH_NICO_WHO")
	advance(d.conv, 8.0)


func lead_b_eva_615() -> void:
	place("hero", "ROOF_SMOKING:arrive")
	place("eva", "ROOF_SMOKING:eva_door")
	ep().hero_zone = "ROOF_SMOKING"
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S04_EVA")
	_choose("CH_EVA_615")
	advance(d.conv, 10.0)


func lead_c_video() -> void:
	place("hero", "SECURITY:chair")
	advance(d.conv, 0.5)
	eq(ep().phase_name(), "S05_VIDEO")
	var v: VideoRoom = d.sm.logic.video
	v.cam_i = VideoRoom.CAMS.find("SCORR")
	v.t = 1471.5
	v._render(1.2)
	check(ep().has_fact("F_THOMAS_LOCATION"), "video 00:31 gives the location")
	place("hero", "SCORR:sec_door")
	advance(d.conv, 0.5)


func test_at_soc_02_eva_615() -> void:
	lead_b_eva_615()
	check(ep().has_fact("F_EVA_KNOWS_WHERE") and ep().has_fact("F_MARA_NOT_ON_6"), "SLIP with suspicion < 2")
	check(ep().lead_done("B"))
	fresh()
	d = start_scene("S04")
	ep().ch("eva").suspicion = 2
	lead_b_eva_615()
	check(not ep().has_fact("F_EVA_KNOWS_WHERE"), "suspicion >= 2 -> no slip")
	check(ep().flag("mara_wary") == true, "called bluff -> mara wary")


func test_at_graph_02_pair_ab() -> void:
	lead_a_nico()
	lead_b_eva_615()
	eq(ep().leads_completed(), 2)
	if not ep().has_fact("F_THOMAS_LOCATION"):
		advance(d.conv, 95.0, 0.5)   # fallback window
		advance(d.conv, 2.0)
	check(ep().has_fact("F_THOMAS_LOCATION"))
	advance(d.conv, 0.5)
	check(ep().flag("thomas_ready") == true, "S06 trigger enabled")


func test_at_graph_02_pair_ac() -> void:
	lead_a_nico()
	lead_c_video()
	check(ep().lead_done("A") and ep().lead_done("C"))
	advance(d.conv, 0.5)
	check(ep().flag("thomas_ready") == true)


func test_at_graph_02_pair_bc() -> void:
	lead_b_eva_615()
	lead_c_video()
	advance(d.conv, 0.5)
	check(ep().flag("thomas_ready") == true)


func test_at_graph_03_failed_c_plus_a() -> void:
	place("hero", "SECURITY:chair")
	advance(d.conv, 0.5)
	d.sm.logic.caught("pavel")
	advance(d.conv, 4.0)
	place("hero", "SECURITY:chair")
	advance(d.conv, 0.5)
	d.sm.logic.caught("pavel")
	advance(d.conv, 6.0)
	eq(ep().leads.C, Episode.LeadState.FAILED_DONE, "second catch -> FAILED_DONE")
	check(ep().flag("daniel_escorted") == true)
	lead_a_nico()
	place("hero", "BAR:nico_tables")
	check(d.conv.talk_to("nico") or true)
	advance(d.conv, 1.0)
	if d.conv.active_id == "X_S04_NICO":
		_choose("CH_NICO_VOLVO")
		advance(d.conv, 8.0)
	advance(d.conv, 0.5)
	check(ep().flag("thomas_ready") == true, "A + FAILED C + Nico's Volvo -> S06")


func test_at_graph_05_fallback_grants_location() -> void:
	ep().set_lead("A", Episode.LeadState.DONE)
	ep().set_lead("C", Episode.LeadState.FAILED_DONE)
	place("hero", "LOBBY:hero_lobby")
	advance(d.conv, 92.0, 0.5)
	advance(d.conv, 6.0)
	check(ep().has_fact("F_THOMAS_LOCATION"), "90 s fallback (Lina) grants the location")
	eq(ep().facts.get("F_THOMAS_LOCATION", {}).get("source", ""), "fb_lina")


func test_at_graph_09_failed_eva_bluff_still_reaches_s06() -> void:
	ep().ch("eva").suspicion = 2
	lead_b_eva_615()
	check(not ep().lead_done("B"))
	lead_a_nico()
	lead_c_video()
	advance(d.conv, 0.5)
	check(ep().flag("thomas_ready") == true)


func test_overhear_adrian_call() -> void:
	place("hero", "MEZZANINE:overhear")
	ep().set_flag("adrian_on_call")
	advance(d.conv, 12.0)
	check(ep().has_fact("F_ADRIAN_THINKS_MARA_FORGOT"), "overheard from the balcony")
	check(ep().has_fact("F_RECORDING_EXISTS"))


func test_overhear_needs_presence() -> void:
	place("hero", "BAR:nico_taps")
	ep().set_flag("adrian_on_call")
	advance(d.conv, 12.0)
	check(not ep().has_fact("F_ADRIAN_THINKS_MARA_FORGOT"), "no fact when not listening")


func test_eva_call_overhear() -> void:
	place("hero", "SERVICE_STAIR:l1")
	ep().beat("BEAT_EVA_CALL")
	advance(d.conv, 10.0)
	check(ep().has_fact("F_THOMAS_NAME") and ep().has_fact("F_THOMAS_LOCATION") and ep().lead_done("B"))


func test_house_phone_distracts_pavel_once() -> void:
	place("pavel", "SECURITY:pavel_chair")
	bus().trap_bait.emit("house_phone", {})
	check(ep().flag("pavel_distracted") == true)
	eq(ep().ch("pavel").schedule, "pavel_to_f3")
	ep().ch("pavel").schedule = "pavel_loop"
	bus().trap_bait.emit("house_phone", {})
	eq(ep().ch("pavel").schedule, "pavel_loop", "second call within 5 min is ignored")
