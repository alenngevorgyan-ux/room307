extends TestCase
## S07 SIM: tools apply their effects, grab #1 struggle, grab #2 -> interrogation -> resume,
## the BCORR end condition hands off to S08 (AT-PLAY-15/16 logic).

var d: Dictionary
var ch: ChaseDirector
var cines: Array = []


func before_each() -> void:
	fresh()
	cines = []
	ep().threat.daniel_knows_hero_met_thomas = true
	d = start_scene("S07")
	ch = d.chase
	bus().cine_requested.connect(func(id): cines.append(id))
	check(ch.active, "chase started")


func _put(id: String, marker: String) -> void:
	place(id, marker)
	if ch.pursuers.has(id):
		ch.pursuers[id].zone = data().marker_zone(marker)
		ch.pursuers[id].pos = data().marker(marker)


func test_tools_apply_effects() -> void:
	var b: Pursuer = ch.pursuers.brody
	var s: Pursuer = ch.pursuers.sato
	# car alarm (needs keys)
	check(not ch.apply_tool("car_alarm"), "no keys -> no alarm")
	ep().give_item("ITEM_VOLVO_KEYS")
	_put("brody", "LOADING_DOCK:brody_start")
	check(ch.apply_tool("car_alarm"))
	eq(b.state_name(), "SEARCH")
	check(b.lure_t > 0.0)
	# roll cart
	_put("brody", "LOADING_DOCK:cart")
	ch.apply_tool("roll_cart")
	eq(b.state_name(), "STUNNED")
	# steam
	_put("sato", "LAUNDRY:press")
	ch.apply_tool("steam")
	eq(s.state_name(), "STUNNED")
	# laundry cart blocks the door for Brody
	ch.apply_tool("laundry_cart_door")
	check(ch.door_block.has("LAUNDRY_SCORR"))
	# sheets
	ch.apply_tool("sheets")
	check(ch.effects.has("los_break"))
	# pots noise lure
	b.set_state(Pursuer.S.SEARCH)
	_put("brody", "KITCHEN:mid")
	ch.apply_tool("pots")
	eq(b.noise_pos, data().marker("KITCHEN:pots"))
	# bottle pick + throw
	ch.apply_tool("bottle_pick")
	check(ep().has_item("ITEM_BOTTLE"))
	place("hero", "KITCHEN:mid")
	b.set_state(Pursuer.S.SEARCH)
	ch.apply_tool("throw_bottle", {"at": data().marker("KITCHEN:rest_door")})
	check(not ep().has_item("ITEM_BOTTLE"))
	eq(b.noise_pos, data().marker("KITCHEN:rest_door"))
	# suppression (one use)
	check(ch.apply_tool("suppression"))
	check(ch.effects.has("suppression"))
	check(not ch.apply_tool("suppression"), "one use")
	# freezer lock-in
	b.set_state(Pursuer.S.SEARCH)
	_put("brody", "COLD_STORAGE:freezer_in")
	_put("sato", "COLD_STORAGE:enter")
	s.set_state(Pursuer.S.SEARCH)
	check(ch.apply_tool("freezer_latch"))
	eq(b.state_name(), "CONTAINED")
	check(s.angry, "partner angry")
	# breaker
	ch.apply_tool("breaker")
	check(ch.effects.has("blackout"))
	# radio bluff on Brody -> doubt
	ch.apply_tool("radio_pick")
	b.set_state(Pursuer.S.PURSUIT)
	_put("brody", "STAFF_CORRIDOR:mid")
	_put("sato", "LAUNDRY:worker")
	place("hero", "STAFF_CORRIDOR:radio")
	ch.heat = 1
	check(ch.apply_tool("radio_bluff"))
	eq(b.state_name(), "DOUBT")
	# fire alarm (once) -> public mode
	check(ch.apply_tool("fire_alarm"))
	check(ch._is_public("SCORR"))
	check(not ch.apply_tool("fire_alarm"))
	# fire door needs the keycard
	check(not ch.apply_tool("fire_door"))
	ep().give_item("ITEM_STAFF_KEYCARD")
	_put("sato", "LAUNDRY:worker")
	s.set_state(Pursuer.S.SEARCH)
	check(ch.apply_tool("fire_door"))
	eq(s.state_name(), "CONTAINED")
	# cart wall
	s.set_state(Pursuer.S.SEARCH)
	b.set_state(Pursuer.S.SEARCH)
	_put("brody", "SCORR:mid")
	_put("sato", "SCORR:mid")
	ch.apply_tool("cart_wall")
	check(b.t > s.t, "Brody blocked longer than Sato (vaults)")
	# freight decoy
	b.set_state(Pursuer.S.SEARCH)
	ch.apply_tool("freight_decoy")
	eq(b.state_name(), "CONTAINED")
	eq(ep().flag("freight_floor"), "3")
	# stair drop
	ch.apply_tool("stair_drop")
	eq(Presence.in_zone("hero"), "SERVICE_STAIR")
	# lockers: hide once, second time found
	ch.apply_tool("locker", {"id": "locker_1"})
	eq(ch.hidden, "locker_1")
	ch.apply_tool("unhide")
	eq(ch.hidden, "")
	check(ch.used_tools.size() >= 10, "≥10 distinct tools used: %d" % ch.used_tools.size())


