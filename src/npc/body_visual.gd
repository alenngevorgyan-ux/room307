class_name BodyVisual
extends Node3D
## Character body — temporary PROXY (Visual Integration V1.6), not a final model.
## Built from data/ep01/proxies.json (VESPER_EP01_CHARACTER_CANON_v1): height, build, wardrobe
## layers and colours, hair mass, identity accessories and resting posture. Primitive meshes only,
## arranged as a small rig (hips, torso, head, two-segment arms reaching for the hand targets,
## swinging legs) so silhouettes, staging and body language read at gameplay distance.
## The public surface is unchanged — `head`, `hand_l`, `hand_r` (READ tells attach there), `pose`,
## `set_pose`, `set_crouch`, `look_target` — so a production rig can replace this file 1:1.

signal footfall(running: bool)    # a foot lands (sound in time with the walk cycle)
signal work_beat(step: int)       # bar routine: 0 polish, 1 set down, 2 bottles, 3 lean

const POSES := {
	"rest": [Vector3(-0.3, 0.85, 0.02), Vector3(0.3, 0.85, 0.02)],
	"pocket": [Vector3(-0.3, 0.85, 0.02), Vector3(0.12, 1.32, -0.2)],     # right hand to inside breast pocket
	"hip_pocket": [Vector3(-0.3, 0.85, 0.02), Vector3(0.24, 0.95, -0.12)],
	"ear": [Vector3(-0.3, 0.85, 0.02), Vector3(0.16, 1.6, -0.06)],         # phone call
	"phone": [Vector3(-0.14, 1.12, -0.3), Vector3(0.14, 1.12, -0.3)],      # phone look
	"smoke": [Vector3(-0.3, 0.85, 0.02), Vector3(0.1, 1.5, -0.22)],
	"table": [Vector3(-0.22, 0.95, -0.42), Vector3(0.22, 0.95, -0.42)],     # hands on the table edge / wheel
	"wheel": [Vector3(-0.22, 1.1, -0.38), Vector3(0.22, 1.1, -0.38)],
	"open": [Vector3(-0.5, 1.05, -0.15), Vector3(0.5, 1.05, -0.15)],
	"gesture": [Vector3(-0.3, 0.85, 0.02), Vector3(0.35, 1.25, -0.35)],
	"polish": [Vector3(-0.12, 1.05, -0.35), Vector3(0.1, 1.12, -0.32)],
	"carry": [Vector3(-0.2, 1.0, -0.35), Vector3(0.2, 1.0, -0.35)],
	"reach": [Vector3(-0.3, 0.85, 0.02), Vector3(0.12, 0.9, -0.65)],
	"club": [Vector3(-0.15, 1.45, -0.2), Vector3(0.15, 1.35, -0.25)],      # extinguisher stance
	"wrist": [Vector3(-0.12, 1.15, -0.32), Vector3(0.3, 0.85, 0.02)],      # shows left wrist
	"behind": [Vector3(-0.15, 0.95, 0.22), Vector3(0.15, 0.95, 0.22)],     # hands behind back
	"grab": [Vector3(-0.25, 1.15, -0.55), Vector3(0.25, 1.15, -0.55)],
	"radio": [Vector3(-0.3, 0.85, 0.02), Vector3(0.18, 1.5, -0.12)],
	"type": [Vector3(-0.1, 1.15, -0.4), Vector3(0.12, 1.2, -0.42)],
	# resting variants (proxy posture "hands"): what a character does with their hands when idle
	"pockets": [Vector3(-0.21, 0.88, 0.04), Vector3(0.21, 0.88, 0.04)],
	"crossed": [Vector3(0.1, 1.22, -0.24), Vector3(-0.1, 1.18, -0.25)],
	"front": [Vector3(-0.09, 0.9, -0.2), Vector3(0.09, 0.92, -0.2)],
	"pocket_guard": [Vector3(0.08, 1.28, -0.24), Vector3(0.28, 0.86, 0.02)], # left hand flat on the chest pocket
	"work": [Vector3(-0.16, 1.02, -0.32), Vector3(0.16, 1.02, -0.32)],
}
const REST_VARIANT := {"pockets": "pockets", "crossed": "crossed", "front": "front", "behind": "behind",
	"pocket_guard": "pocket_guard", "work": "work", "gesture": "gesture", "open": "rest"}
const BUILDS := {   # shoulder width, hip width, torso depth, limb radius
	"slight": [0.36, 0.3, 0.19, 0.05], "lean": [0.41, 0.3, 0.2, 0.058], "average": [0.44, 0.33, 0.22, 0.064],
	"broad": [0.5, 0.35, 0.25, 0.074], "heavy": [0.52, 0.42, 0.31, 0.08],
}
const JACKETS_SLEEVED := ["overshirt", "suit_open", "suit_closed", "cropped", "waxed", "cardigan", "blazer", "bomber"]
const SEG := 0.29          # upper-arm / forearm length at 1.75 m

static var _specs: Dictionary = {}

var proxy_id := ""
var spec: Dictionary = {}
var rig: Node3D            # "Visual"
var upper: Node3D          # waist pivot: torso, arms, head lean together
var head: Node3D
var hand_l: MeshInstance3D
var hand_r: MeshInstance3D
var leg_l: Node3D
var leg_r: Node3D
var pose := "rest"
var look_target: Variant = null    # Vector3 world or null
var mood := ""                     # V1.7 body-language state (see set_mood)

