extends TestCase
## AT-PLAY-13 as SIM: each stop method, silence-only playthrough (guaranteed facts), fail-forward.

const GUARANTEED := ["F_THOMAS_TOOK_BLAME", "F_ADRIAN_WAS_DRIVING", "F_RECORDING_EXISTS", "F_ADRIAN_THINKS_MARA_FORGOT"]

var d: Dictionary
var cines: Array = []


func before_each() -> void:
	fresh()
	cines = []
	ep().give_fact("F_MARA_MET_OLDER_MAN")
	d = start_scene("S06")
	bus().cine_requested.connect(func(id): cines.append(id))
	place("hero", "LOADING_DOCK:enter")
	place("thomas", "LOADING_DOCK:thomas_edge")


func _choose(chip: String) -> void:
	settle(d.conv)
	check(d.conv.choose_id(chip), "chip %s (have %s in %s)" % [chip, d.conv.chips_visible.map(func(c): return c.id), d.conv.active_id])


func _approach() -> void:
	place("hero", "LOADING_DOCK:hero_block")
	advance(d.conv, 0.5)
	eq(d.conv.active_id, "X_S06_STOP")


func _finish() -> void:
	advance(d.conv, 120.0, 0.25)
	for f in GUARANTEED:
		check(ep().has_fact(f), "guaranteed " + f)
	check(cines.has("C_S6_VAN"), "van cine")


func test_stop_mara_then_silence_only() -> void:
	_approach()
	_choose("CH_TH_MARA")
	advance(d.conv, 3.0)
	check(ep().flag("th_stopped") == true)
	eq(d.conv.active_id, "X_S06_TALK")
	_finish()
	eq(ep().ch("thomas").trust, 2, "Мара +1, silence +1")


func test_stop_police_is_cold() -> void:
	ep().give_fact("F_MARA_MET_OLDER_MAN")
	ep().notice("O_THOMAS_PHOTO")
	_approach()
	_choose("CH_TH_POLICE")
	advance(d.conv, 4.0)
	check(ep().flag("th_cold") == true)
	_finish()
	check(not ep().has_fact("F_THOMAS_PAID_SON"), "police lie skips the personal part")


func test_stop_daniel_trap() -> void:
	_approach()
	_choose("CH_TH_DANIEL")
	advance(d.conv, 5.0)
	check(ep().trap_state.get("TR_THOMAS_DANIEL", {}).get("fired", false))
	check(ep().ch("thomas").vars.get("fear_daniel") == true)
	_finish()


func test_stop_keys() -> void:
	ep().set_flag("keys_on_edge")
	ActionRunner.run(data().interactables.I_S6_KEYS.actions, {"source": "I_S6_KEYS"})
	check(ep().has_item("ITEM_VOLVO_KEYS"))
	eq(ep().ch("thomas").trust, -1)
	_finish()


func test_stop_block() -> void:
	var logic: Node = d.sm.logic
	logic.set_meta("force", true)
	place("hero", "LOADING_DOCK:thomas_edge")
	logic.try_block(0.4)
	check(not ep().flag("th_stopped"), "first block -> sidestep")
	logic.try_block(0.4)
	check(ep().flag("th_stopped") == true, "second block -> stop")
	eq(ep().flag("th_method"), "block")
	_finish()


func test_son_with_photo() -> void:
	ep().notice("O_THOMAS_PHOTO")
	_approach()
	_choose("CH_TH_MARA")
	advance(d.conv, 3.0)
	_choose("CH_TH_DRIVER")
	_choose("CH_TH_FORWHOM")
	_choose("CH_TH_SON")
	_finish()
	check(ep().has_fact("F_THOMAS_PAID_SON") and ep().has_fact("F_THOMAS_CONSENTED"))


func test_fail_forward_drove_off() -> void:
	ep().set_flag("th_drove")
	advance(d.conv, 0.5)
	check(ep().flag("th_compressed") == true)
	_finish()


func test_handoff_to_s07() -> void:
	_approach()
	_choose("CH_TH_MARA")
	advance(d.conv, 120.0, 0.25)
	advance(d.conv, 9.0)
	eq(ep().scene_id, "S07")
	check(ep().threat.daniel_knows_hero_met_thomas)
