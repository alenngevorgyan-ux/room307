class_name VesperDress
extends RefCounted
## THE VESPER — environment dressing (Visual Integration V1.5). Purely visual, no collision:
## it only decorates existing collision boxes, walls, ceilings and the camera-side foreground
## (beyond the cutaway wall, where the hero can never walk), so it can never block a path or
## invite the player to walk into something that is not there. Replaceable by final art.

static func apply(world: Node) -> void:
	for zid in world.zones:
		var z: Zone = world.zones[zid]
		var w := VesperLook.wing(zid)
		if not VesperLook.ZONES.has(zid):
			continue
		_walls(z, w)
		var geo: Node = z.get_node_or_null("Geometry")
		if geo:
			for n in geo.get_children():
				if n is Label3D:
					_plaque(n as Label3D, w)
				elif n.has_meta("def"):
					_decorate(z, n, w)
		for did in z.doors:
			_door_sign(z.doors[did], w)
		_foreground(z, w)


# ================================================================== helpers

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, sides: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func lamp_light(parent: Node3D, pos: Vector3, c: Color, energy: float, rng: float, group := "vesper_practical") -> void:
	var l := OmniLight3D.new()
	l.set_meta("base_energy", energy)
	l.add_to_group(group)
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	parent.add_child(l)


static func look_root(z: Zone) -> Node3D:
	return VesperLook._look_root(z)


static func mat(n: String) -> Material:
	return VesperLook.material(n)


## A warm table lamp: brass stem, cream shade glowing, a small pool of light.
static func table_lamp(parent: Node3D, top: Vector3, light := true) -> void:
	cyl(parent, 0.05, 0.08, 0.04, top + Vector3(0, 0.02, 0), mat("brass"))
	cyl(parent, 0.012, 0.012, 0.32, top + Vector3(0, 0.18, 0), mat("brass"), 8)
	cyl(parent, 0.09, 0.15, 0.18, top + Vector3(0, 0.38, 0), VesperLook.emissive(Color(0.95, 0.78, 0.52), 2.2))
	if light:
		lamp_light(parent, top + Vector3(0, 0.45, 0), Color(1.0, 0.7, 0.42), 0.7, 2.6)


static func plant(parent: Node3D, base: Vector3, h: float) -> void:
	var leaf := VesperLook.material("smoked_green", Color(0.16, 0.24, 0.17))
	for i in 7:
		var a := i * 2.4
		var r := 0.12 + 0.05 * (i % 3)
		var mi := sphere(parent, 0.22, 0.1, base + Vector3(cos(a) * r, h * (0.45 + 0.08 * (i % 4)), sin(a) * r), leaf)
		mi.rotation = Vector3(0.5 * sin(a), a, 0.4 * cos(a))
		mi.scale = Vector3(1.0, 1.0, 2.2)


# ================================================================== walls