var H := 1.75
var _crouch := 0.0
var _scale := 1.0
var _shoulder_l := Vector3.ZERO
var _shoulder_r := Vector3.ZERO
var _arm_l: Array = []     # [upper, fore] meshes
var _arm_r: Array = []
var _hip_y := 0.9
var _limb := 0.06
var _seg := SEG
var _phase := 0.0
var _t := 0.0
var _lean_base := 0.0
var _chin_base := 0.0
var _mood_lean := 0.0
var _mood_chin := 0.0
var _mood_amp := 1.0
var _hand_targets: Array = [Vector3.ZERO, Vector3.ZERO]
var _hand_tween: Tween
var _mats: Dictionary = {}


static func proxy_spec(id: String) -> Dictionary:
	if _specs.is_empty():
		var f := FileAccess.open("res://data/ep01/proxies.json", FileAccess.READ)
		if f:
			var j: Variant = JSON.parse_string(f.get_as_text())
			if typeof(j) == TYPE_DICTIONARY:
				_specs = j
	return _specs.get(id, {})


func _mat(hex: String, rough: float = 0.82) -> StandardMaterial3D:
	var key := "%s|%.2f" % [hex, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	# canon wardrobes are dark; lift them so they separate by value in game light (no all-black
	# silhouettes — CIR-25D negative list) while keeping every hue
	var c := Color(hex)
	if c.get_luminance() < 0.3:
		c = c.lerp(c * 2.2, 0.75).clamp(Color(0, 0, 0), Color(0.42, 0.4, 0.38))
		c = Color(maxf(c.r, 0.075), maxf(c.g, 0.07), maxf(c.b, 0.068))
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true        # CIR-25D: a thin rim separates every character from the room
	m.rim = 0.45
	m.rim_tint = 0.55
	_mats[key] = m
	return m


func _mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return _mesh(parent, s, mat, pos, Vector3.ZERO, scl)


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, mat, pos, rot)


