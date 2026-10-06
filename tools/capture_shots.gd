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
	Services.world.camera_director.snap(false)


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
	Services.world.camera_director.snap(false)
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
		Services.world.camera_director.snap(false)
		await wait(0.8)
		await shot("t_" + String(t[1]).replace(":", "_"))


func root_bus() -> Node:
	return get_tree().root.get_node("Bus")


func s_99_debug_lobby() -> void:
	await jump("S04")
	await _quiet()
	hero_at("LOBBY:adrian_mid")
	root_bus().camera_hint.emit({"clear": true})
	Services.world.camera_director.snap(false)
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


# ------------------------------------------------------------------ cast line-up (V1.6 proxies)

const CAST := ["adrian", "mara", "nico", "daniel", "eva", "thomas", "lina", "pavel", "receptionist", "brody", "sato", "hale"]


func _lineup(ids: Array, name: String, closeup: bool) -> void:
	var lobby: Node3D = Services.world.zone_node("LOBBY")
	var o := lobby.global_position
	var x0 := 6.0 - (ids.size() - 1) * 0.55
	for i in ids.size():
		var id: String = ids[i]
		var p := o + Vector3(x0 + i * 1.1, 0, 5.0)
		if id == "hero":
			Services.hero.teleport_to(p, "LOBBY")
			Services.hero.body_vis.rotation.y = PI
		else:
			var n: Node = Services.world.npc(id)
			n.spawn_at(p, "LOBBY", true)
			n.set_schedule("")
			n.body_vis.rotation.y = PI
			n.look_override = null
			n.face_hero = false
	await wait(0.4)
	var cd: Node = Services.world.camera_director
	cd.set_process(false)
	var cam: Camera3D = cd.cam
	var dist := 3.4 if closeup else 6.2
	cam.global_position = o + Vector3(6.0, 1.55 if closeup else 2.1, 5.0 + dist)
	cam.look_at(o + Vector3(6.0, 1.15 if closeup else 1.0, 5.0))
	cam.fov = 40.0
	await wait(0.3)
	await shot(name)
	cd.set_process(true)


func s_30_cast() -> void:
	await jump("S04")
	await _quiet()
	for n in get_tree().get_nodes_in_group("npcs"):
		n._hard_despawn()
	await _lineup(["hero", "adrian", "mara", "nico", "daniel", "eva", "thomas"], "30_cast_main", false)
	await _lineup(["lina", "pavel", "receptionist", "brody", "sato", "hale"], "31_cast_support", false)
	await _lineup(["hero", "adrian", "mara", "nico"], "32_cast_close_a", true)
	await _lineup(["daniel", "eva", "thomas", "lina"], "33_cast_close_b", true)


# ------------------------------------------------------------------ finale + epilogue (V1.8)

func s_40_finale_live() -> void:
	await jump("S09")
	var B := root_bus()
	for s in ["S1", "S2", "S3", "S4"]:
		B.trap_bait.emit("stage", {"cmd": "take_card"})
		B.trap_bait.emit("stage", {"cmd": "seat", "arg": s})
	for inv in [["adrian", "alone"], ["mara", "time"], ["daniel", "vale_wants"], ["thomas", "time"]]:
		B.trap_bait.emit("stage", {"cmd": "invite", "to": inv[0], "template": inv[1]})
	B.trap_bait.emit("stage", {"cmd": "start"})
	hero_at("RESTAURANT:S4")
	await wait(24.0)
	await shot("40_finale_live")
	await wait(9.0)
	await shot("41_finale_life_beat")


func s_42_epilogue() -> void:
	await jump("EPI")
	hero_at("STREET:enter")
	await wait(2.0)
	await shot("42_epilogue_dawn")


# ------------------------------------------------------------------ QA set (Design + Motion Polish V1)
# Same recipes before and after the polish: gameplay cameras only, plus frames DURING motion.

