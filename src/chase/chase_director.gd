class_name ChaseDirector
extends Node
## Scene 07 (ACTION_SEQUENCE): heat 0–3, pursuer FSMs, cross-door spawning, rubber-band,
## grabs + struggle, the interrogation fail-forward, chase tools, the BCORR end condition.
## Works with 3D bodies (NPC with external_control) or headless (sims move Pursuer.pos).

const PURSUER_IDS := ["brody", "sato"]

var active := false
var cfg: Dictionary = {}
var pursuers: Dictionary = {}      # id -> Pursuer
var heat := 1
var _seen_t := 0.0
var _unseen_t := 0.0
var struggling := false
var struggle_t := 0.0
var taps := 0
var _struggler := ""
var interrogation := false
var interrog_t := 0.0
var bcorr_t := 0.0
var finished := false
var effects: Dictionary = {}        # name -> remaining seconds
var used_tools: Dictionary = {}
var lockers_used: Dictionary = {}
var hidden := ""                    # "" | "locker_1" | "cloth" ...
var _hide_check_t := 0.0
var _shove_cd := 0.0
var _arrivals: Array = []           # [{id, t, door}]
var door_block: Dictionary = {}     # door_id -> {brody: s, sato: s}
var _rng := RandomNumberGenerator.new()
var _music := ""


func _ready() -> void:
	Services.chase = self
	_rng.seed = 7
	var B := get_node("/root/Bus")
	B.trap_bait.connect(_on_bait)
	B.noise.connect(_on_noise)


func _exit_tree() -> void:
	if Services.chase == self:
		Services.chase = null


func _ep() -> Node:
	return get_node("/root/Episode")


func _data() -> Node:
	return get_node("/root/Data")


func _bus() -> Node:
	return get_node("/root/Bus")


func run(actions: Variant) -> void:
	ActionRunner.run(actions, {"source": "chase"})


# ================================================================== lifecycle

func load_cfg() -> void:
	cfg = _data().chase.duplicate(true)


func start() -> void:
	load_cfg()
	active = true
	finished = false
	heat = 1
	struggling = false
	interrogation = false
	bcorr_t = 0.0
	effects = {}
	used_tools = {}
	lockers_used = {}
	hidden = ""
	_arrivals = []
	door_block = {}
	_ep().threat.grabs = 0
	_ep().threat.heat = heat
	_ep().set_flag("chase_active")
	pursuers = {}
	for id in PURSUER_IDS:
		var c: Dictionary = cfg.duplicate(true)
		c.erase("pursuers")
		c.merge(cfg.get("pursuers", {}).get(id, {}), true)
		var p := Pursuer.new(id, c)
		p.zone = Presence.in_zone(id)
		p.pos = Presence.pos.get(id, Vector3.ZERO)
		p.set_state(Pursuer.S.PURSUIT)
		p.last_seen = Presence.pos.get("hero", Vector3.ZERO)
		p.last_seen_zone = Presence.in_zone("hero")
		pursuers[id] = p
		var n := _body(id)
		if n:
			n.external_control = true
			n.set_schedule("")
	if Services.world:
		for d in get_tree().get_nodes_in_group("doorways"):
			if not d.traversed.is_connected(_on_traversed):
				d.traversed.connect(_on_traversed)
	_set_music("CHASE_1")


func stop() -> void:
	active = false
	struggling = false
	_ep().clear_flag("chase_active")
	if Services.hud:
		Services.hud.set_edge(false)
		Services.hud.set_struggle("")
	for id in pursuers:
		var n := _body(id)
		if n:
			n.external_control = false
	_bus().control_lock.emit("struggle", false)
	_bus().control_lock.emit("interrog", false)
	_bus().control_lock.emit("hidden", false)
	if Services.hero:
		Services.hero.remove_meta("hidden")
		Services.hero.speed_mult = 1.0


func _body(id: String) -> NPC:
	return Services.world.npc(id) if Services.world else null


func _physics_process(delta: float) -> void:
	if active and Services.world:
		tick(delta)


# ================================================================== tick

