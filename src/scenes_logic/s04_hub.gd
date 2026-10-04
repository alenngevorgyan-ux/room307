extends SceneLogic
## S04 hub glue (+ S05 video room): Pavel's door window, security detection & escorts,
## Eva tail detection, Nico's smoke breaks, Daniel's shadow passes, the Adrian/Daniel argument.

const BEHIND_DESK := Rect2(17.4, 0.0, 10.6, 2.6)   # LOBBY-local forbidden area

var video: VideoRoom
var _door_t := 0.0
var _smoke_t := 0.0
var _shadow_t := 0.0
var _run_past := 0
var _run_cool := 0.0
var _escort_t := -1.0
var _in_security := false


func enter() -> void:
	video = VideoRoom.new()
	video.name = "VideoRoom"
	add_child(video)
	if Services.world:
		for d in ["LOBBY_SEC", "SEC_FRONT", "SCORR_SEC", "SEC_STAFF"]:
			var door: Doorway = Services.world.door(d)
			if door:
				door.traversed.connect(_on_door)
	bus().trap_bait.connect(_on_bait)


func _on_door(_door_id: String, who: String) -> void:
	if who in ["pavel", "daniel"]:
		ep().set_flag("pavel_door_open")
		_door_t = 3.0


func _on_bait(ev: String, d: Dictionary) -> void:
	if ev != "vid" or video == null:
		return
	match String(d.get("cmd", "")):
		"sit": video.sit()
		"cam": video.select_cam(video.cam_i + 1)
		"tab": video.jump((VideoRoom.TABS.find(video.t) + 1) % VideoRoom.TABS.size())


func tick(delta: float) -> void:
	var E := ep()
	if _door_t > 0.0:
		_door_t -= delta
		if _door_t <= 0.0:
			E.clear_flag("pavel_door_open")
	_tick_security(delta)
	_tick_eva_tail()
	_tick_nico(delta)
	_tick_daniel(delta)
	_tick_running(delta)
	if E.flags.get("lina_fb_due", false) and (Services.conversation == null or not Services.conversation.is_active()):
		E.clear_flag("lina_fb_due")
		_lina_fallback()
	if E.flags.get("adrian_daniel_argue_due", false) and Presence.in_zone("adrian") == "LOBBY":
		E.clear_flag("adrian_daniel_argue_due")
		run([{"teleport_npc": ["daniel", "LOBBY:daniel_elev"]}, {"set_schedule": ["daniel", "daniel_argue"]}, {"set_schedule": ["adrian", "adrian_argue"]}])


func _lina_fallback() -> void:
	var z := Presence.in_zone("hero")
	var zd: Dictionary = data().zone(z)
	if not zd.get("public", false) and z != "HALL_3F" and z != "SCORR":
		z = "LOBBY"
	var marks: Dictionary = data().zone(z).get("markers", {})
	var m := ""
	for cand in ["fb_lina", "lina_lobby", "mid", "arrive_bar", "arrive"]:
		if marks.has(cand):
			m = z + ":" + cand
			break
	if m == "":
		m = "LOBBY:lina_lobby"
	run([{"spawn": ["lina", m]}, {"set_schedule": ["lina", ""]}, {"npc": ["lina", "follow", {"target": "hero", "dist": 1.6}]},
		{"delay": 1.0, "do": [{"start_exchange": "X_S04_LINA_FB"}]}, {"delay": 12.0, "do": [{"npc": ["lina", "unfollow", {}]}, {"set_schedule": ["lina", "lina_hall"]}]}])


# ------------------------------------------------------------------ security / S05

func hero_forbidden() -> bool:
	var z := Presence.in_zone("hero")
	if z == "SECURITY":
		return true
	if z == "LOBBY" and Presence.pos.has("hero") and not ep().flags.get("pushing_cart", false):
		var l: Vector3 = (Presence.pos.hero as Vector3) - data().zone_origin("LOBBY")
		return BEHIND_DESK.has_point(Vector2(l.x, l.z))
	return false


func _tick_security(delta: float) -> void:
	var E := ep()
	var in_sec := Presence.in_zone("hero") == "SECURITY"
	if in_sec != _in_security:
		_in_security = in_sec
		if in_sec:
			E.set_phase_name("S05_VIDEO")
			var pavel_away := Presence.in_zone("pavel") != "SECURITY"
			if pavel_away:
				run([{"npc": ["pavel", "hold", {"on": true, "reason": "video"}]}])
			video.enter(E.flags.get("pavel_distracted", false))
			bus().player_decision.emit("enter_security")
		else:
			E.set_phase_name("S04_HUB")
			if video.active:
				_complete_video()
				video.leave()
			run([{"npc": ["pavel", "hold", {"on": false, "reason": "video"}]}, {"music": "HUB_EXPLORE"}])
	if _escort_t >= 0.0:
		_escort_t -= delta
		if _escort_t < 0.0:
			run([{"npc": ["pavel", "unfollow", {}]}, {"set_schedule": ["pavel", "pavel_loop"]}])
		return
	if not hero_forbidden() or Services.world == null:
		return
	for w in ["pavel", "daniel", "receptionist"]:
		var n: NPC = Services.world.npc(w)
		if n == null or not n.spawned or n.perception == null and w != "receptionist":
			continue
		var sees := false
		if n.perception:
			sees = n.perception.seen_t >= n.perception.detect_time
		elif w == "receptionist" and Presence.in_zone("hero") == "LOBBY" and Presence.distance("hero", w) < 3.0:
			sees = true
		if sees:
			if n.perception:
				n.perception.seen_t = 0.0
			caught(w)
			return