func _hold(action: String, sec: float, frames_at: Array, prefix: String) -> void:
	Input.action_press(action)
	var t := 0.0
	for f in frames_at:
		await wait(float(f) - t)
		t = float(f)
		await shot("%s_%.1fs" % [prefix, t])
	Input.action_release(action)
	if sec > t:
		await wait(sec - t)


func _key_toward(dir: Vector3) -> String:
	var cam: Camera3D = Services.world.camera_director.cam
	var yaw := cam.global_rotation.y
	var keys := {"move_left": Vector2(-1, 0), "move_right": Vector2(1, 0), "move_fwd": Vector2(0, 1), "move_back": Vector2(0, -1)}
	var best := ""
	var bd := -2.0
	for k in keys:
		var kv: Vector2 = keys[k]
		var d := Vector3(cos(yaw), 0, -sin(yaw)) * kv.x + Vector3(-sin(yaw), 0, -cos(yaw)) * kv.y
		if d.dot(dir) > bd:
			bd = d.dot(dir)
			best = k
	return best


func s_50_qa() -> void:
	# 01 bar — the opening (seated, the scene's own start camera)
	await _quiet()
	Services.scenes.goto_scene("S01")
	await wait(4.0)
	await shot("qa_01_bar_opening")
	# 02 bar — Nico at work during the hub
	await jump("S04")
	await _quiet()
	hero_at("BAR:nico_tables")
	await wait(1.5)
	await shot("qa_02_bar_nico")
	# 03 room 307
	await jump("S03")
	await _quiet()
	hero_at("ROOM_307:desk")
	await wait(1.5)
	await shot("qa_03_room307")
	# 04 hub corridor
	await jump("S04")
	await _quiet()
	hero_at("HALL_3F:door_307")
	await wait(1.5)
	await shot("qa_04_hub")
	# 05 rooftop with Eva
	hero_at("ROOF_SMOKING:arrive")
	await wait(1.5)
	await shot("qa_05_rooftop")
	# 06 security
	hero_at("SECURITY:enter_staff")
	await wait(1.5)
	await shot("qa_06_security")
	# 07 loading dock, Thomas leaving
	await jump("S06")
	await _quiet()
	hero_at("LOADING_DOCK:hero_block")
	await wait(3.0)
	await shot("qa_07_loading_thomas")
	# 08 chase start, then running through the kitchen
	await jump("S07")
	await wait(1.5)
	await shot("qa_08_chase_start")
	hero_at("KITCHEN:enter")
	await wait(0.6)
	await _hold(_key_toward(Vector3(1, 0, 0)), 1.6, [0.4, 0.8, 1.2], "qm_08_kitchen_run")
	# 09 Mara in the Orchid room
	await jump("S08")
	await wait(2.5)
	await shot("qa_09_mara_orchid")
	# 10 restaurant finale (live)
	await s_40_finale_live()
	# 11 epilogue
	await s_42_epilogue()


func s_51_qa_motion() -> void:
	# walking through the lobby (camera follow, easing, framing)
	await jump("S04")
	await _quiet()
	hero_at("LOBBY:arrive_bar")
	await wait(1.0)
	await _hold(_key_toward(Vector3(1, 0, 0)), 2.4, [0.3, 0.9, 1.6, 2.2], "qm_01_lobby_walk")
	await wait(0.5)
	await shot("qm_01_lobby_walk_stop")
	# conversation with Nico (working while talking)
	hero_at("BAR:nico_tables")
	await wait(1.0)
	Services.conversation.talk_to("nico")
	for i in 4:
		await wait(1.2)
		await shot("qm_02_nico_talk_%d" % i)


