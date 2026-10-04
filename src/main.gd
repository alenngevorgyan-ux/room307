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
	var cine := CinePlayer.new()
	cine.name = "CinePlayer"
	add_child(cine)
	var audio := AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	var sm := SceneManager.new()
	sm.name = "SceneManager"
	add_child(sm)
	var start := "S01"
	var args := OS.get_cmdline_user_args()
	var i := args.find("--scene")
	if i >= 0 and i + 1 < args.size():
		start = args[i + 1]
		sm.debug_jump(start)
	else:
		sm.goto_scene(start)
