extends TestCase
## S02 walk-and-talk through the elevator; S03 room, Lina, Daniel; AT-GRAPH-10.

var d: Dictionary


func before_each() -> void:
	fresh()


func _choose(chip: String) -> void:
	settle(d.conv)
	check(d.conv.choose_id(chip), "chip %s (have %s, x %s)" % [chip, d.conv.chips_visible.map(func(c): return c.id), d.conv.active_id])


func _to_s02() -> void:
	ep().s1_resolution = "PRIVATE_DEAL"
	ep().ch("adrian").trust = 1
	d = start_scene("S02")
	place("hero", "BAR:hero_stand")
	place("adrian", "BAR:adrian_by_hero")


func test_s02_full_walk_silence_gives_deep_line() -> void:
	_to_s02()
	advance(d.conv, 11.0)
	eq(d.conv.active_id, "X_S02_A", "brief starts after the opening beat")
	_choose("CH_S2_DANGER")
	advance(d.conv, 6.0)
	place("hero", "LOBBY:adrian_mid")
	place("adrian", "LOBBY:adrian_mid")
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S02_B")
	_choose("CH_S2_TOOK")
	advance(d.conv, 6.0)
	place("hero", "ELEV_A:hero")
	advance(d.conv, 1.0)
	check(ep().flag("elev_moving") == true, "ride started")
	advance(d.conv, 3.5)
	eq(d.conv.active_id, "X_S02_C")
	settle(d.conv)
	advance(d.conv, 10.0)   # silence on the decisive window
	check(ep().has_fact("F_ADRIAN_THINKS_MARA_FORGOT"), "trust>=1 + silence -> deep line")
	eq(ep().ch("adrian").trust, 2)
	advance(d.conv, 25.0)
	check(ep().has_item("ITEM_KEYCARD_307"), "keycard handed over on 3")
	place("hero", "HALL_3F:arrive_elev")
	advance(d.conv, 0.5)
	eq(ep().scene_id, "S03")


func test_s02_bluff_grab() -> void:
	_to_s02()
	advance(d.conv, 11.0)
	place("hero", "ELEV_A:hero")
	place("adrian", "ELEV_A:adrian")
	d.conv.end_active("SKIP")
	advance(d.conv, 4.5)
	eq(d.conv.active_id, "X_S02_C")
	_choose("CH_S2_CALLED")
	advance(d.conv, 6.0)
	check(ep().has_obs("O_S2_GRAB") and ep().has_fact("F_ADRIAN_EXPECTS_CONTACT"), "grab tell + fact")
	check(ep().threads_available.has("T_ADRIAN_FEARS_WHAT_SHE_HAS") or ep().threads_pinned.has("T_ADRIAN_FEARS_WHAT_SHE_HAS"))
	_choose("CH_S2_ADMIT")
	advance(d.conv, 6.0)
	eq(ep().ch("adrian").respect, 1)


func test_s02_call_lie_fear_hit() -> void:
	_to_s02()
	advance(d.conv, 11.0)
	d.conv.end_active("SKIP")
	place("hero", "ELEV_A:hero")
	place("adrian", "ELEV_A:adrian")
	advance(d.conv, 4.5)
	_choose("CH_S2_CALL_LIE")
	advance(d.conv, 5.0)
	_choose("CH_S2_LOST_HER")
	advance(d.conv, 4.0)
	eq(int(ep().ch("adrian").fear_hits.get("LOSE_MARA", 0)), 1)
	eq(ep().ch("adrian").trust, 0, "1 - 1")


func _to_s03() -> void:
	ep().give_item("ITEM_KEYCARD_307")
	d = start_scene("S03")
	place("hero", "HALL_3F:arrive_elev")


func test_at_graph_10_skip_room_opens_hub() -> void:
	_to_s03()
	advance(d.conv, 46.0, 0.5)
	check(ep().flag("daniel_s3_walking") == true, "Daniel comes even if 307 is skipped")
	place("daniel", "HALL_3F:daniel_mid")
	place("hero", "HALL_3F:daniel_mid")
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S03_DANIEL")
	advance(d.conv, 30.0)
	eq(ep().scene_id, "S04", "hub opens")
	check(ep().beats.has("BEAT_HUB_OPEN"))


func test_s03_lina_after_five_interactions_and_glasses() -> void:
	_to_s03()
	place("hero", "ROOM_307:enter")
	advance(d.conv, 0.5)
	for id in ["I_307_BOTTLE", "I_307_PILLS", "I_307_BAG", "I_307_MATTRESS", "I_307_SHOE_A"]:
		ActionRunner.run(data().interactables[id].actions, {"source": id})
		bus().interact_done.emit(id)
	advance(d.conv, 0.5)
	check(ep().flag("lina_in_room") == true, "Lina interrupts after 5 interactions")
	check(ep().has_obs("O_307_ZIP_WRONG") and ep().has_obs("O_307_MATTRESS_SHIFTED"))
	check(ep().threads_available.has("T_SOMEONE_SEARCHED_307"), "search thread offered")
	check(ep().threads_available.has("T_SHE_LEFT_BY_WINDOW"), "wrong window thread is formable (AT-PLAY-06)")
	place("lina", "ROOM_307:lina_desk")
	place("hero", "ROOM_307:desk")
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S03_LINA")
	_choose("CH_LINA_CALM")
	advance(d.conv, 8.0)
	check(ep().has_fact("F_MARA_LEFT_ALIVE"))
	_choose("CH_LINA_GO")
	advance(d.conv, 10.0)
	eq(ep().ch("lina").vars.get("state"), "ALLY", "calm + release -> ALLY")


func test_s03_daniel_provoke_zip() -> void:
	_to_s03()
	ep().notice("O_307_ZIP_WRONG")
	ep().set_flag("entered_room")
	place("hero", "HALL_3F:door_307")
	advance(d.conv, 0.5)
	place("daniel", "HALL_3F:daniel_mid")
	place("hero", "HALL_3F:daniel_mid")
	advance(d.conv, 0.5)
	_choose("CH_DAN_ZIP")
	advance(d.conv, 8.0)
	eq(ep().ch("daniel").suspicion, 2)
	check(ep().ch("daniel").believes_hero_knows.has("F_SECURITY_IN_307"))
