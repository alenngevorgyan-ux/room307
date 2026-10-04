extends SceneLogic
## S08 glue: Mara keeps the table between herself and the hero (until she lowers the
## extinguisher), backs to the door on a called bluff, and the dashcam clip player on the laptop:
## E plays/pauses, A/D scrubs, 12 s; READ tells on the footage (ring, back seat).

const CLIP_LEN := 12.0
const RING_R := 2.2

var clip_t := 0.0
var _ka_t := 0.0
var _watched := 0.0
var viewport: SubViewport
var screen: MeshInstance3D
var driver: MeshInstance3D
var girl: MeshInstance3D
var ring: MeshInstance3D
var flash: ColorRect
var label: Label


func enter() -> void:
	if Services.world:
		_build_clip()


func _build_clip() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.65, 0.8)
	e.ambient_light_energy = 0.9
	env.environment = e
	viewport.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 1.6)
	cam.rotation_degrees = Vector3(-12, 180, 0)
	cam.fov = 75
	cam.current = true
	viewport.add_child(cam)
	# car interior seen from the dashcam (facing back into the cabin)
	var seat_f := Graybox.box_mesh(Vector3(0.6, 0.9, 0.2), Color(0.15, 0.15, 0.17))
	seat_f.position = Vector3(-0.35, 0.6, 0.6)
	viewport.add_child(seat_f)
	var back_seat := Graybox.box_mesh(Vector3(1.6, 0.5, 0.6), Color(0.13, 0.13, 0.15))
	back_seat.position = Vector3(0, 0.4, -0.6)
	viewport.add_child(back_seat)
	driver = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.22
	cm.height = 1.1
	driver.mesh = cm
	driver.material_override = Graybox.mat(Color(0.15, 0.22, 0.45))
	driver.position = Vector3(-0.35, 1.0, 0.75)
	viewport.add_child(driver)
	ring = MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 0.05
	rm.height = 0.1
	ring.mesh = rm
	ring.material_override = Graybox.mat(Color(1.0, 0.8, 0.2), 2.0)
	ring.position = Vector3(-0.15, 1.05, 1.15)
	viewport.add_child(ring)
	girl = MeshInstance3D.new()
	var gm := CapsuleMesh.new()
	gm.radius = 0.2
	gm.height = 1.2
	girl.mesh = gm
	girl.rotation_degrees = Vector3(0, 0, 90)
	girl.material_override = Graybox.mat(Color(0.7, 0.15, 0.15))
	girl.position = Vector3(0.1, 0.75, -0.6)
	viewport.add_child(girl)
	label = Label.new()
	label.position = Vector2(6, 4)
	label.add_theme_font_size_override("font_size", 14)
	viewport.add_child(label)
	flash = ColorRect.new()
	flash.size = Vector2(320, 200)
	flash.color = Color(1, 1, 1, 0)
	viewport.add_child(flash)
	screen = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.62, 0.4)
	screen.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = viewport.get_texture()
	screen.material_override = m
	Services.world.add_child(screen)
	screen.global_position = data().zone_origin("ORCHID") + Vector3(4.5, 0.98, 2.72)
	screen.rotation_degrees = Vector3(-15, 0, 0)


func exit() -> void:
	if screen:
		screen.queue_free()


func tick(delta: float) -> void:
	var E := ep()
	_keep_away(delta)
	_flee(delta)
	_clip(delta)


func _keep_away(delta: float) -> void:
	var E := ep()
	if E.flags.get("mara_lowered", false) or E.flags.get("mara_fleeing", false):
		return
	_ka_t -= delta
	if _ka_t > 0.0 or not Presence.pos.has("hero"):
		return
	_ka_t = 0.4
	var c: Vector3 = data().marker("ORCHID:table_c")
	var h: Vector3 = Presence.pos.hero
	var ang := atan2(h.x - c.x, h.z - c.z) + PI
	var target := c + Vector3(sin(ang) * RING_R, 0, cos(ang) * RING_R)
	run([{"npc": ["mara", "goto_pos", {"pos": target, "speed": "fast"}]}, {"npc": ["mara", "look", {"target": "hero"}]}])


func _flee(_delta: float) -> void:
	var E := ep()
	if not E.flags.get("mara_fleeing", false):
		return
	if not E.flags.get("mara_flee_started", false):
		E.set_flag("mara_flee_started")
		run([{"npc": ["mara", "walk_to", {"marker": "ORCHID:door", "speed": "fast"}]}])
	# hero blocking the door stops her at once
	if Presence.pos.has("hero") and (Presence.pos.hero as Vector3).distance_to(data().marker("ORCHID:door")) < 1.4:
		E.clear_flag("mara_fleeing")
		run([{"npc": ["mara", "stop", {}]}, {"npc": ["mara", "look", {"target": "hero"}]}])


func _clip(delta: float) -> void:
	var E := ep()
	if E.flags.get("clip_done", false):
		return
	var playing: bool = E.flags.get("clip_playing", false) or E.flags.get("clip_autoplay", false)
	var near := Presence.pos.has("hero") and (Presence.pos.hero as Vector3).distance_to(data().marker("ORCHID:laptop")) < 2.4
	if near and E.flags.get("clip_playing", false):
		var dir := Input.get_axis("move_left", "move_right") if Services.world and InputMap.has_action("move_left") else 0.0
		if absf(dir) > 0.3:
			clip_t = clampf(clip_t + dir * 2.5 * delta, 0.0, CLIP_LEN)
			playing = false
	if playing:
		clip_t = minf(CLIP_LEN, clip_t + delta)
		_watched += delta
	E.set_flag("clip_ring_visible", clip_t >= 3.0 and clip_t <= 8.5)
	E.set_flag("clip_backseat_visible", clip_t >= 2.0 and clip_t <= 11.0)
	if E.flags.get("clip_ring_visible", false) == false:
		E.clear_flag("clip_ring_visible")
	if E.flags.get("clip_backseat_visible", false) == false:
		E.clear_flag("clip_backseat_visible")
	if viewport:
		label.text = "REC  %02d:%02d  ▶" % [int(clip_t) / 60, int(clip_t) % 60] if playing else "REC  ❚❚ %.1f" % clip_t
		driver.position.x = -0.35 + sin(clip_t * 2.0) * 0.02
		ring.visible = clip_t >= 3.0 and clip_t <= 8.5
		var f := 0.0
		if clip_t >= 9.3 and clip_t <= 10.2:
			f = 1.0 - absf(clip_t - 9.6) / 0.6
		flash.color.a = clampf(f, 0, 1)
	if clip_t >= 9.6:
		E.set_flag("clip_impact")
	if clip_t >= CLIP_LEN - 0.01:
		E.set_flag("clip_impact")
		E.set_flag("clip_done")
		E.clear_flag("clip_playing")
		E.clear_flag("clip_autoplay")
		E.beat("BEAT_S8_CLIP_DONE")
