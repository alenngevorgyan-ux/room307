class_name HotelWorld
extends Node3D
## The whole hotel as one world (LEVEL_LAYOUT §1): every block built from data and kept loaded.
## Also spawns the hero, all NPC bodies (despawned until a scene places them), interactables,
## static observables, the camera director, READ, environment and audio buses.

const FADE := 0.25

var zones: Dictionary = {}
var doors: Dictionary = {}
var npcs: Dictionary = {}
var hero: PlayerController
var camera_director: CameraDirector
var read_system: ReadSystem
var env: WorldEnvironment
var sun: DirectionalLight3D
var traversing := false
var bake_nav := true


func _ready() -> void:
	Services.world = self
	_setup_audio_buses()
	_build_environment()
	var D := get_node("/root/Data")
	for zid in D.level:
		var z := LevelBuilder.build(zid, D.level[zid])
		add_child(z)
		zones[zid] = z
		for did in z.doors:
			doors[did] = z.doors[did]
	if bake_nav:
		_bake_navigation()
	for iid in D.interactables:
		var d: Dictionary = D.interactables[iid]
		var it := Interactable.new()
		add_child(it)
		it.setup(iid, d)
		if d.has("zone"):
			it.global_position = D.zone_origin(String(d.zone)) + Data.vec3(d.get("p", [0, 0, 0]))
		if d.has("npc"):
			it.set_meta("follow_npc", String(d.npc))
	# THE VESPER art layer: re-skins visuals and lights only (gameplay geometry untouched)
	if VesperLook.enabled():
		VesperLook.apply(self)
	hero = PlayerController.new()
	hero.name = "Hero"
	add_child(hero)
	for npc_id in D.characters:
		var cd: Dictionary = D.characters[npc_id]
		var n := NPC.new()
		add_child(n)
		n.setup(npc_id, cd)
		npcs[npc_id] = n
	for oid in D.observations:
		var od: Dictionary = D.observations[oid]
		var anc: Dictionary = od.get("anchor", {})
		var o := Observable.new()
		o.setup(oid, od)
		if anc.has("npc") and npcs.has(String(anc.npc)):
			npcs[String(anc.npc)].attach_observable(o, String(anc.get("part", "body")), Data.vec3(anc.get("off", [0, 0, 0])))
		elif anc.has("zone"):
			add_child(o)
			o.global_position = D.zone_origin(String(anc.zone)) + Data.vec3(anc.get("p", [0, 1, 0]))
		elif anc.has("interact"):
			add_child(o)
			o.set_meta("follow_interact", String(anc.interact))
		else:
			add_child(o)
			o.visible = false
	# the world keeps moving at the edge of attention (Motion Polish Pass E/H; visual + audio only)
	if VesperLook.enabled():
		var vm := VesperMotion.new()
		add_child(vm)
		vm.setup(self)
	camera_director = CameraDirector.new()
	camera_director.name = "CameraDirector"
	add_child(camera_director)
	read_system = ReadSystem.new()
	read_system.name = "ReadSystem"
	add_child(read_system)


func _exit_tree() -> void:
	if Services.world == self:
		Services.world = null


var _amb_target := Color(0.36, 0.33, 0.36)
var _amb_energy := 0.55
var _mood_mult := 1.0


func _process(_delta: float) -> void:
	# wing ambience follows the hero (warm public rooms, cooler guest floors, flat service)
	if hero and env and VesperLook.enabled():
		var w := VesperLook.wing(hero.current_zone)
		var wa: Array = VesperLook.WING_AMBIENT.get(w, VesperLook.WING_AMBIENT.PUBLIC)
		var ta: Array = VesperTime.ambient(w, wa[0], float(wa[1]))
		var e := env.environment
		var k := minf(1.0, _delta * 2.0)
		e.ambient_light_color = e.ambient_light_color.lerp(ta[0], k)
		e.ambient_light_energy = lerpf(e.ambient_light_energy, float(ta[1]) * _mood_mult, k)
		# READ (Pass 7): the world drains of colour and cools slightly while EL studies it
		var reading: bool = Services.read != null and Services.read.active
		e.adjustment_saturation = lerpf(e.adjustment_saturation, 0.58 if reading else 0.92, minf(1.0, _delta * 5.0))
		e.adjustment_brightness = lerpf(e.adjustment_brightness, 0.94 if reading else 1.0, minf(1.0, _delta * 5.0))
		# the night moves on with the story (Pass 11) — gradually (Motion Polish Pass G)
		VesperTime.update(self, get_node("/root/Episode"), _delta)
		VesperArt.tick(self)   # rig-specific visual pieces (final visual language); visual only
	# interactables/observables bound to moving NPCs or interactables
	for it in get_tree().get_nodes_in_group("interactables"):
		if it.has_meta("follow_npc"):
			var n: NPC = npcs.get(it.get_meta("follow_npc"))
			if n and n.spawned:
				it.global_position = n.global_position + Vector3(0, 0.0, 0)
	for o in get_tree().get_nodes_in_group("observables"):
		if o.has_meta("follow_interact"):
			var it := get_node_or_null("I_" + String(o.get_meta("follow_interact")))
			if it:
				o.global_position = it.global_position + Vector3(0, 0.15, 0)


