class_name Perception
extends RefCounted
## Vision cone + hearing for an NPC (Pavel, Eva, Daniel, pursuers).
## cfg: {cone: deg, dist: m, periphery: m (only notices running), detect: s, hear: multiplier}

var owner: Node3D
var cone := 70.0
var dist := 9.0
var periphery := 5.0
var detect_time := 1.2
var hear_mult := 1.0
var sight_mult := 1.0      # fog/sprinklers/blackout reduce sight
var seen_t := 0.0
var last_seen_pos := Vector3.INF
var last_heard_pos := Vector3.INF
var heard_t := -999.0


func _init(o: Node3D, cfg: Dictionary) -> void:
	owner = o
	cone = float(cfg.get("cone", 70.0))
	dist = float(cfg.get("dist", 9.0))
	periphery = float(cfg.get("periphery", 0.0))
	detect_time = float(cfg.get("detect", 1.2))
	hear_mult = float(cfg.get("hear", 1.0))


func facing() -> Vector3:
	var yaw: float = owner.body_vis.rotation.y
	return Vector3(-sin(yaw), 0, -cos(yaw))


## Raw sight test of the hero this frame.
func can_see_hero() -> bool:
	var hero: Node3D = Services.hero
	if hero == null or not owner.visible:
		return false
	if Presence.in_zone("hero") != owner.current_zone:
		return false
	var eye: Vector3 = owner.global_position + Vector3(0, 1.65, 0)
	var crouch: bool = hero.crouching
	var tgt := hero.global_position + Vector3(0, 0.6 if crouch else 1.2, 0)
	var to := tgt - eye
	var d := to.length()
	var max_d := dist * sight_mult
	if d > max_d:
		return false
	var flat := Vector3(to.x, 0, to.z).normalized()
	var ang := rad_to_deg(acos(clampf(flat.dot(facing()), -1.0, 1.0)))
	var in_cone := ang <= cone / 2.0
	if not in_cone:
		# peripheral band: notices running only
		if d <= periphery * sight_mult and hero.speed_state in ["run", "slide"] and ang <= 110.0:
			in_cone = true
		else:
			return false
	var space: PhysicsDirectSpaceState3D = owner.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, tgt, Graybox.LAYER_WORLD | Graybox.LAYER_SLIDE)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and eye.distance_to(hit.position) < d - 0.2:
		return false
	return true


## Call every physics frame; returns true once the hero has been in sight for detect_time.
func update(delta: float) -> bool:
	if can_see_hero():
		seen_t += delta
		last_seen_pos = Services.hero.global_position
	else:
		seen_t = maxf(0.0, seen_t - delta * 0.5)
	return seen_t >= detect_time


func on_noise(pos: Vector3, radius: float) -> bool:
	if owner == null or not owner.visible:
		return false
	if owner.global_position.distance_to(pos) <= radius * hear_mult:
		last_heard_pos = pos
		heard_t = Time.get_ticks_msec() / 1000.0
		return true
	return false