func tick(delta: float) -> void:
	if not active:
		return
	var E := _ep()
	for k in effects.keys():
		effects[k] -= delta
		if effects[k] <= 0.0:
			effects.erase(k)
			_effect_ended(k)
	_shove_cd = maxf(0.0, _shove_cd - delta)
	_tick_arrivals(delta)
	if interrogation:
		_tick_interrogation(delta)
		return
	if struggling:
		_tick_struggle(delta)
		return
	var hero_zone := Presence.in_zone("hero")
	var hero_pos: Vector3 = Presence.pos.get("hero", Vector3.ZERO)
	_tick_hidden(delta)
	_tick_sheets()
	var any_seen := false
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		_sync_from_body(p)
		var sees := _sees(p, hero_zone, hero_pos)
		if sees:
			any_seen = true
		p.tick(delta, sees, hero_pos, hero_zone)
		_move(p, delta, hero_zone, hero_pos)
		_check_away(p, delta, hero_zone, hero_pos)
		_check_grab(p, delta, hero_zone, hero_pos)
		if struggling or interrogation:
			return
	_tick_heat(delta, any_seen)
	_tick_edge()
	_tick_end(delta, hero_zone, hero_pos)


func _sync_from_body(p: Pursuer) -> void:
	var n := _body(p.id)
	if n:
		p.pos = n.global_position
		p.zone = n.current_zone


func _is_public(z: String) -> bool:
	return Array(cfg.get("public_zones", [])).has(z) or effects.has("alarm")


func _sees(p: Pursuer, hero_zone: String, hero_pos: Vector3) -> bool:
	if hidden != "" or effects.has("los_break") or effects.has("blackout"):
		return false
	if p.state in [Pursuer.S.STUNNED, Pursuer.S.CONTAINED, Pursuer.S.DOUBT]:
		return false
	if p.zone != hero_zone:
		return false
	var dist_max := 12.0
	var n := _body(p.id)
	if n and n.perception:
		dist_max = n.perception.dist
	if effects.has("suppression") and hero_zone == "KITCHEN":
		dist_max = float(cfg.get("suppression_sight", 4.0))
	if effects.has("alarm") and Services.hero and Services.hero.speed_state in ["walk", "fast", "crouch"] and p.pos.distance_to(hero_pos) > 6.0:
		return false
	if p.pos.distance_to(hero_pos) > dist_max:
		return false
	if n and n.perception:
		var old: float = n.perception.sight_mult
		n.perception.sight_mult = dist_max / maxf(n.perception.dist, 0.1)
		var ok: bool = n.perception.can_see_hero() or p.pos.distance_to(hero_pos) < 2.0
		n.perception.sight_mult = old
		return ok
	return true


func run_speed() -> float:
	return PlayerController.RUN


func _speed(p: Pursuer, zone: String) -> float:
	var m := p.speed_mult(heat, cfg.get("heat_bonus", [0, 0.03, 0.06, 0.09]))
	if _is_public(zone):
		m = minf(m, float(cfg.get("public_speed", 0.3)))
	if effects.has("suppression") and zone == "KITCHEN":
		m *= 0.8
	var cs: Dictionary = cfg.get("close_slow", {})
	if p.close_t >= float(cs.get("after", 4.0)):
		m *= float(cs.get("mult", 0.9))
	return m * run_speed()


func _move(p: Pursuer, delta: float, hero_zone: String, hero_pos: Vector3) -> void:
	var n := _body(p.id)
	var tgt := p.target(hero_pos)
	var moving := p.can_act() and tgt != Vector3.INF and p.zone == (hero_zone if p.state == Pursuer.S.PURSUIT else p.last_seen_zone)
	if p.state == Pursuer.S.PURSUIT and p.pos.distance_to(hero_pos) < float(cfg.get("close_slow", {}).get("dist", 3.0)):
		p.close_t += delta
	else:
		p.close_t = 0.0
	var sp := _speed(p, p.zone)
	if n == null:
		if moving:
			var to := tgt - p.pos
			to.y = 0
			if to.length() > 0.3:
				p.pos += to.normalized() * minf(to.length(), sp * delta)
			elif p.state == Pursuer.S.SEARCH:
				p.noise_pos = Vector3.INF
		Presence.place(p.id, p.zone, p.pos)
		return
	if not moving:
		n.velocity.x = 0
		n.velocity.z = 0
		n.move_and_slide()
		return
	n.nav.target_position = tgt
	var nxt := n.nav.get_next_path_position() - n.global_position
	nxt.y = 0
	var flat := tgt - n.global_position
	flat.y = 0
	if nxt.length() < 0.05 or n.nav.is_navigation_finished():
		nxt = flat
	if flat.length() < 0.4:
		if p.state == Pursuer.S.SEARCH:
			p.noise_pos = Vector3.INF
		nxt = Vector3.ZERO
	var v := nxt.normalized() * sp if nxt.length() > 0.01 else Vector3.ZERO
	n.velocity.x = v.x
	n.velocity.z = v.z
	n.speed_name = "run"
	n.move_and_slide()
	n.look_override = "hero" if p.state == Pursuer.S.PURSUIT else null


