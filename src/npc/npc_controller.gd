class_name NPC
extends CharacterBody3D
## Capsule NPC: beat-driven waypoint schedules (loop / once / lead / stay), cross-zone routing
## through doorways, look-at, hand-pose tells, barks, attached TELL observables, optional perception.
## NPCs never physically collide with the hero (no softlocks); they pause politely instead.

const SPEEDS := {"walk": 1.45, "fast": 2.5, "run": 5.0, "slow": 0.9}
const ARRIVE := 0.35

var npc_id: String = ""
var def: Dictionary = {}
var body_vis: BodyVisual
var bubble: Label3D
var current_zone := ""
var spawned := false
var perception: Perception = null
var tells: Dictionary = {}

# schedule
var schedule_id := ""
var sched: Dictionary = {}
var point_i := 0
var wait_left := 0.0
var arrived := false
var hold := false
var hold_reasons: Dictionary = {}
var face_hero := false
var look_override: Variant = null      # "hero" | npc id | marker | null
var speed_name := "walk"
var speed_mult := 1.0
var external_control := false          # chase/finale drive this NPC directly

# movement
var goal := Vector3.INF
var goal_zone := ""
var route: Array = []
var nav: NavigationAgent3D
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _block_t := 0.0
var _bubble_t := 0.0
var _follow: Dictionary = {}
var _lead_wait := false


func setup(id: String, d: Dictionary) -> void:
	npc_id = id
	def = d
	name = "NPC_" + id
	add_to_group("npcs")
	collision_layer = Graybox.LAYER_NPC
	collision_mask = Graybox.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	add_child(cs)
	var gb: Dictionary = d.get("graybox", {})
	body_vis = BodyVisual.new()
	body_vis.name = "Body"
	add_child(body_vis)
	body_vis.build(Graybox.color(gb.get("color", [0.5, 0.5, 0.5])), float(gb.get("scale", 1.0)), gb)
	bubble = Graybox.label3d("", 34, Color(1, 1, 0.95))
	bubble.fixed_size = true
	bubble.pixel_size = 0.00055
	bubble.position = Vector3(0, 2.25 * float(gb.get("scale", 1.0)), 0)
	bubble.visible = false
	bubble.width = 600
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(bubble)
	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.4
	nav.target_desired_distance = ARRIVE
	nav.radius = 0.3
	nav.height = 1.8
	add_child(nav)
	if d.has("perception"):
		perception = Perception.new(self, d.perception)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	var B := get_node("/root/Bus")
	B.npc_command.connect(_on_command)
	B.line_started.connect(_on_line)
	B.bark_requested.connect(_on_bark)
	B.noise.connect(_on_noise)
	_despawn()


func attach_observable(o: Observable, part: String, off: Vector3) -> void:
	var parent: Node3D = body_vis
	var base := Vector3(0, 1.4, 0)
	match part:
		"head", "eyes", "face":
			parent = body_vis.head
			base = Vector3(0, 0.05, -0.12)
		"left_hand", "left_wrist":
			parent = body_vis.hand_l
			base = Vector3.ZERO
		"right_hand", "hand", "ring":
			parent = body_vis.hand_r
			base = Vector3.ZERO
		"pocket", "chest":
			base = Vector3(0.12, 1.32, -0.25)
		"feet", "stance":
			base = Vector3(0, 0.35, -0.2)
		"body":
			base = Vector3(0, 1.1, -0.25)
	o.position = base + off
	parent.add_child(o)
	tells[o.obs_id] = o


func display_name() -> String:
	return String(def.get("display", npc_id))


func talkable() -> bool:
	if not spawned or def.get("silhouette", false):
		return false
	var c: CharacterState = get_node("/root/Episode").ch(npc_id)
	if c and c.disposition == CharacterState.Disposition.GONE:
		return false
	return true


func on_hero_interact() -> void:
	if Services.conversation and Services.conversation.talk_to(npc_id):
		return
	# handled by an interactable bound to this NPC?
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it and String(it.def.get("npc", "")) == npc_id and it.is_available():
			it.use()
			return
	var barks: Array = def.get("idle_barks", ["…"])
	say(String(barks[randi() % barks.size()]), 2.0)
	get_node("/root/Bus").player_decision.emit("talk")


