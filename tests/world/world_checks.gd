extends SceneTree
## In-engine world checks (real 3D world, physics, cameras, doors, NPC bodies) for behaviour the
## logic-only SIM cannot see. Run:  godot --headless --path . --fixed-fps 60 -s res://tests/world/world_checks.gd
## (run_tests.sh runs it after the unit/SIM suite). Prints "N world checks, M failed"; exit 1 on failure.

const KEYS := {"move_left": Vector2(-1, 0), "move_right": Vector2(1, 0), "move_fwd": Vector2(0, 1), "move_back": Vector2(0, -1)}

var main: Node
var total := 0
var failed := 0
var _cur := ""
var _fails: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	for i in 20:
		await physics_frame
	Services.scenes.autosave = false
	var filter := ""
	var args := OS.get_cmdline_user_args()
	for a in args:
		if not a.begins_with("--"):
			filter = a
	for m in get_script().get_script_method_list():
		var mn := String(m.name)
		if not mn.begins_with("check_") or (filter != "" and not mn.contains(filter)):
			continue
		_cur = mn
		_fails = []
		total += 1
		await call(mn)
		_release_keys()
		if _fails.is_empty():
			print("  ok   world:", mn)
		else:
			failed += 1
			print("  FAIL world:", mn)
			for f in _fails:
				print("       ", f)
	print("\n%d world checks, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)


func expect(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func hero() -> Node:   # (untyped: this script compiles before the autoloads exist)
	return Services.hero


func _release_keys() -> void:
	for k in KEYS:
		Input.action_release(k)


## The movement key that walks the hero along `want` in the live camera's basis.
func key_toward(want: Vector3) -> String:
	var cam_yaw: float = hero().get_viewport().get_camera_3d().global_rotation.y
	var best := -2.0
	var out := ""
	for k in KEYS:
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var d: Vector3 = right * KEYS[k].x + fwd * KEYS[k].y
		if d.dot(want) > best:
			best = d.dot(want)
			out = k
	return out


func _settle_hero_at(p: Vector3, zone: String) -> void:
	_release_keys()
	await frames(12)   # let any in-flight door fade finish
	var h := hero()
	h.seated = false
	h.teleport_to(p, zone)
	Services.world.camera_director.snap()
	await frames(2)


# ================================================================== checks

## Playtest finding 8: walking through an auto door with the key held must cross exactly once —
## never bounce back (BAR_LOBBY <-> LOBBY_BAR used to ping-pong ~3x per second).
func check_doors_cross_once_with_key_held() -> void:
	Services.scenes.paused = true
	var ids: Array = []
	for d in get_nodes_in_group("doorways"):
		var door: Node = d
		if door.auto() and not door.def.get("npc_only", false) and door.target() != null:
			ids.append(door.door_id)
	ids.sort()
	for id in ids:
		var door: Node = Services.world.door(id)
		await _settle_hero_at(door.spawn_point() + Vector3(0, 0.05, 0), door.zone_id)
		var key := key_toward(-door.normal)
		Input.action_press(key)
		var crossings := 0
		var last: String = door.zone_id
		for f in 60 * 4:
			await physics_frame
			if hero().current_zone != last:
				crossings += 1
				last = hero().current_zone
		Input.action_release(key)
		expect(crossings == 1, "%s (%s): %d crossings with the key held, ended in %s" % [id, door.zone_id, crossings, last])
	Services.scenes.paused = false


## A teleport issued by gameplay (catch, cine, chase grab) while a door fade is in flight wins:
## the stale door transition must not drag the hero back afterwards.
func check_teleport_during_door_fade_wins() -> void:
	var door: Node = Services.world.door("LOBBY_BAR")
	await _settle_hero_at(door.spawn_point(), door.zone_id)
	Services.world.traverse_hero(door)
	await frames(2)
	var m := "HALL_3F:hub_start"
	hero().teleport_to(get_root_data().marker(m), get_root_data().marker_zone(m))
	await frames(30)
	expect(hero().current_zone == "HALL_3F", "hero ended in %s, expected HALL_3F" % hero().current_zone)
	expect(not hero().input_locked(), "door lock released")


## Being caught at security escorts the hero to the front of reception — not across the lobby
## to the bar arch (the start area) — and cuts to black before moving him.
func check_security_catch_lands_at_reception() -> void:
	Services.scenes.debug_jump("S04")
	await frames(10)
	var logic: Node = Services.scenes.logic
	var m := "SECURITY:chair"
	await _settle_hero_at(get_root_data().marker(m), "SECURITY")
	var before: Vector3 = hero().global_position
	logic.caught("pavel")
	await frames(3)
	expect(hero().global_position.distance_to(before) < 0.5, "hero must not move before the cut to black")
	await frames(40)
	expect(hero().current_zone == "LOBBY", "escorted to the LOBBY (got %s)" % hero().current_zone)
	var arch: Node = Services.world.door("LOBBY_BAR")
	expect(hero().global_position.distance_to(arch.global_position) > 12.0, "escort drop is far from the bar arch")
	expect(not logic.hero_forbidden(), "escort drop is outside the forbidden area")
	expect(not hero().input_locked() or Services.conversation.is_active(), "control returns after the escort cut")


func get_root_data() -> Node:
	return root.get_node("Data")


# ================================================================== Pass 2: no NPC pop-in

var _pops: Array = []


func _watch_pops() -> void:
	_pops = []
	var B := root.get_node("Bus")
	if not B.npc_popped.is_connected(_on_pop):
		B.npc_popped.connect(_on_pop)


func _on_pop(npc: String, kind: String, _info: Dictionary) -> void:
	_pops.append("%s:%s" % [npc, kind])


func _bar_with_hero_watching() -> void:
	Services.scenes.goto_scene("S01")
	await frames(30)
	ActionRunner.reset()
	Services.conversation.end_active("TEST")
	var cam_hint := {"clear": true}
	root.get_node("Bus").camera_hint.emit(cam_hint)
	await _settle_hero_at(get_root_data().marker("BAR:hero_stand"), "BAR")
	await frames(40)


## Playtest finding 5: an NPC told to despawn while the hero can see them walks out of view
## through a real exit; logic treats them as gone at once.
func check_visible_despawn_walks_out() -> void:
	await _bar_with_hero_watching()
	_watch_pops()
	var n: Node = Services.world.npc("selin")
	expect(n.on_camera(), "setup: Selin is on camera")
	root.get_node("Bus").npc_command.emit("selin", "despawn", {})
	await frames(2)
	expect(not Presence.is_present("selin"), "logic sees her gone immediately")
	expect(n.visible and n.leaving, "her body is still there, walking out")
	var t := 0
	while n.leaving and t < 60 * 26:
		await physics_frame
		t += 1
	expect(not n.leaving and not n.visible, "she has left (%.1f s)" % (t / 60.0))
	expect(_pops.is_empty(), "no pop: %s" % [_pops])


## A fresh spawn where the hero is looking enters through the nearest door and walks in.
func check_visible_spawn_enters_through_door() -> void:
	await _bar_with_hero_watching()
	_watch_pops()
	root.get_node("Bus").npc_command.emit("eva", "despawn", {})
	await frames(2)
	var target: Vector3 = get_root_data().marker("BAR:hale_b")
	root.get_node("Bus").npc_command.emit("eva", "spawn", {"marker": "BAR:hale_b"})
	await frames(2)
	var n: Node = Services.world.npc("eva")
	expect(n.global_position.distance_to(target) > 1.5, "she did not appear on her mark")
	var t := 0
	while n.global_position.distance_to(target) > 0.6 and t < 60 * 15:
		await physics_frame
		t += 1
	expect(n.global_position.distance_to(target) <= 0.6, "she walked to her mark (%.1f s)" % (t / 60.0))
	expect(_pops.is_empty(), "no pop: %s" % [_pops])
	root.get_node("Bus").npc_command.emit("eva", "despawn", {})


## A short teleport the hero would see becomes a brisk walk (staging, cines).
func check_visible_short_teleport_walks() -> void:
	await _bar_with_hero_watching()
	_watch_pops()
	var n: Node = Services.world.npc("adrian")
	var target: Vector3 = get_root_data().marker("BAR:adrian_by_hero")
	expect(n.global_position.distance_to(target) > 1.0, "setup: Adrian in his booth")
	root.get_node("Bus").npc_command.emit("adrian", "teleport", {"marker": "BAR:adrian_by_hero"})
	await frames(2)
	expect(n.global_position.distance_to(target) > 1.0, "no instant jump")
	var t := 0
	while n.global_position.distance_to(target) > 0.6 and t < 60 * 12:
		await physics_frame
		t += 1
	expect(n.global_position.distance_to(target) <= 0.6, "walked there (%.1f s)" % (t / 60.0))
	expect(_pops.is_empty(), "no pop: %s" % [_pops])
