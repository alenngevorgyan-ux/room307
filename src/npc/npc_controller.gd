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
var _follow: Dictionary = {}
var _lead_wait := false
# Pass 2 — never appear / vanish / jump on camera
var leaving := false               # logically despawned, the body is still walking out of view
var _leave_target := Vector3.INF
var _leave_t := 0.0
var _stuck_seen_t := 0.0
var _entering := false             # walking in from a door to where a script placed us
const LEAVE_MAX := 25.0
const ENTER_MAX_DIST := 16.0
const WALK_TELEPORT_MAX := 14.0


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

# ================================================================== on-camera probe (Pass 2)

## Is this body actually on screen: the hero's zone, inside the camera frustum, and not hidden
## behind walls? Spawning, despawning or jumping while this is true is a visible pop.
func on_camera() -> bool:
	if not (spawned or leaving) or not is_inside_tree() or Services.hero == null:
		return false
	return point_on_camera(global_position, current_zone)


## Would a body standing at `p` in `zone_id` be seen right now?
func point_on_camera(p0: Vector3, zone_id: String) -> bool:
	if not is_inside_tree() or Services.hero == null:
		return false
	if Services.hero.current_zone != zone_id:
		return false
	if Services.hud and Services.hud.fade_rect.color.a > 0.85:
		return false   # under a cut to black
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var space := get_world_3d().direct_space_state
	for h in [1.55, 0.9, 0.3]:
		var p := p0 + Vector3(0, h, 0)
		if not cam.is_position_in_frustum(p):
			continue
		if _clear_line(space, cam.global_position, p):
			return true
	return false