## Wainscot / dado / service paint band / pipes along the N, W and E walls, skipping doorways.
static func _walls(z: Zone, w: String) -> void:
	var trim := String(VesperLook.ZONES[z.zone_id].get("trim", ""))
	if trim == "" or String(z.def.get("mode", "")) == "VERTICAL":
		return
	var root := look_root(z)
	var skip: Array = z.def.get("walls", {}).get("skip", [])
	var h_panel := 1.1 if w == "PUBLIC" else 0.9 if w == "GUEST" else 1.2
	var runs: Array = []   # [side, from, to]
	if not skip.has("N"):
		runs.append(["N", 0.0, z.size.x])
	if not skip.has("W"):
		runs.append(["W", 0.0, z.size.y])
	if not skip.has("E"):
		runs.append(["E", 0.0, z.size.y])
	for r in runs:
		var side: String = r[0]
		for seg in _free_segments(z, side, float(r[1]), float(r[2])):
			var a: float = seg.x
			var b: float = seg.y
			if b - a < 0.25:
				continue
			var mid := (a + b) / 2.0
			var len := b - a
			var t := 0.04
			var p: Vector3
			var sz: Vector3
			match side:
				"N":
					p = Vector3(mid, 0, t / 2.0)
					sz = Vector3(len, 0, t)
				"W":
					p = Vector3(t / 2.0, 0, mid)
					sz = Vector3(t, 0, len)
				"E":
					p = Vector3(z.size.x - t / 2.0, 0, mid)
					sz = Vector3(t, 0, len)
			if w == "SERVICE":
				box(root, Vector3(sz.x, h_panel, sz.z), p + Vector3(0, h_panel / 2.0, 0), mat("service_band"))
				# visible infrastructure: two pipes along the top of the back wall
				if side == "N":
					var hh := float(z.def.get("height", 3.0))
					var pipe := mat("steel")
					for k in 2:
						var c := cyl(root, 0.05 + 0.02 * k, 0.05 + 0.02 * k, len, Vector3(mid, hh - 0.25 - 0.18 * k, 0.12 + 0.12 * k), pipe, 10)
						c.rotation_degrees = Vector3(0, 0, 90)
				continue
			var panel_mat := mat(trim)
			box(root, Vector3(sz.x, h_panel, sz.z), p + Vector3(0, h_panel / 2.0, 0), panel_mat)
			# rail on top of the panel, skirting at the floor
			var rail := mat("brass") if w == "PUBLIC" else mat("guest_dado")
			var grow := Vector3(0.03 if side != "N" else 0.0, 0, 0.03 if side == "N" else 0.0)
			box(root, Vector3(sz.x, 0.05, sz.z) + grow, p + Vector3(0, h_panel + 0.025, 0), rail)
			box(root, Vector3(sz.x, 0.12, sz.z) + grow, p + Vector3(0, 0.06, 0), mat("dark"))


## Wall stretches not covered by a doorway on that side.
static func _free_segments(z: Zone, side: String, a: float, b: float) -> Array:
	var holes: Array = []
	for did in z.doors:
		var d: Doorway = z.doors[did]
		if String(d.def.get("side", "N")) != side:
			continue
		var c := d.position.x if side == "N" else d.position.z
		var hw := float(d.def.get("w", 1.2)) / 2.0 + 0.15
		holes.append(Vector2(c - hw, c + hw))
	holes.sort_custom(func(p, q): return p.x < q.x)
	var out: Array = []
	var cur := a
	for hole in holes:
		if hole.x > cur:
			out.append(Vector2(cur, minf(hole.x, b)))
		cur = maxf(cur, hole.y)
	if cur < b:
		out.append(Vector2(cur, b))
	return out


# ================================================================== signage

## Floating world text becomes a physical plaque: cream lettering on a dark plate, lit like the
## wall it hangs on (depth-tested, no outline, no billboard).
static func _plaque(l: Label3D, w: String) -> void:
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.outline_size = 0
	if l.text == "THE VESPER":
		# the hotel's name: wide brass letters, faintly lit — the one logotype in the building
		l.font_size = 96
		l.modulate = Color(1.0, 0.8, 0.48)
		l.shaded = false
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.spacing_glyph = 14
		l.font = f
		return
	l.shaded = true
	l.modulate = Color(0.93, 0.85, 0.66) if w != "SERVICE" else Color(0.86, 0.9, 0.86)
	var chars := maxf(2.0, float(l.text.length()))
	var wdt := chars * float(l.font_size) * l.pixel_size * 0.62 + 0.18
	var hgt := float(l.font_size) * l.pixel_size * 1.5 + 0.08
	var plate := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(wdt, hgt)
	plate.mesh = q
	plate.material_override = mat("dark") if w != "SERVICE" else mat("service_band")
	plate.position = Vector3(0, 0, -0.01)
	l.add_child(plate)


## Door labels: a small plaque over the door (wall doors) or a floor inlay at the threshold
## (camera-side exits) instead of floating text.
static func _door_sign(d: Doorway, w: String) -> void:
	var vis: Node = d.get_node_or_null("Visual")
	if vis == null:
		return
	for c in vis.get_children():
		if c is Label3D:
			var l := c as Label3D
			_plaque(l, w)
			l.font_size = 28
			if String(d.def.get("side", "N")) == "S":
				l.rotation_degrees = Vector3(-90, 0, 0)
				l.position = Vector3(0, 0.03, -0.45)
			else:
				# face into the room
				var n: Vector3 = d.normal
				l.rotation.y = atan2(n.x, n.z)
				l.position = Vector3(0, minf(2.55, float(d.def.get("h", 2.3)) + 0.25), 0) + n * 0.06


