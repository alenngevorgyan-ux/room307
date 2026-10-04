class_name PlayerController
extends CharacterBody3D
## The hero: CharacterBody3D, camera-relative XZ input with the rig-blend direction lock.
## walk / fast walk / run / crouch / slide / vault / stairs (ramps) / doors / interact / context.

const RUN := 6.0
const SPEED := {"walk": 0.35, "fast": 0.6, "run": 1.0, "crouch": 0.3, "slide": 1.2}
const ACCEL := 14.0
const GRAVITY := 18.0
const INTERACT_RADIUS := 1.7
const NPC_TALK_RADIUS := 2.2
const DOOR_RADIUS := 1.3

var body_vis: BodyVisual
var basis_helper := InputBasis.new()
var fast_toggle := false
var crouching := false
var sliding := 0.0
var vaulting := false
var stunned := 0.0
var seated := false
var seat_stand_target := Vector3.ZERO
var speed_state := "walk"
var facing := Vector3.FORWARD
var current_zone := ""
var carry_item := ""
var _locks: Dictionary = {}
var _step_t := 0.0
var _hold_t := 0.0
var _hold_target: Node = null
var _last_dir_tap: Dictionary = {}
var _cap_shape: CapsuleShape3D
var _col: CollisionShape3D
var _carry_mesh: MeshInstance3D
var target: Node = null     # current context target (interactable / npc / door)
var target_kind := ""
var speed_mult := 1.0       # chase/blackout modifiers
var arrival_door := ""      # door the hero just came through: no auto-traverse until stepped away
var teleport_serial := 0    # bumped by every teleport (stale door transitions check it)


func _ready() -> void:
	Services.hero = self
	collision_layer = Graybox.LAYER_HERO
	collision_mask = Graybox.LAYER_WORLD | Graybox.LAYER_NPC | Graybox.LAYER_SLIDE
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	_col = CollisionShape3D.new()
	_cap_shape = CapsuleShape3D.new()
	_cap_shape.radius = 0.3
	_cap_shape.height = 1.8
	_col.shape = _cap_shape
	_col.position = Vector3(0, 0.9, 0)
	add_child(_col)
	body_vis = BodyVisual.new()
	body_vis.name = "Body"
	body_vis.proxy_id = "hero"   # EL (data/ep01/proxies.json; canon sheets 01/02)
	add_child(body_vis)
	body_vis.build(Color(0.15, 0.15, 0.17))
	_carry_mesh = Graybox.box_mesh(Vector3(0.12, 0.02, 0.18), Color(0.95, 0.95, 0.9))
	_carry_mesh.position = Vector3(0.18, 1.02, -0.38)
	_carry_mesh.visible = false
	body_vis.add_child(_carry_mesh)
	get_node("/root/Bus").npc_command.connect(_on_command)
	get_node("/root/Bus").control_lock.connect(func(r: String, l: bool): set_lock(r, l))


func _exit_tree() -> void:
	if Services.hero == self:
		Services.hero = null


func set_lock(reason: String, on: bool) -> void:
	if on:
		_locks[reason] = true
	else:
		_locks.erase(reason)


func input_locked() -> bool:
	return not _locks.is_empty() or vaulting


func reading() -> bool:
	return Services.read != null and Services.read.active


func noise_radius() -> float:
	var echo := 1.0
	if Services.world:
		echo = float(Services.world.zone_def(current_zone).get("echo", 1.0))
	var r := 0.0
	match speed_state:
		"run", "slide": r = 6.0
		"fast": r = 3.0
		"walk": r = 1.5
		"crouch": r = 0.6
	return r * echo


# ================================================================== physics

