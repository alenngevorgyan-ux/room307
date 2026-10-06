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
		VesperLook.art_zone = zid   # final material profiles apply inside VesperArt rollout zones
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
		if zid == "BAR" and VesperArt.zone_on(zid):
			_bar_backdrop(z)
		if zid == "ROOM_307" and VesperArt.zone_on(zid):
			_r307_room(z, world)
	VesperLook.art_zone = ""


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
static func table_lamp(parent: Node3D, top: Vector3, light := true, glow := 2.2, size := 1.0) -> void:
	cyl(parent, 0.05 * size, 0.08 * size, 0.04, top + Vector3(0, 0.02, 0), mat("brass"))
	cyl(parent, 0.012, 0.012, 0.32 * size, top + Vector3(0, 0.18 * size, 0), mat("brass"), 8)
	cyl(parent, 0.09 * size, 0.15 * size, 0.18 * size, top + Vector3(0, 0.38 * size, 0), VesperLook.emissive(Color(0.95, 0.78, 0.52), glow))
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
	if zid == "BAR" and VesperArt.zone_on(zid) and _bar_kit(n, vis, id, s, top):
		return
	if zid == "ROOM_307" and VesperArt.zone_on(zid) and _r307_kit(n, vis, id, s, top):
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
	# above and behind the shelf: backlights the bottles, never sits where Nico's head and hands go
	lamp_light(vis, Vector3(0, 1.7, -0.15), Color(1.0, 0.62, 0.3), 1.2, 4.0)


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
	if z.zone_id == "ROOM_307" and VesperArt.zone_on("ROOM_307") and on_wall:
		box(vis, Vector3(len + 0.24, 0.045, 0.24), Vector3(0, -s.y / 2.0 - 0.03, 0.12), mat("walnut"))   # sill
		rain_light(z, Vector3(n.position.x, 0.006, n.position.z + 1.35), Vector2(len + 0.2, 2.4))
	# the cool 6500 K spill that pairs with the warm practicals (warm / cool split)
	var into := Vector3(0, 0, 0.9) if horiz else (Vector3(0.9, 0, 0) if n.position.x < z.size.x / 2.0 else Vector3(-0.9, 0, 0))
	if horiz and n.position.z > z.size.y / 2.0:
		into = Vector3(0, 0, -0.9)
	# final language (BAR): only the middle pane keeps its cool spill; the two side spills light the
	# hidden back-bar corner and their light slots go to the warm downlights over the guest floor
	if z.zone_id == "BAR" and VesperArt.zone_on("BAR") and String(n.get_meta("def").get("id", "")) != "window_m":
		return
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
			"PUBLIC" when VesperArt.zone_on(z.zone_id):
				# final language: a club chair seen from behind (rounded back, arms), deep oxblood
				var chair := VesperLook.material("dark", Color(0.075, 0.04, 0.038))
				box(root, Vector3(0.92, 0.42, 0.62), Vector3(x, 0.21, y0), chair)
				var back := cyl(root, 0.3, 0.3, 0.92, Vector3(x, 0.6, y0 + 0.2), chair, 16)
				back.rotation_degrees = Vector3(0, 0, 90)
				for ax in [-0.42, 0.42]:
					var arm := cyl(root, 0.1, 0.1, 0.62, Vector3(x + ax, 0.5, y0), chair, 10)
					arm.rotation_degrees = Vector3(90, 0, 0)
			"PUBLIC":
				# the back of a club chair / a lamp shade, low in frame
				box(root, Vector3(0.9, 0.9, 0.5), Vector3(x, 0.45, y0), fg)
				box(root, Vector3(0.9, 0.35, 0.18), Vector3(x, 1.05, y0 + 0.16), fg)
			"SERVICE":
				box(root, Vector3(1.4, 0.7, 0.5), Vector3(x, 0.35, y0), fg)   # trolley edge (low: the camera is lower now)
			"GUEST" when VesperArt.zone_on(z.zone_id):
				# final language: a reading chair seen from behind, same family as the BAR chairs
				var chair_g := VesperLook.material("dark", Color(0.07, 0.045, 0.04))
				box(root, Vector3(0.78, 0.4, 0.56), Vector3(x, 0.2, y0), chair_g)
				var back_g := cyl(root, 0.26, 0.26, 0.78, Vector3(x, 0.56, y0 + 0.18), chair_g, 16)
				back_g.rotation_degrees = Vector3(0, 0, 90)
			"GUEST":
				box(root, Vector3(0.5, 1.6, 0.3), Vector3(x, 0.8, y0), fg)   # door edge / wardrobe
			"EXTERIOR":
				cyl(root, 0.12, 0.12, 1.1, Vector3(x, 0.55, y0), fg, 10)     # bollard
		x += step