## A pursuer left behind in another zone re-appears at the door of the hero's zone (off-screen),
## after `regroup_after` seconds — keeps tension without cheap catches.
func _check_away(p: Pursuer, delta: float, hero_zone: String, hero_pos: Vector3) -> void:
	if p.zone == hero_zone or not p.can_act() or hero_zone == "" or hero_zone == "FREIGHT":
		p.away_t = 0.0
		return
	for a in _arrivals:
		if a.id == p.id:
			return
	p.away_t += delta
	var wait := float(p.cfg.get("regroup_after", 8.0))
	if p.state == Pursuer.S.REGROUP:
		wait *= 0.7
	if p.away_t < wait:
		return
	p.away_t = 0.0
	var r: Array = _data().route(p.zone, hero_zone)
	var door_id := ""
	if not r.is_empty():
		var last: Dictionary = _data().door_def(String(r[r.size() - 1]))
		door_id = String(last.get("to", ""))
	if door_id == "":
		for dd in _data().level.get(hero_zone, {}).get("doors", []):
			if dd.has("to"):
				door_id = String(dd.id)
				break
	_appear_at(p, door_id, hero_pos)


func _appear_at(p: Pursuer, door_id: String, hero_pos: Vector3) -> void:
	var dd: Dictionary = _data().door_def(door_id)
	if dd.is_empty():
		return
	var zone: String = dd.zone
	var pos: Vector3 = _data().zone_origin(zone) + Data.vec3(dd.p) + _door_normal(dd) * 1.1
	p.zone = zone
	p.pos = pos
	p.last_seen = hero_pos
	p.last_seen_zone = zone
	if p.state != Pursuer.S.PURSUIT:
		p.set_state(Pursuer.S.SEARCH)
	var n := _body(p.id)
	if n:
		n.teleport(pos, zone)
	else:
		Presence.place(p.id, zone, pos)


func _door_normal(dd: Dictionary) -> Vector3:
	match String(dd.get("side", "N")):
		"S": return Vector3(0, 0, -1)
		"W": return Vector3(1, 0, 0)
		"E": return Vector3(-1, 0, 0)
	return Vector3(0, 0, 1)


## Hero went through a door: pursuers in that zone follow after distance / speed (+ blocks).
func _on_traversed(door_id: String, who: String) -> void:
	if who != "hero" or not active:
		return
	hero_traversed(door_id)


func hero_traversed(door_id: String) -> void:
	var dd: Dictionary = _data().door_def(door_id)
	if dd.is_empty():
		return
	var from_zone: String = dd.zone
	var door_pos: Vector3 = _data().zone_origin(from_zone) + Data.vec3(dd.p)
	var target := String(dd.get("to", ""))
	if dd.has("to_by_flag"):
		var tb: Dictionary = dd.to_by_flag
		target = String(tb.map.get(String(_ep().flag(String(tb.flag))), tb.map.get("default", target)))
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.zone != from_zone or not p.can_act():
			continue
		if p.state != Pursuer.S.PURSUIT and p.pos.distance_to(door_pos) > 10.0:
			continue
		var delay := p.pos.distance_to(door_pos) / maxf(_speed(p, from_zone), 0.5)
		delay += float(p.cfg.get("door_check", 0.0))
		var blk: Dictionary = door_block.get(door_id, {})
		if blk.has(id):
			delay += float(blk[id])
			door_block.erase(door_id)
		_arrivals.append({"id": id, "t": delay, "door": target})


func _tick_arrivals(delta: float) -> void:
	var due: Array = []
	for a in _arrivals:
		a.t -= delta
		if a.t <= 0.0:
			due.append(a)
	for a in due:
		_arrivals.erase(a)
		var p: Pursuer = pursuers.get(a.id)
		if p and p.can_act() and not (Presence.in_zone("hero") == "FREIGHT"):
			_appear_at(p, String(a.door), Presence.pos.get("hero", Vector3.ZERO))


func _tick_heat(delta: float, seen: bool) -> void:
	if seen:
		_unseen_t = 0.0
		_seen_t += delta
		if _seen_t >= float(cfg.get("heat_up_seen", 2.5)):
			_seen_t = 0.0
			heat = mini(3, heat + 1)
	else:
		_seen_t = 0.0
		_unseen_t += delta
		if _unseen_t >= float(cfg.get("heat_down_unseen", 10.0)):
			_unseen_t = 0.0
			heat = maxi(0, heat - 1)
	_ep().threat.heat = heat
	if not effects.has("doubt_music"):
		_set_music("CHASE_%d" % maxi(1, heat))


func _set_music(m: String) -> void:
	if m != _music:
		_music = m
		_bus().music_requested.emit(m)