## Line of sight that ignores invisible geometry (the camera-side cutaway walls still collide).
static func _clear_line(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var exclude: Array[RID] = []
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(a, b, Graybox.LAYER_WORLD, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(b) < 0.35:
			return true
		var col: Node = hit.collider
		var vis: Node = col.get_node_or_null("Visual") if col else null
		if vis is Node3D and not (vis as Node3D).visible:
			exclude.append(hit.rid)
			continue
		return false
	return false


func _report_pop(kind: String, extra: Dictionary = {}) -> void:
	var info := {"zone": current_zone, "schedule": schedule_id, "pos": global_position}
	info.merge(extra)
	var stack := get_stack()
	var where: Array = []
	for i in range(1, mini(stack.size(), 6)):
		where.append("%s:%d %s" % [String(stack[i].source).get_file(), stack[i].line, stack[i].function])
	info["where"] = where
	get_node("/root/Bus").npc_popped.emit(npc_id, kind, info)


func _despawn() -> void:
	if spawned and on_camera() and not external_control:
		_begin_leave()
		return
	_hard_despawn()


## Logic sees the NPC gone at once (Presence, talkable, schedules); only the body walks to the
## nearest exit — a real door or an `exit*` marker — and is removed there, or as soon as no one
## can see it.
func _begin_leave() -> void:
	spawned = false
	leaving = true
	_leave_t = 0.0
	Presence.remove(npc_id)
	hold_reasons = {}
	hold = false
	_follow = {}
	sched = {}
	face_hero = false
	look_override = null
	goal = Vector3.INF
	route = []
	if not speed_name in ["fast", "run"]:
		speed_name = "walk"
	_leave_target = _nearest_exit(global_position, current_zone)
	if _leave_target != Vector3.INF:
		nav.target_position = _leave_target
	if body_vis.pose in ["table", "club", "ear", "radio", "open"]:
		body_vis.set_pose("rest")


func _tick_leave(delta: float) -> void:
	_leave_t += delta
	if not on_camera() or _leave_t > LEAVE_MAX:
		_hard_despawn()
		return
	if _leave_target == Vector3.INF:
		return   # nowhere to go: stand until the camera looks away
	var flat := _leave_target - global_position
	flat.y = 0
	if flat.length() < 0.55:
		_hard_despawn()
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	var nxt := nav.get_next_path_position() - global_position
	nxt.y = 0
	if nxt.length() < 0.05 or nav.is_navigation_finished():
		nxt = flat
	var hv := nxt.normalized() * float(SPEEDS.get(speed_name, 1.45))
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	_update_facing(delta)


## Nearest way out of a zone: a doorway that is a real door (not hidden) or an `exit*` marker.
func _nearest_exit(from: Vector3, zone_id: String) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	if Services.world:
		var z: Zone = Services.world.zone_node(zone_id)
		if z:
			for did in z.doors:
				var d: Doorway = z.doors[did]
				if String(d.def.get("kind", "door")) == "hidden":
					continue
				var p := d.global_position + d.normal * 0.3
				var dist := from.distance_to(p)
				if dist < best_d:
					best_d = dist
					best = p
	var marks: Dictionary = _D().zone(zone_id).get("markers", {})
	for m in marks:
		if String(m).begins_with("exit"):
			var p: Vector3 = _D().marker(zone_id + ":" + String(m))
			if from.distance_to(p) < best_d:
				best_d = from.distance_to(p)
				best = p
	return best


func _hard_despawn() -> void:
	leaving = false
	_entering = false
	spawned = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	Presence.remove(npc_id)
	global_position = Vector3(0, -500, 0) if is_inside_tree() else position


## `cut`: the camera cuts here anyway (scene start with a hero placement) — place instantly.
func spawn_at(p: Vector3, zone_id: String, cut: bool = false) -> void:
	var was := spawned
	var was_seen := on_camera()
	var from := global_position
	# a fresh spawn the hero would see appears through the nearest door and walks in
	var enter_from := Vector3.INF
	if not was and not cut and not external_control and point_on_camera(p, zone_id):
		var ex := _nearest_entry(p, zone_id)
		if ex != Vector3.INF and ex.distance_to(p) <= ENTER_MAX_DIST:
			enter_from = ex
	leaving = false
	spawned = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = p if enter_from == Vector3.INF else enter_from
	velocity = Vector3.ZERO
	current_zone = zone_id
	if enter_from == Vector3.INF and ((not was and on_camera()) or (was and from.distance_to(p) > 1.5 and (was_seen or on_camera()))):
		_report_pop("spawn" if not was else "teleport", {"to": p})
	goal = Vector3.INF
	route = []
	if enter_from != Vector3.INF:
		speed_name = "fast"
		go_to(p, zone_id)
		_entering = true
	Presence.place(npc_id, zone_id, p)
	var c: CharacterState = get_node("/root/Episode").ch(npc_id)
	if c:
		c.zone = zone_id


## Public teleport (commands, scene logic): also cancels any walk in progress. A short hop the
## hero would see becomes a brisk walk instead (chase/finale-driven bodies excepted).
func teleport(p: Vector3, zone_id: String, cut: bool = false) -> void:
	if not cut and not external_control and zone_id == current_zone and spawned \
			and global_position.distance_to(p) <= WALK_TELEPORT_MAX and global_position.distance_to(p) > 0.6 \
			and (on_camera() or point_on_camera(p, zone_id)):
		set_schedule("")
		speed_name = "fast"
		go_to(p, zone_id)
		return
	if not cut and not external_control and zone_id != current_zone and spawned and point_on_camera(p, zone_id):
		# arriving where the hero is looking: step in through that zone's door
		var ex := _nearest_entry(p, zone_id)
		if ex != Vector3.INF and ex.distance_to(p) <= ENTER_MAX_DIST:
			_entering = true
			_place(ex, zone_id)
			speed_name = "fast"
			go_to(p, zone_id)
			return
	_entering = false
	goal = Vector3.INF
	route = []
	_place(p, zone_id)


## Where someone walking into a zone appears: the threshold of the door nearest to `p`.
func _nearest_entry(p: Vector3, zone_id: String) -> Vector3:
	if Services.world == null:
		return Vector3.INF
	var z: Zone = Services.world.zone_node(zone_id)
	if z == null:
		return Vector3.INF
	var best := Vector3.INF
	var best_d := INF
	for did in z.doors:
		var d: Doorway = z.doors[did]
		if String(d.def.get("kind", "door")) == "hidden":
			continue
		var q := d.global_position + d.normal * 0.35
		if q.distance_to(p) < best_d:
			best_d = q.distance_to(p)
			best = q
	return best


func _place(p: Vector3, zone_id: String, via_door: Doorway = null) -> void:
	var was_seen := on_camera()
	var from := global_position
	var from_zone := current_zone
	global_position = p
	current_zone = zone_id
	velocity = Vector3.ZERO
	Presence.place(npc_id, zone_id, p)
	var c: CharacterState = get_node("/root/Episode").ch(npc_id)
	if c:
		c.zone = zone_id
	if from.distance_to(p) > 1.5 or from_zone != zone_id:
		if via_door:
			# walking through a real door is fine; vanishing into a hidden/npc-only one is not
			var arrive: Doorway = via_door.target()
			if String(via_door.def.get("kind", "")) == "hidden" and was_seen:
				_report_pop("hidden_door_exit", {"door": via_door.door_id})
			if arrive and String(arrive.def.get("kind", "")) == "hidden" and on_camera():
				_report_pop("hidden_door_enter", {"door": arrive.door_id})
		elif was_seen or (on_camera() and not _entering):
			_report_pop("teleport", {"to": p, "from_zone": from_zone})


func _D() -> Node:
	return get_node("/root/Data")


func _on_command(id: String, cmd: String, args: Dictionary) -> void:
	if id != npc_id:
		return
	match cmd:
		"spawn":
			var m := String(args.get("marker", ""))
			if m != "" and spawned:
				teleport(_D().marker(m), _D().marker_zone(m), bool(args.get("cut", false)))   # re-staging
			elif m != "":
				spawn_at(_D().marker(m), _D().marker_zone(m), bool(args.get("cut", false)))
			elif not spawned:
				spawn_at(global_position, current_zone, bool(args.get("cut", false)))
		"despawn":
			_despawn()
		"teleport":
			var m := String(args.marker)
			if not spawned:
				spawn_at(_D().marker(m), _D().marker_zone(m), bool(args.get("cut", false)))
			else:
				teleport(_D().marker(m), _D().marker_zone(m), bool(args.get("cut", false)))
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
		"goto_pos":
			# world position in the NPC's current zone (keep-away, flee, seating)
			speed_name = String(args.get("speed", speed_name))
			if not sched.is_empty():
				set_schedule("")
			go_to(args.pos as Vector3, current_zone)
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
	if id == "" and not _entering:
		goal = Vector3.INF
		route = []
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
	if leaving:
		_tick_leave(delta)
		return
	if not spawned:
		return
	Presence.place(npc_id, current_zone, global_position)
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
			if _lead_blocked():
				look_override = "hero"
			else:
				move_dir = _move_dir()
		else:
			_tick_schedule(delta)
	if not spawned:
		return   # despawned by its own schedule this frame (removed from the physics space)
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
					_place(tgt.spawn_point(), tgt.zone_id, door)
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
			if on_camera():
				# never snap where it can be seen: wait; a final point can be accepted where we stand
				_stuck_seen_t += _stuck_t
				if route.is_empty() and _stuck_seen_t >= 2.0:
					_stuck_seen_t = 0.0
					_stuck_t = 0.0
					goal = Vector3.INF
					velocity = Vector3.ZERO
					_on_goal_reached()
					return Vector3.ZERO
			else:
				_stuck_seen_t = 0.0
				if route.is_empty():
					global_position = dest
				else:
					global_position = nav.target_position
		else:
			_stuck_seen_t = 0.0
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
	_entering = false
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


## FOLLOW_LEAD: a lead NPC only walks while the hero is within wait_radius.
func _lead_blocked() -> bool:
	if String(sched.get("mode", "")) != "lead":
		return false
	var r := float(sched.get("wait_radius", 6.0))
	var hz := Presence.in_zone("hero")
	# close = near him in his zone, or already ahead in the zone he is walking to
	var close := (hz == current_zone and Presence.distance("hero", npc_id) <= r) or (hz != current_zone and hz == goal_zone)
	if not close and not _lead_wait:
		_lead_wait = true
		if sched.has("impatience_bark"):
			get_node("/root/Bus").bark_requested.emit(npc_id, String(_D().line(String(sched.impatience_bark)).text))
	elif close and _lead_wait:
		_lead_wait = false
		look_override = null
	return not close


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

## Dialogue lines are subtitled by the HUD (bottom of the screen, never above heads); the body
## only reacts. Barks (idle chatter, «Позвольте.») become subtitles when the hero is close by.
func _on_line(speaker: String, _text: String, _dur: float) -> void:
	if speaker == npc_id and spawned:
		body_vis.set_pose(body_vis.pose)


func _on_bark(id: String, text: String) -> void:
	if id == npc_id:
		say(text, Data.line_duration(text))


const BARK_HEAR := 9.0


func say(text: String, dur: float) -> void:
	if not spawned:
		return
	body_vis.set_pose(body_vis.pose)
	if Services.hud and Presence.in_zone("hero") == current_zone and Presence.distance("hero", npc_id) <= BARK_HEAR:
		Services.hud.show_bark(npc_id, text, dur)


func _on_noise(pos: Vector3, radius: float, _src: String) -> void:
	if perception and spawned:
		perception.on_noise(pos, radius)
