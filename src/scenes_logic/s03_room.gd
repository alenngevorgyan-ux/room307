extends SceneLogic
## S03 glue: Lina's interruption timer (150 s in the room or 5 meaningful interactions),
## the knock when the hero is in the steamy bathroom, and the mirror fog / re-steam.

var interactions := 0
var _lina_wait := -1.0
var _shower_t := 0.0
var _fog := 0.0
var _msg: Label3D
var _fog_quad: MeshInstance3D
var _steam: CPUParticles3D


func enter() -> void:
	bus().interact_done.connect(_on_interact)
	if Services.world:
		var o: Vector3 = data().zone_origin("ROOM_307")
		_msg = Graybox.label3d("DON'T TRUST HIM", 40, Color(0.95, 0.97, 1.0, 0.5))
		_msg.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_msg.no_depth_test = false
		_msg.fixed_size = false
		_msg.pixel_size = 0.0028
		Services.world.add_child(_msg)
		_msg.global_position = o + Vector3(9.37, 1.32, 3.4)
		_msg.rotation_degrees.y = -90
		_fog_quad = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_fog_quad.mesh = q
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.9, 0.92, 0.95, 0.0)
		_fog_quad.material_override = m
		Services.world.add_child(_fog_quad)
		_fog_quad.global_position = o + Vector3(9.38, 1.0 + 0.0, 3.4)
		_fog_quad.rotation_degrees.y = -90
		_steam = CPUParticles3D.new()
		_steam.amount = 40
		_steam.lifetime = 2.5
		_steam.emitting = false
		_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_steam.emission_box_extents = Vector3(0.6, 0.1, 0.6)
		_steam.direction = Vector3.UP
		_steam.gravity = Vector3(0, 0.4, 0)
		_steam.initial_velocity_min = 0.2
		_steam.initial_velocity_max = 0.5
		var sm := SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		_steam.mesh = sm
		_steam.material_override = Graybox.mat(Color(1, 1, 1, 0.12), 0.0, true)
		Services.world.add_child(_steam)
		_steam.global_position = o + Vector3(8.6, 0.3, 1.0)


func _on_interact(id: String) -> void:
	if id.begins_with("I_307") or id.begins_with("I_308"):
		interactions += 1


func _hero_in_bath() -> bool:
	if Presence.in_zone("hero") != "ROOM_307" or not Presence.pos.has("hero"):
		return false
	var l: Vector3 = (Presence.pos.hero as Vector3) - data().zone_origin("ROOM_307")
	return l.x > 6.6


func tick(delta: float) -> void:
	var E := ep()
	# shower -> steam -> message
	if E.flags.get("shower_on", false):
		_shower_t += delta
		if _shower_t >= 4.0 and not E.flags.get("mirror_steamed", false):
			E.set_flag("mirror_steamed")
			bus().camera_hint.emit({"rig": "ROOM_307:bath", "dur": 3.0})
	else:
		_shower_t = 0.0
	_fog = move_toward(_fog, 1.0 if E.flags.get("shower_on", false) else 0.0, delta * 0.25)
	if _msg:
		_msg.modulate.a = 0.45 + 0.5 * _fog
		(_fog_quad.material_override as StandardMaterial3D).albedo_color.a = 0.35 * _fog
		_steam.emitting = E.flags.get("shower_on", false)
	# Lina
	if E.flags.get("lina_called_in", false):
		if _lina_wait >= 0.0:
			_lina_wait += delta
			if not (_hero_in_bath() and E.flags.get("shower_on", false)) or _lina_wait > 8.0:
				_lina_wait = -1.0
				_lina_enters()
		return
	if Presence.in_zone("hero") == "ROOM_307" and (interactions >= 5 or E.flags.get("lina_due", false)):
		E.set_flag("lina_called_in")
		run([{"spawn": ["lina", "ROOM_307:lina_door"]}, {"npc": ["lina", "pose", {"pose": "carry"}]}])
		if _hero_in_bath() and E.flags.get("shower_on", false):
			run([{"ambient": "LINA_KNOCK"}])
			_lina_wait = 0.0
		else:
			_lina_enters()


func _lina_enters() -> void:
	run([{"flag": "lina_in_room"}, {"set_schedule": ["lina", "lina_307"]}])


func exit() -> void:
	for n in [_msg, _fog_quad, _steam]:
		if n:
			n.queue_free()
