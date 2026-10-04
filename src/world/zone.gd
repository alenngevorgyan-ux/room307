class_name Zone
extends Node3D
## One hotel block, built from data/ep01/level/*.json by LevelBuilder.
## Holds its camera rigs and camera sub-zones (zone-local coordinates).

var zone_id: String = ""
var def: Dictionary = {}
var size := Vector2(10, 10)
var rigs: Dictionary = {}
var camzones: Array = []     # [{rig, rect: Rect2}] in zone-local XZ
var doors: Dictionary = {}   # door_id -> Doorway
var lights_root: Node3D


func local(p: Vector3) -> Vector3:
	return p - global_position


func contains(p: Vector3, margin: float = 0.5) -> bool:
	var l := local(p)
	return l.x >= -margin and l.x <= size.x + margin and l.z >= -margin and l.z <= size.y + margin \
		and l.y > -2.0 and l.y < float(def.get("height", 4.0)) + 6.0


## Rig id for a world position (sub-zones first, else "main").
func rig_id_at(p: Vector3) -> String:
	var l := local(p)
	var best := ""
	var best_area := INF
	for cz in camzones:
		var r: Rect2 = cz.rect
		var yr: Array = cz.get("y", [-100, 100])
		if r.has_point(Vector2(l.x, l.z)) and l.y >= float(yr[0]) and l.y <= float(yr[1]):
			var a := r.get_area()
			if a < best_area:
				best_area = a
				best = cz.rig
	return best if best != "" else "main"


func rig(id: String) -> Dictionary:
	return rigs.get(id, rigs.get("main", {}))