func _physics_process(delta: float) -> void:
	Presence.place("hero", current_zone, global_position)
	if vaulting:
		return
	if stunned > 0.0:
		stunned -= delta
	var input := Vector2.ZERO
	var raw := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_fwd"))
	if not input_locked() and stunned <= 0.0:
		input = raw
	if seated:
		if not has_meta("seat_mode") and (input.length() > 0.2 or Input.is_action_just_pressed("context")):
			_stand_up()
		velocity = Vector3.ZERO
		return
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := cam.global_rotation.y if cam else 0.0
	var dir := Vector3.ZERO
	if not (_locks.has("door") and raw.length() > 0.05):
		dir = basis_helper.world_dir(input, cam_yaw)   # (a key held through a door fade keeps its carried basis)
	# speed state
	var want_crouch := Input.is_action_pressed("crouch") and not input_locked()
	var running := Input.is_action_pressed("run") and dir.length() > 0.1 and not reading()
	if Input.is_action_just_pressed("fast_walk"):
		fast_toggle = not fast_toggle
	if want_crouch and running and sliding <= 0.0 and not crouching and speed_state == "run":
		sliding = 0.6
		get_node("/root/Bus").player_decision.emit("slide")
	if sliding > 0.0:
		sliding -= delta
		speed_state = "slide"
		if dir.length() < 0.1:
			dir = facing
	elif want_crouch or (crouching and _blocked_above()):
		speed_state = "crouch"
	elif running:
		speed_state = "run"
	elif fast_toggle:
		speed_state = "fast"
	else:
		speed_state = "walk"
	_set_crouch(speed_state in ["crouch", "slide"] or (crouching and _blocked_above()))
	var sp := RUN * float(SPEED[speed_state]) * speed_mult
	if speed_state == "slide":
		sp *= lerpf(0.75, 1.0, clampf(sliding / 0.6, 0, 1))
	if reading():
		sp *= 0.5
	var target_v := dir * sp
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(target_v, ACCEL * delta * (2.5 if speed_state == "slide" else 1.0) * RUN)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	move_and_slide()
	if hv.length() > 0.3:
		facing = hv.normalized()
		var yaw := atan2(-facing.x, -facing.z)
		body_vis.rotation.y = lerp_angle(body_vis.rotation.y, yaw, minf(1.0, delta * 12.0))
		_footsteps(delta, hv.length())
	_check_auto_doors(hv)
	_update_target()
	_handle_actions(delta)


func _footsteps(delta: float, v: float) -> void:
	_step_t -= delta
	if _step_t > 0.0:
		return
	_step_t = clampf(1.6 / maxf(v, 0.5), 0.25, 0.7)
	var r := noise_radius()
	get_node("/root/Bus").noise.emit(global_position, r, "hero_" + speed_state)
	get_node("/root/Bus").sfx_requested.emit("step_" + ("run" if speed_state in ["run", "slide"] else "walk"), global_position)


func _set_crouch(on: bool) -> void:
	if on == crouching:
		return
	crouching = on
	_cap_shape.height = 0.95 if on else 1.8
	_col.position.y = 0.5 if on else 0.9
	collision_mask = (Graybox.LAYER_WORLD | Graybox.LAYER_NPC) if on else (Graybox.LAYER_WORLD | Graybox.LAYER_NPC | Graybox.LAYER_SLIDE)
	body_vis.set_crouch(1.0 if on else 0.0)


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + Vector3(0, 1.85, 0), Graybox.LAYER_SLIDE)
	return not space.intersect_ray(q).is_empty()


# ================================================================== doors

func _check_auto_doors(hv: Vector3) -> void:
	if arrival_door != "" and Services.world:
		var ad: Doorway = Services.world.door(arrival_door)
		if ad == null or ad.zone_id != current_zone or Vector2(ad.global_position.x - global_position.x, ad.global_position.z - global_position.z).length() > 1.5:
			arrival_door = ""
	if hv.length() < 0.5 or input_locked() or Services.world == null:
		return
	for d in get_tree().get_nodes_in_group("doorways"):
		var door := d as Doorway
		if door.zone_id != current_zone or not door.auto() or door.def.get("npc_only", false):
			continue
		if door.door_id == arrival_door:
			continue   # re-armed once the hero has stepped away from it (no door ping-pong)
		var to := door.global_position - global_position
		to.y = 0
		if to.length() < 0.95 and absf(door.global_position.y - global_position.y) < 1.4 and hv.normalized().dot(-door.normal) > 0.45:
			Services.world.traverse_hero(door)
			return


# ================================================================== targeting / actions

