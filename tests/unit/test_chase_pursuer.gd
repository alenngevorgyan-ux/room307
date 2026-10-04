extends TestCase
## Pursuer FSM unit tests (M11).

func _p() -> Pursuer:
	return Pursuer.new("brody", {"speed": 0.9, "lost_to_search": 1.5, "search_to_regroup": 12.0, "bluff_bonus_time": 6.0, "bluff_speed_bonus": 0.1})


func test_pursuit_search_regroup() -> void:
	var p := _p()
	p.tick(0.1, true, Vector3(1, 0, 0), "Z")
	eq(p.state_name(), "PURSUIT")
	p.tick(1.0, false, Vector3.ZERO, "Z")
	eq(p.state_name(), "PURSUIT", "short loss keeps pursuit")
	p.tick(0.6, false, Vector3.ZERO, "Z")
	eq(p.state_name(), "SEARCH", "lost 1.5 s -> search")
	eq(p.target(Vector3(9, 0, 9)), Vector3(1, 0, 0), "search goes to last seen")
	p.tick(12.1, false, Vector3.ZERO, "Z")
	eq(p.state_name(), "REGROUP", "lost 12 s -> regroup")
	p.tick(0.1, true, Vector3.ZERO, "Z")
	eq(p.state_name(), "PURSUIT")


func test_stun_doubt_contain() -> void:
	var p := _p()
	p.set_state(Pursuer.S.PURSUIT)
	p.stun(1.0)
	eq(p.state_name(), "STUNNED")
	check(not p.can_act())
	p.tick(1.1, false, Vector3.ZERO, "Z")
	eq(p.state_name(), "SEARCH")
	p.doubt(2.0)
	p.tick(2.1, true, Vector3.ZERO, "Z")
	eq(p.state_name(), "PURSUIT", "doubt ends -> called bluff pursuit")
	check(p.bonus_t > 0.0 and p.called_bluff, "+10% for 6 s")
	check(p.speed_mult(0, [0.0]) > 0.9 * 1.09)
	p.contain(20.0)
	p.stun(1.0)
	eq(p.state_name(), "CONTAINED", "stun can't override containment")
	p.tick(20.1, false, Vector3.ZERO, "Z")
	eq(p.state_name(), "SEARCH")


func test_noise_lure() -> void:
	var p := _p()
	p.set_state(Pursuer.S.SEARCH)
	p.hear(Vector3(5, 0, 5), "Z")
	eq(p.target(Vector3.ZERO), Vector3(5, 0, 5))
	p.lure(Vector3(7, 0, 0), "Z", 4.0)
	p.tick(0.5, true, Vector3.ZERO, "Z")
	eq(p.state_name(), "SEARCH", "lured pursuer ignores the hero briefly")


func test_heat_speed() -> void:
	var p := _p()
	check(p.speed_mult(3, [0, 0.03, 0.06, 0.09]) > p.speed_mult(0, [0, 0.03, 0.06, 0.09]))