func _tick_edge() -> void:
	if Services.hud == null or Services.world == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var best: Pursuer = null
	var bd := INF
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.zone == Presence.in_zone("hero"):
			var d := p.pos.distance_to(Presence.pos.get("hero", Vector3.ZERO))
			if d < bd:
				bd = d
				best = p
	if best == null or cam.is_position_in_frustum(best.pos + Vector3(0, 1, 0)):
		Services.hud.set_edge(false)
		return
	var vp := get_viewport().get_visible_rect().size
	var c := vp / 2.0
	var dir := best.pos - cam.global_position
	var right := cam.global_transform.basis.x
	var sx := signf(dir.dot(right))
	Services.hud.set_edge(true, Vector2(c.x + sx * (vp.x / 2.0 - 40.0), c.y), "›" if sx > 0 else "‹")


# ================================================================== grabs / struggle

func _check_grab(p: Pursuer, _delta: float, hero_zone: String, hero_pos: Vector3) -> void:
	if p.state != Pursuer.S.PURSUIT or p.zone != hero_zone or p.grab_cd > 0.0 or hidden != "":
		return
	var d := p.pos.distance_to(hero_pos)
	if not bool(p.cfg.get("grab", false)):
		# Sato never grabs alone: he radios Brody, who closes in one room
		if d < 1.5 and not effects.has("radio_" + p.id):
			effects["radio_" + p.id] = 8.0
			var b: Pursuer = pursuers.get("brody")
			if b and b.zone != hero_zone and b.can_act():
				b.away_t = float(b.cfg.get("regroup_after", 9.0))
		return
	if _is_public(hero_zone):
		return
	if d <= float(p.cfg.get("grab_range", 1.0)):
		grab(p.id)


func grab(by: String) -> void:
	var E := _ep()
	E.threat.grabs += 1
	_bus().player_detected.emit(by, 3)
	var p: Pursuer = pursuers.get(by)
	if p:
		p.set_state(Pursuer.S.GRAB)
		p.grab_cd = float(cfg.get("grab_cooldown", 3.0))
	if E.threat.grabs >= 2:
		start_interrogation()
		return
	struggling = true
	_struggler = by
	struggle_t = float(cfg.get("struggle_window", 1.2))
	taps = 0
	_bus().control_lock.emit("struggle", true)
	_bus().sfx_requested.emit("struggle", null)
	run([{"ambient": "BRODY_GRAB"}])
	if Services.hud:
		Services.hud.set_struggle("[Пробел] × 3")


func tap() -> void:
	if struggling:
		taps += 1


func _tick_struggle(delta: float) -> void:
	if Services.world and Input.is_action_just_pressed("context"):
		tap()
	struggle_t -= delta / maxf(Engine.time_scale, 0.1)
	var p: Pursuer = pursuers.get(_struggler)
	if taps >= int(cfg.get("struggle_taps", 3)):
		_end_struggle(true, p)
	elif struggle_t <= 0.0:
		_end_struggle(false, p)


func _end_struggle(won: bool, p: Pursuer) -> void:
	struggling = false
	_bus().control_lock.emit("struggle", false)
	if Services.hud:
		Services.hud.set_struggle("")
	var st: Dictionary = cfg.get("stun", {})
	if p:
		p.stun(float(st.get("struggle_win" if won else "struggle_lose", 1.0)))
	if not won and Services.hero:
		Services.hero.stunned = 1.0
	_bus().player_decision.emit("struggle")
	_bus().sfx_requested.emit("impact", Presence.pos.get("hero"))


# ================================================================== interrogation (grab #2)

func start_interrogation() -> void:
	interrogation = true
	interrog_t = 0.0
	struggling = false
	var E := _ep()
	E.set_flag("interrogation")
	E.clear_flag("interrog_window")
	E.set_flag("interrog_started")
	E.flags["interrog_bad"] = 0
	_bus().control_lock.emit("interrog", true)
	if Services.hud:
		Services.hud.set_struggle("")
		Services.hud.fade(0.3, true)
	var acts: Array = [
		{"hero": ["teleport", {"marker": "COLD_STORAGE:interrog_hero"}]},
		{"teleport_npc": ["brody", "COLD_STORAGE:interrog_brody"]}, {"teleport_npc": ["sato", "COLD_STORAGE:interrog_sato"]},
		{"npc": ["brody", "look", {"target": "hero"}]}, {"npc": ["sato", "look", {"target": "hero"}]},
		{"npc": ["brody", "pose", {"pose": "grab"}]},
		{"set": ["threat.daniel_knows_hero_met_thomas", true]}, {"suspicion": ["daniel", 1]},
		{"if": "ITEM_MARA_PHONE", "then": [{"give_item": ["ITEM_MARA_PHONE", "sato"]}]},
		{"if": "ITEM_HERO_PHONE", "then": [{"give_item": ["ITEM_HERO_PHONE", "sato"]}, {"flag": "phone_confiscated"}]},
		{"music": "TENSION_LOW"}, {"start_exchange": "X_S07_INTERROG"}]
	run(acts)
	Presence.place("hero", "COLD_STORAGE", _data().marker("COLD_STORAGE:interrog_hero"))
	_ep().hero_zone = "COLD_STORAGE"
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		p.set_state(Pursuer.S.CONTAINED, 999.0)
		p.zone = "COLD_STORAGE"
		p.pos = _data().marker("COLD_STORAGE:interrog_" + id)
		if _body(id) == null:
			Presence.place(id, p.zone, p.pos)
	if Services.hud:
		get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): if Services.hud: Services.hud.fade(0.3, false))


