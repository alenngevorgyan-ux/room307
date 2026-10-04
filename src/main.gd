extends Node
## Boot: input map, world, HUD, directors, then the first scene (or `-- --scene S04`).

var world: HotelWorld
var hud: HUD


func _ready() -> void:
	InputSetup.install()
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
	var sm := SceneManager.new()
	sm.name = "SceneManager"
	add_child(sm)
	var start := "S01"
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autopilot"):
			_autopilot.call_deferred(a.substr(12) if a.length() > 12 else "A_MARA")
	var i := args.find("--scene")
	if i >= 0 and i + 1 < args.size():
		start = args[i + 1]
		sm.debug_jump(start)
	else:
		sm.goto_scene(start)


func _autopilot(ending: String) -> void:
	var ap := Autopilot.new()
	ap.name = "Autopilot"
	ap.ending = ending
	add_child(ap)
	await ap.run()
	print("[autopilot] RESULT ", "FAIL" if ap.failed or get_node("/root/Episode").phase_name() != "DONE" else "PASS")
	get_tree().quit(1 if ap.failed or get_node("/root/Episode").phase_name() != "DONE" else 0)
