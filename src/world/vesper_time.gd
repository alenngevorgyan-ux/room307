class_name VesperTime
extends RefCounted
## One night in five steps (Pass 11 / Motion Polish Pass G): 02:17 night → deep night →
## late night → pre-dawn → cold dawn. Values never jump: the world drifts toward each step over
## a few seconds, and the finale is one long dawn — from the restaurant's staging to the decision
## the cold morning slowly takes the room from the warm lamps. The rain eases off in steps and
## stops with the story (flag rain_stopped).

const STAGES := {
	"night":      {"top": Color(0.06, 0.09, 0.14), "bottom": Color(0.24, 0.17, 0.12), "glow": 1.0, "spill": Color(0.55, 0.68, 0.9), "spill_e": 1.0,
		"tint": Color(1.0, 1.0, 1.0), "fog": Color(0.07, 0.075, 0.09), "sun": Color(0.6, 0.68, 0.85), "sun_e": 0.22, "rain": 1.0, "lift": 1.0, "lamps": 1.0},
	"deep_night": {"top": Color(0.04, 0.06, 0.1), "bottom": Color(0.18, 0.13, 0.1), "glow": 0.9, "spill": Color(0.48, 0.6, 0.88), "spill_e": 0.85,
		"tint": Color(0.92, 0.94, 1.02), "fog": Color(0.05, 0.06, 0.08), "sun": Color(0.5, 0.58, 0.8), "sun_e": 0.16, "rain": 1.0, "lift": 0.9, "lamps": 1.0},
	"late_night": {"top": Color(0.05, 0.07, 0.11), "bottom": Color(0.16, 0.12, 0.11), "glow": 0.9, "spill": Color(0.5, 0.58, 0.82), "spill_e": 0.85,
		"tint": Color(0.9, 0.93, 1.03), "fog": Color(0.05, 0.055, 0.075), "sun": Color(0.5, 0.56, 0.78), "sun_e": 0.16, "rain": 0.85, "lift": 0.9, "lamps": 1.0},
	"predawn":    {"top": Color(0.16, 0.17, 0.28), "bottom": Color(0.3, 0.22, 0.26), "glow": 0.85, "spill": Color(0.62, 0.62, 0.88), "spill_e": 1.1,
		"tint": Color(0.95, 0.95, 1.05), "fog": Color(0.1, 0.1, 0.14), "sun": Color(0.62, 0.62, 0.86), "sun_e": 0.3, "rain": 0.55, "lift": 1.1, "lamps": 0.95},
	"dawn":       {"top": Color(0.42, 0.5, 0.66), "bottom": Color(0.78, 0.6, 0.52), "glow": 0.75, "spill": Color(0.95, 0.82, 0.74), "spill_e": 1.7,
		"tint": Color(1.1, 1.03, 1.0), "fog": Color(0.26, 0.24, 0.27), "sun": Color(1.0, 0.84, 0.7), "sun_e": 1.0, "rain": 0.0, "lift": 1.9, "lamps": 0.6},
}
## Which part of the night each scene sits in.
const SCENE_STAGE := {"S01": "night", "S02": "night", "S03": "night", "S04": "deep_night", "S05": "deep_night",
	"S06": "late_night", "S07": "late_night", "S08": "predawn", "S09": "predawn", "EPI": "dawn"}
const DRIFT := 0.35            # per second toward the target (a few seconds to settle)
const FINALE_SEC := 420.0      # the finale's dawn takes about seven minutes

static var stage := "night"
static var cur: Dictionary = {}
static var _window_mat: ShaderMaterial = null
static var _skyline_mat: ShaderMaterial = null
static var window_glass: Variant = null      # (kept for API compatibility)
static var window_lights: Array = []
static var wet_floor: ShaderMaterial = null   # set by VesperLook (no static ref: tests compile before autoloads)


static func stage_for(scene_id: String, _phase: String) -> String:
	return String(SCENE_STAGE.get(scene_id, "night"))