func _complete_video() -> void:
	var E := ep()
	if E.has_fact("F_THOMAS_LOCATION") or E.has_fact("F_DANIEL_SEARCHED_307") or E.has_fact("F_MARA_MET_OLDER_MAN"):
		if not E.lead_done("C"):
			E.set_lead("C", Episode.LeadState.DONE)


func caught(by: String) -> void:
	var E := ep()
	var c := int(E.threat.caught_count.get("pavel", 0))
	E.threat.caught_count["pavel"] = c + 1
	bus().player_detected.emit(by, 2)
	if video.active:
		_complete_video_failed()
	var second: bool = c >= 1 or E.ch("pavel").suspicion >= 2
	if not second:
		run([{"suspicion": ["pavel", 1]}, {"teleport_npc": ["pavel", "LOBBY:pavel_reception"]},
			{"hero": ["teleport", {"marker": "LOBBY:hero_lobby"}]}, {"fade": 0.3},
			{"start_exchange": "X_S04_PAVEL_ESCORT"}, {"npc": ["pavel", "follow", {"target": "hero", "dist": 2.0}]}])
		_escort_t = 12.0
	else:
		run([{"ambient": "PAVEL_AGAIN"}, {"spawn": ["daniel", "LOBBY:daniel_elev"]}, {"teleport_npc": ["daniel", "LOBBY:hero_lobby"]},
			{"hero": ["teleport", {"marker": "LOBBY:hero_lobby"}]}, {"fade": 0.3},
			{"set_schedule": ["daniel", ""]}, {"start_exchange": "X_S04_DANIEL_ESCORT"},
			{"delay": 8.0, "do": [{"set_schedule": ["daniel", "daniel_hub"]}]}])
		_escort_t = 6.0
	Presence.place("hero", "LOBBY", data().marker("LOBBY:hero_lobby"))
	E.hero_zone = "LOBBY"


func _complete_video_failed() -> void:
	# facts already seen are kept; Lead C becomes FAILED_DONE on the 2nd catch (exchange action)
	video.leave()


# ------------------------------------------------------------------ Eva tail

func _tick_eva_tail() -> void:
	var E := ep()
	if not E.flags.get("eva_talked", false) or E.flags.get("eva_tail_over", false) or E.flags.get("eva_tail_seen", false):
		return
	if Services.world == null:
		return
	var n: NPC = Services.world.npc("eva")
	if n == null or not n.spawned or n.perception == null:
		return
	if Services.conversation and Services.conversation.is_active():
		return
	if n.perception.seen_t >= n.perception.detect_time and Presence.distance("hero", "eva") < 9.0:
		E.set_flag("eva_tail_seen")
		bus().player_detected.emit("eva", 1)
		run([{"start_exchange": "X_S04_EVA_TAILED"}])


# ------------------------------------------------------------------ Nico / Daniel / running

func _tick_nico(delta: float) -> void:
	_smoke_t += delta
	if _smoke_t >= 180.0 and not ep().flags.get("nico_smoking", false):
		if Services.conversation == null or String(Services.conversation.active.get("npc", "")) != "nico":
			_smoke_t = 0.0
			run([{"set_schedule": ["nico", "nico_smoke"]}])


func _tick_daniel(delta: float) -> void:
	if not ep().flags.get("daniel_shadow", false):
		return
	_shadow_t += delta
	if _shadow_t < 120.0:
		return
	_shadow_t = 0.0
	var z := Presence.in_zone("hero")
	var zd: Dictionary = data().zone(z)
	if zd.is_empty() or z in ["SECURITY", "ELEV_A", "FREIGHT"]:
		return
	var marks: Dictionary = zd.get("markers", {})
	var pick: String = "mid" if marks.has("mid") else (String(marks.keys()[0]) if not marks.is_empty() else "")
	if pick == "":
		return
	run([{"npc": ["daniel", "walk_to", {"marker": z + ":" + pick}]}, {"delay": 25.0, "do": [{"set_schedule": ["daniel", "daniel_hub"]}]}])


func _tick_running(delta: float) -> void:
	_run_cool = maxf(0.0, _run_cool - delta)
	if Services.hero == null or Services.world == null or _run_cool > 0.0:
		return
	if not data().zone(Presence.in_zone("hero")).get("public", false):
		return
	if not (Services.hero.speed_state in ["run", "slide"]):
		return
	var p: NPC = Services.world.npc("pavel")
	if p and p.spawned and p.perception and p.perception.can_see_hero() and Presence.distance("hero", "pavel") < 9.0:
		_run_past += 1
		_run_cool = 10.0
		run([{"bark": ["pavel", "Не бегаем, не бегаем."]}])
		if _run_past >= 2:
			_run_past = 0
			run([{"suspicion": ["pavel", 1]}, {"npc": ["pavel", "follow", {"target": "hero", "dist": 5.0}]},
				{"delay": 25.0, "do": [{"npc": ["pavel", "unfollow", {}]}, {"set_schedule": ["pavel", "pavel_loop"]}]}])
