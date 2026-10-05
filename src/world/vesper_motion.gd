class_name VesperMotion
extends Node
## Design + Motion Polish V1 — Pass E (environment motion) and the sound tied to it (Pass H).
## Visual and audio only: nothing here touches collision, navigation, perception or story state.
## One node per world, ticking a few cheap things at the edge of attention:
##   doors swing and elevator doors slide whenever anyone passes (EL or an NPC), with their sound;
##   kitchen steam over the stove line, the laundry press breathing out in puffs (with a hiss),
##   Eva's cigarette, dust hanging in the restaurant's dawn light;
##   a tired fluorescent tube in the service corridor, the staff corridor and the roof shelter;
##   the Room 307 curtain breathing while the window is open; laundry sheets swaying;
##   the roof HVAC fans turning;
##   rain at the glass of EL's room as a positional loop; the bar's murmur when it has people;
##   the kitchen extractor; a glass set down on the counter in time with Nico's hands.

const SWING_DOORS := ["door", "swing"]
const FLICKER_ZONES := ["SCORR", "STAFF_CORRIDOR", "ROOF_SMOKING"]

var world: Node
var _anim: Dictionary = {}      # door_id -> state
var _flick: Array = []          # [light, wait, burst]
var _sway: Array = []           # {node, rest, pivot, axis, amp, speed, phase, cond}
var _spin: Array = []           # [node, speed]
var _press: CPUParticles3D
var _press_t := 2.5
var _dust: CPUParticles3D
var _smoke: Dictionary = {}     # npc_id -> CPUParticles3D
var _beats: Dictionary = {}     # npc_id -> true (work_beat connected)
var _slow := 0.0
var _rain_src: AudioStreamPlayer3D
var _room_src: AudioStreamPlayer3D
var _room_id := ""
var _rng := RandomNumberGenerator.new()
static var _puff_tex: Texture2D


func setup(w: Node) -> void:
	world = w
	name = "VesperMotion"
	_rng.seed = 3070
	for zid in world.zones:
		var z: Zone = world.zones[zid]
		for did in z.doors:
			var d: Doorway = z.doors[did]
			d.traversed.connect(_on_traversed.bind(d))
	_build_flicker()
	_build_props()
	_rain_src = _source()
	_room_src = _source()


func _source() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Ambience"
	p.unit_size = 4.0
	p.max_distance = 22.0
	p.volume_db = -80.0
	add_child(p)
	return p


# ================================================================== build

func _prop(zid: String, id: String) -> Node3D:
	var z: Node = world.zone_node(zid)
	if z == null:
		return null
	var geo: Node = z.get_node_or_null("Geometry")
	if geo == null:
		return null
	for n in geo.get_children():
		if n.has_meta("def") and String(n.get_meta("def").get("id", "")) == id:
			return n as Node3D
	return null


func _size(n: Node3D) -> Vector3:
	return Data.vec3(n.get_meta("def").get("s", [1, 1, 1]))


func _build_flicker() -> void:
	for zid in FLICKER_ZONES:
		var z: Zone = world.zone_node(zid)
		if z == null or z.lights_root == null or z.lights_root.get_child_count() == 0:
			continue
		var l := z.lights_root.get_child(z.lights_root.get_child_count() - 1) as OmniLight3D
		if l == null:
			continue
		if not l.has_meta("base_energy"):
			l.set_meta("base_energy", l.light_energy)
		l.add_to_group("vesper_practical")
		_flick.append([l, _rng.randf_range(2.0, 6.0), 0.0])