# ------------------------------------------------------------------ lookups

func zone_node(zid: String) -> Zone:
	return zones.get(zid)


func zone_def(zid: String) -> Dictionary:
	var z: Zone = zones.get(zid)
	return z.def if z else {}


func door(did: String) -> Doorway:
	return doors.get(did)


func npc(id: String) -> NPC:
	return npcs.get(id)


func zone_at(p: Vector3) -> String:
	for zid in zones:
		if zones[zid].contains(p):
			return zid
	return ""


# ------------------------------------------------------------------ transitions

func traverse_hero(d: Doorway) -> void:
	if traversing:
		return
	var tgt := d.target()
	if tgt == null:
		return
	traversing = true
	var B := get_node("/root/Bus")
	B.control_lock.emit("door", true)
	B.sfx_requested.emit("door_" + String(d.def.get("kind", "door")), d.global_position)
	if Services.hud:
		Services.hud.fade(FADE / 2.0, true)
	var serial := hero.teleport_serial
	var travel := Vector3(hero.velocity.x, 0, hero.velocity.z)
	if travel.length() < 0.3:
		travel = -d.normal
	var t := get_tree().create_timer(FADE / 2.0, true, false, true)
	await t.timeout
	if hero.teleport_serial != serial or hero.current_zone != d.zone_id:
		# something else (catch, cine, chase grab, scene change) moved the hero mid-fade: it wins
		if Services.hud:
			Services.hud.fade(FADE / 2.0, false)
		B.control_lock.emit("door", false)
		traversing = false
		return
	hero.teleport_to(tgt.spawn_point(), tgt.zone_id)
	hero.arrive_through(tgt, travel.normalized())
	hero.facing = tgt.normal
	hero.body_vis.rotation.y = atan2(-tgt.normal.x, -tgt.normal.z)
	camera_director.snap()
	d.traversed.emit(d.door_id, "hero")
	get_node("/root/Episode").hero_zone = tgt.zone_id
	B.player_decision.emit("door")
	if Services.hud:
		Services.hud.fade(FADE / 2.0, false)
	await get_tree().create_timer(FADE / 2.0, true, false, true).timeout
	B.control_lock.emit("door", false)
	traversing = false


func place_hero(marker_ref: String, seated: bool = false) -> void:
	var D := get_node("/root/Data")
	if seated:
		hero.sit_at(D.marker(marker_ref), D.marker_zone(marker_ref))
	else:
		hero.teleport_to(D.marker(marker_ref), D.marker_zone(marker_ref))
	camera_director.snap()


# ------------------------------------------------------------------ environment

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0e0d0c")      # CIR-25D black floor: never #000
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.36, 0.33, 0.36)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.15
	e.tonemap_white = 1.3
	# slight halation on practicals only (no bloom wash)
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_strength = 0.9
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.15
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.07, 0.075, 0.09)
	e.fog_density = 0.01
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 0.92
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.25
	sun.light_color = Color(0.6, 0.68, 0.85)
	sun.shadow_enabled = false
	add_child(sun)


func set_mood(mood: String) -> void:
	var e := env.environment
	match mood:
		"dawn":
			_mood_mult = 1.25
			sun.light_color = Color(0.95, 0.75, 0.6)
			sun.light_energy = 0.55
		"blackout":
			_mood_mult = 0.15
			e.ambient_light_energy = 0.08
		_:
			_mood_mult = 1.0
			sun.light_color = Color(0.6, 0.68, 0.85)
			sun.light_energy = 0.25
	if not VesperLook.enabled():
		e.ambient_light_energy = 0.9 * _mood_mult


func _setup_audio_buses() -> void:
	for b in ["Ambience", "Music", "SFX", "Dialogue"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
			if b == "Ambience":
				var lp := AudioEffectLowPassFilter.new()
				lp.cutoff_hz = 900
				AudioServer.add_bus_effect(i, lp)
				AudioServer.set_bus_effect_enabled(i, 0, false)


# ------------------------------------------------------------------ navigation

func _bake_navigation() -> void:
	for zid in zones:
		var z: Zone = zones[zid]
		var region := NavigationRegion3D.new()
		region.name = "Nav"
		var nm := NavigationMesh.new()
		nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nm.geometry_collision_mask = Graybox.LAYER_WORLD
		nm.cell_size = 0.25
		nm.cell_height = 0.25
		nm.agent_radius = 0.25
		nm.agent_height = 1.75
		nm.agent_max_climb = 0.5
		nm.agent_max_slope = 50.0
		z.add_child(region)
		var src := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nm, src, z.get_node("Geometry"))
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		region.navigation_mesh = nm