# ================================================================== FINAL VISUAL LANGUAGE V1 — BAR hero kit
# Visual meshes only, inside each prop's original footprint: collision bodies, nav, markers and the
# occluder contract are untouched (none of these props is tall enough to be a camera occluder).

static var _contact_mat: StandardMaterial3D = null
static var _bottle_mesh: Mesh = null
static var _bottle_mat: ShaderMaterial = null


## Soft contact shadow: a flat radial card on the floor (no Decal, no physics).
static func contact(parent: Node3D, size: Vector2, pos: Vector3, alpha := 0.45) -> MeshInstance3D:
	if _contact_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.45, Color(0, 0, 0, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_contact_mat = StandardMaterial3D.new()
		_contact_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_contact_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_contact_mat.albedo_texture = t
		_contact_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_contact_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _contact_mat
	mi.transparency = 1.0 - alpha
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static var _glint_mat: StandardMaterial3D = null


## A blurred warm reflection card on the floor (additive, unshaded): suggests a polished surface.
static func glint(parent: Node3D, size: Vector2, pos: Vector3, c: Color, strength: float) -> MeshInstance3D:
	if _glint_mat == null:
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
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_mat.albedo_texture = t
		_glint_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_glint_mat.vertex_color_use_as_albedo = false
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := _glint_mat.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c.r * strength, c.g * strength, c.b * strength, 1.0)
	mi.material_override = m
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _bar_kit(n: Node3D, vis: Node3D, id: String, s: Vector3, top: Vector3) -> bool:
	var floor_y := -s.y / 2.0 + 0.006
	match id:
		"counter":
			(vis.get_child(0) as MeshInstance3D).material_override = mat("walnut_panel")
			# quiet green marble top with a rounded walnut nose; warm strip under the lip
			box(vis, Vector3(s.x + 0.12, 0.05, s.z + 0.16), top + Vector3(0, 0.025, 0.02), mat("marble_green"))
			var nose := cyl(vis, 0.034, 0.034, s.x + 0.12, Vector3(0, s.y / 2.0 + 0.012, s.z / 2.0 + 0.1), mat("walnut"), 12)
			nose.rotation_degrees = Vector3(0, 0, 90)
			box(vis, Vector3(s.x, 0.1, 0.02), Vector3(0, -s.y / 2.0 + 0.05, s.z / 2.0 + 0.004), mat("dark"))   # kick recess
			var rail := cyl(vis, 0.025, 0.025, s.x, Vector3(0, -s.y / 2.0 + 0.22, s.z / 2.0 + 0.18), mat("brass"), 10)
			rail.rotation_degrees = Vector3(0, 0, 90)
			for i in 6:
				box(vis, Vector3(0.025, 0.05, 0.18), Vector3(-s.x / 2.0 + 0.5 + i * (s.x - 1.0) / 5.0, -s.y / 2.0 + 0.22, s.z / 2.0 + 0.09), mat("brass"))
			# two shaded counter lamps (glow only) and one warm fill at face height for the guests
			for x in [-2.6, 2.4]:
				table_lamp(vis, top + Vector3(x, 0.05, 0.12), false, 0.9, 0.75)
			lamp_light(vis, Vector3(0, 1.05, s.z / 2.0 + 0.9), Color(1.0, 0.74, 0.5), 0.55, 3.6)
			# polished-floor suggestion: soft warm streaks below the counter lamps (no mirror, no probe)
			for x in [-2.6, 2.4]:
				glint(vis, Vector2(0.45, 1.3), Vector3(x, -s.y / 2.0 + 0.008, s.z / 2.0 + 0.85), Color(1.0, 0.7, 0.4), 0.16)
			contact(vis, Vector2(s.x + 0.4, 0.55), Vector3(0, floor_y, s.z / 2.0 + 0.12), 0.5)
			return true
		"back_bar":
			(vis.get_child(0) as MeshInstance3D).material_override = mat("walnut_panel")
			box(vis, Vector3(s.x, 0.04, s.z + 0.04), top + Vector3(0, 0.02, 0), mat("marble_green"))
			box(vis, Vector3(s.x, 0.014, 0.014), top + Vector3(0, -0.01, s.z / 2.0 + 0.022), mat("brass"))
			contact(vis, Vector2(s.x + 0.3, 0.45), Vector3(0, floor_y, s.z / 2.0 + 0.08), 0.45)
			return true
		"bottles":
			_bar_bottle_wall(vis, s)
			return true
		"booth_1", "booth_2", "booth_3":
			box(vis, Vector3(s.x - 0.1, 0.12, s.z * 0.7), Vector3(0, -s.y / 2.0 + 0.5, 0.05), mat("oxblood"))
			var roll := cyl(vis, 0.07, 0.07, s.x - 0.1, Vector3(0, -s.y / 2.0 + 0.5, 0.05 + s.z * 0.35), mat("oxblood"), 12)
			roll.rotation_degrees = Vector3(0, 0, 90)
			var pads := 6
			for i in pads:
				var px := -s.x / 2.0 + (i + 0.5) * s.x / pads
				box(vis, Vector3(s.x / pads - 0.03, 0.46, 0.08), Vector3(px, s.y / 2.0 - 0.28, -s.z / 2.0 + 0.2), mat("oxblood"))
			box(vis, Vector3(s.x, 0.05, 0.24), Vector3(0, s.y / 2.0 + 0.0, -s.z / 2.0 + 0.1), mat("walnut"))
			contact(vis, Vector2(s.x + 0.25, s.z + 0.25), Vector3(0, floor_y, 0), 0.4)
			return true
		"booth_table", "guest_table":
			box(vis, Vector3(s.x + 0.06, 0.04, s.z + 0.06), top + Vector3(0, 0.02, 0), mat("walnut"))
			box(vis, Vector3(s.x + 0.07, 0.012, s.z + 0.07), top + Vector3(0, -0.004, 0), mat("brass"))
			table_lamp(vis, top + Vector3(0, 0.04, 0), id == "guest_table")   # booth lamp: glow only (light cap)
			contact(vis, Vector2(s.x + 0.35, s.z + 0.35), Vector3(0, floor_y, 0), 0.4)
			return true
		"stool_1", "stool_2", "stool_3", "stool_4", "stool_5", "stool_6":
			vis.get_child(0).visible = false
			cyl(vis, 0.205, 0.2, 0.06, top - Vector3(0, 0.045, 0), mat("oxblood"), 18)
			sphere(vis, 0.205, 0.09, top - Vector3(0, 0.02, 0), mat("oxblood"))   # crowned cushion
			cyl(vis, 0.19, 0.19, 0.016, top - Vector3(0, 0.082, 0), mat("brass"), 18)
			cyl(vis, 0.028, 0.034, s.y - 0.12, Vector3(0, -0.03, 0), mat("brass"), 10)
			cyl(vis, 0.07, 0.2, 0.05, Vector3(0, -s.y / 2.0 + 0.025, 0), mat("brass"), 18)
			cyl(vis, 0.155, 0.155, 0.014, Vector3(0, -s.y / 2.0 + 0.3, 0), mat("brass"), 18)   # foot ring
			contact(vis, Vector2(0.62, 0.62), Vector3(0, floor_y, 0), 0.55)
			return true
	return false