func test_sato_calls_bluff_at_high_heat() -> void:
	ch.apply_tool("radio_pick")
	var s: Pursuer = ch.pursuers.sato
	_put("sato", "STAFF_CORRIDOR:mid")
	_put("brody", "LAUNDRY:worker")
	place("hero", "STAFF_CORRIDOR:radio")
	ch.heat = 3
	check(not ch.apply_tool("radio_bluff"), "Sato calls it: knows hero met Thomas + heat 3")
	check(s.bonus_t > 0.0)


func test_grab_one_struggle_frees() -> void:
	ch.grab("brody")
	check(ch.struggling)
	ch.tap()
	ch.tap()
	ch.tap()
	ch.tick(0.05)
	check(not ch.struggling)
	eq(ch.pursuers.brody.state_name(), "STUNNED", "won struggle stuns Brody")
	eq(ep().threat.grabs, 1)


func test_grab_two_interrogation_then_resume() -> void:
	ep().give_item("ITEM_MARA_PHONE")
	ch.grab("brody")
	ch.tick(1.5)        # lose the struggle (no taps): still free
	check(not ch.struggling)
	ch.grab("brody")
	check(ch.interrogation, "grab #2 -> interrogation")
	eq(Presence.in_zone("hero"), "COLD_STORAGE")
	advance(d.conv, 1.0)
	eq(d.conv.active_id, "X_S07_INTERROG")
	eq(ep().holder_of("ITEM_HERO_PHONE"), "sato", "phone confiscated")
	check(ep().flag("phone_confiscated") == true)
	settle(d.conv)
	check(d.conv.choose_id("CH_INT_ADRIAN"))
	advance(d.conv, 6.0)
	check(ep().flag("interrog_window") == true, "escape window opens")
	ch.apply_tool("kick_crates")
	check(not ch.interrogation, "escaped")
	check(ch.active, "chase resumes")
	eq(ch.heat, 3)
	eq(ep().threat.grabs, 0)


func test_interrogation_worst_case_thomas() -> void:
	ch.grab("brody")
	ch.tick(1.5)
	ch.grab("brody")
	advance(d.conv, 30.0, 0.25)   # silence twice -> 2 bad choices -> Thomas
	check(not ch.interrogation, "Thomas slams a crate: escape guaranteed")
	check(ep().flag("thomas_saved") == true)


func test_end_in_bcorr_goes_to_s08() -> void:
	_put("brody", "LAUNDRY:worker")
	_put("sato", "LAUNDRY:worker")
	place("hero", "BCORR:mid")
	advance(d.conv, 1.5)
	check(ch.finished)
	check(cines.has("C_S7_MARA"))


func test_end_timeout_even_if_followed() -> void:
	place("hero", "BCORR:end_zone")
	_put("sato", "BCORR:end_zone")
	ch.pursuers.sato.set_state(Pursuer.S.PURSUIT)
	ch.pursuers.brody.contain(999.0)
	advance(d.conv, 31.0, 0.25)
	check(ch.finished, "30 s in BCORR -> Mara intervenes")


func test_cross_door_arrival() -> void:
	_put("sato", "LAUNDRY:enter")
	ch.pursuers.sato.set_state(Pursuer.S.PURSUIT)
	place("hero", "SCORR:mid")
	ch.hero_traversed("LAUNDRY_SCORR")
	check(not ch._arrivals.is_empty(), "arrival scheduled")
	ch.tick(3.0)
	eq(ch.pursuers.sato.zone, "SCORR", "Sato comes through the same door")


func test_regroup_pursuer_reappears_in_hero_zone() -> void:
	_put("brody", "LOADING_DOCK:van")
	ch.pursuers.brody.set_state(Pursuer.S.SEARCH)
	place("hero", "KITCHEN:mid")
	for i in 40:
		ch.tick(0.25)
	eq(ch.pursuers.brody.zone, "KITCHEN", "rubber-band keeps pressure")
