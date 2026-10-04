class_name SceneManager
extends Node
## Scene flow driven by data/ep01/scenes.json. Spawns NPCs, places the hero, runs enter actions,
## evaluates data rules each tick, owns the active SceneLogic, auto-checkpoints at scene starts.
## Works headless for SIM tests (world-less: NPC commands just go unheard; Presence is updated).

var logic: SceneLogic = null
var current := ""
var _rule_hold: Dictionary = {}
var paused := false
var autosave := true


func _ready() -> void:
	Services.scenes = self


func _exit_tree() -> void:
	if Services.scenes == self:
		Services.scenes = null


func _ep() -> Node:
	return get_node("/root/Episode")


func _data() -> Node:
	return get_node("/root/Data")


func _process(delta: float) -> void:
	if not paused:
		tick(delta)


func tick(delta: float) -> void:
	if current == "":
		return
	_eval_rules(delta)
	if logic:
		logic.tick(delta)


func goto_scene(id: String) -> void:
	var D := _data()
	var E := _ep()
	if not D.scenes.has(id):
		push_error("unknown scene " + id)
		return
	if D.scenes[id].has("jump_to"):
		goto_scene(String(D.scenes[id].jump_to))
		return
	if logic:
		logic.exit()
		logic.queue_free()
		logic = null
	var s: Dictionary = D.scenes[id]
	current = id
	E.scene_id = id
	if s.has("phase"):
		E.set_phase_name(String(s.phase))
	E.scene_clock = 0.0
	_rule_hold = {}
	if Services.conversation:
		Services.conversation.end_active("SCENE")
	# NPCs
	if s.get("despawn_others", true):
		for npc in E.characters:
			if not s.get("npcs", {}).has(npc) and not Array(s.get("keep_npcs", [])).has(npc):
				ActionRunner.run([{"despawn": npc}])
	for npc in s.get("npcs", {}):
		var nd: Dictionary = s.npcs[npc]
		if nd.has("if") and not Conditions.check(nd["if"], E):
			ActionRunner.run([{"despawn": npc}])
			continue
		ActionRunner.run([{"spawn": [npc, String(nd.at)]}])
		if nd.has("schedule"):
			ActionRunner.run([{"set_schedule": [npc, String(nd.schedule)]}])
		if nd.has("pose"):
			ActionRunner.run([{"npc": [npc, "pose", {"pose": nd.pose}]}])
		if nd.has("look"):
			ActionRunner.run([{"npc": [npc, "look", {"target": nd.look}]}])
	# hero
	if s.has("hero") and Services.world:
		Services.world.place_hero(String(s.hero), bool(s.get("hero_seated", false)))
	if s.has("hero"):
		Presence.place("hero", D.marker_zone(String(s.hero)), D.marker(String(s.hero)))
		E.hero_zone = D.marker_zone(String(s.hero))
	if s.has("mood") and Services.world:
		Services.world.set_mood(String(s.mood))
	if s.has("music"):
		get_node("/root/Bus").music_requested.emit(String(s.music))
	get_node("/root/Bus").scene_changed.emit(id)
	ActionRunner.run(s.get("enter", []), {"source": id})
	if s.has("logic"):
		var scr: GDScript = load(String(s.logic))
		if scr:
			logic = scr.new()
			logic.name = "Logic_" + id
			logic.scene_id = id
			logic.def = s
			add_child(logic)
			logic.enter()
	if autosave and s.get("checkpoint", true) and Services.world:
		E.save_game()


func _eval_rules(delta: float) -> void:
	var E := _ep()
	var sc := current
	var s: Dictionary = _data().scenes.get(current, {})
	for r in s.get("rules", []):
		var key := "rule:%s:%s" % [current, r.get("id", "")]
		if not r.get("repeat", false) and E.flags.get(key, false):
			continue
		if r.has("after") and E.scene_clock < float(r.after):
			continue
		var ok := Conditions.check(r.get("when"), E)
		if r.has("hold"):
			if ok:
				_rule_hold[key] = float(_rule_hold.get(key, 0.0)) + delta
				ok = _rule_hold[key] >= float(r.hold)
			else:
				_rule_hold[key] = 0.0
		if ok:
			E.flags[key] = true
			if r.get("repeat", false):
				_rule_hold[key] = 0.0
			ActionRunner.run(r.get("do", []), {"source": String(r.get("source", current))})
			if current != sc:
				return   # the rule changed the scene


## F2: seed the minimum state for a scene, then jump.
func debug_jump(id: String) -> void:
	var D := _data()
	var js: Dictionary = D.scenes.get(id, {})
	if js.has("jump_to"):
		debug_jump(String(js.jump_to))
		ActionRunner.run(js.get("after_jump", []), {"source": "debug_jump"})
		return
	var order: Array = D.scenes.keys()
	order.sort_custom(func(a, b): return ("ZZZ" if a == "EPI" else String(a)) < ("ZZZ" if b == "EPI" else String(b)))
	# run seeds of all previous scenes in order so the jump has minimum state
	for sid in order:
		if sid == id:
			break
		ActionRunner.run(D.scenes[sid].get("seed", []), {"source": "debug_seed"})
	goto_scene(id)
	var s: Dictionary = D.scenes.get(id, {})
	if s.has("debug_hero"):
		var m := String(s.debug_hero)
		if Services.world:
			Services.world.place_hero(m, false)
		Presence.place("hero", D.marker_zone(m), D.marker(m))
		_ep().hero_zone = D.marker_zone(m)


func respawn_current() -> void:
	var sid: String = _ep().scene_id
	var saved: Dictionary = _ep().to_dict()
	goto_scene(sid)
	_ep().from_dict(saved)


## Pause menu: restart Episode 01 from the bar, or reload the last scene-start checkpoint.
## Rebuilds the whole world (main scene reload) so no stale NPC/chase state survives.
func restart_episode(from_checkpoint: bool) -> void:
	var E := _ep()
	get_tree().paused = false
	Engine.time_scale = 1.0
	if from_checkpoint and FileAccess.file_exists(E.SAVE_PATH):
		set_meta("resume", true)
		get_node("/root/Debug").pending_resume = true
	else:
		get_node("/root/Debug").pending_resume = false
	get_node("/root/Bus").player_decision.emit("restart" if not from_checkpoint else "load_checkpoint")
	E.reset()
	ActionRunner.reset()
	get_tree().reload_current_scene()