func _cyl(parent: Node3D, rt: float, rb: float, h: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 14
	return _mesh(parent, c, mat, pos, Vector3.ZERO, scl)


func _capsule(parent: Node3D, r: float, h: float, mat: Material) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 10
	c.rings = 4
	return _mesh(parent, c, mat, Vector3.ZERO)


# ================================================================== build

## `c`, `scale_f`, `extra` are the graybox inputs (kept for compatibility / unknown characters).
func build(c: Color, scale_f: float = 1.0, extra: Dictionary = {}) -> void:
	_scale = scale_f
	spec = proxy_spec(proxy_id).duplicate(true)
	if spec.is_empty():
		# no canon entry: a neutral figure tinted with the graybox colour so it stays distinct
		spec = proxy_spec("guest").duplicate(true)
		if spec.is_empty():
			spec = {"height": 1.75, "build": "average", "skin": "b58e74", "hair": {"style": "short_neat", "color": "231c18"},
				"top": "bfb6a6", "lower": {"style": "trousers", "color": "26262a"}, "shoes": "151313", "acc": [], "posture": {}}
		spec["jacket"] = {"style": "suit_open", "color": c.lerp(Color(0.16, 0.15, 0.16), 0.55).to_html(false)}
		var acc0: Array = spec.get("acc", [])
		if extra.get("apron", false):
			acc0.append("apron_long:2a2422")
		if extra.get("ring", false):
			acc0.append("ring")
		spec["acc"] = acc0
	H = float(spec.get("height", 1.75)) * scale_f
	var b: Array = BUILDS.get(String(spec.get("build", "average")), BUILDS.average)
	var sh_w: float = b[0]
	var hip_w: float = b[1]
	var depth: float = b[2]
	_limb = b[3]
	var k := H / 1.75
	_seg = SEG * k
	rig = Node3D.new()
	rig.name = "Visual"
	add_child(rig)
	var skin := _mat(String(spec.get("skin", "c69a7c")), 0.65)
	var jk: Dictionary = spec.get("jacket", {})
	var jstyle := String(jk.get("style", "none"))
	var jmat := _mat(String(jk.get("color", spec.get("top", "333333"))), 0.75)
	var top := _mat(String(spec.get("top", "333333")), 0.85)
	var low: Dictionary = spec.get("lower", {})
	var lstyle := String(low.get("style", "trousers"))
	var lmat := _mat(String(low.get("color", "222222")), 0.85)
	var shoes := _mat(String(spec.get("shoes", "151313")), 0.45)
	var acc: Array = spec.get("acc", [])
	var post: Dictionary = spec.get("posture", {})
	var dress := lstyle in ["slip_dress", "dress"]
	_hip_y = 0.52 * H
	var waist_y := 0.6 * H
	var chest_y := 0.72 * H
	var sh_y := 0.815 * H
	var neck_y := 0.855 * H
	var head_r := 0.068 * H
	# ---- legs (pivot at the hip so they can swing)
	var leg_w := _limb * (1.45 if lstyle in ["trousers_wide", "cargo"] else 1.25)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * hip_w * 0.27, _hip_y, 0)
		rig.add_child(pivot)
		if dress:
			var shin := _capsule(pivot, _limb * 0.9, _hip_y * 0.55, skin)
			shin.position = Vector3(0, -_hip_y * 0.72, 0)
		else:
			var leg := _capsule(pivot, leg_w, _hip_y + 0.02, lmat)
			leg.position = Vector3(0, -_hip_y / 2.0, 0)
		_box(pivot, Vector3(0.11 * k, 0.085, 0.27 * k), shoes, Vector3(0, -_hip_y + 0.045, -0.05))
		if lstyle == "slip_dress":   # heeled ankle boots
			_cyl(pivot, _limb * 1.0, _limb * 1.1, 0.16, shoes, Vector3(0, -_hip_y + 0.12, 0))
		if side < 0:
			leg_l = pivot
		else:
			leg_r = pivot
	# ---- upper body pivots at the waist (posture leans the whole thing)
	upper = Node3D.new()
	upper.position = Vector3(0, waist_y - 0.04, 0)
	rig.add_child(upper)
	var o := upper.position
	_cyl(upper, hip_w / 2.0, hip_w / 2.0 * 1.02, 0.18 * k, top if dress else lmat,
		Vector3(0, _hip_y - o.y + 0.05, 0), Vector3(1, 1, depth / hip_w * 1.1))
	var tmat := jmat if jstyle in JACKETS_SLEEVED or jstyle == "vest" else top
	var t_h := sh_y - (_hip_y - 0.02)
	var torso := _cyl(upper, sh_w / 2.0, hip_w / 2.0 * (1.12 if spec.get("build") == "heavy" else 1.0), t_h, tmat,
		Vector3(0, (sh_y + _hip_y - 0.02) / 2.0 - o.y, 0), Vector3(1, 1, depth / sh_w * 1.15))
	torso.name = "Torso"
	if jstyle == "cropped":
		torso.material_override = top
		var crop_h := (sh_y - chest_y) + 0.12
		_cyl(upper, sh_w / 2.0 + 0.015, sh_w / 2.0 * 0.92, crop_h, jmat,
			Vector3(0, sh_y - o.y - crop_h / 2.0 + 0.01, 0), Vector3(1, 1, depth / sh_w * 1.2))
	match lstyle:
		"slip_dress":
			_cyl(upper, hip_w / 2.0 * 0.95, hip_w / 2.0 * 1.25, _hip_y * 0.5, top, Vector3(0, _hip_y - o.y - _hip_y * 0.22, 0), Vector3(1, 1, 0.8))
		"dress":
			_cyl(upper, hip_w / 2.0, hip_w / 2.0 * 1.3, _hip_y * 0.55, lmat, Vector3(0, _hip_y - o.y - _hip_y * 0.25, 0), Vector3(1, 1, 0.85))
	var tail := 0.0
	match jstyle:
		"suit_open", "suit_closed", "blazer": tail = 0.13 * k
		"waxed", "overshirt": tail = 0.08 * k
		"cardigan": tail = 0.24 * k
	if tail > 0.0:
		_cyl(upper, hip_w / 2.0 + 0.02, hip_w / 2.0 + 0.035, tail, jmat, Vector3(0, _hip_y - o.y - tail / 2.0 + 0.04, 0), Vector3(1, 1, depth / hip_w * 1.15))
	# shirt showing at the front of an open jacket, a closed suit's V, a vest's shirt
	var front_z := -depth * 0.58 - 0.005
	match jstyle:
		"suit_open", "overshirt", "cardigan", "waxed", "blazer", "bomber":
			var wv := sh_w * (0.32 if jstyle != "overshirt" else 0.22)
			_box(upper, Vector3(wv, t_h * 0.92, 0.02), top, Vector3(0, (sh_y + _hip_y) / 2.0 - o.y + 0.02, front_z))
		"suit_closed":
			_box(upper, Vector3(sh_w * 0.2, t_h * 0.32, 0.02), top, Vector3(0, sh_y - o.y - t_h * 0.16, front_z))
		"vest":
			_box(upper, Vector3(sh_w * 0.18, t_h * 0.45, 0.02), top, Vector3(0, sh_y - o.y - t_h * 0.2, front_z))
	# ---- neck and head
	_cyl(upper, 0.05 * k, 0.058 * k, (neck_y - sh_y) + 0.06, skin, Vector3(0, (neck_y + sh_y) / 2.0 - o.y, -0.01))
	head = Node3D.new()
	head.position = Vector3(0, neck_y + head_r * 0.95 - o.y, -0.01)
	upper.add_child(head)
	_sphere(head, head_r, skin, Vector3.ZERO, Vector3(0.9, 1.06, 0.98))
	var nose := PrismMesh.new()
	nose.size = Vector3(0.035 * k, 0.06 * k, 0.05 * k)
	_mesh(head, nose, skin, Vector3(0, -head_r * 0.08, -head_r * 0.98), Vector3(deg_to_rad(-90), 0, 0))
	var eye := _mat("1a1512", 0.3)
	var brow := _mat(String(spec.get("hair", {}).get("color", "201a16")))
	for side in [-1.0, 1.0]:
		_sphere(head, head_r * 0.075, eye, Vector3(side * head_r * 0.34, head_r * 0.1, -head_r * 0.9))
		_box(head, Vector3(head_r * 0.34, head_r * 0.05, head_r * 0.08), brow, Vector3(side * head_r * 0.34, head_r * 0.26, -head_r * 0.9))
	_hair(head, head_r, spec.get("hair", {}))
	# ---- arms: shoulder balls + two segments that follow the hand targets every frame
	_shoulder_l = Vector3(-sh_w / 2.0 + 0.03, sh_y - 0.05 - o.y, 0)
	_shoulder_r = Vector3(sh_w / 2.0 - 0.03, sh_y - 0.05 - o.y, 0)
	var sleeve := jmat if jstyle in JACKETS_SLEEVED else top
	var fore := skin if acc.has("sleeves_rolled") else sleeve
	for side in [-1.0, 1.0]:
		_sphere(upper, _limb * 1.08, sleeve, _shoulder_l if side < 0 else _shoulder_r)
		var ua := _capsule(upper, _limb * 1.12, _seg, sleeve)
		var fa := _capsule(upper, _limb, _seg, fore)
		if side < 0:
			_arm_l = [ua, fa]
		else:
			_arm_r = [ua, fa]
	hand_l = _hand(skin, k)
	hand_r = _hand(skin, k)
	_accessories(acc, upper, o, sh_w, hip_w, depth, sh_y, chest_y, head_r, k)
	# resting posture
	var slump := float(post.get("slump", 0.0))
	_lean_base = float(post.get("lean", 0.0)) + slump * 0.12
	_chin_base = float(post.get("chin", 0.0))
	_shoulder_l.z += 0.03 * slump
	_shoulder_r.z += 0.03 * slump
	_rng.seed = hash(proxy_id) ^ get_instance_id()
	set_pose("rest", true)


