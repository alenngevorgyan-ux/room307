extends TestCase
## M7 navigation smoke: every doorway target exists, spawn points land inside the target zone,
## and every playable zone is reachable from the lobby through the door graph.


func test_door_targets_and_spawns() -> void:
	var D := data()
	for zid in D.level:
		for dd in D.level[zid].get("doors", []):
			var targets: Array = [String(dd.get("to", ""))]
			if dd.has("to_by_flag"):
				for k in dd.to_by_flag.map:
					targets.append(String(dd.to_by_flag.map[k]))
			for t in targets:
				if t == "":
					continue
				var td: Dictionary = D.door_def(t)
				check(not td.is_empty(), "%s -> %s exists" % [dd.id, t])
				if td.is_empty():
					continue
				var tz: String = td.zone
				var size: Array = D.level[tz].get("size", [10, 10])
				var n := Vector3.ZERO
				match String(td.get("side", "N")):
					"N", "F": n = Vector3(0, 0, 1)
					"S": n = Vector3(0, 0, -1)
					"W": n = Vector3(1, 0, 0)
					"E": n = Vector3(-1, 0, 0)
				var sp: Vector3 = Data.vec3(td.p) + n * float(td.get("spawn_in", 1.1))
				check(sp.x > -0.1 and sp.x < float(size[0]) + 0.1 and sp.z > -0.1 and sp.z < float(size[1]) + 0.1,
					"spawn of %s inside %s (%s)" % [t, tz, sp])


func test_all_zones_reachable() -> void:
	var D := data()
	for zid in D.level:
		if zid == "LOBBY":
			continue
		var r: Array = D.route("LOBBY", zid)
		var back: Array = D.route(zid, "LOBBY")
		check(not r.is_empty(), "LOBBY -> %s" % zid)
		check(not back.is_empty(), "%s -> LOBBY" % zid)


func test_markers_inside_zones() -> void:
	var D := data()
	for zid in D.level:
		var size: Array = D.level[zid].get("size", [10, 10])
		for m in D.level[zid].get("markers", {}):
			if String(m).begins_with("off_"):
				continue
			var p := Data.vec3(D.level[zid].markers[m])
			check(p.x >= -0.5 and p.x <= float(size[0]) + 0.5 and p.z >= -2.0 and p.z <= float(size[1]) + 0.5,
				"%s:%s inside (%s)" % [zid, m, p])


## Playtest finding 8 ("thrown back"): a door must never deliver the hero into solid geometry
## (physics depenetration shoves him) and its spawn must stay reachable on foot.
func test_door_spawns_clear_of_solids() -> void:
	var D := data()
	for zid in D.level:
		var z: Dictionary = D.level[zid]
		for dd in z.get("doors", []):
			if String(dd.get("kind", "")) == "hidden":
				continue
			var n := Vector3.ZERO
			match String(dd.get("side", "N")):
				"N", "F": n = Vector3(0, 0, 1)
				"S": n = Vector3(0, 0, -1)
				"W": n = Vector3(1, 0, 0)
				"E": n = Vector3(-1, 0, 0)
			var dp := Data.vec3(dd.p)
			var sp := dp + n * float(dd.get("spawn_in", 1.1))
			for b in z.get("boxes", []):
				if b.get("nocol", false) or b.has("rot"):
					continue
				var bp: Array = b.p
				var bs := Data.vec3(b.s)
				var bottom := float(bp[1]) if bp.size() >= 3 else 0.0
				if bottom > dp.y + 1.0 or bottom + bs.y <= dp.y + 0.25:
					continue   # overhead, or a floor/landing within step height of the door
				var c := Data.vec3(bp)
				var inside := absf(sp.x - c.x) < bs.x / 2.0 + 0.3 and absf(sp.z - c.z) < bs.z / 2.0 + 0.3
				check(not inside, "%s spawn %s inside %s:%s" % [dd.id, sp, zid, b.get("id", "?")])
