class_name VideoRoom
extends Node
## Scene 05: security monitors. In-control: sit (E), W/S switch cameras, A/D hold to scrub 8×
## (tap to step), 1–5 jump to timestamp tabs, E/Space stands up. Footage is a live graybox
## diorama (SubViewport) with capsules on recorded paths — art-replaceable.
## Facts are granted when an event has been on screen for 1 s. Pavel's return is a soft clock
## with radio cues at T-20 s and T-8 s.

const T_MIN := 1380.0      # 23:00 in minutes
const T_MAX := 1530.0      # 01:30
const PLAY_RATE := 1.0     # footage minutes per real second
const SCRUB_RATE := 8.0
const CAMS := ["LOBBY", "HALL3F", "BAR", "SCORR", "SSTAIR"]
const TABS := [1385.0, 1420.0, 1460.0, 1471.0, 1510.0]

# event: cam, t0, t1, actors [{who, color, from, to}], flags_while, grants [[fact, source]]
const EVENTS := [
	{"id": "lobby_2305", "cam": "LOBBY", "t0": 1385.0, "t1": 1389.0, "actors": [{"c": [0.8, 0.15, 0.15], "from": [-4, 1], "to": [4, -1], "bag": true}],
		"grants": [["F_MARA_LEFT_ALIVE", "video_cam_lobby"]]},
	{"id": "hall_2340", "cam": "HALL3F", "t0": 1420.0, "t1": 1424.0, "actors": [{"c": [0.8, 0.15, 0.15], "from": [-5, 0.5], "to": [-0.6, -1.4]}, {"c": [0.95, 0.8, 0.1], "from": [-5.6, 0.8], "to": [1.4, -1.4]}],
		"grants": [["F_EVA_INVOLVED", "video_cam_hall"], ["F_EVA_ROOM_308", "video_cam_hall"], ["F_MARA_LEFT_ALIVE", "video_cam_hall"]]},
	{"id": "bar_0020", "cam": "BAR", "t0": 1460.0, "t1": 1467.0, "actors": [{"c": [0.8, 0.15, 0.15], "from": [-0.8, 0.0], "to": [-0.7, 0.0]}, {"c": [0.45, 0.3, 0.15], "from": [0.8, 0.0], "to": [0.75, 0.0], "grey": true}],
		"flag": "vid_bar_0020", "grants": [["F_MARA_MET_OLDER_MAN", "video_cam_bar"]]},
	{"id": "scorr_0031", "cam": "SCORR", "t0": 1471.0, "t1": 1475.0, "actors": [{"c": [0.8, 0.15, 0.15], "from": [-5, 0.3], "to": [5, 0.3]}, {"c": [0.45, 0.3, 0.15], "from": [-5.8, -0.3], "to": [4.2, -0.3], "grey": true}],
		"grants": [["F_THOMAS_LOCATION", "video_cam_service"], ["F_MARA_MET_OLDER_MAN", "video_cam_service"]]},
	{"id": "hall_0110", "cam": "HALL3F", "t0": 1510.0, "t1": 1519.0, "actors": [{"c": [0.05, 0.05, 0.06], "from": [5, 0.5], "to": [-0.6, -1.4]}],
		"flag": "daniel_on_monitor", "grants": [["F_DANIEL_SEARCHED_307", "video_cam_hall"]]},
	{"id": "stair_dead", "cam": "SSTAIR", "t0": 1455.0, "t1": 1530.0, "actors": [], "no_signal": true, "flag": "vid_stair_dead", "grants": []},
]

var active := false
var seated := false
var cam_i := 0
var t := 1380.0
var playing := true
var _visible_t: Dictionary = {}
var _jog_hold := 0.0
var viewport: SubViewport
var dio_root: Node3D
var actors: Array = []
var label: Label
var nosig: ColorRect
var monitor: MeshInstance3D
var timer := -1.0
var _cue20 := false
var _cue8 := false


func _ep() -> Node:
	return get_node("/root/Episode")


func _bus() -> Node:
	return get_node("/root/Bus")


func _ready() -> void:
	if Services.world == null:
		return
	_build_monitor()


func _build_monitor() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(400, 240)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.08, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.9, 0.75)
	e.ambient_light_energy = 1.0
	env.environment = e
	viewport.add_child(env)
	dio_root = Node3D.new()
	viewport.add_child(dio_root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 7, 5)
	cam.rotation_degrees = Vector3(-55, 0, 0)
	cam.fov = 60
	cam.current = true
	viewport.add_child(cam)
	var floor_mi := Graybox.box_mesh(Vector3(14, 0.1, 6), Color(0.25, 0.3, 0.27))
	dio_root.add_child(floor_mi)
	for i in 3:
		var a := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.5
		a.mesh = cm
		a.position = Vector3(0, 0.75, 0)
		a.visible = false
		dio_root.add_child(a)
		actors.append(a)
	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	viewport.add_child(label)
	nosig = ColorRect.new()
	nosig.color = Color(0.1, 0.1, 0.1)
	nosig.size = Vector2(400, 240)
	nosig.visible = false
	viewport.add_child(nosig)
	var ns := Label.new()
	ns.text = "НЕТ СИГНАЛА"
	ns.position = Vector2(120, 100)
	ns.add_theme_font_size_override("font_size", 28)
	nosig.add_child(ns)
	monitor = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 1.44)
	monitor.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = viewport.get_texture()
	monitor.material_override = m
	Services.world.add_child(monitor)
	monitor.global_position = get_node("/root/Data").zone_origin("SECURITY") + Vector3(3.0, 1.15, 0.37)


