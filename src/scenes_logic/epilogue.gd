extends SceneLogic
## Epilogue: controllable street at dawn. Ending-variant details, the phone call after ≥ 8 s of
## walking (E answers, auto-answers after 6 s), then cut to black — EPISODE 01 COMPLETE.

var t := 0.0
var walked := 0.0
var _last := Vector3.INF
var ringing := -1.0
var answered := false
var _done_t := -1.0
var props: Array = []
var _mover: Node3D
var _mover_v := Vector3.ZERO


func enter() -> void:
	var E := ep()
	var id: String = E.ending.id
	match id:
		"A_MARA": _prop_box("STREET:van", Vector3(3.2, 2.0, 1.8), Color(0.85, 0.85, 0.88), "NEWS")
		"B_THOMAS": _mover = _prop_box("STREET:off_volvo_start", Vector3(4.2, 1.4, 1.8), Color(0.42, 0.44, 0.46), "")
		"D_ADRIAN":
			_prop_box("STREET:adrian_car", Vector3(4.6, 1.4, 1.9), Color(0.05, 0.05, 0.08), "")
			run([{"spawn": ["adrian", "STREET:lawyer"]}])
		"C_DESTROY": pass
	if E.finale.daniel_state == "escaped":
		_prop_box("STREET:black_car", Vector3(4.2, 1.3, 1.8), Color(0.02, 0.02, 0.02), "")
	if _mover:
		_mover_v = Vector3(2.2, 0, 0)
	bus().music_requested.emit("EPILOGUE")


func _prop_box(marker: String, size: Vector3, c: Color, label: String) -> Node3D:
	if Services.world == null:
		return null
	var root := Node3D.new()
	Services.world.add_child(root)
	root.global_position = data().marker(marker) + Vector3(0, size.y / 2, 0)
	var mi := Graybox.box_mesh(size, c)
	root.add_child(mi)
	if label != "":
		var l := Graybox.label3d(label, 50, Color(0.9, 0.2, 0.2))
		l.position = Vector3(0, size.y / 2 + 0.3, 0)
		root.add_child(l)
	props.append(root)
	return root


func exit() -> void:
	for p in props:
		if is_instance_valid(p):
			p.queue_free()


func tick(delta: float) -> void:
	t += delta
	if _mover:
		_mover.global_position += _mover_v * delta
	if Presence.pos.has("hero"):
		var hp: Vector3 = Presence.pos.hero
		if _last != Vector3.INF:
			walked += hp.distance_to(_last)
		_last = hp
	if ep().ending.id == "C_DESTROY" and t > 4.0 and not ep().flags.get("epi_nico", false):
		ep().set_flag("epi_nico")
		run([{"ambient": "EPI_NICO"}])
	if ringing < 0.0 and not answered and t >= 8.0 and (walked >= 5.0 or t >= 14.0):
		ringing = 0.0
		bus().sfx_requested.emit("ring", null)
		bus().hint_requested.emit("Телефон. [E] — ответить", 4.0)
	if ringing >= 0.0 and not answered:
		ringing += delta
		if fmod(ringing, 1.6) < delta:
			bus().sfx_requested.emit("ring", null)
		if (InputMap.has_action("interact") and Input.is_action_just_pressed("interact")) or ringing >= 6.0:
			answer()
	if _done_t >= 0.0:
		_done_t -= delta
		if _done_t < 0.0:
			_done_t = -1.0
			finish()


func answer() -> void:
	answered = true
	ringing = -1.0
	bus().player_decision.emit("answer")
	run([{"line": ["EPI_1", "EPI_2", "EPI_3", "EPI_4"]}])
	_done_t = 11.5


func finish() -> void:
	ep().set_phase_name("DONE")
	if Services.hud:
		Services.hud.fade(1.2, true)
		Services.hud.show_title("EPISODE 01 COMPLETE", _summary(), 600.0)
	bus().music_requested.emit("SILENCE")
	if Services.hero:
		Services.hero.set_lock("done", true)


func _summary() -> String:
	var E := ep()
	var names := {"A_MARA": "Карта у Мары", "B_THOMAS": "Карта у Томаса", "C_DESTROY": "Карта уничтожена", "D_ADRIAN": "Адриан рассказал сам"}
	var dn := {"confessed": "Дэниел признался", "escaped": "Дэниел ушёл"}
	return "%s · %s" % [names.get(E.ending.id, "—"), dn.get(E.finale.daniel_state, "")]
