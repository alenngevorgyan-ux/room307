class_name OverhearDirector
extends Node
## Ambient conversations the hero can eavesdrop on (GAMEPLAY_SPEC S04 tech notes).
## Lines play positionally; subtitles + fact grants happen only while the hero is inside a listen
## zone and unseen by the speakers. Most loop once more after `loop_gap` seconds.

var state: Dictionary = {}   # oid -> {phase: idle|playing|gap|done, line_i, t, loops_left}


func _ready() -> void:
	get_node("/root/Bus").world_beat.connect(_on_beat)
	get_node("/root/Bus").scene_changed.connect(func(_s): state.clear())


func _process(delta: float) -> void:
	tick(delta)


func _ep() -> Node:
	return get_node("/root/Episode")


func _data() -> Node:
	return get_node("/root/Data")


func _on_beat(b: String) -> void:
	for oid in _data().overhears:
		var o: Dictionary = _data().overhears[oid]
		if String(o.get("start", {}).get("beat", "")) == b and _scene_ok(o) and not state.has(oid):
			_start(oid)


func _scene_ok(o: Dictionary) -> bool:
	return not o.has("scene") or String(o.scene) == _ep().scene_id


func _start(oid: String) -> void:
	var o: Dictionary = _data().overhears[oid]
	state[oid] = {"phase": "playing", "line_i": -1, "t": 0.0, "loops_left": int(o.get("loops", 1))}
	ActionRunner.run(o.get("on_start", []), {"source": oid})


func tick(delta: float) -> void:
	var E := _ep()
	for oid in _data().overhears:
		var o: Dictionary = _data().overhears[oid]
		if not _scene_ok(o):
			continue
		if not state.has(oid):
			var st: Dictionary = o.get("start", {})
			if st.has("beat"):
				continue
			if st.has("after") and E.scene_clock < float(st.after):
				continue
			if st.has("cond") and not Conditions.check(st.cond, E):
				continue
			_start(oid)
			continue
		var s: Dictionary = state[oid]
		match String(s.phase):
			"playing":
				s.t -= delta
				if s.t > 0.0:
					continue
				s.line_i += 1
				var lines: Array = o.get("lines", [])
				if s.line_i >= lines.size():
					s.loops_left -= 1
					if s.loops_left > 0:
						s.phase = "gap"
						s.t = float(o.get("loop_gap", 60.0))
					else:
						s.phase = "done"
						ActionRunner.run(o.get("on_end", []), {"source": oid})
					continue
				_play_line(oid, o, lines[s.line_i], s)
			"gap":
				s.t -= delta
				if s.t <= 0.0:
					if o.get("start", {}).has("cond") and not Conditions.check(o.start.cond, E):
						s.phase = "done"
						ActionRunner.run(o.get("on_end", []), {"source": oid})
						continue
					s.phase = "playing"
					s.line_i = -1
					s.t = 0.0


func hero_listening(o: Dictionary) -> bool:
	if not Presence.pos.has("hero"):
		return false
	var hp: Vector3 = Presence.pos.hero
	var in_zone := false
	for l in o.get("listen", []):
		var m := String(l.marker)
		if Presence.in_zone("hero") == _data().marker_zone(m) and hp.distance_to(_data().marker(m)) <= float(l.get("r", 4.0)):
			in_zone = true
			break
	if not in_zone:
		return false
	for npc in o.get("unseen_by", []):
		if Services.world:
			var n: NPC = Services.world.npc(String(npc))
			if n and n.spawned and n.perception and n.perception.can_see_hero():
				return false
	return true


func _play_line(oid: String, o: Dictionary, line: Dictionary, s: Dictionary) -> void:
	var key := String(line.key)
	var l: Dictionary = _data().line(key)
	s.t = float(l.dur) + 0.4
	var speaker := String(l.get("speaker", o.get("speaker", "")))
	if hero_listening(o):
		get_node("/root/Bus").line_started.emit(speaker, String(l.text), float(l.dur))
		ActionRunner.run(line.get("actions", []), {"source": oid})
	else:
		get_node("/root/Bus").bark_requested.emit(speaker, "…")