func _build_props() -> void:
	# kitchen: steam rising from the stove line into the hood, a little more over the fryer
	var stove := _prop("KITCHEN", "stove_line")
	if stove:
		var s := _size(stove)
		_steam(stove, Vector3(0, s.y / 2.0 + 0.05, 0), Vector3(s.x * 0.42, 0.04, s.z * 0.25), 28, 0.22)
	var fryer := _prop("KITCHEN", "fryer")
	if fryer:
		_steam(fryer, Vector3(0, _size(fryer).y / 2.0 + 0.05, 0), Vector3(0.4, 0.03, 0.4), 10, 0.2)
	# laundry: the press breathes out now and then
	var press := _prop("LAUNDRY", "steam_press")
	if press:
		_press = _steam(press, Vector3(0, _size(press).y / 2.0 + 0.05, 0), Vector3(0.35, 0.05, 0.25), 22, 0.3)
		_press.one_shot = true
		_press.explosiveness = 0.55
		_press.emitting = false
	for id in ["sheets", "sheets_2"]:
		var sh := _prop("LAUNDRY", id)
		if sh:
			_add_sway(sh, 0.022, 0.55, "")
	var curtain := _prop("ROOM_307", "curtain")
	if curtain:
		_add_sway(curtain, 0.07, 0.8, "window_open")
	# roof: the HVAC fans turn
	for id in ["hvac_1", "hvac_2"]:
		var hv := _prop("ROOF_SMOKING", id)
		if hv:
			var s := _size(hv)
			var hub := Node3D.new()
			hub.position = Vector3(0, s.y / 2.0 + 0.07, 0)
			hv.get_node("Visual").add_child(hub)
			for i in 3:
				var blade := VesperDress.box(hub, Vector3(s.z * 0.62, 0.015, 0.09), Vector3.ZERO, VesperLook.material("steel"))
				blade.rotation.y = i * TAU / 3.0
				blade.rotation.x = 0.25
			_spin.append([hub, 5.5 if id == "hvac_1" else 4.3])
	# restaurant: dust hanging in the morning light
	var rest: Zone = world.zone_node("RESTAURANT")
	if rest:
		_dust = CPUParticles3D.new()
		_dust.amount = 70
		_dust.lifetime = 9.0
		_dust.preprocess = 9.0
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_dust.emission_box_extents = Vector3(rest.size.x * 0.4, 1.0, rest.size.y * 0.35)
		_dust.position = Vector3(rest.size.x / 2.0, 1.6, rest.size.y / 2.0)
		_dust.gravity = Vector3(0, -0.004, 0)
		_dust.direction = Vector3(1, 0.2, 0)
		_dust.spread = 180.0
		_dust.initial_velocity_min = 0.01
		_dust.initial_velocity_max = 0.05
		var q := QuadMesh.new()
		q.size = Vector2(0.018, 0.018)
		_dust.mesh = q
		_dust.material_override = _puff_material(Color(1.0, 0.92, 0.8, 0.55), true)
		_dust.emitting = false
		rest.add_child(_dust)


func _steam(parent: Node3D, pos: Vector3, extents: Vector3, amount: int, vel: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0.03, 0.12, 0)
	p.initial_velocity_min = vel * 0.7
	p.initial_velocity_max = vel * 1.3
	p.damping_min = 0.05
	p.damping_max = 0.15
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	p.mesh = q
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.2, Color(1, 1, 1, 0.22))
	g.add_point(0.6, Color(1, 1, 1, 0.1))
	p.color_ramp = g
	p.material_override = _puff_material(Color(0.9, 0.92, 0.95, 1.0), false)
	parent.add_child(p)
	return p


func _puff_material(c: Color, speck: bool) -> StandardMaterial3D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_puff_tex = t
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = _puff_tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if speck else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.disable_receive_shadows = true
	if speck:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = 0.6
	return m


## Sway a thin hanging thing (curtain, sheet) about its top edge.
func _add_sway(n: Node3D, amp: float, speed: float, cond: String) -> void:
	var vis: Node3D = n.get_node_or_null("Visual")
	if vis == null:
		return
	var s := _size(n)
	var axis := Vector3(0, 0, 1) if s.x < s.z else Vector3(1, 0, 0)   # swing across the thin side
	# which way is into the room (a curtain billows away from its window, not into the wall)
	var z: Zone = n.get_parent().get_parent() as Zone
	var into := 1.0
	if z:
		var c := Vector3(z.size.x / 2.0, 0, z.size.y / 2.0) - n.position
		into = signf(c.x) if axis.z > 0.0 else -signf(c.z)
	_sway.append({"node": vis, "rest": vis.transform, "pivot": Vector3(0, s.y / 2.0, 0), "axis": axis,
		"amp": amp, "speed": speed, "phase": _rng.randf() * TAU, "cond": cond, "w": 1.0, "into": into})


# ================================================================== doors

func _on_traversed(_door_id: String, who: String, d: Doorway) -> void:
	var tgt := d.target()
	_kick(d, false)
	if tgt:
		_kick(tgt, true)
	if who == "hero" or not is_instance_valid(Services.audio):
		return
	var hz := _hero_zone()
	var kind := String(d.def.get("kind", "door"))
	if d.zone_id == hz:
		Services.audio.play_sfx("door_" + kind, d.global_position)
	elif tgt and tgt.zone_id == hz:
		Services.audio.play_sfx("door_" + kind, tgt.global_position)


