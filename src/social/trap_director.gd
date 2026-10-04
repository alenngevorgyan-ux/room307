class_name TrapDirector
extends Node
## Traps are armed condition sets waiting for a bait event (STATE_MODEL §8). Never a menu.
##
## Trap JSON:
##   target, bait {event, <key>: value|[values]}, environment {zones:[...], cond},
##   audience {forbid:[...], require:[...]}, object: cond, timing {after_beat, scene, phase},
##   requires: cond, repeatable: bool, priority: int,
##   outcomes: [{if: cond, do:[...]}, ..., {else: true, do:[...]}]
## Outcome conditions may also use event-context keys: audience_has, audience_lacks, addressee.


func _ready() -> void:
	Services.traps = self
	var B := get_node("/root/Bus")
	B.trap_bait.connect(func(ev: String, d: Dictionary):
		var e := d.duplicate()
		e["event"] = ev
		try_bait(e))
	B.stage_point_changed.connect(func(p: String, v: String):
		try_bait({"event": "stage_point_changed", "point": p, "value": v}))
	B.item_changed.connect(func(i: String, h: String):
		try_bait({"event": "item_changed", "item": i, "holder": h}))
	B.world_beat.connect(func(b: String):
		try_bait({"event": "world_beat", "beat": b}))


func _exit_tree() -> void:
	if Services.traps == self:
		Services.traps = null


func _ep() -> Node:
	return get_node("/root/Episode")


func _data() -> Node:
	return get_node("/root/Data")


func runtime(tid: String) -> Dictionary:
	var ts: Dictionary = _ep().trap_state
	if not ts.has(tid):
		ts[tid] = {"armed": false, "fired": false, "outcome_index": -1}
	return ts[tid]


## Conditions currently satisfied (everything except the bait itself).
func is_armed(tid: String, ev: Dictionary = {}) -> bool:
	var t: Dictionary = _data().traps.get(tid, {})
	var rt := runtime(tid)
	if rt.fired and not t.get("repeatable", false):
		return false
	var E := _ep()
	var timing: Dictionary = t.get("timing", {}) if t.get("timing") != null else {}
	if timing.has("after_beat") and not E.beats.has(String(timing.after_beat)):
		return false
	if timing.has("scene"):
		var sc: Variant = timing.scene
		if typeof(sc) == TYPE_ARRAY:
			if not sc.has(E.scene_id):
				return false
		elif E.scene_id != String(sc):
			return false
	if timing.has("phase") and E.phase_name() != String(timing.phase):
		return false
	var env: Dictionary = t.get("environment", {}) if t.get("environment") != null else {}
	if env.has("zones"):
		var hz := _hero_zone()
		if not Array(env.zones).has(hz):
			return false
	if env.has("cond") and not Conditions.check(env.cond, E):
		return false
	if t.get("object") != null and not Conditions.check(t.object, E):
		return false
	if t.has("requires") and not Conditions.check(t.requires, E):
		return false
	var aud_spec: Dictionary = t.get("audience", {}) if t.get("audience") != null else {}
	var aud: Array = ev.get("audience", Presence.audience_of("hero"))
	for f in aud_spec.get("forbid", []):
		if aud.has(String(f)):
			return false
	for r in aud_spec.get("require", []):
		if not aud.has(String(r)):
			return false
	rt.armed = true
	return true


func _hero_zone() -> String:
	var z := Presence.in_zone("hero")
	return z if z != "" else String(_ep().hero_zone)


func _bait_matches(bait: Dictionary, ev: Dictionary) -> bool:
	if String(bait.get("event", "")) != String(ev.get("event", "")):
		return false
	for k in bait:
		if k == "event":
			continue
		var want: Variant = bait[k]
		var got: Variant = ev.get(k)
		if typeof(want) == TYPE_ARRAY:
			if not want.has(got):
				return false
		elif String(want) != String(got):
			return false
	return true


## Returns the fired trap id or "".
func try_bait(ev: Dictionary) -> String:
	var candidates: Array = []
	for tid in _data().traps:
		var t: Dictionary = _data().traps[tid]
		if _bait_matches(t.get("bait", {}), ev) and is_armed(tid, ev):
			candidates.append(tid)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a, b):
		return int(_data().traps[a].get("priority", 0)) > int(_data().traps[b].get("priority", 0)))
	var tid: String = candidates[0]
	fire(tid, ev)
	return tid


func fire(tid: String, ev: Dictionary = {}) -> int:
	var t: Dictionary = _data().traps[tid]
	var rt := runtime(tid)
	var idx := -1
	var outs: Array = t.get("outcomes", [])
	for i in outs.size():
		var o: Dictionary = outs[i]
		if o.get("else", false) or _ctx_check(o.get("if"), ev):
			idx = i
			break
	rt.fired = true
	rt.outcome_index = idx
	get_node("/root/Bus").trap_fired.emit(tid, idx)
	if idx >= 0:
		ActionRunner.run(outs[idx].get("do", []), {"npc": String(t.get("target", "")), "source": tid, "trap": tid})
	return idx


func _ctx_check(cond: Variant, ev: Dictionary) -> bool:
	if typeof(cond) != TYPE_DICTIONARY:
		return Conditions.check(cond, _ep())
	var rest: Dictionary = cond.duplicate()
	var aud: Array = ev.get("audience", Presence.audience_of("hero"))
	if rest.has("audience_has"):
		for n in rest.audience_has:
			if not aud.has(String(n)):
				return false
		rest.erase("audience_has")
	if rest.has("audience_lacks"):
		for n in rest.audience_lacks:
			if aud.has(String(n)):
				return false
		rest.erase("audience_lacks")
	if rest.has("addressee"):
		if String(ev.get("addressee", "")) != String(rest.addressee):
			return false
		rest.erase("addressee")
	return Conditions.check(rest, _ep())