func _tick_interrogation(delta: float) -> void:
	interrog_t += delta
	var E := _ep()
	var ic: Dictionary = cfg.get("interrogation", {})
	if interrog_t >= float(ic.get("thomas_save_after", 60.0)) or int(E.flags.get("interrog_bad", 0)) >= int(ic.get("bad_choices_save", 2)):
		if not E.flags.get("thomas_saved", false):
			E.set_flag("thomas_saved")
			run([{"spawn": ["thomas", "COLD_STORAGE:enter"]}, {"line": "THOMAS_SAVE"}, {"sfx": "crash"}])
			escape("thomas")


func escape(how: String) -> void:
	if not interrogation:
		return
	interrogation = false
	var E := _ep()
	E.clear_flag("interrogation")
	E.clear_flag("interrog_window")
	E.threat.grabs = 0
	if Services.conversation and Services.conversation.active_id == "X_S07_INTERROG":
		Services.conversation.end_active("ESCAPE")
	_bus().control_lock.emit("interrog", false)
	var st: Dictionary = cfg.get("stun", {})
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		p.set_state(Pursuer.S.SEARCH)
		p.stun(2.5 if id == "brody" else 1.5)
		if how == "freezer" and id == "sato":
			p.contain(float(cfg.get("contain", {}).get("freezer", 20.0)))
	if how == "thomas":
		var b: Pursuer = pursuers.get("brody")
		if b:
			b.stun(float(st.get("hit", 2.0)) + 2.0)
		run([{"delay": 4.0, "do": [{"despawn": "thomas"}]}])
	heat = 3
	run([{"npc": ["brody", "pose", {"pose": "rest"}]}, {"hint": ["Беги!", 2.0]}, {"sfx": "impact"}])
	_set_music("CHASE_3")
	_bus().player_decision.emit("escape")


# ================================================================== end condition

func _tick_end(delta: float, hero_zone: String, hero_pos: Vector3) -> void:
	if finished or hero_zone != "BCORR":
		bcorr_t = 0.0 if hero_zone != "BCORR" else bcorr_t
		return
	bcorr_t += delta
	var safe := true
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.zone == "BCORR" and p.pos.distance_to(hero_pos) < float(cfg.get("end", {}).get("safe_dist", 6.0)) and p.can_act():
			safe = false
	if (safe and bcorr_t >= 1.0) or bcorr_t >= float(cfg.get("end", {}).get("timeout", 30.0)):
		finish()


func finish() -> void:
	if finished:
		return
	finished = true
	stop()
	run([{"play_cine": "C_S7_MARA"}])


# ================================================================== context key (shove / bottle / radio)

## Called by PlayerController on Space. Returns true if the chase consumed it.
func on_context() -> bool:
	if not active or interrogation:
		return false
	if struggling:
		tap()
		return true
	var hp: Vector3 = Presence.pos.get("hero", Vector3.ZERO)
	var near: Pursuer = nearest_pursuer(hp, float(cfg.get("shove_range", 1.2)))
	if near and _shove_cd <= 0.0:
		if _ep().has_item("ITEM_BOTTLE"):
			_ep().take_item("ITEM_BOTTLE")
			near.stun(float(cfg.get("stun", {}).get("hit", 2.0)))
			_bus().sfx_requested.emit("crash", hp)
		else:
			near.stun(float(cfg.get("stun", {}).get("shove", 1.0)))
			_bus().sfx_requested.emit("impact", hp)
		near.hits += 1
		if near.id == "brody" and near.hits >= 2:
			near.angry = true
		_shove_cd = float(cfg.get("shove_cooldown", 4.0))
		_bus().player_decision.emit("shove")
		return true
	if _ep().has_item("ITEM_BOTTLE"):
		apply_tool("throw_bottle", {})
		return true
	if _ep().has_item("ITEM_RADIO") and nearest_pursuer(hp, 14.0) != null:
		apply_tool("radio_bluff", {"radio": true})
		return true
	return false


