extends TestCase
## Visual Integration V1.1 — UX clarity (playtest findings 1–7): subtitle speaker labels, two-line
## subtitles, the single current objective, and the level-3 hint director.


func before_each() -> void:
	fresh()


# ------------------------------------------------------------------ speaker labels

func test_speaker_labels_strangers_until_named() -> void:
	eq(SpeakerNames.label("hero"), "ЭЛ", "the protagonist is ЭЛ")
	eq(SpeakerNames.label("daniel"), "НЕЗНАКОМЕЦ", "Daniel before he says his name")
	eq(SpeakerNames.label("nico"), "БАРМЕН", "Nico before talking")
	eq(SpeakerNames.label("voice"), "НЕЗНАКОМЕЦ", "unknown caller")
	eq(SpeakerNames.label("screen"), "", "screen text has no name line")
	eq(SpeakerNames.label("receptionist"), "АДМИНИСТРАТОР", "staff role known from the start")
	SpeakerNames.observe_line("Вы, должно быть, наш новый друг. Дэниел. Безопасность мистера Вейла.")
	eq(SpeakerNames.label("daniel"), "ДЭНИЕЛ", "self-introduction")
	eq(SpeakerNames.label("adrian"), "АДРИАН", "«мистера Вейла» names Adrian")


func test_speaker_alias_is_whole_word() -> void:
	SpeakerNames.observe_line("Никогда Мара бы так не сказала.")
	eq(SpeakerNames.label("nico"), "БАРМЕН", "«Никогда» is not «Нико»")
	eq(SpeakerNames.label("mara"), "МАРА")


func test_badge_staff_known_after_talk_only() -> void:
	SpeakerNames.on_exchange_ended("eva")
	eq(SpeakerNames.label("eva"), "НЕЗНАКОМКА", "Eva never gives her name")
	SpeakerNames.on_exchange_ended("lina")
	eq(SpeakerNames.label("lina"), "ЛИНА", "Lina wears a name badge")


func test_names_survive_checkpoint() -> void:
	SpeakerNames.mark_known("thomas")
	var saved: Dictionary = ep().to_dict()
	ep().reset()
	eq(SpeakerNames.label("thomas"), "НЕЗНАКОМЕЦ")
	ep().from_dict(saved)
	eq(SpeakerNames.label("thomas"), "ТОМАС")


func test_hiring_scene_introduces_adrian_before_the_brief() -> void:
	var st: Array = data().cines.C_S2_OPEN.start
	var keys: Array = []
	for a in st:
		if a.has("line"):
			keys.append(String(a.line))
	check(keys.find("ADR_NAME") >= 0 and keys.find("ADR_NAME") < keys.find("ADR_01"), "Адриан Вейл. comes first: %s" % [keys])


# ------------------------------------------------------------------ subtitles

## Every line in the game reads as at most two lines per page at the target 1280 px layout.
func test_every_line_pages_to_two_lines() -> void:
	var font: Font = ThemeDB.fallback_font
	var width := 1280.0 * HUD.SUB_WIDTH_FRAC
	var paged := 0
	for k in data().lines_ru:
		var text := String(data().lines_ru[k].get("text", ""))
		var pages: Array = HUD.paginate(text, font, HUD.SUB_SIZE, width)
		check(not pages.is_empty(), "%s has pages" % k)
		var joined := " ".join(pages)
		eq(joined.replace(" ", ""), text.replace(" ", ""), "%s: paging keeps every word" % k)
		for p in pages:
			check(HUD._lines(String(p), font, HUD.SUB_SIZE, width) <= 2, "%s page over two lines: %s" % [k, p])
		if pages.size() > 1:
			paged += 1
	check(paged < 20, "long lines are the exception (%d paged)" % paged)


func test_sentence_split_prefers_sentence_ends() -> void:
	var font: Font = ThemeDB.fallback_font
	var long := "Была старая история. Авария. Ей было семнадцать, она спала сзади. Она ничего не помнит. Слава богу. Это всё, что вам нужно знать об этой семье, и больше я ничего не скажу."
	var pages: Array = HUD.paginate(long, font, 24, 520.0)
	check(pages.size() >= 2, "split")
	var sentence_ends := 0
	for i in pages.size() - 1:
		var s := String(pages[i])
		if s.ends_with(".") or s.ends_with("?") or s.ends_with("!") or s.ends_with("…"):
			sentence_ends += 1
	check(sentence_ends >= pages.size() - 2, "pages break at sentence ends where they fit: %s" % [pages])


# ------------------------------------------------------------------ objectives

