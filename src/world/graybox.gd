class_name Graybox
extends RefCounted
## Graybox palette + primitive factory (LEVEL_LAYOUT §8). Gameplay never references these meshes;
## they live under a "Visual" node so art can replace them.

const LAYER_WORLD := 1
const LAYER_NPC := 2
const LAYER_HERO := 4
const LAYER_TRIGGER := 8
const LAYER_SLIDE := 16   # obstacles only a crouching/sliding hero can pass under

const COLORS := {
	"floor": Color(0.16, 0.16, 0.18),
	"wall": Color(0.36, 0.36, 0.39),
	"furn": Color(0.42, 0.40, 0.38),
	"cover": Color(0.42, 0.29, 0.18),
	"vault": Color(0.44, 0.42, 0.36),
	"stripe": Color(0.92, 0.78, 0.15),
	"door": Color(0.28, 0.24, 0.22),
	"trim": Color(0.95, 0.52, 0.12),
	"interact": Color(0.2, 0.85, 0.95),
	"glass": Color(0.45, 0.6, 0.75, 0.25),
	"counter": Color(0.33, 0.22, 0.16),
	"metal": Color(0.5, 0.52, 0.55),
	"cloth": Color(0.85, 0.85, 0.82),
	"dark": Color(0.08, 0.08, 0.09),
	"accent_warm": Color(0.55, 0.32, 0.18),
	"accent_service": Color(0.18, 0.4, 0.38),
	"accent_cold": Color(0.3, 0.42, 0.55),
	"accent_purple": Color(0.35, 0.22, 0.45),
	"accent_red": Color(0.5, 0.15, 0.13),
	"accent_gold": Color(0.6, 0.48, 0.2),
}

static var _mats: Dictionary = {}


static func color(c: Variant) -> Color:
	if c is Color:
		return c
	if typeof(c) == TYPE_STRING:
		return COLORS.get(c, Color.MAGENTA)
	if typeof(c) == TYPE_ARRAY:
		if c.size() >= 4:
			return Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color.MAGENTA


static func mat(c: Color, emissive: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [c.to_html(), emissive, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func box_mesh(size: Vector3, c: Color, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emissive)
	return mi


## A solid box: StaticBody3D at centre `pos` with a visual child. Returns the body.
static func solid(parent: Node3D, name: String, pos: Vector3, size: Vector3, c: Color, layer: int = LAYER_WORLD,
		collide: bool = true) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	root.name = name
	root.position = pos
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.add_child(box_mesh(size, c))
	root.add_child(vis)
	parent.add_child(root)
	return root


static func label3d(text: String, size: int = 48, c: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = c
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.double_sided = true
	return l