func nearest_pursuer(p: Vector3, max_d: float, zone: String = "") -> Pursuer:
	var z := zone if zone != "" else Presence.in_zone("hero")
	var best: Pursuer = null
	var bd := max_d
	for id in pursuers:
		var q: Pursuer = pursuers[id]
		if q.zone != z or q.state == Pursuer.S.CONTAINED:
			continue
		var d := q.pos.distance_to(p)
		if d <= bd:
			bd = d
			best = q
	return best


# ================================================================== noise & tools

func _on_noise(pos: Vector3, radius: float, src: String) -> void:
	if not active or interrogation:
		return
	var z: String = _data().zone_at(pos) if Services.world else Presence.in_zone("hero")
	if z == "":
		z = Presence.in_zone("hero")
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.zone == z and p.pos.distance_to(pos) <= radius:
			if src.begins_with("hero") and effects.has("blackout") or not src.begins_with("hero"):
				p.hear(pos, z)
			elif src.begins_with("hero") and p.state in [Pursuer.S.SEARCH, Pursuer.S.REGROUP]:
				p.hear(pos, z)


func _on_bait(ev: String, d: Dictionary) -> void:
	if ev == "chase_tool":
		apply_tool(String(d.get("tool", "")), d)


func _lure_at(marker: String, radius: float, dur: float = 0.0) -> void:
	var pos: Vector3 = _data().marker(marker)
	var z: String = _data().marker_zone(marker)
	_bus().noise.emit(pos, radius, "tool")
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.zone == z and p.pos.distance_to(pos) <= radius:
			p.lure(pos, z, dur)


func _pursuers_near(marker: String, r: float) -> Array:
	var pos: Vector3 = _data().marker(marker)
	var z: String = _data().marker_zone(marker)
	var out: Array = []
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.zone == z and p.pos.distance_to(pos) <= r:
			out.append(p)
	return out


