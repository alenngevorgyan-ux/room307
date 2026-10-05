class_name VesperTime
extends RefCounted
## Visual Integration V1.8 — one night in five steps (Pass 11): 02:17 night → deep night →
## late night → pre-dawn → cold dawn. Each step re-tints the world through a few shared handles:
## the ambient tint, the fog, the window glass and its cool spill, the exterior light, and the
## rain (which stops at the end of Scene 08: flag rain_stopped). Warm practicals stay; the outside changes.

## stage: [window glow, window spill, ambient tint (multiplies the wing ambient), fog colour,
##         sun colour, sun energy, rain on, exterior ambient lift]
const STAGES := {
	"night": [Color(0.16, 0.24, 0.33), Color(0.55, 0.68, 0.9), Color(1.0, 1.0, 1.0), Color(0.07, 0.075, 0.09), Color(0.6, 0.68, 0.85), 0.22, true, 1.0],
	"deep_night": [Color(0.11, 0.17, 0.26), Color(0.48, 0.6, 0.88), Color(0.92, 0.94, 1.02), Color(0.05, 0.06, 0.08), Color(0.5, 0.58, 0.8), 0.16, true, 0.9],
	"late_night": [Color(0.12, 0.16, 0.24), Color(0.5, 0.58, 0.82), Color(0.9, 0.93, 1.03), Color(0.05, 0.055, 0.075), Color(0.5, 0.56, 0.78), 0.16, true, 0.9],
	"predawn": [Color(0.24, 0.24, 0.36), Color(0.6, 0.62, 0.88), Color(0.95, 0.95, 1.05), Color(0.1, 0.1, 0.14), Color(0.62, 0.62, 0.86), 0.3, true, 1.1],
	"dawn": [Color(0.55, 0.5, 0.58), Color(0.9, 0.78, 0.74), Color(1.05, 1.0, 1.0), Color(0.2, 0.19, 0.22), Color(0.98, 0.8, 0.68), 0.6, false, 1.35],
}
## Which part of the night each scene sits in.
const SCENE_STAGE := {"S01": "night", "S02": "night", "S03": "night", "S04": "deep_night", "S05": "deep_night",
	"S06": "late_night", "S07": "late_night", "S08": "predawn", "S09": "predawn", "EPI": "dawn"}

static var stage := "night"
static var window_glass: StandardMaterial3D = null
static var window_lights: Array = []


static func stage_for(scene_id: String, phase: String) -> String:
	if phase in ["S09_LIVE", "S09_DECISION"]:
		return "dawn"   # the decision is made as the light comes up
	return String(SCENE_STAGE.get(scene_id, "night"))


static func apply(world: Node, s: String) -> void:
	if not STAGES.has(s):
		return
	stage = s
	var v: Array = STAGES[s]
	if window_glass:
		window_glass.albedo_color = v[0]
		window_glass.emission = v[0]
	for l in window_lights:
		if is_instance_valid(l):
			(l as OmniLight3D).light_color = v[1]
	var e: Environment = world.env.environment
	e.fog_light_color = v[3]
	world.sun.light_color = v[4]
	world.sun.light_energy = float(v[5])
	for zid in world.zones:
		var rain: Node = world.zones[zid].get_node_or_null("Rain")
		if rain:
			(rain as CPUParticles3D).emitting = bool(v[6]) and not world.get_node("/root/Episode").flags.get("rain_stopped", false)


## Ambient tint and exterior lift for the current stage (HotelWorld blends the wing ambient).
static func ambient(wing: String, base: Color, energy: float) -> Array:
	var v: Array = STAGES.get(stage, STAGES.night)
	var c: Color = base * (v[2] as Color)
	var e := energy * (float(v[7]) if wing == "EXTERIOR" else 1.0)
	return [c, e]
