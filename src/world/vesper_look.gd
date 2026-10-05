class_name VesperLook
extends RefCounted
## THE VESPER — one coherent hotel identity over the graybox (Visual Integration V1.4).
## Runs after the world is built and only touches "Visual" meshes and lights: collision, groups,
## markers and gameplay are never changed, and final art can replace any of it later.
##
## Wings (CIR-25D direction):
##   PUBLIC   — dark timber, stone, aged brass, warm tungsten (2700 K), smoked green, dirty cream
##   GUEST    — cooler and quieter: patterned carpet, controlled repetition, softer 3000 K
##   SERVICE  — older and practical: painted two-tone walls, tile, steel, flat 4500 K, pipes
##   EXTERIOR — wet concrete and brick, sodium bounce, cool night ambient, rain
## Value range: black floor #0E0D0C, highlight ceiling #F1E6CF (enforced in the surface shader).

const SHADER := preload("res://src/world/vesper_surface.gdshader")

const ZONES := {
	"BAR": {"wing": "PUBLIC", "floor": "timber_floor", "wall": "bar_wall", "trim": "walnut_wainscot"},
	"LOBBY": {"wing": "PUBLIC", "floor": "stone_floor", "wall": "cream_wallpaper", "trim": "walnut_wainscot"},
	"RESTAURANT": {"wing": "PUBLIC", "floor": "timber_floor", "wall": "cream_wallpaper", "trim": "walnut_wainscot"},
	"MEZZANINE": {"wing": "PUBLIC", "floor": "guest_carpet", "wall": "cream_wallpaper", "trim": "walnut_wainscot"},
	"BHALL": {"wing": "PUBLIC", "floor": "timber_floor", "wall": "cream_wallpaper", "trim": "walnut_wainscot"},
	"BCORR": {"wing": "PUBLIC", "floor": "guest_carpet", "wall": "cream_wallpaper", "trim": "walnut_wainscot"},
	"ORCHID": {"wing": "PUBLIC", "floor": "timber_floor", "wall": "orchid_wall", "trim": "walnut_wainscot"},
	"HALL_3F": {"wing": "GUEST", "floor": "guest_carpet", "wall": "guest_wall", "trim": "guest_dado"},
	"ROOM_307": {"wing": "GUEST", "floor": "room_carpet", "wall": "room_wall", "trim": "guest_dado"},
	"ROOM_308": {"wing": "GUEST", "floor": "room_carpet", "wall": "room_wall", "trim": "guest_dado"},
	"ELEV_A": {"wing": "GUEST", "floor": "stone_floor", "wall": "walnut_panel", "trim": ""},
	"SCORR": {"wing": "SERVICE", "floor": "service_floor", "wall": "service_wall", "trim": "service_band"},
	"SECURITY": {"wing": "SERVICE", "floor": "service_floor", "wall": "service_wall", "trim": "service_band"},
	"LAUNDRY": {"wing": "SERVICE", "floor": "tile_floor", "wall": "tile_wall", "trim": ""},
	"KITCHEN": {"wing": "SERVICE", "floor": "tile_floor", "wall": "tile_wall", "trim": ""},
	"COLD_STORAGE": {"wing": "SERVICE", "floor": "tile_floor", "wall": "steel_wall", "trim": ""},
	"STAFF_CORRIDOR": {"wing": "SERVICE", "floor": "service_floor", "wall": "service_wall", "trim": "service_band"},
	"SERVICE_STAIR": {"wing": "SERVICE", "floor": "service_floor", "wall": "service_wall", "trim": "service_band"},
	"FREIGHT": {"wing": "SERVICE", "floor": "steel_floor", "wall": "steel_wall", "trim": ""},
	"LOADING_DOCK": {"wing": "EXTERIOR", "floor": "concrete_wet", "wall": "brick", "trim": ""},
	"ROOF_SMOKING": {"wing": "EXTERIOR", "floor": "concrete_wet", "wall": "brick", "trim": ""},
	"STREET": {"wing": "EXTERIOR", "floor": "concrete_wet", "wall": "stone_facade", "trim": ""},
}