## Two warm ceiling downlights over the guest floor (they take the slots of two hidden window spills):
## pools on floor, stools and standing guests in ordinary gameplay view.
static func _bar_downlights(z: Zone) -> void:
	var root := look_root(z)
	for x in [4.6, 10.4]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(x, 3.45, 7.6)
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.light_color = Color(1.0, 0.72, 0.46)
		sp.light_energy = 2.2
		sp.spot_range = 5.0
		sp.spot_angle = 48.0
		sp.spot_angle_attenuation = 0.8
		sp.spot_attenuation = 0.7
		# selected shadowed key: measured on the target GL machine before enabling (debug probe file only)
		sp.shadow_enabled = OS.is_debug_build() and FileAccess.file_exists("/tmp/room307_bar_shadow") and x < 5.0
		sp.set_meta("base_energy", sp.light_energy)
		sp.add_to_group("vesper_practical")
		root.add_child(sp)
		cyl(root, 0.06, 0.08, 0.04, Vector3(x, 3.58, 7.6), VesperLook.emissive(Color(1.0, 0.85, 0.62), 1.6))


## Shelving with grouped bottles (one MultiMesh, one draw call) in front of the backlit panel.
static func _bar_bottle_wall(vis: Node3D, s: Vector3) -> void:
	vis.get_child(0).visible = false
	var h := 1.6
	var rows := 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 3071
	var xf: Array = []
	var cols: Array = []
	var pal := [Color(0.62, 0.36, 0.13), Color(0.45, 0.24, 0.1), Color(0.2, 0.32, 0.17), Color(0.58, 0.56, 0.48), Color(0.36, 0.1, 0.07), Color(0.7, 0.5, 0.22)]
	for r in rows:
		var y := -h / 2.0 + 0.12 + r * (h / rows)
		box(vis, Vector3(s.x, 0.03, s.z + 0.08), Vector3(0, y - 0.02, 0), mat("walnut"))
		box(vis, Vector3(s.x, 0.014, 0.012), Vector3(0, y - 0.012, s.z / 2.0 + 0.045), mat("brass"))
		var x := -s.x / 2.0 + 0.1
		while x < s.x / 2.0 - 0.1:
			var group := rng.randi_range(3, 7)
			var c: Color = pal[rng.randi() % pal.size()]
			var tall := rng.randf_range(0.85, 1.25)
			for b in group:
				if x > s.x / 2.0 - 0.08:
					break
				var sc := tall * rng.randf_range(0.94, 1.06)
				xf.append(Transform3D(Basis().scaled(Vector3(1, sc, 1)), Vector3(x, y, rng.randf_range(-0.03, 0.03))))
				cols.append(c.lerp(pal[rng.randi() % pal.size()], 0.15))
				x += 0.085
			x += rng.randf_range(0.08, 0.3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _bottle()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _bottle_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vis.add_child(mmi)
	# backlit panel: warm at the counter, falling off toward the ceiling
	for b in 3:
		box(vis, Vector3(s.x, 0.5, 0.02), Vector3(0, 0.25 + b * 0.5, -s.z / 2.0 - 0.02), VesperLook.emissive(Color(0.82, 0.55, 0.32), [0.36, 0.19, 0.08][b]))
	lamp_light(vis, Vector3(0, 1.7, -0.15), Color(1.0, 0.62, 0.3), 1.0, 4.0)


static func _bottle() -> Mesh:
	if _bottle_mesh:
		return _bottle_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := CylinderMesh.new()
	body.top_radius = 0.034
	body.bottom_radius = 0.036
	body.height = 0.2
	body.radial_segments = 10
	body.rings = 1
	var shoulder := CylinderMesh.new()
	shoulder.top_radius = 0.014
	shoulder.bottom_radius = 0.034
	shoulder.height = 0.05
	shoulder.radial_segments = 10
	shoulder.rings = 1
	var neck := CylinderMesh.new()
	neck.top_radius = 0.012
	neck.bottom_radius = 0.013
	neck.height = 0.075
	neck.radial_segments = 8
	neck.rings = 1
	st.append_from(body, 0, Transform3D(Basis(), Vector3(0, 0.1, 0)))
	st.append_from(shoulder, 0, Transform3D(Basis(), Vector3(0, 0.225, 0)))
	st.append_from(neck, 0, Transform3D(Basis(), Vector3(0, 0.2875, 0)))
	_bottle_mesh = st.commit()
	return _bottle_mesh


## Subdued glass: dark core, colour from the backlit liquid, a painted bright rim — no transparency.
static func _bottle_material() -> ShaderMaterial:
	if _bottle_mat:
		return _bottle_mat
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float glow = 0.5;
void fragment() {
	float rim_f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = COLOR.rgb * 0.3;
	ROUGHNESS = 0.24;
	SPECULAR = 0.5;
	EMISSION = COLOR.rgb * glow * (0.3 + 0.7 * rim_f) + vec3(1.0, 0.86, 0.62) * rim_f * 0.1;
}"""
	_bottle_mat = ShaderMaterial.new()
	_bottle_mat.shader = sh
	return _bottle_mat


## The BAR opening looks from behind the counter toward the camera side of the room, which the follow
## rig never shows. This wall exists only while that fixed rig is live (VesperArt.tick).
static func _bar_backdrop(z: Zone) -> void:
	var root := look_root(z)
	var bd := Node3D.new()
	bd.name = "OpeningBackdrop"
	bd.set_meta("rig", "BAR:start")
	bd.add_to_group("vesper_rig_only")
	bd.visible = false
	root.add_child(bd)
	var zz := z.size.y + 1.65
	var cx := z.size.x / 2.0
	_bar_downlights(z)
	box(bd, Vector3(z.size.x - 1.0, 0.02, 1.8), Vector3(cx, -0.01, z.size.y + 0.85), mat("timber_floor"))
	box(bd, Vector3(z.size.x - 1.0, 3.6, 0.1), Vector3(cx, 1.8, zz), mat("bar_wall"))
	box(bd, Vector3(z.size.x - 1.0, 1.0, 0.06), Vector3(cx, 0.5, zz - 0.07), mat("walnut_wainscot"))
	box(bd, Vector3(z.size.x - 1.0, 0.03, 0.05), Vector3(cx, 1.02, zz - 0.09), mat("brass"))
	box(bd, Vector3(z.size.x - 2.0, 0.5, 0.25), Vector3(cx, 0.78, zz - 0.25), mat("oxblood"))   # banquette backs
	for x in [cx - 3.6, cx, cx + 3.6]:
		box(bd, Vector3(0.12, 0.22, 0.03), Vector3(x, 2.05, zz - 0.07), mat("brass"))
		cyl(bd, 0.07, 0.11, 0.16, Vector3(x, 2.13, zz - 0.18), VesperLook.emissive(Color(0.95, 0.76, 0.48), 2.2))
	for x in [cx - 1.8, cx + 1.8]:
		box(bd, Vector3(1.1, 0.8, 0.03), Vector3(x, 1.75, zz - 0.07), mat("brass"))
		box(bd, Vector3(1.0, 0.7, 0.03), Vector3(x, 1.75, zz - 0.09), VesperLook.material("night_glass"))
	lamp_light(bd, Vector3(cx, 2.2, zz - 0.6), Color(1.0, 0.7, 0.42), 0.8, 4.5)
	# its lamp lights only the backdrop (render layer 2): it never takes one of the 16 per-object light
	# slots of the room floor or the cast
	for c in bd.find_children("*", "", true, false):
		if c is MeshInstance3D:
			(c as MeshInstance3D).layers = 2
		elif c is OmniLight3D:
			(c as OmniLight3D).light_cull_mask = 2


# ================================================================== FINAL VISUAL LANGUAGE V1 — ROOM 307 kit
# Visual only, inside each prop's footprint; bodies, nav, markers, interactables untouched. Nothing is
# placed on top of a clue (desk slip/glasses/bottle, nightstand pills, floor phone/shoes, towels).

static var _rain_mat: ShaderMaterial = null


## Cool rain light lying on the floor in front of a window: soft pane shape, mullion, rain shadows
## sliding down (additive, unshaded, faint) — the cool half of the warm/cool split.
static func rain_light(z: Zone, pos: Vector3, size: Vector2) -> MeshInstance3D:
	if _rain_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 tint : source_color = vec3(0.42, 0.52, 0.78);
uniform float strength = 0.11;
void fragment() {
	vec2 uv = UV;
	float pane = smoothstep(0.0, 0.14, uv.x) * smoothstep(1.0, 0.86, uv.x) * smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.35, uv.y);
	float mull = 1.0 - 0.35 * smoothstep(0.035, 0.0, abs(uv.x - 0.5));
	float col_id = floor(uv.x * 26.0);
	float h = fract(sin(col_id * 12.9898) * 43758.5453);
	float streak = smoothstep(0.86, 1.0, fract(uv.y * 1.2 - TIME * (0.22 + h * 0.3) + h)) * step(0.45, h);
	ALBEDO = tint * strength * pane * mull * (1.0 - 0.5 * streak);
}"""
		_rain_mat = ShaderMaterial.new()
		_rain_mat.shader = sh
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "RainLight"
	mi.mesh = q
	mi.material_override = _rain_mat
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	look_root(z).add_child(mi)
	return mi


static func _r307_kit(n: Node3D, vis: Node3D, id: String, s: Vector3, top: Vector3) -> bool:
	var floor_y := -s.y / 2.0 + 0.006
	match id:
		"bed":
			(vis.get_child(0) as MeshInstance3D).material_override = mat("linen")
			box(vis, Vector3(s.x + 0.06, 0.2, s.z + 0.04), Vector3(0, -s.y / 2.0 + 0.1, 0), mat("walnut"))   # plinth
			box(vis, Vector3(s.x - 0.02, 0.04, s.z - 0.04), top + Vector3(0, 0.02, 0), mat("linen"))       # sheet
			# duvet over the foot 60%, turned back at the head edge and pushed aside on one side:
			# someone got up from this bed not long ago
			var duv := VesperLook.material("v_duvet")
			box(vis, Vector3(s.x + 0.06, 0.09, s.z * 0.58), top + Vector3(0.04, 0.065, s.z * 0.21), duv)
			var fold := cyl(vis, 0.055, 0.055, s.x * 0.7, top + Vector3(0.3, 0.11, s.z * 0.21 - s.z * 0.29), duv, 12)
			fold.rotation_degrees = Vector3(0, 12, 90)
			var corner := box(vis, Vector3(0.62, 0.05, 0.5), top + Vector3(-s.x / 2.0 + 0.4, 0.13, s.z * 0.05), duv)
			corner.rotation_degrees = Vector3(0, 28, 4)
			for sx in [-1.0, 1.0]:   # drapes over the sides (never over the foot: the phone lies there)
				box(vis, Vector3(0.03, 0.3, s.z * 0.58), Vector3(sx * (s.x / 2.0 + 0.045), s.y / 2.0 - 0.06, s.z * 0.21), duv)
			for i in 2:
				var pil := sphere(vis, 0.3, 0.16, top + Vector3(-0.45 + i * 0.92, 0.1, -s.z / 2.0 + 0.32), mat("linen"))
				pil.scale = Vector3(1.0, 1.0 - 0.2 * i, 0.55)
				pil.rotation_degrees = Vector3(0, -6 + i * 16, i * 4)
			box(vis, Vector3(s.x + 0.08, 0.025, 0.42), top + Vector3(0, 0.118, s.z / 2.0 - 0.32), mat("oxblood"))   # runner
			contact(vis, Vector2(s.x + 0.5, s.z + 0.5), Vector3(0, floor_y, 0), 0.45)
			return true
		"headboard":
			(vis.get_child(0) as MeshInstance3D).material_override = mat("walnut_panel")
			box(vis, Vector3(s.x - 0.24, s.y - 0.34, 0.04), Vector3(0, 0.02, s.z / 2.0 + 0.02), VesperLook.material("v_curtain"))
			box(vis, Vector3(s.x + 0.06, 0.05, s.z + 0.04), top + Vector3(0, 0.025, 0), mat("walnut"))
			return true
		"nightstand":
			(vis.get_child(0) as MeshInstance3D).material_override = mat("walnut")
			box(vis, Vector3(s.x - 0.06, 0.16, 0.02), Vector3(0, 0.08, s.z / 2.0 + 0.01), mat("walnut_panel"))   # drawer
			sphere(vis, 0.018, 0.03, Vector3(0, 0.08, s.z / 2.0 + 0.03), mat("brass"))
			table_lamp(vis, top + Vector3(0.11, 0.0, -0.12), true, 2.0, 0.8)   # back corner: the pills stay in view
			cyl(vis, 0.032, 0.028, 0.11, top + Vector3(-0.15, 0.055, 0.13), _glass_mat(), 12)   # half-drunk glass
			cyl(vis, 0.026, 0.024, 0.05, top + Vector3(-0.15, 0.03, 0.13), VesperLook.material("object", Color(0.62, 0.68, 0.7)), 10)
			contact(vis, Vector2(s.x + 0.25, s.z + 0.25), Vector3(0, floor_y, 0), 0.4)
			return true
		"desk":
			(vis.get_child(0) as MeshInstance3D).material_override = mat("walnut")
			box(vis, Vector3(0.02, s.y - 0.24, s.z * 0.55), Vector3(s.x / 2.0 + 0.002, -0.08, 0.1), mat("dark"))   # kneehole
			box(vis, Vector3(s.x + 0.04, 0.035, s.z + 0.04), top + Vector3(0, 0.0175, 0), mat("walnut"))
			table_lamp(vis, top + Vector3(0, 0.035, -s.z / 2.0 + 0.2), true, 2.0, 0.85)
			contact(vis, Vector2(s.x + 0.35, s.z + 0.3), Vector3(0, floor_y, 0), 0.4)
			return true
		"wardrobe":
			_consolidated_wardrobe(n, vis, s)
			contact(vis, Vector2(s.x + 0.3, s.z + 0.3), Vector3(0, floor_y, 0), 0.45)
			return true
		"curtain":
			(vis.get_child(0) as MeshInstance3D).material_override = mat_curtain()
			for i in 3:   # gathered folds (children of Visual: they breathe with the curtain)
				cyl(vis, 0.055, 0.065, s.y - 0.06, Vector3(0.0, 0.0, -0.1 + i * 0.1), mat_curtain(), 10)
			return true
		"tv":
			box(vis, Vector3(s.x * 0.6, s.y + 0.05, s.z + 0.05), Vector3(0.02, 0, 0), mat("walnut"))
			return false
		"shower_tray":
			(vis.get_child(0) as MeshInstance3D).material_override = VesperLook.material("v_ceramic")
			var screen := box(vis, Vector3(0.012, 1.9, s.z * 0.65), Vector3(-s.x / 2.0, 0.98, s.z * 0.15), _screen_mat())
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			box(vis, Vector3(0.02, 0.02, s.z * 0.65), Vector3(-s.x / 2.0, 1.94, s.z * 0.15), mat("brass"))
			cyl(vis, 0.012, 0.012, 1.1, Vector3(0, 1.45, -s.z / 2.0 + 0.06), mat("brass"), 8)
			var head := cyl(vis, 0.07, 0.05, 0.03, Vector3(0, 2.0, -s.z / 2.0 + 0.16), mat("brass"), 14)
			head.rotation_degrees = Vector3(20, 0, 0)
			return true
		"sink":
			(vis.get_child(0) as MeshInstance3D).material_override = VesperLook.material("v_marble_cream")
			box(vis, Vector3(s.x + 0.06, 0.04, s.z + 0.06), top + Vector3(0, 0.02, 0), VesperLook.material("v_marble_cream"))
			box(vis, Vector3(0.02, s.y * 0.6, s.z * 0.8), Vector3(-s.x / 2.0 - 0.003, -0.05, 0), mat("walnut"))   # cabinet door
			cyl(vis, 0.2, 0.17, 0.08, top + Vector3(-0.04, 0.06, 0), VesperLook.material("v_ceramic"), 18)
			cyl(vis, 0.15, 0.13, 0.012, top + Vector3(-0.04, 0.097, 0), VesperLook.material("object", Color(0.78, 0.8, 0.8)), 16)
			cyl(vis, 0.02, 0.02, 0.006, top + Vector3(-0.04, 0.104, 0), mat("brass"), 8)   # drain
			var tap := cyl(vis, 0.012, 0.012, 0.16, top + Vector3(0.22, 0.12, 0), mat("brass"), 8)
			tap.rotation_degrees = Vector3(0, 0, 70)
			contact(vis, Vector2(s.x + 0.25, s.z + 0.25), Vector3(0, floor_y, 0), 0.4)
			return true
		"mirror":
			(vis.get_child(0) as MeshInstance3D).material_override = _mirror_mat()
			box(vis, Vector3(0.02, s.y + 0.06, s.z + 0.06), Vector3(0.012, 0, 0), mat("brass"))
			return true
	return false


static func mat_curtain() -> Material:
	return VesperLook.material("v_curtain")


## One mesh for body + raised doors + cornice + plinth, wearing the occluder's own (fadeable)
## material: the camera can still dither the whole wardrobe out (one-mesh occluder contract).
static func _consolidated_wardrobe(n: Node3D, vis: Node3D, s: Vector3) -> void:
	var body := vis.get_child(0) as MeshInstance3D
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [
		[s, Vector3.ZERO],
		[Vector3(0.025, s.y * 0.8, s.z * 0.46), Vector3(s.x / 2.0 + 0.012, 0.04, -s.z * 0.245)],   # door L
		[Vector3(0.025, s.y * 0.8, s.z * 0.46), Vector3(s.x / 2.0 + 0.012, 0.04, s.z * 0.245)],    # door R
		[Vector3(s.x + 0.06, 0.07, s.z + 0.06), Vector3(0, s.y / 2.0 - 0.035, 0)],               # cornice
		[Vector3(s.x + 0.02, 0.09, s.z + 0.02), Vector3(0, -s.y / 2.0 + 0.045, 0)],              # plinth
		[Vector3(0.03, 0.14, 0.025), Vector3(s.x / 2.0 + 0.035, 0.08, -0.05)],                  # pulls
		[Vector3(0.03, 0.14, 0.025), Vector3(s.x / 2.0 + 0.035, 0.08, 0.05)],
	]
	for p in parts:
		var b := BoxMesh.new()
		b.size = p[0]
		st.append_from(b, 0, Transform3D(Basis(), p[1]))
	body.mesh = st.commit()
	body.material_override = VesperLook.material("walnut") if not n.has_meta("occluder") else body.material_override
	if n.has_meta("occluder") and body.material_override is ShaderMaterial:
		var m := (VesperLook.material("walnut") as ShaderMaterial).duplicate() as ShaderMaterial
		body.material_override = m   # still its own instance: the camera fades only this wardrobe


static var _glass_m: StandardMaterial3D = null
static var _screen_m: StandardMaterial3D = null
static var _mirror_m: ShaderMaterial = null


static func _glass_mat() -> StandardMaterial3D:
	if _glass_m == null:
		_glass_m = StandardMaterial3D.new()
		_glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_m.albedo_color = Color(0.82, 0.88, 0.9, 0.28)
		_glass_m.roughness = 0.08
		_glass_m.rim_enabled = true
		_glass_m.rim = 0.4
	return _glass_m


static func _screen_mat() -> StandardMaterial3D:
	if _screen_m == null:
		_screen_m = StandardMaterial3D.new()
		_screen_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_screen_m.albedo_color = Color(0.78, 0.86, 0.9, 0.1)
		_screen_m.roughness = 0.05
		_screen_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _screen_m


## A painted mirror: dark cool depth with one soft diagonal highlight (no reflection camera).
static func _mirror_mat() -> ShaderMaterial:
	if _mirror_m == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
	float band = smoothstep(0.16, 0.0, abs(UV.x + UV.y * 0.6 - 0.62)) * 0.5 + smoothstep(0.05, 0.0, abs(UV.x + UV.y * 0.6 - 0.9)) * 0.3;
	vec3 depth = mix(vec3(0.16, 0.19, 0.21), vec3(0.3, 0.33, 0.35), UV.y);
	ALBEDO = depth * 0.6;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	EMISSION = depth * 0.12 + vec3(0.75, 0.8, 0.82) * band * 0.18;
}"""
		_mirror_m = ShaderMaterial.new()
		_mirror_m.shader = sh
	return _mirror_m


## Room-level pieces: bathroom tile floor + wall cladding (inside the bath area, flush on the
## perimeter walls only — never on the camera-fading partition walls), and quiet contact under clues.
static func _r307_room(z: Zone, world: Node) -> void:
	var root := look_root(z)
	var bx0 := 6.7
	var bw := z.size.x - bx0
	box(root, Vector3(bw, 0.004, z.size.y), Vector3(bx0 + bw / 2.0, 0.002, z.size.y / 2.0), VesperLook.material("v_tile_floor_bath"))
	box(root, Vector3(bw, 1.35, 0.012), Vector3(bx0 + bw / 2.0, 0.675, 0.006), VesperLook.material("v_tile_bath"))       # N wall
	box(root, Vector3(0.012, 1.35, z.size.y), Vector3(z.size.x - 0.006, 0.675, z.size.y / 2.0), VesperLook.material("v_tile_bath"))  # E wall
	box(root, Vector3(bw, 0.03, 0.025), Vector3(bx0 + bw / 2.0, 1.36, 0.012), mat("walnut"))
	box(root, Vector3(0.025, 0.03, z.size.y), Vector3(z.size.x - 0.012, 1.36, z.size.y / 2.0), mat("walnut"))
	# small evidence objects: grounded by a faint contact, never lit or outlined
	for it in world.get_tree().get_nodes_in_group("interactables"):
		if String(it.def.get("zone", "")) != z.zone_id or it.has_meta("follow_npc"):
			continue
		var mn: Node = it.get("mesh_node")
		if mn == null or not (mn is MeshInstance3D):
			continue
		var ms := Data.vec3((it.def.get("mesh", {}) as Dictionary).get("s", [0.1, 0.1, 0.1]))
		if ms.y > 0.5 or ms.x > 0.6:
			continue
		var c := contact(mn.get_parent() as Node3D, Vector2(maxf(ms.x, 0.08) * 2.2, maxf(ms.z, 0.08) * 2.2),
			(mn as Node3D).position - Vector3(0, ms.y / 2.0 - 0.003, 0), 0.35)
		c.name = "ClueContact"