func _update_target() -> void:
	target = null
	target_kind = ""
	if input_locked():
		return
	var best_score := INF
	var pos := global_position
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it == null or not it.visible or not it.is_available():
			continue
		var d := Vector2(it.global_position.x - pos.x, it.global_position.z - pos.z).length()
		var dy := absf(it.global_position.y - pos.y - 0.9)
		if d > it.radius() or dy > 1.8:
			continue
		var score := d - _facing_bonus(it.global_position) - float(it.def.get("priority", 0)) * 0.5
		if score < best_score:
			best_score = score
			target = it
			target_kind = "interact"
	for n in get_tree().get_nodes_in_group("npcs"):
		var npc: Node3D = n
		if not npc.visible or not npc.talkable():
			continue
		var d := Vector2(npc.global_position.x - pos.x, npc.global_position.z - pos.z).length()
		if d > NPC_TALK_RADIUS or absf(npc.global_position.y - pos.y) > 1.5:
			continue
		var score := d - _facing_bonus(npc.global_position) + 0.25
		if score < best_score:
			best_score = score
			target = npc
			target_kind = "npc"
	for d in get_tree().get_nodes_in_group("doorways"):
		var door := d as Doorway
		if door.zone_id != current_zone or door.def.get("npc_only", false) or door.def.get("kind", "") == "hidden":
			continue
		var dd := Vector2(door.global_position.x - pos.x, door.global_position.z - pos.z).length()
		if dd > DOOR_RADIUS or absf(door.global_position.y - pos.y) > 1.4:
			continue
		var score := dd + 0.4
		if score < best_score:
			best_score = score
			target = door
			target_kind = "door"


func _facing_bonus(p: Vector3) -> float:
	var to := p - global_position
	to.y = 0
	if to.length() < 0.01:
		return 0.5
	return facing.dot(to.normalized()) * 0.6


func target_prompt() -> String:
	match target_kind:
		"interact":
			return ("[Пробел] " if target.uses_context_key() else "[E] ") + target.prompt_text()
		"npc":
			return "[E] " + target.display_name()
		"door":
			var door := target as Doorway
			if door.is_locked():
				return String(door.def.get("locked_text", "Заперто"))
			return "[E] " + door.label()
	return ""


## Structured context prompt for the HUD: {key: "E"|"Space"|"", verb, what}. No character names
## (playtest finding 6) — the subtitle is the only place a name appears.
func target_prompt_parts() -> Dictionary:
	match target_kind:
		"interact":
			var full: String = target.prompt_text()
			var parts := full.split(" · ", true, 1)
			var locked: bool = (target.def.has("requires") and not Conditions.check(target.def.requires)) \
				or (target.def.has("blocked_if") and Conditions.check(target.def.blocked_if))
			return {"key": "" if locked else ("Space" if target.uses_context_key() else "E"),
				"verb": parts[0] if locked else parts[0].to_lower(),
				"what": parts[1] if parts.size() > 1 else ""}
		"npc":
			return {"key": "E", "verb": "поговорить", "what": ""}
		"door":
			var door := target as Doorway
			if door.is_locked():
				return {"key": "", "verb": String(door.def.get("locked_text", "Заперто")), "what": ""}
			return {"key": "E", "verb": door.label(), "what": ""}
	if not input_locked() and not seated and Vector2(velocity.x, velocity.z).length() > 0.8 and vault_target() != null:
		return {"key": "Space", "verb": "перепрыгнуть", "what": "", "at_hero": true}
	return {}


func hold_progress() -> float:
	if _hold_target == null or _hold_target != target:
		return 0.0
	var ht: float = target.hold_time() if target_kind == "interact" else 0.0
	return _hold_t / ht if ht > 0.0 else 0.0


func _handle_actions(delta: float) -> void:
	if input_locked():
		return
	var e_pressed := Input.is_action_just_pressed("interact")
	var ctx_pressed := Input.is_action_just_pressed("context")
	# hold-to-use interactables
	if target_kind == "interact" and target.hold_time() > 0.0:
		var key := "context" if target.uses_context_key() else "interact"
		if Input.is_action_pressed(key):
			if _hold_target != target:
				_hold_target = target
				_hold_t = 0.0
			_hold_t += delta
			if _hold_t >= target.hold_time():
				_hold_t = 0.0
				_hold_target = null
				target.use()
			return
		_hold_target = null
		_hold_t = 0.0
		return
	if ctx_pressed:
		if Services.chase and Services.chase.has_method("on_context") and Services.chase.on_context():
			return
		if _try_vault():
			return
		if target_kind == "interact" and target.uses_context_key():
			target.use()
			return
		if target_kind == "door":
			_use_door(target)
			return
	if e_pressed:
		match target_kind:
			"interact":
				if not target.uses_context_key():
					target.use()
			"npc":
				target.on_hero_interact()
			"door":
				_use_door(target)