# ================================================================== spawn / commands

func _despawn() -> void:
	spawned = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	Presence.remove(npc_id)
	global_position = Vector3(0, -500, 0) if is_inside_tree() else position


func spawn_at(p: Vector3, zone_id: String) -> void:
	spawned = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = p
	velocity = Vector3.ZERO
	current_zone = zone_id
	goal = Vector3.INF
	route = []
	Presence.place(npc_id, zone_id, p)
	var c: CharacterState = get_node("/root/Episode").ch(npc_id)
	if c:
		c.zone = zone_id


func teleport(p: Vector3, zone_id: String) -> void:
	global_position = p
	current_zone = zone_id
	velocity = Vector3.ZERO
	Presence.place(npc_id, zone_id, p)
	var c: CharacterState = get_node("/root/Episode").ch(npc_id)
	if c:
		c.zone = zone_id


func _D() -> Node:
	return get_node("/root/Data")


func _on_command(id: String, cmd: String, args: Dictionary) -> void:
	if id != npc_id:
		return
	match cmd:
		"spawn":
			var m := String(args.get("marker", ""))
			if m != "":
				spawn_at(_D().marker(m), _D().marker_zone(m))
			elif not spawned:
				spawn_at(global_position, current_zone)
		"despawn":
			_despawn()
		"teleport":
			var m := String(args.marker)
			if not spawned:
				spawn_at(_D().marker(m), _D().marker_zone(m))
			else:
				teleport(_D().marker(m), _D().marker_zone(m))
		"schedule":
			set_schedule(String(args.id))
		"hold":
			var reason := String(args.get("reason", "conv"))
			if bool(args.get("on", true)):
				hold_reasons[reason] = true
			else:
				hold_reasons.erase(reason)
			hold = not hold_reasons.is_empty()
		"face_hero":
			face_hero = bool(args.get("on", true))
		"look":
			look_override = args.get("target")
		"walk_to":
			set_schedule("")
			speed_name = String(args.get("speed", "walk"))
			go_to(_D().marker(String(args.marker)), _D().marker_zone(String(args.marker)))
		"pose":
			body_vis.set_pose(String(args.get("pose", "rest")))
		"follow":
			_follow = {"target": String(args.get("target", "hero")), "dist": float(args.get("dist", 1.6))}
			set_schedule("")
		"unfollow":
			_follow = {}
		"stop":
			set_schedule("")
			goal = Vector3.INF
			route = []
		"speed":
			speed_mult = float(args.get("mult", 1.0))
			if args.has("name"):
				speed_name = String(args.name)
		"say":
			say(String(args.get("text", "")), float(args.get("dur", 2.5)))
		"face":
			var p: Vector3 = _D().marker(String(args.marker))
			_face_point(p, true)


func set_schedule(id: String) -> void:
	schedule_id = id
	sched = _D().schedules.get(id, {}) if id != "" else {}
	point_i = 0
	wait_left = 0.0
	arrived = false
	_lead_wait = false
	if not sched.is_empty():
		_follow = {}
		_goto_point()
	var c: CharacterState = get_node("/root/Episode").ch(npc_id)
	if c:
		c.schedule = id


func _goto_point() -> void:
	var pts: Array = sched.get("points", [])
	if pts.is_empty():
		return
	var p: Dictionary = pts[point_i]
	speed_name = String(p.get("speed", sched.get("speed", "walk")))
	arrived = false
	if p.has("at"):
		go_to(_D().marker(String(p.at)), _D().marker_zone(String(p.at)))
	else:
		_arrive()


func go_to(p: Vector3, zone_id: String) -> void:
	goal = p
	goal_zone = zone_id
	route = _D().route(current_zone, zone_id) if zone_id != current_zone else []
	_stuck_t = 0.0
	_set_nav_target()


func _set_nav_target() -> void:
	if route.is_empty():
		nav.target_position = goal
	else:
		var door: Doorway = Services.world.door(String(route[0])) if Services.world else null
		if door:
			nav.target_position = door.spawn_point()


func at_goal() -> bool:
	return goal == Vector3.INF