## The finale's dawn progress (0 = staging begins, 1 = full cold morning).
static func dawn_progress(ep: Node) -> float:
	if ep.scene_id == "EPI":
		return 1.0
	if ep.scene_id != "S09":
		return 0.0
	var p := clampf(float(ep.scene_clock) / FINALE_SEC, 0.0, 1.0)
	match String(ep.phase_name()):
		"S09_LIVE": p = maxf(p, 0.45)
		"S09_DECISION": p = maxf(p, 0.85)
	return p


static func target(ep: Node) -> Dictionary:
	var s := stage_for(ep.scene_id, ep.phase_name())
	var t: Dictionary = STAGES[s].duplicate()
	if ep.scene_id == "S09":
		t = _mix(STAGES.predawn, STAGES.dawn, smoothstep(0.0, 1.0, dawn_progress(ep)))
	if ep.flags.get("rain_stopped", false):
		t["rain"] = 0.0
	return t


static func _mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for k in a:
		var va: Variant = a[k]
		var vb: Variant = b[k]
		out[k] = (va as Color).lerp(vb, w) if va is Color else lerpf(float(va), float(vb), w)
	return out


static func window_material() -> ShaderMaterial:
	if _window_mat == null:
		_window_mat = ShaderMaterial.new()
		_window_mat.shader = preload("res://src/world/vesper_window.gdshader")
	return _window_mat


static func skyline_material() -> ShaderMaterial:
	if _skyline_mat == null:
		_skyline_mat = ShaderMaterial.new()
		_skyline_mat.shader = preload("res://src/world/vesper_window.gdshader")
		_skyline_mat.set_shader_parameter("mode", 1)
	return _skyline_mat


static func reset() -> void:
	stage = ""
	cur = {}
	window_lights.clear()


## Drift the world toward the current target (call every frame).
static func update(world: Node, ep: Node, delta: float) -> void:
	var t := target(ep)
	stage = stage_for(ep.scene_id, ep.phase_name())
	if cur.is_empty():
		cur = t.duplicate()
	else:
		cur = _mix(cur, t, minf(1.0, delta * DRIFT))
	_apply(world)


## Jump straight to the current target (world build, debug jumps, tests).
static func snap(world: Node, ep: Node) -> void:
	cur = target(ep)
	stage = stage_for(ep.scene_id, ep.phase_name())
	_apply(world)


static func _apply(world: Node) -> void:
	var m := window_material()
	m.set_shader_parameter("sky_top", cur.top)
	m.set_shader_parameter("sky_bottom", cur.bottom)
	m.set_shader_parameter("energy", float(cur.glow))
	m.set_shader_parameter("rain", float(cur.rain))
	var sk := skyline_material()
	sk.set_shader_parameter("sky_top", cur.top)
	sk.set_shader_parameter("energy", lerpf(1.0, 0.3, clampf(float(cur.lift) - 1.0, 0.0, 1.0)))
	for l in world.get_tree().get_nodes_in_group("vesper_window_light"):
		var o := l as OmniLight3D
		o.light_color = cur.spill
		o.light_energy = float(o.get_meta("base_energy", 1.0)) * float(cur.spill_e)
	for l in world.get_tree().get_nodes_in_group("vesper_practical"):
		var o := l as OmniLight3D
		o.light_energy = float(o.get_meta("base_energy", 1.0)) * float(cur.lamps) * float(o.get_meta("flicker", 1.0))
	var e: Environment = world.env.environment
	e.fog_light_color = cur.fog
	world.sun.light_color = cur.sun
	world.sun.light_energy = float(cur.sun_e)
	for zid in world.zones:
		var rain: Node = world.zones[zid].get_node_or_null("Rain")
		if rain:
			var r := float(cur.rain)
			(rain as CPUParticles3D).emitting = r > 0.02
			if "amount_ratio" in rain:
				rain.set("amount_ratio", clampf(r, 0.05, 1.0))
	if wet_floor:
		wet_floor.set_shader_parameter("ripple", float(cur.rain))


## Ambient tint and exterior lift for the current moment (HotelWorld blends the wing ambient).
static func ambient(wing: String, base: Color, energy: float) -> Array:
	if cur.is_empty():
		return [base, energy]
	var c: Color = base * (cur.tint as Color)
	var e := energy * (float(cur.lift) if wing == "EXTERIOR" else 1.0)
	return [c, e]