func _hand(skin: Material, k: float) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.036 * k
	s.height = 0.09 * k
	s.radial_segments = 10
	s.rings = 6
	var h := MeshInstance3D.new()
	h.mesh = s
	h.material_override = skin
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(h)   # hands are pose targets in rig space; the arms reach for them
	return h


## Hair as sculpted masses (CIR-25D): the silhouette carries identity at distance.
func _hair(hd: Node3D, r: float, hdef: Dictionary) -> void:
	var m := _mat(String(hdef.get("color", "1b1512")), 0.7)
	match String(hdef.get("style", "short_neat")):
		"curly_volume":   # EL: loose dark curls falling forward over the forehead
			_sphere(hd, r * 1.08, m, Vector3(0, r * 0.28, r * 0.06), Vector3(1.05, 0.82, 1.08))
			for i in 10:
				var a := i * 0.63
				_sphere(hd, r * 0.36, m, Vector3(cos(a) * r * 0.78, r * (0.55 + 0.12 * sin(a * 3.0)), sin(a) * r * 0.78 + r * 0.05))
			_sphere(hd, r * 0.42, m, Vector3(-r * 0.25, r * 0.55, -r * 0.72))
			_sphere(hd, r * 0.36, m, Vector3(r * 0.3, r * 0.48, -r * 0.78))
		"swept_back":     # Adrian: salt-and-pepper, swept back, collar length
			_sphere(hd, r * 1.06, m, Vector3(0, r * 0.32, r * 0.14), Vector3(1.0, 0.72, 1.12))
			_sphere(hd, r * 0.62, m, Vector3(0, r * 0.0, r * 0.72), Vector3(1.25, 1.0, 0.7))
		"messy_updo":     # Mara: knot at the back, loose strands
			_sphere(hd, r * 1.05, m, Vector3(0, r * 0.3, r * 0.08), Vector3(1.0, 0.75, 1.05))
			_sphere(hd, r * 0.5, m, Vector3(0, r * 0.78, r * 0.72))
			for side in [-1.0, 1.0]:
				_box(hd, Vector3(r * 0.14, r * 1.2, r * 0.12), m, Vector3(side * r * 0.82, -r * 0.25, -r * 0.35), Vector3(0, 0, side * 0.12))
		"shoulder_wavy":  # Nico: wavy mass to the collar
			_sphere(hd, r * 1.1, m, Vector3(0, r * 0.25, r * 0.12), Vector3(1.08, 0.86, 1.1))
			_sphere(hd, r * 0.85, m, Vector3(0, -r * 0.55, r * 0.55), Vector3(1.3, 1.2, 0.75))
			for side in [-1.0, 1.0]:
				_sphere(hd, r * 0.5, m, Vector3(side * r * 0.85, -r * 0.35, r * 0.1), Vector3(0.7, 1.4, 1.0))
		"short_neat":
			_sphere(hd, r * 1.04, m, Vector3(0, r * 0.3, r * 0.08), Vector3(1.0, 0.7, 1.04))
		"short_messy":    # Eva: short, messy, falling over the eyes
			_sphere(hd, r * 1.07, m, Vector3(0, r * 0.25, r * 0.08), Vector3(1.05, 0.85, 1.05))
			for i in 8:
				var a := i * 0.8
				_sphere(hd, r * 0.32, m, Vector3(cos(a) * r * 0.85, r * (0.2 + 0.2 * sin(a * 2.0)), sin(a) * r * 0.85))
			_sphere(hd, r * 0.4, m, Vector3(0, r * 0.35, -r * 0.82), Vector3(1.3, 0.8, 0.6))
		"short_curly":    # Thomas: short greying curls
			_sphere(hd, r * 1.05, m, Vector3(0, r * 0.3, r * 0.08), Vector3(1.02, 0.74, 1.05))
			for i in 6:
				var a := i * 1.05
				_sphere(hd, r * 0.24, m, Vector3(cos(a) * r * 0.7, r * 0.62, sin(a) * r * 0.7))
		"bun":
			_sphere(hd, r * 1.04, m, Vector3(0, r * 0.3, r * 0.08), Vector3(1.0, 0.74, 1.04))
			_sphere(hd, r * 0.42, m, Vector3(0, r * 0.45, r * 0.95))
		"receding":
			_sphere(hd, r * 1.03, m, Vector3(0, r * 0.12, r * 0.3), Vector3(1.02, 0.7, 0.85))
		"long_straight":
			_sphere(hd, r * 1.06, m, Vector3(0, r * 0.3, r * 0.08), Vector3(1.0, 0.75, 1.06))
			_box(hd, Vector3(r * 1.9, r * 2.6, r * 0.5), m, Vector3(0, -r * 1.0, r * 0.62))
		"buzz":
			_sphere(hd, r * 1.02, m, Vector3(0, r * 0.32, r * 0.06), Vector3(1.0, 0.66, 1.02))