func _kick(d: Doorway, arriving: bool) -> void:
	var kind := String(d.def.get("kind", "door"))
	if not (kind in SWING_DOORS or kind == "elevator") or String(d.def.get("side", "N")) == "S":
		return
	var vis: Node = d.get_node_or_null("Visual")
	if vis == null or vis.get_child_count() == 0 or not (vis.get_child(0) is MeshInstance3D):
		return
	var mi := vis.get_child(0) as MeshInstance3D
	if not (mi.mesh is BoxMesh):
		return
	var st: Dictionary = _anim.get(d.door_id, {})
	if st.is_empty():
		var sz := (mi.mesh as BoxMesh).size
		var along := Vector3(1, 0, 0) if sz.x > sz.z else Vector3(0, 0, 1)
		st = {"mi": mi, "rest": mi.transform, "along": along, "dw": maxf(sz.x, sz.z), "kind": kind,
			"n": d.normal, "zone": d.zone_id, "pos": d.global_position, "t": 99.0, "dir": 1.0}
		_anim[d.door_id] = st
	st.t = 0.0
	# the free edge swings away from whoever pushed it: into the room on arrival, out on leaving
	var edge := -(st.along as Vector3)
	st.dir = signf(Vector3.UP.cross(edge).dot(st.n)) * (1.0 if arriving else -1.0)
	if kind == "elevator" and st.zone == _hero_zone() and is_instance_valid(Services.audio):
		Services.audio.play_sfx("elev_slide", st.pos)


func _door_tick(st: Dictionary, delta: float) -> void:
	var t: float = st.t
	if t > 4.0:
		return
	st.t = t + delta
	var mi: MeshInstance3D = st.mi
	var rest: Transform3D = st.rest
	if not is_instance_valid(mi):
		return
	var along: Vector3 = st.along
	var dw: float = st.dw
	if st.kind == "elevator":
		var f := 0.0
		if t < 0.7:
			f = smoothstep(0.0, 0.7, t)
		elif t < 2.0:
			f = 1.0
		elif t < 2.8:
			f = 1.0 - smoothstep(2.0, 2.8, t)
		var b := rest.basis.scaled(Vector3.ONE - along * 0.9 * f)
		mi.transform = Transform3D(b, rest.origin + along * dw * 0.45 * f)
		if t >= 2.8:
			mi.transform = rest
			st.t = 99.0
		return
	var a := 0.0
	if st.kind == "swing":
		# kitchen doors flap through and settle
		a = 1.15 * sin(t * 5.2) * exp(-t * 1.6)
		if t > 3.2:
			a = 0.0
			st.t = 99.0
	else:
		if t < 0.35:
			a = 1.25 * (1.0 - pow(1.0 - t / 0.35, 2.0))
		elif t < 0.8:
			a = 1.25
		elif t < 1.9:
			var k := (t - 0.8) / 1.1
			a = 1.25 * (1.0 - k * k * (3.0 - 2.0 * k))
		else:
			a = 0.0
			st.t = 99.0
			if st.zone == _hero_zone() and is_instance_valid(Services.audio):
				Services.audio.play_sfx("door_shut", st.pos)
	var hinge := rest.origin + along * dw / 2.0
	var rb := Basis(Vector3.UP, a * float(st.dir))
	mi.transform = Transform3D(rb * rest.basis, hinge + rb * (rest.origin - hinge))


# ================================================================== tick

func _hero_zone() -> String:
	return String(Services.hero.get("current_zone")) if Services.hero else ""


func _process(delta: float) -> void:
	if world == null:
		return
	for id in _anim:
		_door_tick(_anim[id], delta)
	var ep: Node = get_node("/root/Episode")
	var t := Time.get_ticks_msec() / 1000.0
	# fluorescent tubes: steady for a while, then a short stutter
	for f in _flick:
		var l: OmniLight3D = f[0]
		f[1] = float(f[1]) - delta
		if float(f[1]) <= 0.0 and float(f[2]) <= 0.0:
			f[2] = _rng.randf_range(0.18, 0.5)
		if float(f[2]) > 0.0:
			f[2] = float(f[2]) - delta
			l.set_meta("flicker", 0.25 if _rng.randf() < 0.45 else 1.0)
			if float(f[2]) <= 0.0:
				f[1] = _rng.randf_range(3.5, 11.0)
				l.set_meta("flicker", 1.0)
	# hanging cloth
	for s in _sway:
		var on := true
		if s.cond == "window_open":
			on = not ep.flags.get("window_closed", false)
		s.w = lerpf(float(s.w), 1.0 if on else 0.08, minf(1.0, delta * 0.8))
		var sp: float = s.speed
		var ph: float = s.phase
		var a := float(s.amp) * float(s.w) * (sin(t * sp + ph) * 0.7 + sin(t * sp * 2.3 + ph * 1.7) * 0.3)
		if s.cond == "window_open":
			a = absf(a) * 1.4 * float(s.into)   # air comes in from the window side only
		var rb := Basis(s.axis as Vector3, a)
		var piv: Vector3 = s.pivot
		var rest: Transform3D = s.rest
		(s.node as Node3D).transform = Transform3D(rb, piv - rb * piv) * rest
	for sp in _spin:
		(sp[0] as Node3D).rotation.y += float(sp[1]) * delta
	# laundry press
	if _press:
		_press_t -= delta
		if _press_t <= 0.0:
			_press_t = _rng.randf_range(5.0, 9.0)
			_press.restart()
			if _hero_zone() == "LAUNDRY" and is_instance_valid(Services.audio):
				Services.audio.play_sfx("steam", _press.global_position)
	if _dust:
		_dust.emitting = not VesperTime.cur.is_empty() and float(VesperTime.cur.get("lift", 1.0)) > 1.35
	_slow -= delta
	if _slow <= 0.0:
		_slow = 0.4
		_slow_tick(ep)