## name: [pattern, base, alt, scale, contrast, rough, metal, variation, wet, emission]
const MATS := {
	"timber_floor": [1, "3b2c20", "4f3a28", 1.0, 0.55, 0.5, 0.0, 0.10, 0.0],
	"walnut": [1, "3a2618", "4e3220", 2.2, 0.5, 0.42, 0.0, 0.08, 0.0],
	"walnut_panel": [7, "3a2618", "24170e", 1.2, 0.5, 0.45, 0.0, 0.06, 0.0],
	"stone_floor": [2, "7a7266", "564f46", 0.5, 0.45, 0.3, 0.0, 0.10, 0.0],
	"marble_green": [6, "1f3a31", "a7b2a8", 0.8, 0.3, 0.22, 0.0, 0.06, 0.0],
	"marble_cream": [6, "6f685d", "4f4a43", 0.6, 0.35, 0.3, 0.0, 0.06, 0.0],
	"cream_wallpaper": [3, "a89878", "8f8064", 1.0, 0.5, 0.85, 0.0, 0.12, 0.0],
	"bar_wall": [3, "2f3f35", "26332b", 1.0, 0.6, 0.8, 0.0, 0.12, 0.0],
	"orchid_wall": [3, "4a2e33", "3b2228", 1.0, 0.45, 0.85, 0.0, 0.12, 0.0],
	"walnut_wainscot": [7, "3a2618", "24170e", 1.0, 0.5, 0.45, 0.0, 0.06, 0.0],
	"brass": [0, "9c7a42", "9c7a42", 1.0, 0.0, 0.36, 0.8, 0.06, 0.0],
	"oxblood": [0, "5a2724", "5a2724", 1.0, 0.0, 0.5, 0.0, 0.08, 0.0],
	"smoked_green": [0, "2f3f35", "2f3f35", 1.0, 0.0, 0.55, 0.0, 0.08, 0.0],
	"linen": [0, "e3d7bf", "e3d7bf", 1.0, 0.0, 0.9, 0.0, 0.05, 0.0],
	"guest_carpet": [4, "3b2228", "6a3a3a", 0.9, 0.55, 0.95, 0.0, 0.08, 0.0],
	"guest_wall": [3, "6e675c", "5e584f", 1.0, 0.45, 0.85, 0.0, 0.10, 0.0],
	"guest_dado": [7, "d9cfbc", "b8ad98", 1.3, 0.3, 0.6, 0.0, 0.05, 0.0],
	"room_carpet": [4, "4a433c", "5a5148", 1.1, 0.35, 0.95, 0.0, 0.06, 0.0],
	"room_wall": [3, "6f665a", "625a50", 1.0, 0.35, 0.85, 0.0, 0.08, 0.0],
	"service_floor": [5, "3a3d3a", "2b2d2b", 1.0, 0.6, 0.75, 0.0, 0.10, 0.0],
	"service_wall": [0, "75807a", "75807a", 1.0, 0.0, 0.85, 0.0, 0.14, 0.0],
	"service_band": [0, "4f5b53", "4f5b53", 1.0, 0.0, 0.7, 0.0, 0.10, 0.0],
	"tile_wall": [2, "9ba197", "5e635c", 3.3, 0.7, 0.4, 0.0, 0.10, 0.0],
	"tile_floor": [2, "6e736c", "3a3d3a", 3.0, 0.75, 0.55, 0.0, 0.10, 0.0],
	"steel": [0, "8e9590", "8e9590", 1.0, 0.0, 0.42, 0.55, 0.06, 0.0],
	"steel_wall": [7, "7d847f", "6a706c", 0.8, 0.3, 0.45, 0.4, 0.06, 0.0],
	"steel_floor": [2, "5a5f5c", "3a3d3a", 2.0, 0.5, 0.5, 0.4, 0.06, 0.0],
	"painted_metal": [0, "4f5b53", "4f5b53", 1.0, 0.0, 0.6, 0.15, 0.08, 0.0],
	"concrete_wet": [5, "2b2d33", "3a3d44", 0.7, 0.6, 0.6, 0.0, 0.10, 0.85],
	"brick": [8, "4a2e25", "2a2622", 1.0, 0.0, 0.85, 0.0, 0.12, 0.0],
	"stone_facade": [2, "56544f", "3a3834", 0.5, 0.6, 0.8, 0.0, 0.12, 0.0],
	"door_timber": [7, "3a2618", "24170e", 1.6, 0.5, 0.45, 0.0, 0.06, 0.0],
	"door_service": [0, "55625a", "55625a", 1.0, 0.0, 0.6, 0.1, 0.08, 0.0],
	"night_glass": [0, "1c2833", "1c2833", 1.0, 0.0, 0.1, 0.0, 0.0, 0.0],
	"dark": [0, "1a1714", "1a1714", 1.0, 0.0, 0.8, 0.0, 0.04, 0.0],
	"opening": [0, "0e0d0c", "0e0d0c", 1.0, 0.0, 1.0, 0.0, 0.0, 0.0],
	"crate": [1, "5a4630", "3e2f20", 2.5, 0.5, 0.8, 0.0, 0.1, 0.0],
	"ceramic_dark": [0, "2a2622", "2a2622", 1.0, 0.0, 0.5, 0.0, 0.06, 0.0],
	"object": [0, "cbbb9a", "cbbb9a", 1.0, 0.0, 0.7, 0.0, 0.04, 0.0],
}