func _accessories(acc: Array, up: Node3D, o: Vector3, sh_w: float, hip_w: float, depth: float, sh_y: float, chest_y: float,
		head_r: float, k: float) -> void:
	var gold := _mat("9c7a42", 0.35)
	gold.metallic = 0.8
	var front_z := -depth * 0.58 - 0.012
	var hair_c := String(spec.get("hair", {}).get("color", "201a16"))
	for a in acc:
		var s := String(a)
		var arg := ""
		if s.contains(":"):
			arg = s.get_slice(":", 1)
			s = s.get_slice(":", 0)
		match s:
			"ring", "rings":
				_sphere(hand_r, 0.016 * k, gold, Vector3(0.03 * k, -0.01, -0.02)).name = "Ring"
			"watch":
				_box(hand_l, Vector3(0.05 * k, 0.03 * k, 0.05 * k), _mat("1a1715", 0.35), Vector3(0, 0.055 * k, 0)).name = "Watch"
			"tie":
				_box(up, Vector3(0.05 * k, (sh_y - chest_y) * 1.6, 0.012), _mat(arg, 0.6),
					Vector3(0, sh_y - o.y - (sh_y - chest_y) * 0.85, front_z - 0.004))
			"pocket_square":
				_box(up, Vector3(0.06 * k, 0.03 * k, 0.01), _mat("e3d7bf"), Vector3(-sh_w * 0.27, chest_y - o.y + 0.05, front_z))
			"earpiece":
				_sphere(head, head_r * 0.12, _mat("151313", 0.4), Vector3(head_r * 0.92, -head_r * 0.05, 0))
				_cyl(up, 0.004, 0.004, 0.2 * k, _mat("2a2826", 0.4), Vector3(head_r * 0.9, sh_y - o.y + 0.05, 0.02))
			"badge":
				_box(up, Vector3(0.025 * k, 0.025 * k, 0.008), gold, Vector3(-sh_w * 0.27, chest_y - o.y + 0.08, front_z))
			"name_badge":
				_box(up, Vector3(0.07 * k, 0.025 * k, 0.008), gold, Vector3(-sh_w * 0.25, chest_y - o.y + 0.06, front_z - 0.02))
			"apron_long":
				_box(up, Vector3(hip_w * 0.95, _hip_y * 0.95, 0.02), _mat(arg, 0.9),
					Vector3(0, _hip_y - o.y - _hip_y * 0.36, -depth * 0.55 - 0.03))
			"apron_bib":
				_box(up, Vector3(sh_w * 0.62, (sh_y - _hip_y) + _hip_y * 0.55, 0.02), _mat(arg, 0.9),
					Vector3(0, (chest_y + _hip_y * 0.45) / 2.0 - o.y - 0.05, front_z - 0.012))
			"towel":
				_box(up, Vector3(0.12 * k, 0.3 * k, 0.04), _mat("d9cfbc"), Vector3(hip_w * 0.45, _hip_y - o.y - 0.1, -0.05))
			"bag":   # Eva's crossbody bag
				_box(up, Vector3(0.04, (sh_y - _hip_y) * 1.25, 0.015), _mat("1a1716", 0.6),
					Vector3(0, (sh_y + _hip_y) / 2.0 - o.y, front_z - 0.01), Vector3(0, 0, 0.62))
				_box(up, Vector3(0.18 * k, 0.13 * k, 0.07), _mat("1d1a19", 0.55), Vector3(hip_w * 0.42, _hip_y - o.y + 0.02, -0.08))
			"necklace":
				_sphere(up, 0.012, gold, Vector3(0, sh_y - o.y - 0.09, front_z - 0.004))
			"earrings":
				for side in [-1.0, 1.0]:
					_sphere(head, head_r * 0.07, gold, Vector3(side * head_r * 0.9, -head_r * 0.35, 0))
			"radio":
				_box(up, Vector3(0.06, 0.12, 0.04), _mat("151313", 0.5), Vector3(hip_w * 0.45, _hip_y - o.y + 0.04, 0))
			"clutch":
				_box(hand_l, Vector3(0.18 * k, 0.1 * k, 0.04), _mat("2a1c22", 0.5), Vector3(0, -0.02, 0))
			"goatee":
				_box(head, Vector3(head_r * 0.42, head_r * 0.42, head_r * 0.2), _mat(hair_c, 0.8), Vector3(0, -head_r * 0.72, -head_r * 0.78))
			"moustache":
				_box(head, Vector3(head_r * 0.6, head_r * 0.12, head_r * 0.15), _mat(hair_c, 0.8), Vector3(0, -head_r * 0.36, -head_r * 0.92))
			"stubble", "stubble_grey":
				# a faint shadow on the jaw only — never a mask over the face
				var c := Color(String(spec.get("skin", "c69a7c"))).darkened(0.1).lerp(Color(hair_c), 0.12)
				_sphere(head, head_r * 0.95, _mat(c.to_html(false), 0.9), Vector3(0, -head_r * 0.58, -head_r * 0.1), Vector3(0.86, 0.34, 0.92))


# ================================================================== pose & motion

func _rest_key() -> String:
	return String(REST_VARIANT.get(String(spec.get("posture", {}).get("hands", "")), "rest"))


func set_pose(p: String, instant: bool = false) -> void:
	if not POSES.has(p):
		p = "rest"
	pose = p
	var key := _rest_key() if p == "rest" else p
	var targets: Array = POSES[key]
	var k := H / 1.75
	var a: Vector3 = (targets[0] as Vector3) * Vector3(1.0, k, 1.0)
	var b: Vector3 = (targets[1] as Vector3) * Vector3(1.0, k, 1.0)
	_hand_targets = [a, b]
	if hand_l == null:
		return
	if instant or not is_inside_tree():
		hand_l.position = a
		hand_r.position = b
		return
	if _hand_tween:
		_hand_tween.kill()
	_hand_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(hand_l, "position", a, 0.35)
	_hand_tween.tween_property(hand_r, "position", b, 0.35)


