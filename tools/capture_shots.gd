extends Node
## Visual-QA shots (used by tools/capture.gd and the persistent tools/capture_server.gd).
## Each `s_*` method stages a moment through the normal scene / debug-jump code and saves a PNG
## of `view` (the viewport the game renders into). Nothing in the game is altered.

var main: Node
var view: Viewport
var out_dir := "user://captures"
var only: Array = []


func D() -> Node:
	return get_tree().root.get_node("Data")


func E() -> Node:
	return get_tree().root.get_node("Episode")


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


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
		await get_tree().process_frame
		await get_tree().process_frame
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
	await get_tree().process_frame


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# macOS skips drawing occluded windows (the capture window sits behind whatever is on screen):
	# render this exact frame explicitly before reading it back
	RenderingServer.force_draw(false)
	RenderingServer.force_draw(false)
	var img := view.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("[capture] ", path)


func want(name: String) -> bool:
	return only.is_empty() or only.has(name)


## Runs every shot method `s_*` (or only those listed) and returns when done.
func run_shots(out: String, only_list: Array) -> void:
	out_dir = out
	only = only_list
	DirAccess.make_dir_recursive_absolute(out_dir)
	await wait(0.5)
	Services.scenes.autosave = false
	for m in get_script().get_script_method_list():
		var n := String(m.name)
		if n.begins_with("s_") and want(n.substr(2)):
			await call(n)


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
	get_tree().root.get_node("Bus").camera_hint.emit({"clear": true})
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


# ------------------------------------------------------------------ zone tour (V1.4–V1.6 look)

const TOUR := [
	["S04", "BAR:hero_stand"], ["S04", "LOBBY:adrian_mid"], ["S04", "LOBBY:receptionist"], ["S04", "ELEV_A:hero"],
	["S04", "HALL_3F:door_307"], ["S04", "ROOM_307:desk"], ["S04", "ROOM_307:bath_center"], ["S04", "ROOM_308:center"],
	["S04", "ROOF_SMOKING:arrive"], ["S04", "SECURITY:enter_staff"], ["S04", "SCORR:key_hook"], ["S04", "SERVICE_STAIR:l2"],
	["S04", "LAUNDRY:enter"], ["S04", "LOADING_DOCK:enter"], ["S04", "KITCHEN:mid"], ["S04", "COLD_STORAGE:mid"],
	["S04", "STAFF_CORRIDOR:mid"], ["S04", "MEZZANINE:mid"], ["S04", "BCORR:mid"], ["S04", "BHALL:mid"],
	["S08", "ORCHID:hero_in"], ["S09", "RESTAURANT:enter"], ["EPI", "STREET:enter"],
]


func s_20_tour() -> void:
	var cur := ""
	for t in TOUR:
		if t[0] != cur:
			cur = t[0]
			await jump(cur)
			await _quiet()
		hero_at(t[1])
		root_bus().camera_hint.emit({"clear": true})
		Services.world.camera_director.snap()
		await wait(0.8)
		await shot("t_" + String(t[1]).replace(":", "_"))


func root_bus() -> Node:
	return get_tree().root.get_node("Bus")


func s_99_debug_lobby() -> void:
	await jump("S04")
	await _quiet()
	hero_at("LOBBY:adrian_mid")
	root_bus().camera_hint.emit({"clear": true})
	Services.world.camera_director.snap()
	await wait(0.8)
	var cam: Camera3D = Services.world.camera_director.cam
	print("[dbg] cam pos ", cam.global_position, " rot ", cam.global_rotation_degrees, " fov ", cam.fov, " hero ", Services.hero.global_position, " zone ", Services.hero.current_zone)
	print("[dbg] rig ", Services.world.camera_director.current_rig().get("key"), " mode ", Services.world.camera_director.mode_name)
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, Services.hero.global_position + Vector3(0, 1, 0), 1)
	var hit := space.intersect_ray(q)
	print("[dbg] ray hit ", hit.get("collider"), " at ", hit.get("position"))
	print("[dbg] faded ", Services.world.camera_director._faded)
	await shot("dbg_lobby")