# ================================================================== decorators (existing boxes)

static func _decorate(z: Zone, n: Node3D, w: String) -> void:
	var def: Dictionary = n.get_meta("def")
	var id := String(def.get("id", ""))
	var k := String(def.get("k", ""))
	var s := Data.vec3(def.s)
	var vis: Node3D = n.get_node_or_null("Visual")
	if vis == null:
		return
	var top := Vector3(0, s.y / 2.0, 0)
	var zid := z.zone_id
	if k == "glass" and not id.contains("jet") and s.y > 0.5:
		_window(z, n, s, w)
		return
	match id:
		"counter":
			if zid == "BAR":
				box(vis, Vector3(s.x + 0.1, 0.06, s.z + 0.12), top + Vector3(0, 0.03, 0), mat("marble_green"))
				var rail := cyl(vis, 0.025, 0.025, s.x, Vector3(0, -s.y / 2.0 + 0.22, s.z / 2.0 + 0.18), mat("brass"), 8)
				rail.rotation_degrees = Vector3(0, 0, 90)
				box(vis, Vector3(s.x, 0.04, 0.04), Vector3(0, -s.y / 2.0 + 0.04, s.z / 2.0 + 0.01), mat("brass"))
		"back_bar":
			box(vis, Vector3(s.x, 0.04, s.z + 0.04), top + Vector3(0, 0.02, 0), mat("marble_green"))
		"bottles":
			_bottle_wall(z, n, vis, s)
		"reception":
			box(vis, Vector3(s.x + 0.1, 0.06, s.z + 0.1), top + Vector3(0, 0.03, 0), mat("marble_green"))
			box(vis, Vector3(s.x, 0.08, 0.04), Vector3(0, -s.y / 2.0 + 0.3, s.z / 2.0 + 0.02), mat("brass"))
			table_lamp(vis, top + Vector3(-s.x / 2.0 + 0.5, 0.06, 0))
			sphere(vis, 0.06, 0.06, top + Vector3(0.6, 0.08, 0.2), mat("brass"))   # desk bell
		"booth_1", "booth_2", "booth_3":
			box(vis, Vector3(s.x - 0.1, 0.12, s.z * 0.7), Vector3(0, -s.y / 2.0 + 0.5, 0.05), mat("oxblood"))
			box(vis, Vector3(s.x, 0.5, 0.18), Vector3(0, s.y / 2.0 - 0.25, -s.z / 2.0 + 0.09), mat("oxblood"))
		"booth_table", "guest_table", "four_top", "gala_table", "low_table", "table":
			if k == "vault" or s.y > 0.6:
				table_lamp(vis, top, zid != "RESTAURANT")
		"stool_1", "stool_2", "stool_3", "stool_4", "stool_5", "stool_6":
			vis.get_child(0).visible = false
			cyl(vis, 0.2, 0.2, 0.08, top - Vector3(0, 0.04, 0), mat("oxblood"))
			cyl(vis, 0.03, 0.03, s.y - 0.1, Vector3(0, 0, 0), mat("brass"), 8)
			cyl(vis, 0.18, 0.2, 0.03, Vector3(0, -s.y / 2.0 + 0.015, 0), mat("brass"))
			cyl(vis, 0.15, 0.15, 0.02, Vector3(0, -s.y / 2.0 + 0.3, 0), mat("brass"))   # foot ring
		"armchair_1", "armchair_2", "sofa", "armchair_below":
			box(vis, Vector3(s.x, s.y * 0.55, 0.2), Vector3(0, s.y * 0.2, -s.z / 2.0 + 0.1), mat("oxblood"))
		"planter":
			plant(vis, top, 1.4)
		"fountain":
			cyl(vis, s.x / 2.0, s.x / 2.0 + 0.05, 0.08, top + Vector3(0, 0.04, 0), mat("marble_cream"), 24)
		"pillar_1", "pillar_2", "pillar_3":
			box(vis, Vector3(s.x + 0.14, 0.3, s.z + 0.14), Vector3(0, -s.y / 2.0 + 0.15, 0), mat("walnut"))
			box(vis, Vector3(s.x + 0.1, 0.08, s.z + 0.1), Vector3(0, -s.y / 2.0 + 0.32, 0), mat("brass"))
		"bed":
			box(vis, Vector3(s.x - 0.04, 0.16, s.z - 0.1), top + Vector3(0, 0.08, 0.05), mat("linen"))
			box(vis, Vector3(s.x - 0.1, 0.06, s.z * 0.45), top + Vector3(0, 0.19, s.z * 0.22), VesperLook.material("object", Color(0.45, 0.3, 0.3)))
			for sx in [-0.45, 0.45]:
				box(vis, Vector3(0.62, 0.12, 0.34), top + Vector3(sx * (s.x / 2.0) * 0.9, 0.22, -s.z / 2.0 + 0.3), mat("linen"))
		"nightstand":
			table_lamp(vis, top)
		"desk":
			if zid in ["ROOM_307", "ROOM_308"]:
				table_lamp(vis, top + Vector3(0, 0, -s.z / 2.0 + 0.25))
			elif zid == "SECURITY":
				box(vis, Vector3(0.5, 0.03, 0.2), top + Vector3(0.6, 0.02, 0.1), mat("dark"))
		"wardrobe", "locker", "lockers_1", "lockers_2":
			var doors := maxi(1, int(round(s.x / 0.45)))
			for i in doors:
				var x := -s.x / 2.0 + (i + 0.5) * s.x / doors
				box(vis, Vector3(0.02, s.y * 0.92, 0.02), Vector3(x + s.x / doors / 2.0 - 0.01, 0, s.z / 2.0 + 0.005), mat("dark"))
				box(vis, Vector3(0.03, 0.12, 0.03), Vector3(x + s.x / doors / 2.0 - 0.06, 0.1, s.z / 2.0 + 0.02), mat("brass" if w != "SERVICE" else "steel"))
		"machines_bg", "machines_bg_2", "machines_fg", "machines_fg2":
			var count := maxi(1, int(s.x / 1.0))
			for i in count:
				var x := -s.x / 2.0 + (i + 0.5) * s.x / count
				var face := 1.0 if id.begins_with("machines_bg") else -1.0
				var drum := cyl(vis, 0.3, 0.3, 0.04, Vector3(x, 0.05, face * (s.z / 2.0 + 0.02)), VesperLook.material("night_glass"), 20)
				drum.rotation_degrees = Vector3(90, 0, 0)
				var rim := cyl(vis, 0.34, 0.34, 0.02, Vector3(x, 0.05, face * (s.z / 2.0 + 0.005)), mat("steel"), 20)
				rim.rotation_degrees = Vector3(90, 0, 0)
		"stove_line":
			for i in 6:
				cyl(vis, 0.13, 0.13, 0.02, top + Vector3(-s.x / 2.0 + 0.75 + i * 1.5, 0.01, 0), mat("dark"), 14)
		"hood":
			for i in 3:
				lamp_light(vis, Vector3(-s.x / 3.0 + i * s.x / 3.0, -0.5, 0), Color(1.0, 0.55, 0.25), 0.8, 2.4)
				box(vis, Vector3(0.5, 0.04, 0.3), Vector3(-s.x / 3.0 + i * s.x / 3.0, -s.y / 2.0 - 0.02, 0), VesperLook.emissive(Color(1.0, 0.5, 0.2), 2.5))
		"pot_rack":
			for i in 4:
				var pan := cyl(vis, 0.16, 0.13, 0.08, Vector3(-0.55 + i * 0.37, s.y / 2.0 - 0.45 - 0.08 * (i % 2), 0.12), mat("steel"), 14)
				pan.rotation_degrees = Vector3(90, 0, 0)
		"bottle_shelf":
			_bottle_rows(vis, s, 3)
		"shelf_1", "shelf_2":
			for i in 3:
				box(vis, Vector3(s.x * 0.9, 0.25, s.z * 0.7), Vector3(0, -s.y / 2.0 + 0.35 + i * 0.6, 0), mat("crate"))
		"crate_stack", "crates", "pallets":
			box(vis, Vector3(s.x + 0.01, 0.04, s.z + 0.01), Vector3(0, s.y * 0.1, 0), mat("dark"))
		"cart_1", "cart_2":
			box(vis, Vector3(s.x * 0.9, 0.35, s.z * 0.8), top + Vector3(0, 0.17, 0), mat("linen"))
		"hvac_1", "hvac_2":
			cyl(vis, s.z * 0.35, s.z * 0.35, 0.05, top + Vector3(0, 0.03, 0), mat("dark"), 20)   # fan
			for i in 5:
				box(vis, Vector3(0.02, s.y * 0.7, s.z * 0.95), Vector3(-s.x / 2.0 + 0.25 + i * (s.x - 0.5) / 4.0, 0, 0), mat("dark"))
		"volvo":
			box(vis, Vector3(0.1, 0.18, 0.5), Vector3(-s.x / 2.0 - 0.02, 0.15, 0.55), VesperLook.emissive(Color(0.9, 0.12, 0.08), 1.6))
			box(vis, Vector3(0.1, 0.18, 0.5), Vector3(-s.x / 2.0 - 0.02, 0.15, -0.55), VesperLook.emissive(Color(0.9, 0.12, 0.08), 1.6))
			for wx in [-1.3, 1.3]:
				for wz in [-1.0, 1.0]:
					var wheel := cyl(vis, 0.33, 0.33, 0.22, Vector3(wx, -s.y / 2.0 + 0.2, wz * (s.z / 2.0)), mat("dark"), 16)
					wheel.rotation_degrees = Vector3(90, 0, 0)
		"monitor_wall":
			for i in 3:
				for j in 2:
					box(vis, Vector3(1.3, 0.62, 0.02), Vector3(-1.5 + i * 1.5, -0.38 + j * 0.76, s.z / 2.0 + 0.01), VesperLook.emissive(Color(0.16, 0.24, 0.24), 0.45))
			lamp_light(vis, Vector3(0, 0, 0.8), Color(0.55, 0.75, 0.8), 0.6, 3.5)
		"ice_machine":
			box(vis, Vector3(s.x * 0.8, 0.3, 0.02), Vector3(0, 0.2, s.z / 2.0 + 0.01), VesperLook.emissive(Color(0.6, 0.8, 0.85), 0.6))
		"stage":
			box(vis, Vector3(s.x + 0.06, 0.06, s.z + 0.06), top + Vector3(0, 0.03, 0), mat("timber_floor"))
		"t1", "t2", "t3", "t4", "t5", "t6":
			cyl(vis, s.x / 2.0 + 0.1, s.x / 2.0 + 0.15, s.y * 0.95, Vector3(0, -0.02, 0), mat("linen"), 24)
			cyl(vis, 0.08, 0.1, 0.25, top + Vector3(0, 0.12, 0), mat("brass"), 10)
			vis.get_child(0).visible = false
			vis.get_child(1).visible = false   # the cloth's edge is the vault cue now
		"chair_stack_1", "chair_stack_2", "stacked_1", "stacked_2":
			for i in 4:
				box(vis, Vector3(s.x * 0.95, 0.04, s.z * 0.95), Vector3(0, -s.y / 2.0 + 0.2 + i * s.y / 4.5, 0), mat("dark"))
		"headboard":
			box(vis, Vector3(s.x + 0.1, 0.06, s.z + 0.06), top + Vector3(0, 0.03, 0), mat("brass"))


