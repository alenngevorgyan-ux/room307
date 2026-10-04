extends Node
## Debug — F1 state dump, F2 scene jump, F3 fact grant, F4 pacing log, F5 reload data,
## F6 quick-save, F7 quick-load. Also hosts pacing telemetry and the CINE ≤ 15 s assert.

var telemetry := PacingTelemetry.new()
var enabled := true
var _layer: CanvasLayer
var _label: RichTextLabel
var _mode := 0          # 0 off, 1 state, 2 scene jump, 3 fact grant, 4 pacing
var _cursor := 0
var _cine_start: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.position = Vector2(8, 8)
	_label.size = Vector2(620, 700)
	_label.add_theme_font_size_override("normal_font_size", 12)
	_label.add_theme_color_override("default_color", Color(0.85, 1.0, 0.85))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.72)
	_label.add_theme_stylebox_override("normal", bg)
	_label.visible = false
	_layer.add_child(_label)
	var B := get_node("/root/Bus")
	B.player_decision.connect(func(k: String): telemetry.on_decision(k, get_node("/root/Episode").clock_sec))
	B.control_lock.connect(func(r: String, l: bool): telemetry.set_lock(r, l))
	B.cine_started.connect(_on_cine_started)
	B.cine_ended.connect(_on_cine_ended)
	_parse_automation()


# --- automation: -- --shot=path.png --shot-at=3.0 [--shots=3,6,9] [--quit-at=10] [--do=json-actions-at] ---
var _shots: Array = []
var _shot_path := ""
var _quit_at := -1.0
var _auto_t := 0.0
var _auto_actions: Array = []   # [{t, actions}]
var _trace: Array = []
var _trace_t := 0.0


func _parse_automation() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			_shots.append(float(a.substr(10)))
		elif a.begins_with("--shots="):
			for x in a.substr(8).split(","):
				_shots.append(float(x))
		elif a.begins_with("--quit-at="):
			_quit_at = float(a.substr(10))
		elif a.begins_with("--trace="):
			_trace = Array(a.substr(8).split(","))
		elif a.begins_with("--do="):
			var j: Variant = JSON.parse_string(a.substr(5))
			if typeof(j) == TYPE_ARRAY:
				_auto_actions = j


func _tick_automation(delta: float) -> void:
	_auto_t += delta
	for e in _auto_actions.duplicate():
		if _auto_t >= float(e.t):
			_auto_actions.erase(e)
			if e.has("key"):
				_press(String(e.key), float(e.get("hold", 0.1)))
			if e.has("mouse"):
				get_viewport().warp_mouse(Vector2(e.mouse[0], e.mouse[1]))
			if e.has("actions"):
				ActionRunner.run(e.actions, {"source": "automation"})
	for i in range(_shots.size() - 1, -1, -1):
		if _auto_t >= float(_shots[i]):
			var t: float = _shots[i]
			_shots.remove_at(i)
			var img := get_viewport().get_texture().get_image()
			var p := _shot_path.replace(".png", "_%05.1f.png" % t) if _shot_path != "" else "user://shot_%05.1f.png" % t
			img.save_png(p)
			print("[shot] ", p)
	if not _trace.is_empty():
		_trace_t -= delta
		if _trace_t <= 0.0:
			_trace_t = 2.0
			var E := get_node("/root/Episode")
			var parts: Array = ["t=%.0f %s %s x=%s" % [_auto_t, E.scene_id, E.phase_name(), Services.conversation.active_id if Services.conversation else ""]]
			for id in _trace:
				if Presence.pos.has(id):
					var p: Vector3 = Presence.pos[id]
					var z: String = Presence.in_zone(id)
					var lp: Vector3 = p - get_node("/root/Data").zone_origin(z) if z != "" else p
					parts.append("%s@%s(%.1f,%.1f,%.1f)" % [id, z, lp.x, lp.y, lp.z])
				else:
					parts.append(id + "@-")
			print("[trace] ", " ".join(parts))
	if _quit_at > 0.0 and _auto_t >= _quit_at:
		get_tree().quit()


func _press(action: String, hold: float) -> void:
	Input.action_press(action)
	get_tree().create_timer(hold, true, false, true).timeout.connect(func(): Input.action_release(action))


func _on_cine_started(id: String, dur: float) -> void:
	assert(dur <= 15.0, "CINE %s longer than 15 s" % id)
	if dur > 15.0:
		push_error("CINE %s is %.1fs (> 15 s)" % [id, dur])
	_cine_start[id] = Time.get_ticks_msec()
	telemetry.set_lock("cine:" + id, true)