## V1.7 body language: authored states shift posture, head and motion amplitude.
func set_mood(m: String) -> void:
	mood = m
	_stance_wide = m == "cornered"   # Thomas holds his ground
	_mood_lean = 0.0
	_mood_chin = 0.0
	_mood_amp = 1.0
	match m:
		"attention": _mood_lean = -0.04; _mood_chin = 0.08
		"bluff": _mood_lean = -0.06; _mood_chin = 0.1
		"uncertain": _mood_lean = 0.06; _mood_chin = -0.12
		"authority": _mood_lean = -0.05; _mood_chin = 0.1; _mood_amp = 0.6
		"control_breaking": _mood_lean = 0.08; _mood_chin = -0.08; _mood_amp = 1.8
		"guarded": _mood_lean = 0.04; _mood_chin = -0.1
		"defiant": _mood_lean = -0.05; _mood_chin = 0.14
		"withdrawn": _mood_lean = 0.1; _mood_chin = -0.16
		"cornered": _mood_lean = -0.03; _mood_chin = 0.04; _mood_amp = 0.4
		"still": _mood_amp = 0.25
		"stress": _mood_amp = 2.2
		"restless": _mood_amp = 2.0


func set_crouch(f: float) -> void:
	_crouch = f
	if rig:
		rig.scale = Vector3(1.0, lerpf(1.0, 0.6, f), 1.0)


func set_color(_c: Color) -> void:
	pass   # proxies take their colours from the canon (kept for API compatibility)


func _process(delta: float) -> void:
	if head == null:
		return
	_t += delta
	var M := _motion()
	# the speed of the body we belong to (hero or NPC) drives the gait
	var v := Vector3.ZERO
	var par := get_parent()
	if par is CharacterBody3D:
		v = (par as CharacterBody3D).velocity
	var speed := Vector2(v.x, v.z).length()
	var walking := speed > 0.25 and _crouch < 0.5
	var running := speed > 3.8 and _crouch < 0.5
	if walking:
		var was := sin(_phase)
		_phase += delta * (4.2 + speed * 1.6)
		if signf(sin(_phase)) != signf(was):
			footfall.emit(running)
		_idle_t = 0.0
	else:
		_idle_t += delta
	var amp := clampf(speed / 3.0, 0.0, 1.0)
	var swing := sin(_phase) * lerpf(0.25, 0.7 if running else 0.6, amp) if walking else 0.0
	# ---- weight: idle bodies shift their weight now and then (stillness is a choice: some rarely do)
	var w_every := float(M.get("weight", 8.0)) / maxf(0.3, _mood_amp)
	_weight_t -= delta
	if _weight_t <= 0.0 and not walking:
		_weight_t = w_every * _rng.randf_range(0.7, 1.4)
		_weight_goal = _rng.randf_range(-1.0, 1.0) * (0.35 if _stance_wide else 1.0)
	if walking:
		_weight_goal = 0.0
	_weight = lerpf(_weight, _weight_goal, minf(1.0, delta * 1.6))
	var spread := 0.07 if _stance_wide else 0.0
	leg_l.rotation.x = lerp_angle(leg_l.rotation.x, swing, minf(1.0, delta * 14.0))
	leg_r.rotation.x = lerp_angle(leg_r.rotation.x, -swing, minf(1.0, delta * 14.0))
	leg_l.rotation.z = lerp_angle(leg_l.rotation.z, -spread + (0.05 * maxf(0.0, _weight)), minf(1.0, delta * 4.0))
	leg_r.rotation.z = lerp_angle(leg_r.rotation.z, spread - (0.05 * maxf(0.0, -_weight)), minf(1.0, delta * 4.0))
	# ---- breathing / sway (exertion after the chase makes it heavy)
	if _exert > 0.0:
		_exert -= delta
	var ex := clampf(_exert / 3.0, 0.0, 1.0)
	var breath := sin(_t * lerpf(1.7, 4.2, ex)) * lerpf(0.012, 0.05, ex) * _mood_amp
	var sway := sin(_t * 0.7 + float(get_instance_id() % 7)) * 0.012 * _mood_amp
	rig.position.y = absf(sin(_phase)) * (0.05 if running else 0.035) * amp if walking else 0.0
	rig.position.x = lerpf(rig.position.x, _weight * 0.03, minf(1.0, delta * 3.0))
	var gait_lean := (0.15 if running else 0.08) * amp if walking else 0.0
	var lean := _lean_base + _mood_lean + gait_lean + 0.28 * ex + _extra_lean
	upper.rotation.x = lerp_angle(upper.rotation.x, -lean + breath, minf(1.0, delta * 5.0))
	upper.rotation.z = sway - _weight * 0.03
	# ---- head: an explicit look target from the owner, else the idle gaze
	var gaze: Variant = look_target
	if _gaze_override_t > 0.0:
		_gaze_override_t -= delta
		gaze = _gaze_override
	elif gaze == null:
		gaze = _idle_gaze(delta, M)
	var target_yaw := 0.0
	var target_pitch := _chin_base + _mood_chin
	if gaze != null:
		var local := to_local(gaze as Vector3) - (upper.position + head.position)
		target_yaw = clampf(atan2(-local.x, -local.z), -1.3, 1.3)
		target_pitch += clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
	# the torso follows the eyes a little (turn the body before the feet), plus authored twists
	var twist := clampf(target_yaw * 0.35, -0.45, 0.45) + _twist_extra
	# restless listeners half-turn to leave while someone is still talking to them (Eva)
	if look_target != null and _speak_t <= 0.0 and _away_t <= 0.0 and float(M.get("turn_away", 0.0)) >= 0.3 \
			and mood in ["restless", "stress"] and _rng.randf() < delta * 0.12:
		_away_t = 1.3
		_away_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	if _away_t > 0.0:
		_away_t -= delta
		twist += 0.75 * _away_sign
		target_yaw += 0.9 * _away_sign
	upper.rotation.y = lerp_angle(upper.rotation.y, twist, minf(1.0, delta * 3.5))
	head.rotation.y = lerp_angle(head.rotation.y, target_yaw - upper.rotation.y, minf(1.0, delta * 6.0))
	head.rotation.x = lerp_angle(head.rotation.x, target_pitch + _nod(delta), minf(1.0, delta * 6.0))
	# ---- hands: pose target + work routine / fidget / speaking overlays + gait swing
	_tick_work(delta, walking)
	var tl: Vector3 = _hand_targets[0]
	var tr: Vector3 = _hand_targets[1]
	var k := H / 1.75
	if running:
		var pump := sin(_phase) * 0.2
		tl = Vector3(-0.22, 1.05 * k, -0.12 - pump)
		tr = Vector3(0.22, 1.05 * k, -0.12 + pump)
	elif _fidget_t > 0.0:
		_fidget_t -= delta
		if _fidget_l != Vector3.INF:
			tl = _fidget_l * Vector3(1, k, 1)
		if _fidget_r != Vector3.INF:
			tr = _fidget_r * Vector3(1, k, 1)
	elif _speak_t > 0.0 and not walking and pose in ["rest", "polish", "work"]:
		var g := float(M.get("talk", 0.6))
		var beat := absf(sin(_t * 3.3)) * g
		tr = Vector3(0.24, 1.02 * k, -0.24) + Vector3(0.05, 0.12, -0.08) * beat
		if g > 1.0:
			tl = Vector3(-0.24, 1.0 * k, -0.22) + Vector3(-0.04, 0.1, -0.06) * absf(sin(_t * 2.7 + 1.0)) * (g - 0.8)
	elif not walking and _idle_t > 1.5 and _fidget_cooldown <= 0.0 and pose == "rest":
		_maybe_fidget(M)
	_fidget_cooldown -= delta
	_speak_t = maxf(0.0, _speak_t - delta)
	var free := pose == "rest" and _rest_key() in ["rest", "front", "gesture"]
	if walking and free and not running and _fidget_t <= 0.0:
		var sw := Vector3(0, 0, swing * 0.22)
		tl -= sw
		tr += sw
	if _hand_tween == null or not _hand_tween.is_running():
		hand_l.position = hand_l.position.lerp(tl, minf(1.0, delta * 8.0))
		hand_r.position = hand_r.position.lerp(tr, minf(1.0, delta * 8.0))
	_reach(_arm_l, _shoulder_l, hand_l.position)
	_reach(_arm_r, _shoulder_r, hand_r.position)