## Light colour temperature per wing and an energy scale.
const WING_LIGHT := {
	"PUBLIC": [Color(1.0, 0.70, 0.42), 1.7],
	"GUEST": [Color(1.0, 0.77, 0.54), 1.35],
	"SERVICE": [Color(0.84, 0.92, 0.86), 1.25],
	"EXTERIOR": [Color(1.0, 0.62, 0.32), 1.4],
}

## Cool/warm ambient per wing (blended in as the hero changes zones).
const WING_AMBIENT := {
	"PUBLIC": [Color(0.42, 0.38, 0.40), 0.75],
	"GUEST": [Color(0.40, 0.38, 0.40), 0.7],
	"SERVICE": [Color(0.46, 0.51, 0.50), 0.85],
	"EXTERIOR": [Color(0.32, 0.40, 0.55), 0.8],
}

static var _cache: Dictionary = {}


## The art layer can be switched off for A/B comparison: `-- --graybox`, or (debug builds only)
## the marker file /tmp/room307_graybox, which the persistent capture server picks up.
static func enabled() -> bool:
	if "--graybox" in OS.get_cmdline_user_args():
		return false
	return not (OS.is_debug_build() and FileAccess.file_exists("/tmp/room307_graybox"))


static func reset_cache() -> void:
	_cache.clear()


static func wing(zone_id: String) -> String:
	return String(ZONES.get(zone_id, {}).get("wing", "PUBLIC"))


static func material(name: String, tint: Variant = null) -> ShaderMaterial:
	var key := name + ("" if tint == null else "|" + (tint as Color).to_html())
	if _cache.has(key):
		return _cache[key]
	var p: Array = MATS.get(name, MATS.dark)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var base := Color(String(p[1]))
	var alt := Color(String(p[2]))
	if tint != null:
		base = tint
		alt = (tint as Color).darkened(0.25)
	m.set_shader_parameter("pattern", int(p[0]))
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("alt_color", alt)
	m.set_shader_parameter("scale", float(p[3]))
	m.set_shader_parameter("contrast", float(p[4]))
	m.set_shader_parameter("rough", float(p[5]))
	m.set_shader_parameter("metal", float(p[6]))
	m.set_shader_parameter("variation", float(p[7]))
	m.set_shader_parameter("wet", float(p[8]))
	_cache[key] = m
	return m