## Bar back: rows of bottles with a soft amber back-glow (the bar's warm heart).
static func _bottle_wall(z: Zone, n: Node3D, vis: Node3D, s: Vector3) -> void:
	vis.get_child(0).visible = false
	_bottle_rows(vis, Vector3(s.x, 1.6, s.z), 3)
	# backlit shelf: warm and bright at the counter, falling off toward the ceiling (no flat slab)
	for b in 3:
		box(vis, Vector3(s.x, 0.5, 0.02), Vector3(0, 0.25 + b * 0.5, -s.z / 2.0 - 0.02), VesperLook.emissive(Color(0.82, 0.55, 0.32), [0.42, 0.22, 0.09][b]))
	lamp_light(vis, Vector3(0, 0.9, 0.4), Color(1.0, 0.62, 0.3), 1.0, 4.0)


static func _bottle_rows(vis: Node3D, s: Vector3, rows: int) -> void:
	var cols := [Color(0.35, 0.18, 0.08), Color(0.12, 0.25, 0.14), Color(0.55, 0.42, 0.2), Color(0.3, 0.08, 0.08), Color(0.6, 0.6, 0.5)]
	for r in rows:
		var y := -s.y / 2.0 + 0.12 + r * (s.y / rows)
		box(vis, Vector3(s.x, 0.03, s.z + 0.08), Vector3(0, y - 0.02, 0), mat("walnut"))
		var count := int(s.x / 0.16)
		for i in count:
			var hgt := 0.22 + 0.08 * ((i * 7 + r * 3) % 3)
			var c: Color = cols[(i * 3 + r) % cols.size()]
			cyl(vis, 0.035, 0.045, hgt, Vector3(-s.x / 2.0 + 0.08 + i * 0.16, y + hgt / 2.0, 0), VesperLook.material("object", c), 8)