## Every tool changes pursuer state (ChaseTool contract: use → effect). Returns true if it applied.
func apply_tool(tool: String, args: Dictionary = {}) -> bool:
	if not active and not interrogation:
		return false
	var E := _ep()
	var st: Dictionary = cfg.get("stun", {})
	_bus().player_decision.emit("tool")
	used_tools[tool] = int(used_tools.get(tool, 0)) + 1
	match tool:
		"car_alarm":
			if not E.has_item("ITEM_VOLVO_KEYS"):
				return false
			_bus().sfx_requested.emit("car_alarm", _data().marker("LOADING_DOCK:thomas_car"))
			for id in pursuers:
				var p: Pursuer = pursuers[id]
				if p.zone in ["LOADING_DOCK", "LAUNDRY"]:
					p.lure(_data().marker("LOADING_DOCK:thomas_car"), "LOADING_DOCK", float(cfg.get("car_alarm", 4.0)))
			return true
		"roll_cart":
			_bus().sfx_requested.emit("cart", _data().marker("LOADING_DOCK:cart"))
			for p in _pursuers_near("LOADING_DOCK:cart", 8.0):
				p.stun(float(st.get("cart", 1.5)))
			return true
		"laundry_cart_door":
			door_block["LAUNDRY_SCORR"] = {"brody": float(st.get("laundry_cart_brody", 3.0)), "sato": float(st.get("vault_wall", 0.6))}
			door_block["SCORR_LAUNDRY"] = door_block["LAUNDRY_SCORR"].duplicate()
			door_block["LAUNDRY_KITCHEN"] = door_block["LAUNDRY_SCORR"].duplicate()
			_bus().sfx_requested.emit("cart", null)
			return true
		"steam":
			_bus().sfx_requested.emit("foam", _data().marker("LAUNDRY:press"))
			for p in _pursuers_near("LAUNDRY:press", 3.5):
				p.stun(float(st.get("steam", 1.0)))
			return true
		"sheets":
			effects["los_break"] = float(cfg.get("los_break", 1.5))
			return true
		"pots":
			_bus().sfx_requested.emit("crash", _data().marker("KITCHEN:pots"))
			_lure_at("KITCHEN:pots", float(cfg.get("noise_lure", 15.0)), 2.0)
			return true
		"bottle_pick":
			E.give_item("ITEM_BOTTLE", "hero")
			return true
		"throw_bottle":
			if not E.has_item("ITEM_BOTTLE"):
				return false
			E.take_item("ITEM_BOTTLE")
			var hp: Vector3 = Presence.pos.get("hero", Vector3.ZERO)
			var fwd: Vector3 = Services.hero.facing if Services.hero else Vector3(1, 0, 0)
			var at: Vector3 = args.get("at", hp + fwd * 8.0)
			var z := Presence.in_zone("hero")
			_bus().sfx_requested.emit("crash", at)
			_bus().noise.emit(at, float(cfg.get("noise_lure", 15.0)), "tool")
			for id in pursuers:
				var p: Pursuer = pursuers[id]
				if p.zone == z and p.pos.distance_to(at) <= float(cfg.get("noise_lure", 15.0)):
					p.lure(at, z, 2.5)
			return true
		"suppression":
			if used_tools[tool] > 1:
				return false
			effects["suppression"] = float(cfg.get("suppression", 10.0))
			_bus().sfx_requested.emit("foam", null)
			if Services.hero:
				Services.hero.speed_mult = 0.8
			return true
		"freezer_tray":
			_lure_at("COLD_STORAGE:freezer_in", float(cfg.get("noise_lure", 15.0)), 3.0)
			_bus().sfx_requested.emit("crash", _data().marker("COLD_STORAGE:freezer_in"))
			return true
		"freezer_latch":
			_bus().sfx_requested.emit("latch", _data().marker("COLD_STORAGE:freezer_door"))
			var caught := _pursuers_near("COLD_STORAGE:freezer_in", 2.0)
			for p in caught:
				p.contain(float(cfg.get("contain", {}).get("freezer", 20.0)))
				E.set_flag("freezer_locked_" + p.id)
			for id in pursuers:
				var q: Pursuer = pursuers[id]
				if not caught.has(q) and not caught.is_empty():
					q.angry = true
					run([{"bark": [id, "Броди?!" if id == "sato" else "Сато?!"]}])
			return not caught.is_empty()
		"breaker":
			effects["blackout"] = float(cfg.get("blackout", 8.0))
			_bus().sfx_requested.emit("breaker", null)
			if Services.world:
				Services.world.set_mood("blackout")
			return true
		"radio_pick":
			E.give_item("ITEM_RADIO", "hero")
			return true
		"radio_bluff", "shout_bluff":
			return _radio_bluff(tool == "radio_bluff" and E.has_item("ITEM_RADIO"))
		"locker":
			var lid := String(args.get("id", "locker"))
			if lockers_used.has(lid):
				var p := nearest_pursuer(Presence.pos.get("hero", Vector3.ZERO), 30.0)
				run([{"ambient": "SATO_SEARCH"}])
				if p:
					grab(p.id if pursuers.get("brody") == null else "brody")
				return true
			lockers_used[lid] = true
			_hide(lid)
			return true
		"cloth":
			_hide("cloth")
			return true
		"unhide":
			_unhide()
			return true
		"fire_alarm":
			if E.flags.get("fire_alarm_used", false):
				return false
			E.set_flag("fire_alarm_used")
			effects["alarm"] = float(cfg.get("alarm", 25.0))
			_bus().sfx_requested.emit("alarm", null)
			var z := Presence.in_zone("hero")
			var marks: Dictionary = _data().zone(z).get("markers", {})
			var keys: Array = marks.keys()
			for i in mini(4, keys.size()):
				run([{"spawn": ["staff_%d" % (i + 1), z + ":" + String(keys[i])]}])
			return true
		"fire_door":
			if not E.has_item("ITEM_STAFF_KEYCARD"):
				run([{"sfx": "click"}, {"hint": ["Закрыта. Без карты не запереть.", 2.0]}])
				return false
			_bus().sfx_requested.emit("latch", null)
			var hp2: Vector3 = Presence.pos.get("hero", Vector3.ZERO)
			for id in pursuers:
				var p: Pursuer = pursuers[id]
				if p.pos.distance_to(hp2) > 4.0 or p.zone != Presence.in_zone("hero"):
					p.contain(float(cfg.get("contain", {}).get("fire_door", 15.0)))
			return true
		"cart_wall":
			for id in pursuers:
				var p: Pursuer = pursuers[id]
				if p.zone == "SCORR":
					p.stun(float(st.get("cart_wall" if not bool(p.cfg.get("vault", false)) else "vault_wall", 1.0)))
			door_block["SCORR_FREIGHT"] = {"brody": 4.0, "sato": 0.6}
			_bus().sfx_requested.emit("cart", null)
			return true
		"freight_decoy":
			E.set_flag("freight_decoyed")
			E.flags["freight_floor"] = "3"
			run([{"ambient": "SATO_ELEV"}])
			for id in pursuers:
				var p: Pursuer = pursuers[id]
				if p.can_act() and p.state != Pursuer.S.PURSUIT:
					p.contain(float(cfg.get("contain", {}).get("decoy", 12.0)))
			return true
		"kick_crates":
			if not interrogation:
				return false
			_bus().sfx_requested.emit("crash", null)
			escape("crates")
			return true
		"freezer_shove":
			if not interrogation:
				return false
			_bus().sfx_requested.emit("latch", null)
			escape("freezer")
			return true
		"stair_drop":
			run([{"hero": ["teleport", {"marker": "SERVICE_STAIR:drop_target"}]}, {"hero": ["stun", {"dur": 0.5}]}, {"sfx": "impact"}])
			Presence.place("hero", "SERVICE_STAIR", _data().marker("SERVICE_STAIR:drop_target"))
			for id in pursuers:
				var p: Pursuer = pursuers[id]
				if p.zone == "SERVICE_STAIR" and p.state == Pursuer.S.PURSUIT:
					p.set_state(Pursuer.S.SEARCH)
			return true
	return false