static func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var key := "emit|%s|%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	_cache[key] = m
	return m


# ================================================================== apply

const DRESS := preload("res://src/world/vesper_dress.gd")


static func apply(world: Node) -> void:
	VesperTime.stage = ""          # re-applied on the first frame of this world
	VesperTime.window_lights.clear()
	for zid in world.zones:
		skin_zone(world.zones[zid])
	for it in world.get_tree().get_nodes_in_group("interactables"):
		_skin_interactable(it)
	DRESS.apply(world)


static func skin_zone(z: Zone) -> void:
	var zd: Dictionary = ZONES.get(z.zone_id, {})
	if zd.is_empty():
		return
	var w := String(zd.wing)
	var geo: Node = z.get_node_or_null("Geometry")
	if geo:
		for n in geo.get_children():
			_skin_node(n, z, zd, w)
	for did in z.doors:
		_skin_door(z.doors[did], w)
	_relight(z, w)


static func _mesh_of(n: Node) -> MeshInstance3D:
	var vis := n.get_node_or_null("Visual")
	if vis and vis.get_child_count() > 0 and vis.get_child(0) is MeshInstance3D:
		return vis.get_child(0)
	return null


static func _skin_node(n: Node, z: Zone, zd: Dictionary, w: String) -> void:
	var mi := _mesh_of(n)
	if mi == null:
		return
	var nm := String(n.name)
	if nm == "Floor":
		mi.material_override = material(String(zd.floor))
		return
	if nm.begins_with("Wall"):
		mi.material_override = material(String(zd.wall))
		return
	var def: Dictionary = n.get_meta("def", {})
	if def.is_empty():
		mi.material_override = material(String(zd.floor) if nm.begins_with("Ramp") or nm.begins_with("ramp") else "walnut" if w == "PUBLIC" else "service_floor")
		return
	var m := _box_material(def, w, mi)
	if m:
		mi.material_override = m
	# tall props can stand between the 2.5D camera and the hero: own material so the camera can
	# dither them out (CameraDirector) — perimeter walls are cutaways already
	var sz := Data.vec3(def.get("s", [1, 1, 1]))
	if sz.y >= 1.6 and n is StaticBody3D and mi.material_override is ShaderMaterial:
		mi.material_override = (mi.material_override as ShaderMaterial).duplicate()
		n.set_meta("occluder", mi)
	# the yellow "vaultable" stripe becomes a worn brass / pale edge: still readable, not a UI colour
	var vis: Node = n.get_node("Visual")
	for i in range(1, vis.get_child_count()):
		var c := vis.get_child(i)
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = material("brass") if w != "SERVICE" else material("linen")


static func _box_material(def: Dictionary, w: String, mi: MeshInstance3D) -> Material:
	var k := String(def.get("k", "furn"))
	var has_c := def.has("c")
	var c: Color = Graybox.color(def.get("c", "furn")) if has_c else Color.BLACK
	var reddish := has_c and c.r > c.g + 0.08 and c.r > c.b + 0.08
	var greenish := has_c and c.g > c.r + 0.05 and c.g >= c.b
	match k:
		"floor":
			return material(String(ZONES.get(_zone_of(mi), {}).get("floor", "service_floor")))
		"wall":
			return material("marble_cream") if w == "PUBLIC" else material("guest_wall") if w == "GUEST" else material("service_wall") if w == "SERVICE" else material("brick")
		"counter":
			return material("walnut") if w in ["PUBLIC", "GUEST"] else material("steel")
		"metal":
			return material("brass") if w in ["PUBLIC", "GUEST"] else material("steel")
		"cloth":
			return material("linen")
		"glass":
			if def.get("nocol", false) and String(def.get("id", "")).contains("jet"):
				return null   # the fountain's water stays translucent
			return material("night_glass")
		"dark":
			return material("dark")
		"door":
			return material("door_timber") if w in ["PUBLIC", "GUEST"] else material("door_service")
		"cover":
			if w == "EXTERIOR":
				return material("steel")
			if w == "SERVICE":
				return material("crate")
			return material("ceramic_dark") if greenish or not has_c else material("oxblood")
		"vault":
			return material("walnut") if w in ["PUBLIC", "GUEST"] else material("steel") if w == "SERVICE" else material("concrete_wet")
	# furniture
	if reddish:
		return material("oxblood")
	if greenish:
		return material("smoked_green")
	if has_c and c.get_luminance() > 0.6:
		return material("linen")
	if w == "SERVICE":
		return material("painted_metal")
	if w == "EXTERIOR":
		return material("painted_metal")
	return material("walnut")