func test_objectives_data_is_valid() -> void:
	var D := data()
	check(D.objectives.size() >= 10, "objectives loaded")
	for id in D.objectives:
		var o: Dictionary = D.objectives[id]
		check(String(o.get("text", "")).length() > 3, "%s has text" % id)
		check(String(o.get("text", "")).length() <= 48, "%s is one short line" % id)
		check(o.has("when"), "%s has a condition" % id)
		for n in o.get("nudges", []):
			check(String(n.get("text", "")) != "", "%s nudge text" % id)
			check(float(n.get("after", 0)) >= 30.0, "%s nudges only after a real stall" % id)
			if n.has("zone"):
				check(D.level.has(String(n.zone)), "%s nudge zone %s exists" % [id, n.zone])


func test_objective_opening_and_hire() -> void:
	var d := start_scene("S01")
	eq(Objectives.current_id(), "O_BAR", "bar incident first")
	ep().s1_resolution = "PRIVATE_DEAL"
	d.sm.goto_scene("S02")
	place("hero", "BAR:hero_stand")
	place("adrian", "BAR:adrian_by_hero")
	eq(Objectives.current_id(), "O_FOLLOW_ADRIAN", "follow the client while he talks")
	check(wait_until(d.conv, func(): return d.conv.active_id == "X_S02_A", 30.0), "brief starts")
	eq(Objectives.current_id(), "O_FIND_MARA", "the brief makes the goal explicit")
	eq(Objectives.current().sub, "Последнее известное место: номер 307.")


# ------------------------------------------------------------------ level-3 hints

func _hint_director() -> HintDirector:
	var h := HintDirector.new()
	h.set_meta("sim_node", true)
	h.set_process(false)
	tree.root.add_child(h)
	return h


func test_hint_nudge_after_stall_in_zone() -> void:
	var d := start_scene("S03")
	var h := _hint_director()
	place("hero", "HALL_3F:arrive_elev")
	var said: Array = []
	var cb := func(t: String, _dur: float): said.append(t)
	bus().thought_requested.connect(cb)
	for i in 30 * 4:
		h.tick(0.25)
	check(said.is_empty(), "nothing before the stall threshold")
	for i in 10 * 4:
		h.tick(0.25)
	check(said.has("307 должна быть на этом этаже."), "zone nudge after ~35 s without progress: %s" % [said])
	var n := said.size()
	for i in 200 * 4:
		h.tick(0.25)
	eq(said.count("307 должна быть на этом этаже."), 1, "each nudge at most once")
	bus().thought_requested.disconnect(cb)
	h.free()
	check(n >= 1)


func test_hint_progress_resets_stall_and_conversation_blocks() -> void:
	var d := start_scene("S03")
	var h := _hint_director()
	place("hero", "HALL_3F:arrive_elev")
	var said: Array = []
	var cb := func(t: String, _dur: float): said.append(t)
	bus().thought_requested.connect(cb)
	for i in 25 * 4:
		h.tick(0.25)
	ep().give_fact("F_SERVICE_STAIR", "test")   # progress
	for i in 25 * 4:
		h.tick(0.25)
	check(said.is_empty(), "progress resets the stall clock")
	# a conversation in progress is never interrupted by a thought
	d.conv.auto_triggers = false
	check(d.conv.start(String(data().exchanges.keys()[0]), true), "an exchange is active")
	for i in 120 * 4:
		h.tick(0.25)
	check(said.is_empty(), "no thought during a conversation: %s" % [said])
	d.conv.end_active("TEST")
	for i in 40 * 4:
		h.tick(0.25)
	check(not said.is_empty(), "the nudge comes once the conversation is over")
	bus().thought_requested.disconnect(cb)
	h.free()


# ------------------------------------------------------------------ V1.6 proxies

## Every principal has a canon proxy, and they are differentiated (no identical capsules).
func test_cast_proxies_are_distinct() -> void:
	var cast := ["hero", "adrian", "mara", "nico", "daniel", "eva", "thomas", "lina", "pavel"]
	var seen: Dictionary = {}
	for id in cast:
		var s: Dictionary = BodyVisual.proxy_spec(id)
		check(not s.is_empty(), "%s has a proxy" % id)
		if s.is_empty():
			continue
		var sig := "%s|%s|%s|%s|%s" % [s.height, s.build, s.hair.style, s.jacket.style, s.lower.style]
		check(not seen.has(sig), "%s silhouette differs from %s" % [id, seen.get(sig, "")])
		seen[sig] = id
	var el: Dictionary = BodyVisual.proxy_spec("hero")
	eq(el.hair.style, "curly_volume", "EL: dark wavy hair mass")
	check(el.acc.has("ring"), "EL: the subtle ring")
	eq(el.jacket.style, "overshirt", "EL: short dark overshirt, no detective costume")