# AFTER-only checks for rooms whose camera / light / motion changed in Motion Polish V1
func s_52_qa_extra() -> void:
	await jump("S04")
	await _quiet()
	hero_at("LOBBY:hero_lobby")
	await wait(1.5)
	await shot("qa_15_lobby")
	await jump("S03")
	await _quiet()
	hero_at("ROOM_307:window")
	await wait(2.0)
	await shot("qa_17_room307_window")
	await jump("S07")
	await _quiet()
	hero_at("KITCHEN:mid")
	await wait(2.0)
	await shot("qa_13_kitchen_steam")
	hero_at("KITCHEN:enter")
	await wait(1.0)
	var vm: Node = Services.world.get_node("VesperMotion")
	vm.call("_kick", Services.world.door("KITCHEN_SCORR"), true)
	for t in [0.15, 0.45, 0.9]:
		await wait(0.15 if t == 0.15 else (0.3 if t == 0.45 else 0.45))
		await shot("qm_14_kitchen_door_%.2fs" % t)
	hero_at("LAUNDRY:press")
	await wait(2.0)
	await shot("qa_11_laundry")
	hero_at("COLD_STORAGE:mid")
	await wait(1.5)
	await shot("qa_12_cold")
	await jump("S08")
	await _quiet()
	hero_at("BHALL:mid")
	await wait(1.5)
	await shot("qa_10_banquet")
	await jump("S09")
	await _quiet()
	hero_at("RESTAURANT:enter")
	await wait(2.0)
	await shot("qa_16_restaurant_staging")


func s_54_check() -> void:
	await jump("S06")
	await _quiet()
	hero_at("LOADING_DOCK:hero_block")
	await wait(3.0)
	await shot("chk_dock")
	await jump("S04")
	await _quiet()
	hero_at("BAR:nico_tables")
	await wait(1.5)
	await shot("chk_bar")
	await jump("S09")
	await _quiet()
	hero_at("RESTAURANT:enter")
	await wait(2.0)
	await shot("chk_restaurant")
	await jump("S07")
	await _quiet()
	hero_at("KITCHEN:mid")
	await wait(2.0)
	await shot("chk_kitchen")
	await s_42_epilogue()


# ------------------------------------------------------------------ FINAL VISUAL LANGUAGE — BAR gate
# Same gameplay cameras only (opening fixed rig, hub follow rig). Run on the baseline worktree and on
# the candidate with identical recipes; nothing here changes the camera or staging.

func s_60_bar_art() -> void:
	await _quiet()
	Services.scenes.goto_scene("S01")
	await wait(4.0)
	await shot("bar_01_opening_4s")
	await wait(6.0)
	await shot("bar_02_opening_10s")
	await jump("S04")
	await _quiet()
	# ordinary gameplay framing: no auto-started exchange may switch the camera to its social mode
	Services.conversation.auto_triggers = false
	hero_at("BAR:nico_tables")
	await wait(1.5)
	await shot("bar_03_hub")
	hero_at("BAR:hero_stand")
	await wait(1.5)
	await shot("bar_04_hub_counter")
	Services.conversation.auto_triggers = true


## Motion evidence (no video encoder on this machine): 10 fps frame sequences through the normal game.
func s_61_bar_motion() -> void:
	await jump("S04")
	await _quiet()
	Services.conversation.auto_triggers = false   # same framing on every run (no auto exchange)
	hero_at("BAR:selin_spot")
	await wait(1.2)
	var key := _key_toward(Vector3(1, 0, 0))
	Input.action_press(key)
	for i in 30:
		await wait(0.1)
		await shot("bm_walk_%02d" % i)
	Input.action_release(key)
	Services.conversation.auto_triggers = true
	hero_at("BAR:nico_tables")
	await wait(1.0)
	Services.conversation.talk_to("nico")
	for i in 40:
		await wait(0.15)
		await shot("bm_nico_%02d" % i)


