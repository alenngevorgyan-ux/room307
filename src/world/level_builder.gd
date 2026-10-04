class_name LevelBuilder
extends RefCounted
## Builds a Zone from its JSON block definition (LEVEL_LAYOUT). All coordinates are zone-local:
## X along screen width, Z = depth (0 = back wall, size.y = camera side), Y up.
##
## Block keys: origin, size [W,D], height, tint, floor_color, walls {skip:[N,E,W,S], front_visible},
## boxes [{id,p:[x,z]|[x,y,z],s:[w,h,d],k,c,rot,nocol,slide}], ramps [{from,to,w}],
## doors [...], markers {}, rigs {}, camzones [{rig,p,s,y}], lights [{p,c,e,r}], rain, labels [{p,t,s}]

const WALL_T := 0.3

const KIND_COLOR := {"furn": "furn", "cover": "cover", "vault": "vault", "wall": "wall", "glass": "glass",
	"counter": "counter", "metal": "metal", "cloth": "cloth", "dark": "dark", "floor": "floor", "door": "door"}


static func build(zid: String, d: Dictionary) -> Zone:
	var z := Zone.new()
	z.name = zid
	z.zone_id = zid
	z.def = d
	var s: Array = d.get("size", [10, 10])
	z.size = Vector2(float(s[0]), float(s[1]))
	z.position = Data.vec3(d.get("origin", [0, 0, 0]))
	var h := float(d.get("height", 3.5))
	var vis_root := Node3D.new()
	vis_root.name = "Geometry"
	z.add_child(vis_root)
	var tint := Graybox.color(d.get("tint", "wall"))
	var floor_c := Graybox.color(d.get("floor_color", "floor"))
	# floor
	if d.get("floor", true):
		Graybox.solid(vis_root, "Floor", Vector3(z.size.x / 2, -0.1, z.size.y / 2),
			Vector3(z.size.x, 0.2, z.size.y), floor_c)
	# perimeter walls (front S wall is invisible by default: cutaway towards the camera)
	var walls: Dictionary = d.get("walls", {})
	var skip: Array = walls.get("skip", [])
	var wall_c := Graybox.color("wall")
	if not skip.has("N"):
		Graybox.solid(vis_root, "WallN", Vector3(z.size.x / 2, h / 2, -WALL_T / 2), Vector3(z.size.x + WALL_T * 2, h, WALL_T), tint)
	if not skip.has("W"):
		Graybox.solid(vis_root, "WallW", Vector3(-WALL_T / 2, h / 2, z.size.y / 2), Vector3(WALL_T, h, z.size.y), wall_c)
	if not skip.has("E"):
		Graybox.solid(vis_root, "WallE", Vector3(z.size.x + WALL_T / 2, h / 2, z.size.y / 2), Vector3(WALL_T, h, z.size.y), wall_c)
	if not skip.has("S"):
		var front := Graybox.solid(vis_root, "WallS", Vector3(z.size.x / 2, h / 2, z.size.y + WALL_T / 2),
			Vector3(z.size.x + WALL_T * 2, h, WALL_T), wall_c)
		if not walls.get("front_visible", false):
			front.get_node("Visual").visible = false
	# boxes
	for b in d.get("boxes", []):
		_box(vis_root, b)
	for r in d.get("ramps", []):
		_ramp(vis_root, r)
	# labels (signage)
	for l in d.get("labels", []):
		var lab := Graybox.label3d(String(l.t), int(l.get("s", 40)), Graybox.color(l.get("c", [0.9, 0.85, 0.7])))
		lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED if l.get("flat", true) else BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = false
		lab.position = Data.vec3(l.p)
		vis_root.add_child(lab)
	# doors
	for dd in d.get("doors", []):
		_door(z, dd, h)
	# rigs + camzones
	z.rigs = d.get("rigs", {}).duplicate(true)
	if not z.rigs.has("main"):
		z.rigs["main"] = default_rig(z.size, String(d.get("mode", "ROOM")))
	for cz in d.get("camzones", []):
		var p := Data.vec3(cz.p)
		var sz: Array = cz.s
		z.camzones.append({"rig": String(cz.rig), "rect": Rect2(p.x, p.z, float(sz[0]), float(sz[1])),
			"y": cz.get("y", [-100, 100])})
	# lights
	z.lights_root = Node3D.new()
	z.lights_root.name = "Lights"
	z.add_child(z.lights_root)
	var lights: Array = d.get("lights", [])
	if lights.is_empty():
		lights = [{"p": [z.size.x / 2, h - 0.4, z.size.y / 2], "c": [1, 0.9, 0.75], "e": 1.0, "r": maxf(z.size.x, z.size.y)}]
	for l in lights:
		var o := OmniLight3D.new()
		o.position = Data.vec3(l.p)
		o.light_color = Graybox.color(l.get("c", [1, 0.9, 0.75]))
		o.light_energy = float(l.get("e", 1.0))
		o.omni_range = float(l.get("r", 8.0))
		o.omni_attenuation = 1.2
		o.shadow_enabled = false
		z.lights_root.add_child(o)
	if d.get("rain", false):
		_rain(z, h)
	return z


static func default_rig(size: Vector2, mode: String) -> Dictionary:
	if mode == "CORRIDOR":
		return {"type": "follow", "offset": [0, 3.2, 8.5], "look": [0, 1.0, 0], "fov": 50,
			"clamp_x": [2.5, maxf(2.5, size.x - 2.5)]}
	return {"type": "follow", "offset": [0, 7.5, 8.5], "look": [0, 0.8, -0.5], "fov": 52,
		"clamp_x": [minf(4.0, size.x / 2), maxf(size.x / 2, size.x - 4.0)]}