func _exit_tree() -> void:
	if monitor:
		monitor.queue_free()


func clock_text(tm: float) -> String:
	var mins := int(tm) % 1440
	return "%02d:%02d" % [mins / 60, mins % 60]


## Called by the hub logic while the hero is inside SECURITY.
func enter(pavel_distracted: bool) -> void:
	active = true
	timer = 75.0 if pavel_distracted else 50.0
	_cue20 = false
	_cue8 = false
	_bus().music_requested.emit("STEALTH_LOW")


func leave() -> void:
	active = false
	seated = false
	timer = -1.0
	for e in EVENTS:
		if e.has("flag"):
			_ep().clear_flag(String(e.flag))


func sit() -> void:
	seated = true
	if Services.hero:
		Services.hero.sit_at(get_node("/root/Data").marker("SECURITY:chair"), "SECURITY")
		Services.hero.set_meta("seat_mode", "video")
	_bus().hint_requested.emit("W/S — камера · A/D — перемотка · 1–5 — время · E — встать", 4.0)
	_bus().player_decision.emit("sit")


func stand() -> void:
	seated = false
	if Services.hero:
		Services.hero.seated = false
		Services.hero.remove_meta("seat_mode")
		Services.hero.body_vis.set_crouch(0.0)


func select_cam(i: int) -> void:
	cam_i = posmod(i, CAMS.size())
	_bus().sfx_requested.emit("click", null)
	_bus().player_decision.emit("cam")


func jump(tab: int) -> void:
	t = TABS[clampi(tab, 0, TABS.size() - 1)]
	_bus().sfx_requested.emit("click", null)
	_bus().player_decision.emit("timestamp")


func _process(delta: float) -> void:
	if not active:
		return
	var real := delta / maxf(Engine.time_scale, 0.05)
	_tick_timer(real)
	if seated:
		_input_seated(real)
	elif playing:
		t = minf(T_MAX, t + PLAY_RATE * delta)
	_render(real)


func _input_seated(real: float) -> void:
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("context"):
		stand()
		return
	if Input.is_action_just_pressed("move_fwd"):
		select_cam(cam_i - 1)
	if Input.is_action_just_pressed("move_back"):
		select_cam(cam_i + 1)
	for i in 5:
		if Input.is_key_pressed(KEY_1 + i):
			if int(get_meta("last_tab", -1)) != i:
				jump(i)
				set_meta("last_tab", i)
	if not (Input.is_key_pressed(KEY_1) or Input.is_key_pressed(KEY_2) or Input.is_key_pressed(KEY_3) or Input.is_key_pressed(KEY_4) or Input.is_key_pressed(KEY_5)):
		set_meta("last_tab", -1)
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.3:
		_jog_hold += real
		if _jog_hold > 0.25:
			t = clampf(t + dir * SCRUB_RATE * real, T_MIN, T_MAX)
		elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
			t = clampf(t + signf(dir), T_MIN, T_MAX)
			_bus().sfx_requested.emit("click", null)
	else:
		if _jog_hold > 0.0:
			_bus().player_decision.emit("jog")
		_jog_hold = 0.0
		t = minf(T_MAX, t + PLAY_RATE * real)


func _render(real: float) -> void:
	var cam: String = CAMS[cam_i]
	var shown_any := false
	var no_signal := false
	for a in actors:
		a.visible = false
	for e in EVENTS:
		var on: bool = e.cam == cam and t >= float(e.t0) and t <= float(e.t1)
		if e.has("flag"):
			if on:
				_ep().set_flag(String(e.flag))
			else:
				_ep().clear_flag(String(e.flag))
		if not on:
			_visible_t[e.id] = 0.0
			continue
		if e.get("no_signal", false):
			no_signal = true
		var k := (t - float(e.t0)) / maxf(0.01, float(e.t1) - float(e.t0))
		var i := 0
		for ad in e.actors:
			if i >= actors.size():
				break
			var mi: MeshInstance3D = actors[i]
			mi.visible = true
			var c := Graybox.color(ad.c)
			mi.material_override = Graybox.mat(c, 0.3)
			var p: Vector2 = Vector2(ad.from[0], ad.from[1]).lerp(Vector2(ad.to[0], ad.to[1]), clampf(k, 0, 1))
			mi.position = Vector3(p.x, 0.75, p.y)
			i += 1
		shown_any = true
		_visible_t[e.id] = float(_visible_t.get(e.id, 0.0)) + real
		if float(_visible_t[e.id]) >= 1.0:
			for g in e.grants:
				_ep().give_fact(String(g[0]), String(g[1]))
	if label:
		label.text = "CAM %d · %s · %s%s" % [cam_i + 1, cam, clock_text(t), "  ◀◀▶▶" if _jog_hold > 0.25 else ""]
		nosig.visible = no_signal
	if shown_any:
		pass


func _tick_timer(real: float) -> void:
	if timer < 0.0:
		return
	timer -= real
	if timer <= 20.0 and not _cue20:
		_cue20 = true
		_bus().sfx_requested.emit("radio", null)
		ActionRunner.run([{"ambient": "PAVEL_RADIO"}])
	if timer <= 8.0 and not _cue8:
		_cue8 = true
		_bus().sfx_requested.emit("step_walk", null)
		ActionRunner.run([{"ambient": "PAVEL_BACK"}])
	if timer <= 0.0:
		timer = -1.0
		# Pavel walks back to his chair (he'll see the hero if still here)
		ActionRunner.run([{"npc": ["pavel", "hold", {"on": false, "reason": "video"}]}, {"set_schedule": ["pavel", "pavel_loop"]}])