static func _zone_of(n: Node) -> String:
	var p := n.get_parent()
	while p and not (p is Zone):
		p = p.get_parent()
	return (p as Zone).zone_id if p else ""


static func _skin_door(d: Doorway, w: String) -> void:
	var vis: Node = d.get_node_or_null("Visual")
	if vis == null:
		return
	var kind := String(d.def.get("kind", "door"))
	var trim := material("brass") if w in ["PUBLIC", "GUEST"] else material("steel") if w == "EXTERIOR" else material("service_band")
	var first := true
	for c in vis.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi := c as MeshInstance3D
		if first:
			first = false
			if kind in ["arch", "stair"]:
				mi.material_override = material("opening")
			elif kind == "elevator":
				mi.material_override = material("brass") if w != "SERVICE" else material("steel")
			else:
				mi.material_override = material("door_timber") if w in ["PUBLIC", "GUEST"] else material("door_service") if w == "SERVICE" else material("painted_metal")
			continue
		mi.material_override = trim


static func _skin_interactable(it: Node) -> void:
	var mn: Node = it.get("mesh_node")
	if mn == null or not (mn is MeshInstance3D):
		return
	var m: Dictionary = it.def.get("mesh", {})
	if m.has("c") and str(m.get("c", "")) != "interact":
		var c := Graybox.color(m.c)
		(mn as MeshInstance3D).material_override = material("object", c.lerp(Color("cbbb9a"), 0.35))
		return
	# clue objects read as objects (warm paper / brass), lifted just enough to be found — no cyan
	var e := emissive(Color("cbbb9a"), 0.18)
	(mn as MeshInstance3D).material_override = e


static func _relight(z: Zone, w: String) -> void:
	if z.lights_root == null:
		return
	var wl: Array = WING_LIGHT.get(w, WING_LIGHT.PUBLIC)
	for l in z.lights_root.get_children():
		var o := l as OmniLight3D
		if o == null:
			continue
		# keep deliberate cool/accent lights (e.g. window or monitor spill); retemper the rest
		var c := o.light_color
		var cool := c.b > c.r + 0.05
		if not cool:
			o.light_color = (wl[0] as Color).lerp(c, 0.15)
		o.light_energy *= float(wl[1])
		o.omni_range *= 1.15
		o.omni_attenuation = 1.3
		o.light_specular = 0.6
		_fixture(z, o, w)
	if w in ["PUBLIC", "GUEST"]:
		_sconces(z, w)


# ================================================================== practical light sources

const WARM_SHADE := Color(0.95, 0.76, 0.48)
const TUBE := Color(0.86, 0.93, 0.88)
const SODIUM := Color(1.0, 0.62, 0.3)


static func _mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _look_root(z: Zone) -> Node3D:
	var r: Node3D = z.get_node_or_null("Look")
	if r == null:
		r = Node3D.new()
		r.name = "Look"
		z.add_child(r)
	return r