static func _box(parent: Node3D, b: Dictionary) -> void:
	var sz := Data.vec3(b.s)
	var p := Data.vec3(b.p)
	var y_given: bool = (b.p as Array).size() >= 3
	var center := Vector3(p.x, (p.y if y_given else 0.0) + sz.y / 2.0, p.z)
	var k := String(b.get("k", "furn"))
	var c: Color = Graybox.color(b.get("c", KIND_COLOR.get(k, "furn")))
	var layer := Graybox.LAYER_WORLD
	if b.get("slide", false):
		layer = Graybox.LAYER_SLIDE
	var node := Graybox.solid(parent, String(b.get("id", k)), center, sz, c, layer, not b.get("nocol", false))
	if b.has("rot"):
		node.rotation_degrees.y = float(b.rot)
	if k == "vault" or b.get("vault", false):
		node.add_to_group("vaultables")
		node.set_meta("box_size", sz)
		var stripe := Graybox.box_mesh(Vector3(sz.x + 0.02, 0.04, sz.z + 0.02), Graybox.color("stripe"))
		stripe.position = Vector3(0, sz.y / 2 + 0.01, 0)
		node.get_node("Visual").add_child(stripe)
	if k == "cover" or b.get("cover", false):
		node.add_to_group("cover")
	if k == "glass":
		node.add_to_group("glass")
	if b.has("emit"):
		var mi: MeshInstance3D = node.get_node("Visual").get_child(0)
		mi.material_override = Graybox.mat(c, float(b.emit))
	if b.has("group"):
		node.add_to_group(String(b.group))
	node.set_meta("def", b)


static func _ramp(parent: Node3D, r: Dictionary) -> void:
	var a := Data.vec3(r.from)
	var b := Data.vec3(r.to)
	var w := float(r.get("w", 1.4))
	var horiz := Vector2(b.x - a.x, b.z - a.z)
	var length := sqrt(horiz.length_squared() + pow(b.y - a.y, 2))
	var body := StaticBody3D.new()
	body.name = String(r.get("id", "Ramp"))
	body.collision_layer = Graybox.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, 0.2, length)
	cs.shape = sh
	body.add_child(cs)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.add_child(Graybox.box_mesh(Vector3(w, 0.2, length), Graybox.color(r.get("c", [0.3, 0.3, 0.32]))))
	body.add_child(vis)
	parent.add_child(body)
	body.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) / 2.0 - Vector3(0, 0.1, 0))


static func _door(z: Zone, dd: Dictionary, h: float) -> void:
	var p := Data.vec3(dd.p)
	var side := String(dd.get("side", "N"))
	var n := Vector3.BACK
	match side:
		"N": n = Vector3(0, 0, 1)
		"S": n = Vector3(0, 0, -1)
		"W": n = Vector3(1, 0, 0)
		"E": n = Vector3(-1, 0, 0)
		"F": n = Vector3(0, 0, 1)   # free-standing (in-room) doorway, faces camera-back
	var door := Doorway.new()
	door.name = "Door_" + String(dd.id)
	door.position = p
	door.setup(dd, z.zone_id, n)
	z.add_child(door)
	z.doors[String(dd.id)] = door
	var kind := String(dd.get("kind", "door"))
	var vis := Node3D.new()
	vis.name = "Visual"
	door.add_child(vis)
	var dw := float(dd.get("w", 1.2))
	var dh := minf(2.3, h - 0.1)
	var along := Vector3(1, 0, 0) if side in ["N", "S", "F"] else Vector3(0, 0, 1)
	if kind != "hidden":
		var panel_c := Graybox.color("dark") if kind in ["arch"] else Graybox.color(dd.get("c", "door"))
		var panel := Graybox.box_mesh(Vector3(dw, dh, 0.08) if along.x > 0 else Vector3(0.08, dh, dw), panel_c)
		panel.position = Vector3(0, dh / 2, 0) - n * 0.12
		vis.add_child(panel)
		# orange trim = interactive
		var trim_c := Graybox.color("trim")
		for sgn in [-1.0, 1.0]:
			var post := Graybox.box_mesh(Vector3(0.08, dh, 0.08), trim_c)
			post.position = along * (dw / 2 + 0.04) * sgn + Vector3(0, dh / 2, 0) - n * 0.1
			vis.add_child(post)
		var top := Graybox.box_mesh((along * (dw + 0.16)) + Vector3(0, 0.08, 0) + (Vector3(0, 0, 0.08) if along.x > 0 else Vector3(0.08, 0, 0)), trim_c)
		top.position = Vector3(0, dh + 0.04, 0) - n * 0.1
		vis.add_child(top)
		if dd.has("label"):
			var lab := Graybox.label3d(String(dd.label), 34, Color(1, 0.85, 0.6))
			lab.position = Vector3(0, dh + 0.35, 0) + n * 0.1
			lab.no_depth_test = false
			vis.add_child(lab)


static func _rain(z: Zone, h: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Rain"
	p.amount = int(clampf(z.size.x * z.size.y * 1.6, 200, 900))
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(z.size.x / 2, 0.2, z.size.y / 2)
	p.position = Vector3(z.size.x / 2, h + 3.0, z.size.y / 2)
	p.direction = Vector3(0.08, -1, 0)
	p.spread = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 12.0
	var m := BoxMesh.new()
	m.size = Vector3(0.012, 0.35, 0.012)
	p.mesh = m
	p.material_override = Graybox.mat(Color(0.7, 0.8, 0.95, 0.35), 0.4, true)
	p.local_coords = true
	z.add_child(p)
