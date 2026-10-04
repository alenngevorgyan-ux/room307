class_name BodyVisual
extends Node3D
## Graybox character: capsule + head sphere + nose wedge (facing) + coloured band + two hand
## cylinders (for hand tells). Poses are procedural tweens so polish can swap in clips later.

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
}

var body: MeshInstance3D
var head: Node3D
var nose: MeshInstance3D
var hand_l: MeshInstance3D
var hand_r: MeshInstance3D
var band: MeshInstance3D
var pose := "rest"
var look_target: Variant = null    # Vector3 world or null
var _crouch := 0.0
var _scale := 1.0
var _skin := Color(0.86, 0.72, 0.62)


func build(c: Color, scale_f: float = 1.0, extra: Dictionary = {}) -> void:
	_scale = scale_f
	var vis := Node3D.new()
	vis.name = "Visual"
	add_child(vis)
	body = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.55
	body.mesh = cap
	body.position = Vector3(0, 0.78, 0)
	body.material_override = Graybox.mat(c.lerp(Color(0.32, 0.32, 0.34), 0.7))
	vis.add_child(body)
	band = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.295
	bm.bottom_radius = 0.295
	bm.height = 0.16
	band.mesh = bm
	band.position = Vector3(0, 1.18, 0)
	band.material_override = Graybox.mat(c)
	vis.add_child(band)
	head = Node3D.new()
	head.position = Vector3(0, 1.68, 0)
	vis.add_child(head)
	var hm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	hm.mesh = sm
	hm.material_override = Graybox.mat(_skin)
	head.add_child(hm)
	nose = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.08, 0.1, 0.12)
	nose.mesh = pm
	nose.rotation_degrees = Vector3(-90, 0, 0)
	nose.position = Vector3(0, 0, -0.19)
	nose.material_override = Graybox.mat(_skin.darkened(0.15))
	head.add_child(nose)
	hand_l = _hand(vis)
	hand_r = _hand(vis)
	if extra.get("ring", false):
		var r := MeshInstance3D.new()
		var rm := SphereMesh.new()
		rm.radius = 0.035
		rm.height = 0.07
		r.mesh = rm
		r.material_override = Graybox.mat(Color(0.95, 0.75, 0.2), 0.6)
		r.position = Vector3(0.05, 0, 0)
		hand_r.add_child(r)
	if extra.get("cap", false):
		var capm := Graybox.box_mesh(Vector3(0.36, 0.08, 0.4), c.darkened(0.3))
		capm.position = Vector3(0, 0.16, -0.04)
		head.add_child(capm)
	if extra.get("apron", false):
		var ap := Graybox.box_mesh(Vector3(0.42, 0.6, 0.05), Color(0.9, 0.9, 0.88))
		ap.position = Vector3(0, 0.75, -0.28)
		vis.add_child(ap)
	if extra.get("pocket_stud", false):
		var ps := Graybox.box_mesh(Vector3(0.03, 0.12, 0.03), Color(0.8, 0.8, 0.85), 0.3)
		ps.position = Vector3(-0.12, 1.36, -0.27)
		vis.add_child(ps)
	vis.scale = Vector3.ONE * scale_f
	set_pose("rest", true)


func _hand(parent: Node3D) -> MeshInstance3D:
	var h := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.06
	cm.height = 0.2
	h.mesh = cm
	h.material_override = Graybox.mat(_skin)
	parent.add_child(h)
	return h


func set_pose(p: String, instant: bool = false) -> void:
	if not POSES.has(p):
		p = "rest"
	pose = p
	var targets: Array = POSES[p]
	if instant:
		hand_l.position = targets[0]
		hand_r.position = targets[1]
		return
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	t.tween_property(hand_l, "position", targets[0] as Vector3, 0.35)
	t.tween_property(hand_r, "position", targets[1] as Vector3, 0.35)


func set_crouch(f: float) -> void:
	_crouch = f
	var vis: Node3D = get_node("Visual")
	vis.scale = Vector3(_scale, _scale * lerpf(1.0, 0.6, f), _scale)


func set_color(c: Color) -> void:
	band.material_override = Graybox.mat(c)


func _process(delta: float) -> void:
	if head == null:
		return
	var target_yaw := 0.0
	var target_pitch := 0.0
	if look_target != null:
		var local := to_local(look_target as Vector3) - head.position
		target_yaw = clampf(atan2(-local.x, -local.z), -1.2, 1.2)
		target_pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
	head.rotation.y = lerp_angle(head.rotation.y, target_yaw, minf(1.0, delta * 6.0))
	head.rotation.x = lerp_angle(head.rotation.x, target_pitch, minf(1.0, delta * 6.0))