func _on_cine_ended(id: String) -> void:
	var real := (Time.get_ticks_msec() - int(_cine_start.get(id, Time.get_ticks_msec()))) / 1000.0
	telemetry.cine_log.append({"id": id, "dur": real})
	telemetry.set_lock("cine:" + id, false)
	if real > 15.5:
		push_error("CINE %s ran %.1fs (> 15 s)" % [id, real])


func _process(delta: float) -> void:
	_tick_automation(delta / maxf(Engine.time_scale, 0.05))
	if get_tree().paused:
		return
	telemetry.tick(delta)
	if _label.visible:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	match k:
		KEY_F1: _toggle(1)
		KEY_F2: _toggle(2)
		KEY_F3: _toggle(3)
		KEY_F4: _toggle(4)
		KEY_F5:
			get_node("/root/Data").reload()
			get_node("/root/Bus").hint_requested.emit("data reloaded", 1.5)
		KEY_F6:
			get_node("/root/Episode").save_game()
			get_node("/root/Bus").hint_requested.emit("quick-save", 1.5)
		KEY_F7:
			if get_node("/root/Episode").load_game() and Services.scenes:
				Services.scenes.respawn_current()
		KEY_PAGEUP:
			_cursor = maxi(0, _cursor - 1)
		KEY_PAGEDOWN:
			_cursor += 1
		KEY_ENTER, KEY_KP_ENTER:
			_activate()
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle(m: int) -> void:
	if _mode == m:
		_mode = 0
	else:
		_mode = m
		_cursor = 0
	_label.visible = _mode != 0


func _list() -> Array:
	var D := get_node("/root/Data")
	if _mode == 2:
		var s: Array = D.scenes.keys()
		s.sort()
		return s
	if _mode == 3:
		var f: Array = D.facts.keys()
		f.sort()
		return f
	return []


func _activate() -> void:
	var l := _list()
	if l.is_empty():
		return
	var id: String = l[clampi(_cursor, 0, l.size() - 1)]
	if _mode == 2 and Services.scenes:
		Services.scenes.debug_jump(id)
		_toggle(2)
	elif _mode == 3:
		get_node("/root/Episode").give_fact(id, "debug")


func _refresh() -> void:
	var E := get_node("/root/Episode")
	var t := ""
	match _mode:
		1:
			t = "[b]F1 STATE[/b]  scene %s  phase %s  zone %s  clock %.0f\n" % [E.scene_id, E.phase_name(), E.hero_zone, E.clock_sec]
			t += "leads %s  s1 %s\n" % [E.leads, E.s1_resolution]
			t += "facts %s\n" % [E.facts.keys()]
			t += "obs %s\n" % [E.observations.keys()]
			t += "threads avail %s pinned %s struck %s\n" % [E.threads_available, E.threads_pinned, E.threads_struck]
			t += "items %s\nflags %s\n" % [E.items, E.flags]
			t += "finale %s\n" % [E.finale.to_dict()]
			t += "threat heat %d grabs %d\n" % [E.threat.heat, E.threat.grabs]
			for npc in E.characters:
				var c: CharacterState = E.characters[npc]
				if Presence.is_present(npc) or c.trust != 0 or c.stress != c.start_stress or c.suspicion != 0:
					t += "  %s %s s%d t%d r%d su%d fear%s %s\n" % [npc, c.disposition_name(), c.stress, c.trust, c.respect, c.suspicion, c.fear_hits, c.vars]
		2, 3:
			t = "[b]%s[/b] (PgUp/PgDn, Enter)\n" % ("F2 SCENE JUMP" if _mode == 2 else "F3 FACT GRANT")
			var l := _list()
			_cursor = clampi(_cursor, 0, maxi(0, l.size() - 1))
			var from := maxi(0, _cursor - 20)
			for i in range(from, mini(l.size(), from + 40)):
				var mark := ">" if i == _cursor else " "
				var have: String = " ✓" if _mode == 3 and E.has_fact(l[i]) else ""
				t += "%s %s%s\n" % [mark, l[i], have]
		4:
			t = "[b]F4 PACING[/b]\n" + telemetry.report() + "\n"
			var g := telemetry.gaps()
			for i in range(maxi(0, telemetry.decisions.size() - 25), telemetry.decisions.size()):
				var d: Dictionary = telemetry.decisions[i]
				t += "  %6.1f  %-8s gap %.1f\n" % [d.t, d.kind, g[i]]
			for c in telemetry.cine_log:
				t += "  cine %s %.1fs\n" % [c.id, c.dur]
	_label.text = t
