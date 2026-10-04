extends TestCase
## Conversation director: chips, silence, leave, trap precedence (AT-SOC basics + AT-ROB-03 leave).

var d: Dictionary


func before_each() -> void:
	fresh()
	d = make_directors()
	ep().scene_id = "S01"
	place("hero", "BAR:hero_stand")
	place("kai", "BAR:kai_spot")
	place("hale", "BAR:hale_a")
	place("selin", "BAR:selin_spot")
	place("jules", "BAR:jules_a")


func test_talk_chips_and_choose() -> void:
	var conv: ConversationDirector = d.conv
	check(conv.talk_to("kai"), "kai talk exchange opens")
	settle(conv)
	check(conv.chips_visible.size() >= 2, "chips shown")
	conv.choose_id("CH_KAI_HANDS")
	advance(conv, 8.0)
	eq(conv.active_id, "", "exchange ended")
	check(ep().seen_exchanges.has("X_S01_KAI"))


func test_silence_branch() -> void:
	var conv: ConversationDirector = d.conv
	var said: Array = []
	bus().line_started.connect(func(s, t, _d): said.append(t))
	conv.talk_to("kai")
	settle(conv)
	advance(conv, 7.0)   # chip timeout 6 s -> silence
	check(said.has(data().line("KAI_B1").text), "silence line played")


func test_leave_branch() -> void:
	var conv: ConversationDirector = d.conv
	conv.talk_to("kai")
	settle(conv)
	place("hero", "BAR:restroom")
	advance(conv, 2.0)
	eq(conv.active_id, "", "walking away ends the exchange (LEAVE)")


func test_repeatable_needs_new_knowledge() -> void:
	var conv: ConversationDirector = d.conv
	conv.talk_to("kai")
	settle(conv)
	conv.choose_id("CH_KAI_HANDS")
	advance(conv, 8.0)
	check(not conv.talk_to("kai"), "no re-open without new info")
	ep().notice("O_S1_KAI_STAYS")
	check(conv.talk_to("kai"), "re-opens after a new observation")
