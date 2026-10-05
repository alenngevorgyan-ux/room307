class_name ReadSystem
extends Node
## READ (STATE_MODEL §5): hold to slow time to 0.6, low-pass ambience, vignette, aim a reticle,
## dwell on an observable to notice it. No meter. Never shows a conclusion.

const SCALE_NORMAL := 0.6
const SCALE_CHASE := 0.8
const RETICLE_CLAMP := 0.45

var active := false
var reticle := Vector2.ZERO
var focus: Observable = null
var focus_t := 0.0
var camera: Camera3D
var enabled := true
var _last_usec := 0


func _ready() -> void:
	Services.read = self
	_last_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	if Services.read == self:
		Services.read = null
	if active:
		_set_active(false)


func _ep() -> Node:
	return get_node("/root/Episode")


func can_read() -> bool:
	return enabled and not get_tree().paused and Services.hero != null and not Services.hero.input_locked()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf((now - _last_usec) / 1_000_000.0, 0.1)
	_last_usec = now
	var want := Input.is_action_pressed("read") and can_read()
	if want != active:
		_set_active(want)
	if not active:
		return
	camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	_update_reticle()
	var best := _find_focus()
	if best != focus:
		focus = best
		focus_t = 0.0
	if focus:
		focus_t += real_dt
		if focus_t >= focus.dwell:
			_notice(focus)
			focus = null
			focus_t = 0.0
	if Services.hud:
		Services.hud.set_read_focus(reticle, focus_t / focus.dwell if focus else 0.0)


func _set_active(on: bool) -> void:
	active = on
	focus = null
	focus_t = 0.0
	var scale := SCALE_CHASE if _ep().flags.get("chase_active", false) else SCALE_NORMAL
	Engine.time_scale = scale if on else 1.0
	var bus_i := AudioServer.get_bus_index("Ambience")
	if bus_i >= 0 and AudioServer.get_bus_effect_count(bus_i) > 0:
		AudioServer.set_bus_effect_enabled(bus_i, 0, on)
	if Services.hud:
		Services.hud.set_read_active(on)
	if on:
		reticle = get_viewport().get_mouse_position()
		get_node("/root/Bus").player_decision.emit("read")


func _hero_head_screen() -> Vector2:
	var h: Node3D = Services.hero
	return camera.unproject_position(h.global_position + Vector3(0, 1.6, 0))


func _update_reticle() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var pad := Vector2(Input.get_axis("aim_left", "aim_right"), Input.get_axis("aim_up", "aim_down"))
	if pad.length() > 0.2:
		reticle += pad * vp.y * 0.9 * get_process_delta_time() / maxf(Engine.time_scale, 0.1)
		Input.warp_mouse(reticle)
	else:
		reticle = m
	var c := _hero_head_screen()
	var r := vp.y * RETICLE_CLAMP
	if reticle.distance_to(c) > r:
		reticle = c + (reticle - c).normalized() * r


func _find_focus() -> Observable:
	var hero: Node3D = Services.hero
	var best: Observable = null
	var best_score := INF
	var lights_full: bool = _ep().scene_id == "S09" and _ep().finale.lights == "full"
	for n in get_tree().get_nodes_in_group("observables"):
		var o := n as Observable
		if o == null or not o.readable():
			continue
		var wp := o.global_position
		if wp.distance_to(hero.global_position) > o.max_distance:
			continue
		if not camera.is_position_in_frustum(wp):
			continue
		var sp := camera.unproject_position(wp)
		var rad := o.focus_radius * (1.6 if lights_full else 1.0) * (1.25 if Settings.read_assist else 1.0)
		var edge := camera.unproject_position(wp + camera.global_transform.basis.x * rad)
		var px := maxf(sp.distance_to(edge), 16.0)
		var d := sp.distance_to(reticle)
		if d > px:
			continue
		var score := d / px
		if score < best_score and _los(wp):
			best = o
			best_score = score
	return best


## Line of sight from the camera; invisible geometry (the camera-side cutaway walls) does not count.
func _los(target: Vector3) -> bool:
	return NPC._clear_line(camera.get_world_3d().direct_space_state, camera.global_position, target)


func _notice(o: Observable) -> void:
	if _ep().notice(o.obs_id):
		get_node("/root/Bus").caption_shown.emit(o.obs_id, o.caption, o.global_position)
		get_node("/root/Bus").sfx_requested.emit("pen", o.global_position)
