class_name CameraDirector
extends Node3D
## One Camera3D driven by CameraZones -> CameraRigs with 0.6 s blends (no free camera).
## Five camera modes shape the zone rig's framing without ever swinging its direction (2.5D):
##   explore — the zone rig as authored (Exploration Wide);
##   social  — in conversation: drift toward the hero/speaker midpoint, push in (Social Medium);
##   read    — READ held: tighter, a slight lean toward what is being studied (READ Focus);
##   chase   — S07: higher, wider, more lead so routes and pursuers stay readable (Chase Wide);
##   finale  — S09 live/decision near the table: the table orbit, favouring the hero's side
##             (Finale Social Stage).
## Cines (camera_hint rigs) override all of them.
## Rig (zone-local): {type: follow|fixed|orbit, offset, look, fov, clamp_x, clamp_z, lock_x/lock_y/lock_z,
##                    pos, at, center, radius, height, yaw, arc, lead, damp}

const BLEND := 0.6

var cam: Camera3D
var rig_key := ""
var _blend_t := 1.0
var _from_xf := Transform3D.IDENTITY
var _from_fov := 50.0
var _override: Dictionary = {}
var _override_t := 0.0
var _read_push := 0.0
var shake := 0.0
var mode_name := "explore"
var _social := 0.0               # 0..1 eased weights so modes glide in and out
var _chase := 0.0
const FINALE_STAGE_RADIUS := 6.5


func _ready() -> void:
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.near = 0.1
	cam.far = 200.0
	add_child(cam)
	get_node("/root/Bus").camera_hint.connect(_on_hint)


func _on_hint(h: Dictionary) -> void:
	if h.has("rig"):
		_override = h
		_override_t = float(h.get("dur", 6.0))
		_start_blend()
	if h.get("clear", false):
		_override = {}
		_start_blend()
	if h.has("shake"):
		shake = float(h.shake)


func _start_blend() -> void:
	_from_xf = cam.global_transform
	_from_fov = cam.fov
	_blend_t = 0.0


func snap() -> void:
	rig_key = ""
	_blend_t = 1.0
	_process(0.0)
	var d := _desired()
	if not d.is_empty():
		cam.global_transform = d.xf
		cam.fov = d.fov
	_blend_t = 1.0


func current_rig() -> Dictionary:
	var hero: Node3D = Services.hero
	if hero == null or Services.world == null:
		return {}
	if not _override.is_empty():
		var ref := String(_override.rig).split(":")
		var z: Zone = Services.world.zone_node(ref[0])
		if z:
			return {"zone": z, "rig": z.rig(ref[1]), "key": String(_override.rig)}
	var zone: Zone = Services.world.zone_node(hero.current_zone)
	if zone == null:
		return {}
	if _finale_stage(zone):
		return {"zone": zone, "rig": zone.rig("table"), "key": zone.zone_id + ":table"}
	var rid := zone.rig_id_at(hero.global_position)
	return {"zone": zone, "rig": zone.rig(rid), "key": zone.zone_id + ":" + rid}


## E — the live meeting and the decision are staged around the table while the hero is near it.
func _finale_stage(zone: Zone) -> bool:
	if zone.zone_id != "RESTAURANT" or not zone.rigs.has("table"):
		return false
	var ph: String = get_node("/root/Episode").phase_name()
	if ph != "S09_LIVE" and ph != "S09_DECISION":
		return false
	var c := zone.global_position + Data.vec3(zone.rigs.table.get("center", [0, 0, 0]))
	var h: Vector3 = Services.hero.global_position
	return Vector2(h.x - c.x, h.z - c.z).length() <= FINALE_STAGE_RADIUS


func _conversation_partner() -> Node3D:
	var conv: Node = Services.conversation
	if conv == null or not conv.is_active() or Services.world == null:
		return null
	var n: Node3D = Services.world.npc(String(conv.active.get("npc", "")))
	if n == null or not n.spawned or n.current_zone != Services.hero.current_zone:
		return null
	if n.global_position.distance_to(Services.hero.global_position) > 6.0:
		return null
	return n