func _use_door(door: Doorway) -> void:
	if door.is_locked():
		ActionRunner.run(door.def.get("locked_actions", [{"sfx": "locked"}, {"hint": [String(door.def.get("locked_text", "Заперто")), 1.5]}]),
			{"source": door.door_id})
		return
	Services.world.traverse_hero(door)


# ================================================================== vault

## The low obstacle a vault would clear right now (no side effects), or null.
func vault_target() -> Node3D:
	var dir := facing
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("vaultables"):
		var b: Node3D = n
		var sz: Vector3 = b.get_meta("box_size", Vector3.ONE)
		if sz.y > 1.35:
			continue
		var to := b.global_position - global_position
		to.y = 0
		var half := maxf(sz.x, sz.z) / 2.0
		var d := to.length() - minf(sz.x, sz.z) / 2.0
		if d > 1.1 or to.length() > half + 1.4:
			continue
		if dir.dot(to.normalized()) < 0.2 and to.length() > 0.6:
			continue
		if d < best_d:
			best_d = d
			best = b
	return best


func _try_vault() -> bool:
	var dir := facing
	var best := vault_target()
	if best == null:
		return false
	var sz: Vector3 = best.get_meta("box_size")
	var top := best.global_position.y + sz.y / 2.0
	# step forward until clear of the box footprint
	var land := global_position
	var aabb := AABB(best.global_position - sz / 2.0, sz).grow(0.35)
	for i in 40:
		land += dir * 0.1
		if not aabb.has_point(Vector3(land.x, best.global_position.y, land.z)):
			break
	land += dir * 0.35
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(land + Vector3(0, 2.0, 0), land + Vector3(0, -2.5, 0), Graybox.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	land.y = hit.position.y
	var mid := (global_position + land) / 2.0
	mid.y = top + 0.35
	vaulting = true
	var old_mask := collision_mask
	collision_mask = 0
	var t := create_tween()
	t.tween_property(self, "global_position", mid, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", land, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		vaulting = false
		collision_mask = old_mask
		velocity = facing * RUN * 0.6)
	get_node("/root/Bus").player_decision.emit("vault")
	get_node("/root/Bus").sfx_requested.emit("vault", global_position)
	get_node("/root/Bus").noise.emit(global_position, 4.0, "hero_vault")
	return true


# ================================================================== commands

func _on_command(npc: String, cmd: String, args: Dictionary) -> void:
	if npc != "hero":
		return
	match cmd:
		"teleport":
			teleport_to(get_node("/root/Data").marker(String(args.marker)), get_node("/root/Data").marker_zone(String(args.marker)))
		"sit":
			sit_at(get_node("/root/Data").marker(String(args.marker)), get_node("/root/Data").marker_zone(String(args.marker)))
		"stun":
			stunned = float(args.get("dur", 0.5))
		"lock":
			set_lock(String(args.get("reason", "cmd")), bool(args.get("on", true)))
		"face":
			var p: Vector3 = get_node("/root/Data").marker(String(args.marker))
			var to := p - global_position
			to.y = 0
			if to.length() > 0.01:
				facing = to.normalized()
				body_vis.rotation.y = atan2(-facing.x, -facing.z)
		"carry":
			carry(String(args.get("item", "")))


func teleport_to(p: Vector3, zone_id: String) -> void:
	teleport_serial += 1
	arrival_door = ""
	global_position = p
	velocity = Vector3.ZERO
	current_zone = zone_id
	get_node("/root/Episode").hero_zone = zone_id
	Presence.place("hero", zone_id, p)
	seated = false
	basis_helper.locked = false


## Called by HotelWorld after a door traversal teleport.
func arrive_through(door: Doorway, travel_dir: Vector3) -> void:
	arrival_door = door.door_id
	basis_helper.carry_through(travel_dir, door.normal)


func sit_at(p: Vector3, zone_id: String) -> void:
	teleport_to(p, zone_id)
	seated = true
	body_vis.set_crouch(0.35)


func _stand_up() -> void:
	seated = false
	body_vis.set_crouch(0.0)
	get_node("/root/Bus").player_decision.emit("stand")


func carry(item: String) -> void:
	carry_item = item
	_carry_mesh.visible = item != ""
	body_vis.set_pose("carry" if item != "" else "rest")