# ================================================================== motion layer (Design + Motion Polish V1)

var _rng := RandomNumberGenerator.new()
var _idle_t := 0.0
var _weight := 0.0
var _weight_goal := 0.0
var _weight_t := 2.0
var _stance_wide := false
var _exert := 0.0
var _extra_lean := 0.0
var _twist_extra := 0.0
var _gaze_t := 1.0
var _gaze_hold := 0.0
var _gaze_pt: Variant = null
var _gaze_override: Variant = null
var _gaze_override_t := 0.0
var _fidget_t := 0.0
var _fidget_l := Vector3.INF
var _fidget_r := Vector3.INF
var _fidget_cooldown := 4.0
var _speak_t := 0.0
var _nod_t := 0.0
var _work_t := 0.0
var _work_step := 0
var _cross_flip := false
var _working := false
var _away_t := 0.0
var _away_sign := 1.0
## Context the owner refreshes a few times a second: {"zone", "people": [heads], "hero": Vector3|null}
var context: Dictionary = {}
var _hero_was_near := false


func _motion() -> Dictionary:
	return spec.get("motion", {})


## The owner says a line: gesture while speaking, a small nod on the beats.
func speak(dur: float) -> void:
	_speak_t = dur
	_nod_t = dur
	# some people turn away before a difficult answer (guarded / restless characters)
	var p := float(_motion().get("turn_away", 0.0))
	if p > 0.0 and (mood in ["guarded", "defiant", "restless", "stress"]) and _rng.randf() < p:
		_away_t = minf(dur, 1.6)
		_away_sign = -1.0 if _rng.randf() < 0.5 else 1.0


## Look somewhere for a moment regardless of the owner's target (hesitation, a reaction).
func gaze_override(point: Vector3, dur: float) -> void:
	_gaze_override = point
	_gaze_override_t = dur


## Winded after running: heavy breathing, a lean, hands to the knees at first.
func exert(dur: float) -> void:
	_exert = dur
	fidget("knees")


## Holding ground (Thomas when cornered): a wider, planted stance.
func set_stance_wide(on: bool) -> void:
	_stance_wide = on


func _nod(delta: float) -> float:
	if _nod_t <= 0.0:
		return 0.0
	_nod_t -= delta
	return sin(_t * 5.5) * 0.04 * float(_motion().get("talk", 0.6))


