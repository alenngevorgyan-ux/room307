extends Node
## Data — loads all JSON under data/ep01 at boot.
## Every category may live in `<cat>.json` and/or `<cat>/*.json`; files are merged and
## duplicate ids are reported as errors (lets scene content be authored in parallel).

const ROOT := "res://data/ep01/"
const CATEGORIES := ["facts", "observations", "threads", "claims", "characters", "items",
	"exchanges", "traps", "overhears", "schedules", "interactables", "chase", "finale",
	"lines_ru", "cines", "scenes", "level", "hints", "phone"]

var facts: Dictionary = {}
var observations: Dictionary = {}
var threads: Dictionary = {}
var claims: Dictionary = {}
var characters: Dictionary = {}
var items: Dictionary = {}
var exchanges: Dictionary = {}
var traps: Dictionary = {}
var overhears: Dictionary = {}
var schedules: Dictionary = {}
var interactables: Dictionary = {}
var chase: Dictionary = {}
var finale: Dictionary = {}
var lines_ru: Dictionary = {}
var cines: Dictionary = {}
var scenes: Dictionary = {}
var level: Dictionary = {}
var hints: Dictionary = {}
var phone: Dictionary = {}

var load_errors: Array = []
var _zone_origin_cache: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	load_errors.clear()
	_zone_origin_cache.clear()
	for cat in CATEGORIES:
		set(cat, _load_category(cat))
	if not load_errors.is_empty():
		for e in load_errors:
			push_error("[Data] " + e)


func _load_category(cat: String) -> Dictionary:
	var out: Dictionary = {}
	var single := ROOT + cat + ".json"
	if FileAccess.file_exists(single):
		_merge(out, _read_json(single), single)
	var dir_path := ROOT + cat
	var dir := DirAccess.open(dir_path)
	if dir:
		var files: Array = []
		for f in dir.get_files():
			if f.ends_with(".json"):
				files.append(f)
		files.sort()
		for f in files:
			var p: String = dir_path + "/" + f
			_merge(out, _read_json(p), p)
	return out


func _merge(into: Dictionary, src: Variant, path: String) -> void:
	if typeof(src) != TYPE_DICTIONARY:
		load_errors.append("%s: top level must be an object" % path)
		return
	for k in src:
		if String(k).begins_with("_"):
			continue   # comments / metadata
		if into.has(k):
			load_errors.append("%s: duplicate id %s" % [path, k])
		into[k] = src[k]


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_errors.append("cannot open " + path)
		return {}
	var txt := f.get_as_text()
	var j := JSON.new()
	var err := j.parse(txt)
	if err != OK:
		load_errors.append("%s:%d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return {}
	return j.data


# ---------------------------------------------------------------- lookups

func line(key: String) -> Dictionary:
	var l: Variant = lines_ru.get(key)
	if l == null:
		return {"speaker": "?", "text": "[" + key + "]", "dur": 1.5}
	var d: Dictionary = l.duplicate()
	if not d.has("dur"):
		d["dur"] = line_duration(String(d.get("text", "")))
	return d


static func line_duration(text: String) -> float:
	return clampf(1.2 + text.length() * 0.055, 1.6, 7.0)


func character(npc: String) -> Dictionary:
	return characters.get(npc, {})


func npc_display(npc: String) -> String:
	if npc == "hero":
		return "Я"
	return String(characters.get(npc, {}).get("display", npc))


func zone(zone_id: String) -> Dictionary:
	return level.get(zone_id, {})


func zone_origin(zone_id: String) -> Vector3:
	if _zone_origin_cache.has(zone_id):
		return _zone_origin_cache[zone_id]
	var z := zone(zone_id)
	var o := vec3(z.get("origin", [0, 0, 0]))
	_zone_origin_cache[zone_id] = o
	return o


## "ZONE:marker" -> world position. Markers live in level[zone].markers as [x,z] or [x,y,z].
func marker(ref: String) -> Vector3:
	var parts := ref.split(":")
	if parts.size() != 2:
		push_warning("bad marker ref " + ref)
		return Vector3.ZERO
	var z := zone(parts[0])
	var m: Variant = z.get("markers", {}).get(parts[1])
	if m == null:
		push_warning("missing marker " + ref)
		return zone_origin(parts[0])
	return zone_origin(parts[0]) + vec3(m)


func has_marker(ref: String) -> bool:
	var parts := ref.split(":")
	return parts.size() == 2 and zone(parts[0]).get("markers", {}).has(parts[1])


func marker_zone(ref: String) -> String:
	return ref.split(":")[0]


## Accepts [x,z] (y=0) or [x,y,z].
static func vec3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	if typeof(a) != TYPE_ARRAY:
		return Vector3.ZERO
	if a.size() == 2:
		return Vector3(float(a[0]), 0.0, float(a[1]))
	if a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


## Which zone contains a world point (by block footprint).
func zone_at(p: Vector3) -> String:
	for zid in level:
		var z: Dictionary = level[zid]
		var o := zone_origin(zid)
		var s: Array = z.get("size", [10, 10])
		var local := p - o
		if local.x >= -0.5 and local.x <= float(s[0]) + 0.5 and local.z >= -0.5 and local.z <= float(s[1]) + 0.5 \
				and local.y > -2.0 and local.y < float(z.get("height", 4.0)) + 6.0:
			return zid
	return ""


## Doorway graph: zone -> [{door, to_zone, to_door}]
func door_graph() -> Dictionary:
	var g: Dictionary = {}
	for zid in level:
		g[zid] = []
		for d in level[zid].get("doors", []):
			if d.has("to"):
				var target: String = d.to
				g[zid].append({"door": d.id, "to_zone": door_zone(target), "to_door": target})
	return g


func door_zone(door_id: String) -> String:
	for zid in level:
		for d in level[zid].get("doors", []):
			if d.id == door_id:
				return zid
	return ""


func door_def(door_id: String) -> Dictionary:
	for zid in level:
		for d in level[zid].get("doors", []):
			if d.id == door_id:
				var c: Dictionary = d.duplicate()
				c["zone"] = zid
				return c
	return {}


## BFS route of door ids from zone a to zone b (doors to walk through, in order).
func route(a: String, b: String) -> Array:
	if a == b:
		return []
	var g := door_graph()
	var prev: Dictionary = {a: null}
	var q: Array = [a]
	while not q.is_empty():
		var cur: String = q.pop_front()
		for e in g.get(cur, []):
			if e.get("locked_for_npc", false):
				continue
			var nz: String = e.to_zone
			if nz == "" or prev.has(nz):
				continue
			prev[nz] = {"from": cur, "door": e.door}
			if nz == b:
				var path: Array = []
				var z: String = b
				while prev[z] != null:
					path.push_front(prev[z].door)
					z = prev[z].from
				return path
			q.append(nz)
	return []