func _radio_bluff(with_radio: bool) -> bool:
	var hp: Vector3 = Presence.pos.get("hero", Vector3.ZERO)
	var p := nearest_pursuer(hp, 14.0)
	if p == null:
		return false
	run([{"line": "H_RADIO_BLUFF"}])
	var E := _ep()
	var called := false
	if p.id == "sato":
		called = (E.threat.daniel_knows_hero_met_thomas and heat >= 3) or (not with_radio and heat >= 2)
	elif not with_radio:
		called = heat >= 3
	if called:
		run([{"line": "SATO_CALLED" if p.id == "sato" else "BRODY_CALLED"}])
		p.bonus_t = float(p.cfg.get("bluff_bonus_time", 6.0))
		p.called_bluff = true
		return false
	var d := float(p.cfg.get("doubt", 2.0)) * (1.0 if with_radio else 0.6)
	p.doubt(d)
	run([{"line": "SATO_DOUBT" if p.id == "sato" else "BRODY_DOUBT"}])
	effects["doubt_music"] = d
	_set_music("DOUBT")
	return true


func _effect_ended(k: String) -> void:
	match k:
		"blackout":
			if Services.world:
				Services.world.set_mood("night")
		"suppression":
			if Services.hero:
				Services.hero.speed_mult = 1.0
		"alarm":
			for i in 4:
				run([{"despawn": "staff_%d" % (i + 1)}])
		"doubt_music":
			_music = ""


func _hide(kind: String) -> void:
	hidden = kind
	_hide_check_t = 0.0
	_bus().control_lock.emit("hidden", true)
	if Services.hero:
		Services.hero.set_meta("hidden", true)
		Services.hero.body_vis.visible = false
	for id in pursuers:
		var p: Pursuer = pursuers[id]
		if p.state == Pursuer.S.PURSUIT:
			p.set_state(Pursuer.S.SEARCH)


func _unhide() -> void:
	if hidden == "":
		return
	hidden = ""
	_bus().control_lock.emit("hidden", false)
	if Services.hero:
		Services.hero.remove_meta("hidden")
		Services.hero.body_vis.visible = true


## Running through hanging sheets breaks line of sight for 1.5 s.
func _tick_sheets() -> void:
	if Services.world == null or Services.hero == null:
		return
	var hp: Vector3 = Services.hero.global_position
	for n in get_tree().get_nodes_in_group("sheets"):
		var s: Node3D = n
		var sz: Vector3 = Data.vec3(s.get_meta("def", {}).get("s", [0.1, 1, 1]))
		var l := hp - s.global_position
		if absf(l.x) <= sz.x / 2.0 + 0.5 and absf(l.z) <= sz.z / 2.0 + 0.2:
			effects["los_break"] = float(cfg.get("los_break", 1.5))


func _tick_hidden(delta: float) -> void:
	if hidden == "":
		return
	if Services.world and Input.is_action_just_pressed("interact"):
		_unhide()
		return
	if hidden != "cloth":
		return
	# a searching pursuer lifts one cloth of three: 1/3 risk while he lingers close
	var hp: Vector3 = Presence.pos.get("hero", Vector3.ZERO)
	var p := nearest_pursuer(hp, 2.2)
	if p and p.state == Pursuer.S.SEARCH:
		_hide_check_t += delta
		if _hide_check_t >= 2.0:
			_hide_check_t = 0.0
			if _rng.randi_range(0, 2) == 0:
				_unhide()
				grab(p.id if bool(p.cfg.get("grab", false)) else "brody")
	else:
		_hide_check_t = 0.0
