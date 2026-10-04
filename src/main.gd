extends Node
## Boot: input map, world, HUD, directors, then the first scene (or `-- --scene S04`).

var world: HotelWorld
var hud: HUD


func _ready() -> void:
	InputSetup.install()
	# one local playtest log per app session (survives in-game restarts)
	var dbg := get_node("/root/Debug")
	if not dbg.has_node("PlaytestLog") and not "--no-playtest-log" in OS.get_cmdline_user_args():
		var pl := PlaytestLog.new()
		pl.name = "PlaytestLog"
		dbg.add_child(pl)
	Presence.clear()
	ActionRunner.reset()
	world = HotelWorld.new()
	world.name = "HotelWorld"
	add_child(world)
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	var conv := ConversationDirector.new()
	conv.name = "ConversationDirector"
	add_child(conv)
	var traps := TrapDirector.new()
	traps.name = "TrapDirector"
	add_child(traps)
	var oh := OverhearDirector.new()
	oh.name = "OverhearDirector"
	add_child(oh)
	var cine := CinePlayer.new()
	cine.name = "CinePlayer"
	add_child(cine)
	var audio := AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	var chase := ChaseDirector.new()
	chase.name = "ChaseDirector"
	add_child(chase)
	var hints := HintDirector.new()
	hints.name = "HintDirector"
	add_child(hints)
	var bl: Node = preload("res://src/npc/body_language.gd").new()
	bl.name = "BodyLanguage"
	add_child(bl)
	var sm := SceneManager.new()
	sm.name = "SceneManager"
	add_child(sm)
	var start := "S01"
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autopilot") and not get_node("/root/Debug").has_meta("booted"):
			_autopilot.call_deferred(a.substr(12) if a.length() > 12 else "A_MARA")
	var i := args.find("--scene")
	var D := get_node("/root/Debug")
	if D.pending_resume and get_node("/root/Episode").load_game():
		D.pending_resume = false
		var saved: Dictionary = get_node("/root/Episode").to_dict()
		var sid: String = get_node("/root/Episode").scene_id
		sm.autosave = false
		sm.goto_scene(sid)
		get_node("/root/Episode").from_dict(saved)
		sm.autosave = true
		hud.show_toast("Чекпоинт: начало сцены %s" % sid, 3.0)
	elif i >= 0 and i + 1 < args.size() and not D.has_meta("booted"):
		start = args[i + 1]
		sm.debug_jump(start)
	else:
		sm.goto_scene(start)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		get_node("/root/Debug").set_meta("booted", true)


func _autopilot(ending: String) -> void:
	var ap := Autopilot.new()
	ap.name = "Autopilot"
	ap.ending = ending
	add_child(ap)
	await ap.run()
	print("[autopilot] RESULT ", "FAIL" if ap.failed or get_node("/root/Episode").phase_name() != "DONE" else "PASS")
	get_tree().quit(1 if ap.failed or get_node("/root/Episode").phase_name() != "DONE" else 0)