# ================================================================== physics

func _physics_process(delta: float) -> void:
	if not spawned:
		return
	Presence.place(npc_id, current_zone, global_position)
	_tick_bubble(delta)
	if perception:
		perception.update(delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	var move_dir := Vector3.ZERO
	if not hold and not external_control:
		if not _follow.is_empty():
			move_dir = _follow_dir()
		elif goal != Vector3.INF:
			move_dir = _move_dir()
		else:
			_tick_schedule(delta)
	var sp := float(SPEEDS.get(speed_name, 1.45)) * speed_mult
	if external_control:
		pass
	else:
		var hv := move_dir * sp
		# polite pause when the hero stands right in the way
		if hv.length() > 0.1 and Services.hero:
			var to_h: Vector3 = Services.hero.global_position - global_position
			to_h.y = 0
			if Presence.in_zone("hero") == current_zone and to_h.length() < 0.85 and to_h.normalized().dot(hv.normalized()) > 0.6:
				_block_t += delta
				if _block_t < 2.5:
					hv = Vector3.ZERO
				elif _block_t < 2.6:
					say(String(def.get("excuse", "Позвольте.")), 1.4)
			else:
				_block_t = 0.0
		velocity.x = hv.x
		velocity.z = hv.z
		move_and_slide()
	_update_facing(delta)


func _move_dir() -> Vector3:
	# reached a doorway on the route?
	if not route.is_empty() and Services.world:
		var door: Doorway = Services.world.door(String(route[0]))
		if door == null:
			route = []
		else:
			var to := door.spawn_point() - global_position
			to.y = 0
			if to.length() < 0.6:
				var tgt := door.target()
				route.pop_front()
				if tgt:
					teleport(tgt.spawn_point(), tgt.zone_id)
					door.traversed.emit(door.door_id, npc_id)
				_set_nav_target()
				return Vector3.ZERO
	var dest := nav.target_position
	var flat := dest - global_position
	flat.y = 0
	if route.is_empty() and flat.length() < ARRIVE:
		goal = Vector3.INF
		velocity = Vector3.ZERO
		_on_goal_reached()
		return Vector3.ZERO
	var nxt := nav.get_next_path_position()
	var d := nxt - global_position
	d.y = 0
	if d.length() < 0.05 or nav.is_navigation_finished():
		d = flat
	# stuck detection -> nudge to destination
	_stuck_t += get_physics_process_delta_time()
	if _stuck_t > 1.0:
		if global_position.distance_to(_last_pos) < 0.15:
			if route.is_empty():
				global_position = dest
			else:
				global_position = nav.target_position
		_stuck_t = 0.0
		_last_pos = global_position
	return d.normalized()


func _follow_dir() -> Vector3:
	var t := String(_follow.target)
	var tp: Vector3
	if t == "hero":
		if Services.hero == null:
			return Vector3.ZERO
		tp = Services.hero.global_position
		if Presence.in_zone("hero") != current_zone:
			# follow through doors: route to hero zone
			go_to(tp, Presence.in_zone("hero"))
			return _move_dir()
	else:
		if not Presence.pos.has(t):
			return Vector3.ZERO
		tp = Presence.pos[t]
	var to := tp - global_position
	to.y = 0
	if to.length() <= float(_follow.dist):
		return Vector3.ZERO
	nav.target_position = tp
	var nxt := nav.get_next_path_position() - global_position
	nxt.y = 0
	if nxt.length() < 0.05:
		nxt = to
	return nxt.normalized()


func _on_goal_reached() -> void:
	if not sched.is_empty():
		_arrive()


func _arrive() -> void:
	arrived = true
	var pts: Array = sched.get("points", [])
	var p: Dictionary = pts[point_i]
	wait_left = float(p.get("wait", 0.0))
	if p.has("pose"):
		body_vis.set_pose(String(p.pose))
	if p.has("face"):
		_face_point(_D().marker(String(p.face)), true)
	if p.has("look"):
		look_override = p.look
	elif not p.has("keep_look"):
		look_override = null
	if p.has("tell"):
		var tl: Dictionary = p.tell
		ActionRunner.run([{"delay": float(tl.get("at", 0.3)), "do": [{"tell": [tl.obs, float(tl.get("dur", 1.5))]}]}])
	if p.has("bark"):
		get_node("/root/Bus").bark_requested.emit(npc_id, String(_D().line(String(p.bark)).text))
	if p.has("activity"):
		var c: CharacterState = get_node("/root/Episode").ch(npc_id)
		if c:
			c.activity = String(p.activity)
	if p.has("actions"):
		ActionRunner.run(p.actions, {"npc": npc_id, "source": schedule_id})
	if p.has("beat"):
		get_node("/root/Episode").beat(String(p.beat))


func _tick_schedule(delta: float) -> void:
	if sched.is_empty() or not arrived:
		return
	var pts: Array = sched.get("points", [])
	var mode := String(sched.get("mode", "loop"))
	if mode == "lead":
		# FOLLOW_LEAD: move on only while the hero is close; otherwise stop and turn (impatience)
		var r := float(sched.get("wait_radius", 6.0))
		var close := Presence.in_zone("hero") == current_zone and Presence.distance("hero", npc_id) <= r
		if not close:
			if not _lead_wait:
				_lead_wait = true
				look_override = "hero"
				if sched.has("impatience_bark"):
					get_node("/root/Bus").bark_requested.emit(npc_id, String(_D().line(String(sched.impatience_bark)).text))
			return
		if _lead_wait:
			_lead_wait = false
			look_override = null
	wait_left -= delta
	if wait_left > 0.0:
		return
	if point_i + 1 >= pts.size():
		if mode == "loop":
			point_i = 0
		else:
			if sched.has("on_done") and not arrived_done():
				set_meta("sched_done", schedule_id)
				ActionRunner.run(sched.on_done, {"npc": npc_id, "source": schedule_id})
			return
	else:
		point_i += 1
	_goto_point()


func arrived_done() -> bool:
	return get_meta("sched_done", "") == schedule_id


func _update_facing(delta: float) -> void:
	var look_pt: Variant = null
	if face_hero and Services.hero and Presence.in_zone("hero") == current_zone:
		look_pt = Services.hero.global_position + Vector3(0, 1.6, 0)
	if look_override != null:
		look_pt = _resolve_look(look_override)
	body_vis.look_target = look_pt
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 0.2:
		_face_dir(hv.normalized(), delta)
	elif face_hero and look_pt != null:
		var to: Vector3 = (look_pt as Vector3) - global_position
		to.y = 0
		if to.length() > 0.1:
			_face_dir(to.normalized(), delta * 0.6)


func _resolve_look(t: Variant) -> Variant:
	var s := String(t)
	if s == "hero":
		return Services.hero.global_position + Vector3(0, 1.6, 0) if Services.hero else null
	if Presence.pos.has(s):
		return (Presence.pos[s] as Vector3) + Vector3(0, 1.6, 0)
	if s.contains(":") and _D().has_marker(s):
		return _D().marker(s)
	return null


func _face_dir(dir: Vector3, delta: float) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	body_vis.rotation.y = lerp_angle(body_vis.rotation.y, yaw, minf(1.0, delta * 8.0))


func _face_point(p: Vector3, instant: bool) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() < 0.01:
		return
	if instant:
		body_vis.rotation.y = atan2(-to.x, -to.z)
	else:
		_face_dir(to.normalized(), 0.1)


func facing_dir() -> Vector3:
	var yaw := body_vis.rotation.y
	return Vector3(-sin(yaw), 0, -cos(yaw))


# ================================================================== speech

func _on_line(speaker: String, text: String, dur: float) -> void:
	if speaker == npc_id:
		say(text, dur)


func _on_bark(id: String, text: String) -> void:
	if id == npc_id:
		say(text, Data.line_duration(text))


func say(text: String, dur: float) -> void:
	if not spawned:
		return
	bubble.text = text
	bubble.visible = true
	_bubble_t = dur
	body_vis.set_pose(body_vis.pose)


func _tick_bubble(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			bubble.visible = false


func _on_noise(pos: Vector3, radius: float, _src: String) -> void:
	if perception and spawned:
		perception.on_noise(pos, radius)