## Windows: mullions, a cool night glow and cool exterior spill into the room.
static func _window(z: Zone, n: Node3D, s: Vector3, w: String) -> void:
	var vis: Node3D = n.get_node("Visual")
	var p := n.position
	var on_wall := p.z < 0.6 or p.x < 0.6 or p.x > z.size.x - 0.6 or p.z > z.size.y - 0.6
	if on_wall:
		n.remove_meta("occluder")   # a window in a wall never stands between camera and hero
	if on_wall:   # free-standing tall glass (the revolving door) keeps its fadeable material
		# rain on the glass, passing headlights, the sky moving toward morning (VesperTime)
		(vis.get_child(0) as MeshInstance3D).material_override = VesperTime.window_material()
	var horiz := s.x >= s.z
	var len := s.x if horiz else s.z
	var frame := mat("walnut") if w == "PUBLIC" else mat("guest_dado") if w == "GUEST" else mat("steel")
	var panes := maxi(1, int(round(len / 1.1)))
	for i in panes + 1:
		var o := -len / 2.0 + i * len / panes
		box(vis, Vector3(0.05, s.y + 0.06, 0.08) if horiz else Vector3(0.08, s.y + 0.06, 0.05), Vector3(o, 0, 0) if horiz else Vector3(0, 0, o), frame)
	for y in [-s.y / 2.0, s.y / 2.0]:
		box(vis, Vector3(len + 0.1, 0.07, 0.1) if horiz else Vector3(0.1, 0.07, len + 0.1), Vector3(0, y, 0), frame)
	# the cool 6500 K spill that pairs with the warm practicals (warm / cool split)
	var into := Vector3(0, 0, 0.9) if horiz else (Vector3(0.9, 0, 0) if n.position.x < z.size.x / 2.0 else Vector3(-0.9, 0, 0))
	if horiz and n.position.z > z.size.y / 2.0:
		into = Vector3(0, 0, -0.9)
	lamp_light(vis, into, Color(0.55, 0.68, 0.9), 0.6 + 0.12 * len, maxf(3.0, len * 0.9), "vesper_window_light")