## A visible source for every lamp: the light has to come from somewhere (motivated lighting).
static func _fixture(z: Zone, o: OmniLight3D, w: String) -> void:
	var root := _look_root(z)
	var p := o.position
	var h := float(z.def.get("height", 3.5))
	match w:
		"PUBLIC":
			var cord := CylinderMesh.new()
			cord.top_radius = 0.012
			cord.bottom_radius = 0.012
			cord.height = maxf(0.05, h - p.y)
			_mesh(root, cord, material("brass"), Vector3(p.x, p.y + cord.height / 2.0 + 0.2, p.z))
			var shade := CylinderMesh.new()
			shade.top_radius = 0.16
			shade.bottom_radius = 0.34
			shade.height = 0.3
			_mesh(root, shade, material("brass"), p + Vector3(0, 0.25, 0))
			var glow := SphereMesh.new()
			glow.radius = 0.17
			glow.height = 0.2
			_mesh(root, glow, emissive(WARM_SHADE, 3.0), p + Vector3(0, 0.08, 0))
		"GUEST":
			if String(z.def.get("mode", "ROOM")) == "ROOM":
				return   # rooms are seen from above the ceiling line: their lamps are props (V1.5)
			var dome := SphereMesh.new()
			dome.radius = 0.28
			dome.height = 0.14
			_mesh(root, dome, emissive(WARM_SHADE.lerp(Color(1, 0.9, 0.75), 0.4), 1.4), Vector3(p.x, minf(h - 0.07, p.y + 0.5), p.z))
		"SERVICE":
			var tube := BoxMesh.new()
			tube.size = Vector3(1.25, 0.05, 0.16)
			_mesh(root, tube, material("painted_metal"), Vector3(p.x, minf(h - 0.05, p.y + 0.4), p.z))
			var lit := BoxMesh.new()
			lit.size = Vector3(1.15, 0.03, 0.1)
			_mesh(root, lit, emissive(TUBE, 2.6), Vector3(p.x, minf(h - 0.05, p.y + 0.4) - 0.03, p.z))
		"EXTERIOR":
			var head := BoxMesh.new()
			head.size = Vector3(0.5, 0.12, 0.3)
			_mesh(root, head, material("painted_metal"), p + Vector3(0, 0.2, 0))
			var lens := BoxMesh.new()
			lens.size = Vector3(0.42, 0.03, 0.24)
			_mesh(root, lens, emissive(SODIUM, 3.0), p + Vector3(0, 0.13, 0))


## Warm wall sconces along the back wall: small 2700 K pools that model the walls and frame
## the play plane. Never over a doorway.
static func _sconces(z: Zone, w: String) -> void:
	var root := _look_root(z)
	var spans: Array = []
	for did in z.doors:
		var d: Doorway = z.doors[did]
		if String(d.def.get("side", "N")) == "N":
			spans.append(Vector2(d.position.x - float(d.def.get("w", 1.2)) / 2.0 - 0.5, d.position.x + float(d.def.get("w", 1.2)) / 2.0 + 0.5))
	var n := clampi(int(z.size.x / 4.5), 1, 5)
	var step := z.size.x / float(n + 1)
	for i in n:
		var x := step * (i + 1)
		var blocked := false
		for s in spans:
			if x >= s.x and x <= s.y:
				blocked = true
		if blocked:
			continue
		var y := 2.05 if w == "PUBLIC" else 1.9
		var plate := BoxMesh.new()
		plate.size = Vector3(0.12, 0.22, 0.03)
		_mesh(root, plate, material("brass"), Vector3(x, y, 0.02))
		var shade := CylinderMesh.new()
		shade.top_radius = 0.07
		shade.bottom_radius = 0.11
		shade.height = 0.16
		_mesh(root, shade, emissive(WARM_SHADE, 2.4), Vector3(x, y + 0.08, 0.13))
		var l := OmniLight3D.new()
		l.position = Vector3(x, y + 0.1, 0.35)
		l.light_color = Color(1.0, 0.68, 0.4)
		l.light_energy = 0.9 if w == "PUBLIC" else 0.7
		l.omni_range = 3.2
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		root.add_child(l)