func _slow_tick(ep: Node) -> void:
	# cigarettes and the bar routine follow the people
	for id in world.npcs:
		var n: Node = world.npcs[id]
		var bv: BodyVisual = n.get("body_vis")
		if bv == null:
			continue
		var smoking: bool = n.get("spawned") and bv.pose == "smoke"
		if smoking and not _smoke.has(id) and bv.hand_r:
			var p := _steam(bv.hand_r, Vector3(0, 0.05, 0), Vector3(0.01, 0.01, 0.01), 8, 0.12)
			(p.mesh as QuadMesh).size = Vector2(0.14, 0.14)
			p.lifetime = 2.6
			_smoke[id] = p
		if _smoke.has(id):
			(_smoke[id] as CPUParticles3D).emitting = smoking
		if not _beats.has(id):
			_beats[id] = true
			bv.work_beat.connect(_on_work_beat.bind(n))
	_tick_sources(ep)


func _on_work_beat(step: int, n: Node) -> void:
	if step != 1 or not is_instance_valid(Services.audio) or String(n.get("current_zone")) != _hero_zone():
		return
	var bv: BodyVisual = n.get("body_vis")
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(bv) and is_instance_valid(Services.audio):
			Services.audio.play_sfx("glass_set", bv.hand_r.global_position))


## Positional loops near EL: rain on the window glass; the bar's voices; the kitchen extractor.
func _tick_sources(ep: Node) -> void:
	var a: Node = Services.audio
	if not is_instance_valid(a):
		return
	var hz := _hero_zone()
	var hero_pos: Vector3 = (Services.hero as Node3D).global_position if Services.hero else Vector3.ZERO
	# rain at the glass
	var rain := float(VesperTime.cur.get("rain", 0.0)) if not VesperTime.cur.is_empty() else 0.0
	var wins: Array = BodyMotion.zone_points(hz).windows if VesperLook.wing(hz) != "EXTERIOR" else []
	if rain > 0.05 and not wins.is_empty():
		var best: Vector3 = wins[0]
		for wpt in wins:
			if (wpt as Vector3).distance_to(hero_pos) < best.distance_to(hero_pos):
				best = wpt
		_rain_src.global_position = best
		if _rain_src.stream == null:
			_rain_src.stream = a.loop("rain_glass")
		if not _rain_src.playing:
			_rain_src.play()
		var closed: bool = hz == "ROOM_307" and ep.flags.get("window_closed", false)
		_rain_src.volume_db = lerpf(_rain_src.volume_db, linear_to_db(rain * (0.3 if closed else 1.0)) - 6.0, 0.5)
	elif _rain_src.playing:
		_rain_src.volume_db -= 6.0
		if _rain_src.volume_db < -50.0:
			_rain_src.stop()
	# the room's own source
	var want := ""
	var pos := Vector3.ZERO
	if hz == "BAR":
		var people := 0
		for id in world.npcs:
			var n: Node = world.npcs[id]
			if n.get("spawned") and String(n.get("current_zone")) == "BAR":
				people += 1
		if people >= 3:
			want = "murmur"
			pos = world.zone_node("BAR").global_position + Vector3(10, 1.2, 5)
	elif hz == "KITCHEN":
		var hood := _prop("KITCHEN", "hood")
		if hood:
			want = "extractor"
			pos = hood.global_position
	if want != _room_id:
		_room_id = want
		_room_src.stop()
		if want != "":
			_room_src.stream = a.loop(want)
			_room_src.volume_db = -30.0
			_room_src.play()
	if want != "":
		_room_src.global_position = pos
		_room_src.volume_db = lerpf(_room_src.volume_db, -9.0 if want == "murmur" else -12.0, 0.35)