# ================================================================== foreground layer

## Dark silhouettes beyond the camera-side cutaway: the first of the three depth layers. They
## sit outside the room (unreachable) and pass in front of the follow camera with parallax.
static func _foreground(z: Zone, w: String) -> void:
	if String(z.def.get("mode", "")) != "ROOM" or z.size.x < 8.0:
		return
	var root := look_root(z)
	var fg := VesperLook.material("dark", Color(0.035, 0.032, 0.03))
	var y0 := z.size.y + 0.9
	var step := 6.5
	var x := 2.0 + fmod(float(z.zone_id.hash() % 7), 3.0)
	while x < z.size.x - 1.0:
		match w:
			"PUBLIC":
				# the back of a club chair / a lamp shade, low in frame
				box(root, Vector3(0.9, 0.9, 0.5), Vector3(x, 0.45, y0), fg)
				box(root, Vector3(0.9, 0.35, 0.18), Vector3(x, 1.05, y0 + 0.16), fg)
			"SERVICE":
				box(root, Vector3(1.4, 1.2, 0.5), Vector3(x, 0.6, y0), fg)   # shelving / trolley
			"GUEST":
				box(root, Vector3(0.5, 1.6, 0.3), Vector3(x, 0.8, y0), fg)   # door edge / wardrobe
			"EXTERIOR":
				cyl(root, 0.12, 0.12, 1.1, Vector3(x, 0.55, y0), fg, 10)     # bollard
		x += step
