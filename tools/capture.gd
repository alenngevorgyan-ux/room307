extends SceneTree
## Screenshot capture for visual QA (needs a display; not headless):
##   godot --path . -s res://tools/capture.gd -- --out=/abs/dir [--only=name,name]
## Boots the real game, stages each shot through the normal scene / debug-jump code, lets it run,
## and saves PNGs. Autosave and playtest logging are off; nothing in the game is altered.

var main: Node
var out_dir := "user://captures"
var only: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func D() -> Node:
	return root.get_node("Data")


func E() -> Node:
	return root.get_node("Episode")


func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func hero_at(marker: String, face: String = "") -> void:
	Services.world.place_hero(marker, false)
	if face != "":
		Services.hero.facing = (D().marker(face) - Services.hero.global_position).normalized()
		Services.hero.body_vis.rotation.y = atan2(-Services.hero.facing.x, -Services.hero.facing.z)
	Services.world.camera_director.snap()


func jump(scene_id: String) -> void:
	await _quiet()
	Services.scenes.debug_jump(scene_id)
	await wait(0.4)


## Finish any cine and silence queued dialogue so one shot never leaks into the next.
func _quiet() -> void:
	var cine := main.get_node_or_null("CinePlayer")
	if cine and cine.active != "":
		cine.skip()
		await process_frame
		await process_frame
	ActionRunner.reset()   # delayed actions of the previous shot's scene
	if Services.hud:
		if Services.hud.opening_tween:
			Services.hud.opening_tween.kill()
		Services.hud.opening.modulate.a = 0.0
		Services.hud._sub_queue = []
		Services.hud._next_page()
	if Services.conversation:
		Services.conversation.end_active("CAPTURE")
		Services.conversation.clear_lines()
		Services.conversation.world_queue.clear()
		Services.conversation.current_line = {}
	await process_frame


func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("[capture] ", path)


func want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _run() -> void:
	await wait(0.5)
	Services.scenes.autosave = false
	for m in get_script().get_script_method_list():
		var n := String(m.name)
		if n.begins_with("s_") and want(n.substr(2)):
			await call(n)
	quit()


# ------------------------------------------------------------------ shots (V1.1 UX)

func s_01_opening() -> void:
	await _quiet()
	Services.scenes.goto_scene("S01")
	await wait(2.6)
	await shot("01_opening")


func s_02_bar_subtitle() -> void:
	await _quiet()
	Services.scenes.goto_scene("S01")
	await wait(1.2)
	await shot("02_bar_subtitle_stranger")


func s_03_bar_prompt() -> void:
	await _quiet()
	Services.scenes.goto_scene("S01")
	await wait(14.0)
	hero_at("BAR:hero_stand", "BAR:selin_spot")
	await wait(0.6)
	await shot("03_bar_prompt_talk")


func s_04_hire() -> void:
	E().s1_resolution = "PRIVATE_DEAL"
	await jump("S02")
	await wait(13.5)
	await shot("04_hire_objective")


func s_05_hall_thought() -> void:
	await jump("S03")
	hero_at("HALL_3F:arrive_elev")
	await wait(1.0)
	await shot("05_hall_objective")
	if Services.hints:
		Services.hints.stall = 40.0
	await wait(1.2)
	await shot("06_hall_thought")


func s_07_room_read() -> void:
	await jump("S03")
	hero_at("ROOM_307:desk")
	await wait(1.5)
	await shot("07_room307_prompt")


# ------------------------------------------------------------------ shots (V1.3 camera)

func s_10_social() -> void:
	await _quiet()
	Services.scenes.goto_scene("S01")
	await wait(0.5)
	await _quiet()
	root.get_node("Bus").camera_hint.emit({"clear": true})
	hero_at("BAR:hale_a")
	Services.hero.teleport_to(D().marker("BAR:hale_a") + Vector3(1.2, 0, 1.0), "BAR")
	Services.world.camera_director.snap()
	await wait(1.0)
	await shot("10a_explore_bar")
	Services.conversation.start("X_S01_HALE", true)
	await wait(3.0)
	await shot("10b_social_bar")


func s_11_read() -> void:
	await jump("S03")
	hero_at("ROOM_307:desk")
	await wait(0.8)
	Input.action_press("read")
	await wait(1.5)
	await shot("11_read_focus")
	Input.action_release("read")


func s_12_finale() -> void:
	await jump("S09")
	hero_at("RESTAURANT:S4")
	E().set_phase_name("S09_LIVE")
	await wait(2.0)
	await shot("12_finale_stage")


func s_13_chase() -> void:
	await jump("S07")
	await wait(2.5)
	await shot("13_chase_wide")