func _idle_gaze(delta: float, M: Dictionary) -> Variant:
	var par := get_parent() as Node3D
	if par == null:
		return null
	var origin := par.global_position
	var facing := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	# a brief reaction when EL comes close (hero has none: he is the one approaching)
	var hero_pos: Variant = context.get("hero")
	var near: bool = hero_pos != null and (hero_pos as Vector3).distance_to(origin) < 3.2
	if near and not _hero_was_near:
		match String(M.get("react", "none")):
			"look":
				_gaze_pt = (hero_pos as Vector3) + Vector3(0, 1.55, 0)
				_gaze_hold = _rng.randf_range(1.2, 2.0)
				_gaze_t = _gaze_hold + _rng.randf_range(1.0, 2.5)
			"away":
				_gaze_pt = origin + facing.rotated(Vector3.UP, 1.2) * 2.0 + Vector3(0, 0.6, 0)
				_gaze_hold = 1.8
				_gaze_t = 3.0
	_hero_was_near = near
	_gaze_t -= delta
	_gaze_hold -= delta
	if _gaze_t <= 0.0:
		var every := float(M.get("glance", 5.0))
		if mood == "stress" or mood == "restless":
			every *= 0.6
		_gaze_t = every * _rng.randf_range(0.7, 1.4)
		_gaze_hold = float(M.get("glance_dur", 1.4)) * _rng.randf_range(0.8, 1.3)
		var prof := M
		if mood == "stress":
			prof = M.duplicate()
			prof["exits"] = minf(0.85, float(M.get("exits", 0.0)) + 0.35)   # checks the exit
		_gaze_pt = BodyMotion.pick_glance(prof, origin, facing, String(context.get("zone", "")), context.get("people", []), _rng)
	if _gaze_hold > 0.0:
		return _gaze_pt
	return null


func _maybe_fidget(M: Dictionary) -> void:
	var list: Array = M.get("fidgets", [])
	if list.is_empty():
		_fidget_cooldown = 6.0
		return
	var every := float(M.get("fidget_every", 14.0))
	if mood in ["stress", "control_breaking"] and M.has("fidget_every_stressed"):
		every = float(M.fidget_every_stressed)
	_fidget_cooldown = every * _rng.randf_range(0.7, 1.4)
	fidget(String(list[_rng.randi() % list.size()]))


func fidget(name: String) -> void:
	if name == "cross_toggle":
		# Mara: arms crossed, then a moment open, then crossed again
		_cross_flip = not _cross_flip
		var posture: Dictionary = spec.get("posture", {})
		posture["hands"] = "front" if _cross_flip else "crossed"
		set_pose(pose)
		return
	var f: Array = BodyMotion.FIDGETS.get(name, [])
	if f.is_empty():
		return
	var pts: Array = f[1]
	_fidget_l = Vector3.INF
	_fidget_r = Vector3.INF
	match String(f[0]):
		"l": _fidget_l = pts[0]
		"r": _fidget_r = pts[0]
		"both":
			_fidget_l = pts[0]
			_fidget_r = pts[1]
	_fidget_t = float(f[2])


## Work routines that carry on through conversations (Nico / Jules behind the bar): polish a
## glass, set it down, turn to the bottles, lean on the counter — then polish again.
func _tick_work(delta: float, walking: bool) -> void:
	if String(_motion().get("work", "")) != "bar" or walking or not (pose in ["rest", "polish"]):
		_twist_extra = lerpf(_twist_extra, 0.0, minf(1.0, delta * 3.0))
		_extra_lean = lerpf(_extra_lean, 0.0, minf(1.0, delta * 3.0))
		if _working:
			_working = false
			set_pose(pose)   # hands back to the authored pose
		return
	_working = true
	_work_t -= delta
	if _work_t <= 0.0:
		_work_step = (_work_step + 1) % 4
		work_beat.emit(_work_step)
		_work_t = [5.0, 1.6, 2.4, 3.0][_work_step] * _rng.randf_range(0.8, 1.25)
	var k := H / 1.75
	var tw := 0.0
	var ln := 0.0
	match _work_step:
		0:   # polishing a glass
			var c := Vector3(0, 1.08 * k, -0.33)
			_hand_targets = [c + Vector3(-0.08, sin(_t * 6.0) * 0.03, 0), c + Vector3(0.08 + cos(_t * 6.0) * 0.05, 0.02, sin(_t * 6.0) * 0.03)]
		1:   # sets it down
			_hand_targets = [Vector3(-0.2, 0.9 * k, -0.1), Vector3(0.14, 0.98 * k, -0.48)]
			ln = 0.08
		2:   # turns to the bottles
			_hand_targets = [Vector3(-0.22, 0.9 * k, 0.0), Vector3(0.1, 1.25 * k, -0.4)]
			tw = 1.1
		3:   # leans on the counter
			_hand_targets = [Vector3(-0.24, 0.98 * k, -0.42), Vector3(0.24, 0.98 * k, -0.42)]
			ln = 0.14
	_twist_extra = lerpf(_twist_extra, tw, minf(1.0, delta * 2.5))
	_extra_lean = lerpf(_extra_lean, ln, minf(1.0, delta * 2.5))


## Two-segment arm from the shoulder (upper-body space) to a hand target (rig space).
func _reach(arm: Array, shoulder: Vector3, hand_rig: Vector3) -> void:
	if arm.is_empty():
		return
	var inv := upper.transform.affine_inverse()
	var s := shoulder
	var h := inv * hand_rig
	var d := s.distance_to(h)
	var mid := (s + h) * 0.5
	var bend := sqrt(maxf(0.0, _seg * _seg - (d * 0.5) * (d * 0.5)))
	var out := Vector3(signf(s.x) * 0.55, -0.25, 0.6).normalized()
	var elbow := mid + out * bend
	_segment(arm[0], s, elbow)
	_segment(arm[1], elbow, h)


## Place a capsule between two points (upper-body space), stretched by scale (no mesh rebuilds).
func _segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	var base_h := (mi.mesh as CapsuleMesh).height
	mi.basis = Basis(x, y * (len / base_h), z)
	mi.position = (a + b) * 0.5
