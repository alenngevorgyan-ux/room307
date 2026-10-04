extends TestCase
## Input lock (M1), ActionRunner verbs (M2), conditions, threads, save/load.


func before_each() -> void:
	fresh()


func test_input_basis_stable_during_blend() -> void:
	var ib := InputBasis.new()
	var fwd := Vector2(0, 1)
	var d0 := ib.world_dir(fwd, 0.0)
	check(d0.distance_to(Vector3(0, 0, -1)) < 0.01, "W goes -Z with yaw 0")
	# camera swings 90° while W is held: direction must not change
	var d1 := ib.world_dir(fwd, PI / 2)
	check(d1.distance_to(d0) < 0.01, "locked through the blend")
	var d2 := ib.world_dir(fwd, PI / 2)
	check(d2.distance_to(d0) < 0.01, "still locked while held")
	# release -> re-sync to the new camera
	ib.world_dir(Vector2.ZERO, PI / 2)
	var d3 := ib.world_dir(fwd, PI / 2)
	check(d3.distance_to(Vector3(-1, 0, 0)) < 0.01, "after release W follows the new rig")


func test_action_runner_core_verbs() -> void:
	ActionRunner.run([{"give_fact": ["F_OLD_ACCIDENT", "t"]}, {"flag": "x"}, {"give_item": "ITEM_KEYCARD_307"},
		{"trust": ["adrian", 1]}, {"stress": ["kai", 5]}, {"lead": ["A", "DONE"]}, {"beat": "BEAT_HUB_OPEN"},
		{"fear_hit": ["adrian", "LOSE_MARA"]}, {"set_disposition": ["kai", "HOSTILE"]}, {"set": ["finale.lights", "full"]}])
	check(ep().has_fact("F_OLD_ACCIDENT"))
	eq(ep().facts.F_OLD_ACCIDENT.source, "t")
	check(ep().flag("x") == true)
	check(ep().has_item("ITEM_KEYCARD_307"))
	eq(ep().ch("adrian").trust, 1)
	eq(ep().ch("kai").stress, 3, "stress clamps at 3")
	check(ep().lead_done("A"))
	check(ep().beats.has("BEAT_HUB_OPEN"))
	eq(int(ep().ch("adrian").fear_hits.LOSE_MARA), 1)
	eq(ep().ch("kai").disposition_name(), "HOSTILE")
	eq(ep().finale.lights, "full")
	ActionRunner.run([{"take_item": "ITEM_KEYCARD_307"}, {"unflag": "x"}])
	check(not ep().has_item("ITEM_KEYCARD_307"))
	check(ep().flag("x") == null)


func test_action_if_and_delay() -> void:
	ActionRunner.run([{"if": "flag:nope", "then": [{"flag": "a"}], "else": [{"flag": "b"}]},
		{"delay": 1.0, "do": [{"flag": "c"}]}])
	check(ep().flag("a") == null and ep().flag("b") == true)
	check(ep().flag("c") == null, "delayed not yet")
	ActionRunner.tick(1.1)
	check(ep().flag("c") == true, "delayed ran")


func test_conditions() -> void:
	check(Conditions.check(null, ep()))
	check(not Conditions.check("F_OLD_ACCIDENT", ep()))
	ep().give_fact("F_OLD_ACCIDENT")
	check(Conditions.check(["F_OLD_ACCIDENT", "!flag:z"], ep()))
	check(Conditions.check({"any_n": 1, "of": ["F_X_NOPE", "F_OLD_ACCIDENT"]}, ep()))
	check(not Conditions.check({"none": ["F_OLD_ACCIDENT"]}, ep()))
	check(Conditions.check({"npc_state": {"adrian": {"trust_gte": 0, "stress_lt": 3}}}, ep()))
	check(Conditions.check({"cmp": ["s1_resolution", "==", ""]}, ep()))
	Presence.place("a", "BAR", Vector3.ZERO)
	Presence.place("b", "BAR", Vector3(3, 0, 0))
	check(Conditions.check("near:a:b:4", ep()) and not Conditions.check("near:a:b:2", ep()))


func test_threads_offer_pin_max3() -> void:
	ep().notice("O_S1_WRIST_TAN")
	check(not ep().threads_available.has("T_WATCH_NOT_STOLEN"))
	ep().notice("O_S1_UNPAID_TAB")
	check(ep().threads_available.has("T_WATCH_NOT_STOLEN"), "2 of N offers")
	ep().pin_thread("T_WATCH_NOT_STOLEN")
	check(ep().threads_pinned.has("T_WATCH_NOT_STOLEN"))
	for t in ["T_EX_BOYFRIEND", "T_307_STAGED", "T_SHE_LEFT_BY_WINDOW"]:
		ep().offer_thread(t)
		ep().pin_thread(t)
	eq(ep().threads_pinned.size(), 3, "max 3 pinned")
	check(not ep().threads_pinned.has("T_WATCH_NOT_STOLEN"), "oldest replaced")
	check(ep().threads_available.has("T_WATCH_NOT_STOLEN"), "replaced goes back to available")


func test_save_load_roundtrip() -> void:
	ActionRunner.run([{"give_fact": "F_OLD_ACCIDENT"}, {"trust": ["adrian", 2]}, {"lead": ["B", "FAILED_DONE"]},
		{"set": ["finale.recorder", "vase"]}, {"phone_msg": ["eva", "hi"]}])
	ep().notice("O_S1_WRIST_TAN")
	var before: Dictionary = ep().to_dict()
	var path := "user://test_save.json"
	ep().save_game(path)
	ep().reset()
	check(ep().load_game(path))
	var after: Dictionary = ep().to_dict()
	eq(JSON.stringify(after), JSON.stringify(before), "F1 dump identical after load (AT-ROB-01 logic)")


func test_leads_terminal() -> void:
	ep().set_lead("C", Episode.LeadState.FAILED_DONE)
	ep().set_lead("C", Episode.LeadState.ACTIVE)
	check(ep().lead_done("C"), "FAILED_DONE is terminal and counts")
	eq(ep().leads_completed(), 1)


## Playtest finding 8: a key held through a door keeps walking INTO the new room even when the
## arrival camera faces the other way (BAR_LOBBY <-> LOBBY_BAR used to ping-pong).
func test_input_basis_carries_through_doors() -> void:
	var b := InputBasis.new()
	var key := Vector2(1, 0)                       # "right"
	var bar_yaw := deg_to_rad(-150.0)
	var d0 := b.world_dir(key, bar_yaw)             # walking toward the bar's W arch
	check(d0.dot(Vector3(-1, 0, 0)) > 0.3, "setup: right walks west in the bar camera")
	b.carry_through(d0, Vector3(1, 0, 0))   # arrive through the lobby's W arch (normal +x)
	for cam_yaw in [0.0, deg_to_rad(-150.0), deg_to_rad(35.0), deg_to_rad(90.0)]:
		var d := b.world_dir(key, cam_yaw)
		check(d.dot(Vector3(1, 0, 0)) > 0.9, "held key walks into the room (cam %.0f°): %s" % [rad_to_deg(cam_yaw), d])
	b.world_dir(Vector2.ZERO, 0.0)                  # release re-syncs to the live camera
	check(b.world_dir(key, 0.0).dot(Vector3(1, 0, 0)) > 0.9 and not b.locked, "release unlocks")
