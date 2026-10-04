extends TestCase
## AT-SOC-01, 03, 04, 05 + resolver basics.


func before_each() -> void:
	fresh()


func test_at_soc_01_called_on_contradiction() -> void:
	var j: CharacterState = ep().ch("jules")
	var s0 := j.suspicion
	var t0 := j.trust
	var r := SocialResolver.resolve("jules", "C_CAMERAS_RECORDED", [])
	eq(r, "CALLED", "jules knows the dome is dead")
	eq(j.suspicion, s0 + 1, "suspicion +1")
	eq(j.trust, t0 - 1, "trust -1")
	check(j.caught_hero_lying, "caught_hero_lying set")
	check(not j.believes_hero_knows.has("F_CAMERA_FOOTAGE"), "called claim doesn't add belief")


func test_at_soc_03_feared_audience_plus_one() -> void:
	var a := SocialResolver.pressure("hale", "C_CAMERAS_RECORDED", [])
	var b := SocialResolver.pressure("hale", "C_CAMERAS_RECORDED", ["selin"])
	eq(b - a, 1, "selin is hale's feared audience")
	var c := SocialResolver.pressure("hale", "C_CAMERAS_RECORDED", ["kai"])
	eq(c - a, 0, "kai is not")


func test_at_soc_04_belief_after_uncalled_claim() -> void:
	var h: CharacterState = ep().ch("hale")
	var r := SocialResolver.resolve("hale", "C_CAMERAS_RECORDED", [])
	check(r != "CALLED", "hale can't call the camera bluff")
	check(h.believes_hero_knows.has("F_CAMERA_FOOTAGE"), "believes_hero_knows has claim.about")
	eq(int(h.fear_hits.get("EXPOSED", 0)), 1, "fear hit recorded")


func test_at_soc_05_stress_decay() -> void:
	var k: CharacterState = ep().ch("kai")
	var start := k.start_stress
	k.stress = mini(3, start + 1)
	var raised := k.stress
	ep().tick(44.0)
	eq(k.stress, raised, "no decay before 45 s")
	ep().tick(1.5)
	eq(k.stress, raised - 1, "decays 1 after 45 s")
	ep().tick(200.0)
	eq(k.stress, start, "never below start value")


func test_stress_no_decay_in_conversation() -> void:
	var k: CharacterState = ep().ch("kai")
	k.stress = 3
	ep().active_exchange_npc = "kai"
	ep().tick(100.0)
	eq(k.stress, 3, "no decay while in conversation")


func test_pressure_thresholds() -> void:
	# hale: EXPOSED 3 + stress 2 - savvy 0 = 5 -> SLIP
	eq(SocialResolver.resolve("hale", "C_SAW_YOU", []), "SLIP")
	var k: CharacterState = ep().ch("kai")
	k.stress = 0
	eq(SocialResolver.resolve("kai", "C_KAI_TOOK", []), "DEFLECT")


func test_override_wins() -> void:
	eq(SocialResolver.resolve("selin", "C_HALE_LOST_MONEY", []), "CALLED", "no tab known -> called")
	fresh()
	ep().notice("O_S1_UNPAID_TAB")
	eq(SocialResolver.resolve("selin", "C_HALE_LOST_MONEY", []), "SLIP", "tab known -> slip")