func _desired() -> Dictionary:
	var cr := current_rig()
	if cr.is_empty():
		return {}
	var z: Zone = cr.zone
	var r: Dictionary = cr.rig
	var hero: Node3D = Services.hero
	var hp := hero.global_position
	var o := z.global_position
	var pos: Vector3
	var look: Vector3
	match String(r.get("type", "follow")):
		"fixed":
			pos = o + Data.vec3(r.pos)
			look = o + Data.vec3(r.at)
			if r.has("track"):
				# fixed position but look follows hero partially
				look = look.lerp(hp + Vector3(0, 1.0, 0), float(r.track))
		"orbit":
			var c := o + Data.vec3(r.center)
			var to := hp - c
			var base := deg_to_rad(float(r.get("yaw", 0.0)))
			var hy := atan2(to.x, to.z)
			var arc := deg_to_rad(float(r.get("arc", 25.0)))
			var yaw := base + clampf(angle_difference(base, hy), -arc, arc)
			var rad := float(r.get("radius", 6.0))
			pos = c + Vector3(sin(yaw) * rad, float(r.get("height", 4.0)), cos(yaw) * rad)
			look = c + Vector3(0, 0.9, 0)
		_:
			var off := Data.vec3(r.get("offset", [0, 6, 8]))
			var lead := float(r.get("lead", 0.0))
			var lv := Vector3.ZERO
			if lead > 0.0 and hero is CharacterBody3D:
				lv = Vector3(hero.velocity.x, 0, 0) * lead
			pos = hp + off + lv
			look = hp + Data.vec3(r.get("look", [0, 1, 0])) + lv
			var lp := pos - o
			if r.has("clamp_x"):
				var cx: Array = r.clamp_x
				var nx := clampf(lp.x, float(cx[0]), float(cx[1]))
				look.x += nx - lp.x
				lp.x = nx
			if r.has("clamp_z"):
				var cz: Array = r.clamp_z
				var nz := clampf(lp.z, float(cz[0]), float(cz[1]))
				look.z += nz - lp.z
				lp.z = nz
			if r.has("lock_x"):
				lp.x = float(r.lock_x)
			if r.has("lock_y"):
				lp.y = float(r.lock_y)
			if r.has("lock_z"):
				lp.z = float(r.lock_z)
			if r.has("look_lock_y"):
				look.y = o.y + float(r.look_lock_y)
			pos = o + lp
	var fov := float(r.get("fov", 50.0))
	var is_follow := String(r.get("type", "follow")) == "follow"
	if _override.is_empty():
		# B — Social Medium: frame the pair, a little closer; same direction as the zone rig
		var partner := _conversation_partner()
		if _social > 0.001:
			var mid := hp
			if partner:
				mid = (hp + partner.global_position) * 0.5
				_last_mid = mid
			else:
				mid = _last_mid
			var shift := (mid - hp) * (0.8 if is_follow else 0.0)
			shift.y = 0.0
			pos += shift * _social
			look = look.lerp(look + (mid - hp) * 0.9, _social)
			if is_follow:
				pos = look + (pos - look) * lerpf(1.0, 0.8, _social)
			fov *= lerpf(1.0, 0.93, _social)
		# D — Chase Wide: higher and wider, routes and pursuers in frame
		if _chase > 0.001 and is_follow:
			pos = look + (pos - look) * lerpf(1.0, 1.14, _chase) + Vector3(0, 0.7, 0) * _chase
			fov += 4.0 * _chase
		# C — READ Focus: tighter, leaning slightly toward what is being studied
		if _read_push > 0.001:
			var f: Variant = _read_target()
			if f != null:
				look = look.lerp(f as Vector3, 0.22 * _read_push)
			if is_follow:
				pos = look + (pos - look) * lerpf(1.0, 0.9, _read_push)
			fov *= lerpf(1.0, 0.88, _read_push)
		# E — the table orbit keeps the hero in the picture as he moves around the table
		if String(r.get("type", "")) == "orbit":
			look = look.lerp(hp + Vector3(0, 1.0, 0), 0.25)
	var xf := Transform3D.IDENTITY.translated(pos)
	if pos.distance_to(look) > 0.01:
		xf = xf.looking_at(look, Vector3.UP)
	return {"xf": xf, "fov": fov, "key": cr.key, "damp": float(r.get("damp", 6.0))}


var _last_mid := Vector3.ZERO


func _read_target() -> Variant:
	var rs: Node = Services.read
	if rs and rs.focus and is_instance_valid(rs.focus):
		return rs.focus.global_position
	return null


func _update_mode(real_dt: float) -> void:
	var reading: bool = Services.read != null and Services.read.active
	var chasing: bool = Services.chase != null and Services.chase.get("active") == true
	var talking := _conversation_partner() != null and not chasing
	_social = move_toward(_social, 1.0 if talking else 0.0, real_dt / 0.9)
	_chase = move_toward(_chase, 1.0 if chasing else 0.0, real_dt / 1.2)
	if not _override.is_empty():
		mode_name = "cine"
	elif chasing:
		mode_name = "chase"
	elif reading:
		mode_name = "read"
	elif String(current_rig().get("key", "")).ends_with(":table"):
		mode_name = "finale"
	elif talking:
		mode_name = "social"
	else:
		mode_name = "explore"


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	if _override_t > 0.0:
		_override_t -= real_dt
		if _override_t <= 0.0:
			_override = {}
			_start_blend()
	var reading: bool = Services.read != null and Services.read.active
	_read_push = move_toward(_read_push, 1.0 if reading else 0.0, real_dt * 4.0)
	_update_mode(real_dt)
	var d := _desired()
	if d.is_empty():
		return
	if d.key != rig_key:
		if rig_key != "":
			_start_blend()
		rig_key = d.key
	var target_xf: Transform3D = d.xf
	if _blend_t < 1.0:
		_blend_t = minf(1.0, _blend_t + real_dt / BLEND)
		var w := smoothstep(0.0, 1.0, _blend_t)
		cam.global_transform = _from_xf.interpolate_with(target_xf, w)
		cam.fov = lerpf(_from_fov, d.fov, w)
	else:
		var k := minf(1.0, real_dt * float(d.damp))
		cam.global_transform = cam.global_transform.interpolate_with(target_xf, k)
		cam.fov = lerpf(cam.fov, d.fov, k)
	if shake > 0.0:
		shake = maxf(0.0, shake - real_dt)
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.04 * shake


func blending() -> bool:
	return _blend_t < 1.0
