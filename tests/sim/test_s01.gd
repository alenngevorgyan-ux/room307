extends TestCase
## AT-PLAY-03 as SIM: all four S01 resolutions are reachable.

var d: Dictionary


func before_each() -> void:
	fresh()
	d = start_scene("S01")


func _talk(npc: String, chip: String) -> void:
	var conv: ConversationDirector = d.conv
	check(conv.talk_to(npc), "talk to " + npc)
	settle(conv)
	check(conv.choose_id(chip), "chip %s visible (have %s)" % [chip, conv.chips_visible.map(func(c): return c.id)])


func test_public_expose_by_camera_bluff() -> void:
	place("hero", "BAR:hale_c")   # Hale at hale_a, Selin within earshot of the hero
	_talk("hale", "CH_HALE_CAMERAS")
	advance(d.conv, 20.0)
	eq(ep().s1_resolution, "PUBLIC_EXPOSE")
	check(ep().has_fact("F_WATCH_PAWNED"))
	eq(ep().ch("adrian").respect, 1)


func test_private_deal_by_camera_bluff_alone() -> void:
	place("hale", "BAR:restroom")
	place("hero", "BAR:restroom_door")
	_talk("hale", "CH_HALE_CAMERAS")
	advance(d.conv, 9.0)
	eq(d.conv.active_id, "X_S01_HALE_ASIDE", "Hale pulls the hero aside")
	settle(d.conv)
	check(d.conv.choose_id("CH_HALE_PRIVATE"))
	settle(d.conv)
	check(d.conv.choose_id("CH_HALE_APOLOGY"))
	advance(d.conv, 10.0)
	eq(ep().s1_resolution, "PRIVATE_DEAL")
	eq(ep().ch("adrian").trust, 1)
	check(ep().flag("jules_saved") == true)


func test_private_deal_by_pawn_line() -> void:
	# learn the pawn quietly from Jules (Selin out of earshot), then confront Hale alone
	place("selin", "BAR:guest_a")
	place("hero", "BAR:jules_counter")
	ep().notice("O_S1_JULES_UNDER")
	_talk("jules", "CH_JULES_PAWN")
	advance(d.conv, 8.0)
	check(ep().has_fact("F_WATCH_PAWNED"), "Jules breaks")
	eq(ep().s1_resolution, "", "not public")
	place("hale", "BAR:restroom")
	place("hero", "BAR:restroom_door")
	_talk("hale", "CH_HALE_PAWN")
	advance(d.conv, 6.0)
	settle(d.conv)
	check(d.conv.choose_id("CH_HALE_APOLOGY_D"))
	advance(d.conv, 10.0)
	eq(ep().s1_resolution, "PRIVATE_DEAL")


func test_wrong_accuse() -> void:
	place("hero", "BAR:kai_spot")
	_talk("kai", "CH_KAI_ACCUSE")
	advance(d.conv, 6.0)
	eq(ep().s1_resolution, "WRONG_ACCUSE")
	eq(ep().ch("pavel").suspicion, 1)


func test_observe_only() -> void:
	advance(d.conv, 271.0, 0.5)
	eq(ep().s1_resolution, "OBSERVE_ONLY")
	check(ep().has_fact("F_WATCH_PAWNED"))


func test_resolution_triggers_adrian_cine() -> void:
	var cines: Array = []
	bus().cine_requested.connect(func(id): cines.append(id))
	place("hero", "BAR:kai_spot")
	_talk("kai", "CH_KAI_ACCUSE")
	advance(d.conv, 12.0)
	check(cines.has("C_S1_ADRIAN"), "Adrian two-shot plays after the resolution")


func test_leaving_early_goes_to_s02() -> void:
	place("hero", "LOBBY:arrive_bar")
	advance(d.conv, 1.0)
	check(ep().flag("s1_left_early") == true)
	eq(ep().scene_id, "S02")