## Render cost of the game view (vsync off). Viewport render time CPU/GPU + wall time of one draw.
func _perf(label: String, warm: float, windows: int, sec: float) -> void:
	var rid := view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await wait(warm)
	var res := {"label": label, "windows": []}
	for w in windows:
		var wall: Array = []
		var gpu: Array = []
		var cpu: Array = []
		var t_end := Time.get_ticks_msec() + int(sec * 1000.0)
		while Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			var t0 := Time.get_ticks_usec()
			RenderingServer.force_draw(false)
			wall.append((Time.get_ticks_usec() - t0) / 1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		wall.sort()
		gpu.sort()
		cpu.sort()
		res.windows.append({"n": wall.size(),
			"wall_median": wall[wall.size() / 2], "wall_p95": wall[int(wall.size() * 0.95)],
			"gpu_median": gpu[gpu.size() / 2], "gpu_p95": gpu[int(gpu.size() * 0.95)],
			"cpu_median": cpu[cpu.size() / 2], "cpu_p95": cpu[int(cpu.size() * 0.95)],
			"over_33ms": wall.filter(func(v): return v > 33.3).size()})
	res["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	res["objects"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	res["primitives"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	res["video_mem_mb"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	res["texture_mem_mb"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0
	var f := FileAccess.open(out_dir.path_join("perf_%s.json" % label), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	RenderingServer.viewport_set_measure_render_time(rid, false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("[perf] ", label, " done")


func s_62_perf() -> void:
	await jump("S04")
	await _quiet()
	hero_at("BAR:nico_tables")
	await _perf("bar_hub", 30.0, 3, 60.0)
	await _quiet()
	Services.scenes.goto_scene("S01")
	await _perf("bar_opening", 3.0, 3, 15.0)


func s_63_perf_short() -> void:
	await jump("S04")
	await _quiet()
	hero_at("BAR:nico_tables")
	await _perf("bar_hub_short", 10.0, 3, 20.0)
	await _quiet()
	Services.scenes.goto_scene("S01")
	await _perf("bar_opening_short", 3.0, 3, 15.0)
	await shot("bar_shadow_probe")



# ------------------------------------------------------------------ FINAL VISUAL LANGUAGE — ROOM 307 gate
# Same gameplay cameras (follow rig + bath fixed rig); auto exchanges off so framing is deterministic.

func s_64_room307_art() -> void:
	await jump("S03")
	await _quiet()
	Services.conversation.auto_triggers = false
	hero_at("ROOM_307:desk")
	await wait(1.8)
	await shot("r307_01_desk")
	hero_at("ROOM_307:window")
	await wait(1.8)
	await shot("r307_02_window")
	hero_at("ROOM_307:lina_bed")
	await wait(1.8)
	await shot("r307_03_bed")
	hero_at("ROOM_307:enter")
	await wait(1.8)
	await shot("r307_04_room_from_door")
	hero_at("ROOM_307:bath_center")
	await wait(2.0)
	await shot("r307_05_bath")
	hero_at("ROOM_307:desk")
	await wait(1.0)
	Input.action_press("read")
	await wait(1.2)
	await shot("r307_06_read_desk")
	Input.action_release("read")
	await wait(0.6)
	Services.conversation.auto_triggers = true


func s_65_room307_motion() -> void:
	await jump("S03")
	await _quiet()
	Services.conversation.auto_triggers = false
	hero_at("ROOM_307:enter")
	await wait(1.2)
	var key := _key_toward(Vector3(0.45, 0, -1).normalized())
	Input.action_press(key)
	for i in 30:
		await wait(0.1)
		await shot("rm_walk_%02d" % i)
	Input.action_release(key)
	hero_at("ROOM_307:window")
	await wait(0.8)
	for i in 16:
		await wait(0.25)
		await shot("rm_curtain_%02d" % i)
	Services.conversation.auto_triggers = true


func s_66_perf_room307() -> void:
	await jump("S03")
	await _quiet()
	Services.conversation.auto_triggers = false
	hero_at("ROOM_307:desk")
	await _perf("room307_desk", 30.0, 3, 60.0)
	Services.conversation.auto_triggers = true


func s_67_perf_room307_short() -> void:
	await jump("S03")
	await _quiet()
	Services.conversation.auto_triggers = false
	hero_at("ROOM_307:desk")
	await _perf("room307_desk_short", 10.0, 3, 20.0)
	Services.conversation.auto_triggers = true
