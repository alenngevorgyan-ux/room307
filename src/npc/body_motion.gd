class_name BodyMotion
extends RefCounted
## Design + Motion Polish V1 — the motion vocabulary of the proxy rigs (visual only: nothing here
## changes positions, perception or any gameplay state). BodyVisual asks it for:
##   - fidgets: brief authored hand moves (adjust a cuff, touch the lapel, check a pocket …),
##   - points of interest in a zone (doors = exits, windows) for idle glances,
##   - an idle glance target chosen from the character's profile (people / exits / windows / down).
## Profiles live in data/ep01/proxies.json → "motion".

## name: [hand ("l"|"r"|"both"), target (rig space at 1.75 m), seconds]
const FIDGETS := {
	"cuff": ["both", [Vector3(0.16, 0.98, -0.24), Vector3(0.22, 0.95, -0.2)], 1.6],     # adjusts a cuff
	"lapel": ["r", [Vector3(0.1, 1.33, -0.19)], 1.4],                                    # straightens the jacket
	"face": ["r", [Vector3(0.05, 1.5, -0.17)], 2.0],                                     # hand to chin
	"hair": ["r", [Vector3(0.12, 1.66, -0.05)], 1.1],
	"pocket_check": ["l", [Vector3(0.06, 1.25, -0.24)], 0.9],                             # touches the phone pocket
	"apron": ["both", [Vector3(-0.07, 0.96, -0.24), Vector3(0.08, 0.95, -0.24)], 1.6],   # wipes hands on the apron
	"radio": ["r", [Vector3(0.18, 1.5, -0.12)], 1.5],
	"wrist": ["l", [Vector3(-0.1, 1.16, -0.32)], 1.6],                                   # looks at a bare wrist
	"beckon": ["r", [Vector3(0.38, 1.12, -0.32)], 1.0],                                  # "this way"
	"knees": ["both", [Vector3(-0.16, 0.62, -0.3), Vector3(0.16, 0.62, -0.3)], 1.8],     # winded, hands on knees
}

static var _zone_cache: Dictionary = {}


static func reset_cache() -> void:
	_zone_cache.clear()


## Exits (doorways) and windows of a zone, as world points at eye height.
static func zone_points(zone_id: String) -> Dictionary:
	if _zone_cache.has(zone_id):
		return _zone_cache[zone_id]
	var out := {"exits": [], "windows": []}
	if Services.world:
		var z: Node = Services.world.zone_node(zone_id)
		if z:
			for did in z.doors:
				var d: Node3D = z.doors[did]
				if String(d.def.get("kind", "door")) != "hidden":
					out.exits.append(d.global_position + Vector3(0, 1.4, 0))
			var geo: Node = z.get_node_or_null("Geometry")
			if geo:
				for n in geo.get_children():
					var def: Dictionary = n.get_meta("def", {})
					if String(def.get("k", "")) == "glass" and Data.vec3(def.get("s", [0, 0, 0])).y > 0.5:
						out.windows.append((n as Node3D).global_position)
	_zone_cache[zone_id] = out
	return out


## Pick an idle glance target. `people` are other heads nearby; `origin` is the body position.
static func pick_glance(profile: Dictionary, origin: Vector3, facing: Vector3, zone_id: String, people: Array, rng: RandomNumberGenerator) -> Variant:
	var pts := zone_points(zone_id)
	var r := rng.randf()
	var acc := 0.0
	for kind in ["people", "exits", "windows", "down"]:
		acc += float(profile.get(kind, 0.0))
		if r > acc:
			continue
		match kind:
			"people":
				if not people.is_empty():
					return people[rng.randi() % people.size()]
			"exits":
				if not pts.exits.is_empty():
					return _nearest_few(pts.exits, origin, rng)
			"windows":
				if not pts.windows.is_empty():
					return _nearest_few(pts.windows, origin, rng)
			"down":
				return origin + facing * 1.2 + Vector3(0, 0.2, 0)
		break
	# otherwise a neutral look a little off to one side
	var side := facing.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
	return origin + side * 4.0 + Vector3(0, 1.55, 0)


static func _nearest_few(points: Array, origin: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var sorted := points.duplicate()
	sorted.sort_custom(func(a, b): return (a as Vector3).distance_to(origin) < (b as Vector3).distance_to(origin))
	return sorted[rng.randi() % mini(2, sorted.size())]
