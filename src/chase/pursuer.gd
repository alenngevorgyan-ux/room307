class_name Pursuer
extends RefCounted
## Pursuer FSM (ACTION_SEQUENCE §2). Pure logic: the ChaseDirector moves the body.
## SPAWN/IDLE → PURSUIT ⇄ SEARCH → (lost 12 s) → REGROUP; any → STUNNED / DOUBT / CONTAINED.

enum S { IDLE, PURSUIT, SEARCH, REGROUP, GRAB, STUNNED, DOUBT, CONTAINED }

var id := ""
var cfg: Dictionary = {}
var state: int = S.IDLE
var t := 0.0               # remaining time for timed states
var lost_t := 0.0
var search_t := 0.0
var zone := ""
var pos := Vector3.ZERO    # mirror of the body (sims move this directly)
var last_seen := Vector3.INF
var last_seen_zone := ""
var noise_pos := Vector3.INF
var bonus_t := 0.0         # +10% after calling a bluff
var angry := false
var hits := 0
var away_t := 0.0
var close_t := 0.0
var grab_cd := 0.0
var called_bluff := false
var lure_t := 0.0


func _init(pid: String, c: Dictionary) -> void:
	id = pid
	cfg = c


func state_name() -> String:
	return S.keys()[state]


func set_state(s: int, dur: float = 0.0) -> void:
	state = s
	t = dur
	if s == S.SEARCH:
		search_t = 0.0
	if s == S.PURSUIT:
		lost_t = 0.0


func can_act() -> bool:
	return state in [S.IDLE, S.PURSUIT, S.SEARCH, S.REGROUP]


func stun(d: float) -> void:
	if state == S.CONTAINED:
		return
	set_state(S.STUNNED, maxf(d, t if state == S.STUNNED else 0.0))


func doubt(d: float) -> void:
	if state == S.CONTAINED:
		return
	set_state(S.DOUBT, d)


func contain(d: float) -> void:
	set_state(S.CONTAINED, d)


func hear(p: Vector3, z: String) -> void:
	if state in [S.IDLE, S.SEARCH, S.REGROUP]:
		noise_pos = p
		last_seen_zone = z
		set_state(S.SEARCH)


func lure(p: Vector3, z: String, dur: float) -> void:
	if not can_act():
		return
	noise_pos = p
	last_seen_zone = z
	lure_t = dur
	set_state(S.SEARCH)


## sees: hero visible this frame.
func tick(delta: float, sees: bool, hero_pos: Vector3, hero_zone: String) -> void:
	bonus_t = maxf(0.0, bonus_t - delta)
	grab_cd = maxf(0.0, grab_cd - delta)
	lure_t = maxf(0.0, lure_t - delta)
	if sees:
		last_seen = hero_pos
		last_seen_zone = hero_zone
	match state:
		S.STUNNED, S.CONTAINED, S.DOUBT:
			t -= delta
			if t <= 0.0:
				if state == S.DOUBT:
					called_bluff = true
					bonus_t = float(cfg.get("bluff_bonus_time", 6.0))
				set_state(S.PURSUIT if sees else S.SEARCH)
		S.IDLE:
			if sees:
				set_state(S.PURSUIT)
		S.PURSUIT:
			if sees:
				lost_t = 0.0
			else:
				lost_t += delta
				if lost_t >= float(cfg.get("lost_to_search", 1.5)):
					set_state(S.SEARCH)
		S.SEARCH:
			if sees and lure_t <= 0.0:
				set_state(S.PURSUIT)
			else:
				search_t += delta
				if search_t >= float(cfg.get("search_to_regroup", 12.0)):
					set_state(S.REGROUP)
		S.REGROUP:
			if sees:
				set_state(S.PURSUIT)


func target(hero_pos: Vector3) -> Vector3:
	match state:
		S.PURSUIT:
			return hero_pos
		S.SEARCH:
			if noise_pos != Vector3.INF:
				return noise_pos
			return last_seen
		S.REGROUP:
			return last_seen
	return Vector3.INF


## Speed multiplier relative to the hero's run speed.
func speed_mult(heat: int, heat_bonus: Array) -> float:
	var m := float(cfg.get("speed", 1.0))
	m *= 1.0 + float(heat_bonus[clampi(heat, 0, heat_bonus.size() - 1)])
	if bonus_t > 0.0:
		m *= 1.0 + float(cfg.get("bluff_speed_bonus", 0.1))
	if angry:
		m *= 1.0 + float(cfg.get("angry_bonus", 0.05))
	if state in [S.SEARCH, S.REGROUP]:
		m *= 0.75
	return m
