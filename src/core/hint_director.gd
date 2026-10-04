class_name HintDirector
extends Node
## Three-level guidance (playtest findings 2–4), without arrows or waypoints:
##   1. the world itself (light, open doors, signage, NPC movement, sound) — level data;
##   2. the one current objective line (HUD, from Objectives);
##   3. only after a long stretch without progress: one short EL thought from the objective's
##      `nudges` (zone/condition specific, each at most once per objective). Never a solution.
## Progress = a new fact / observation / lead / item / exchange / interaction / thread, a scene
## change, or setting foot in a zone for the first time.

signal objective_changed(id: String)

var objective_id := ""
var stall := 0.0
var fired: Dictionary = {}      # nudge index -> true (current objective)
var _visited: Dictionary = {}
var _poll := 0.0
var _cine := false
var enabled := true


func _ready() -> void:
	Services.hints = self
	var B := get_node("/root/Bus")
	for s in ["fact_learned", "observation_noticed", "lead_changed", "item_changed", "exchange_started",
			"interact_done", "thread_pinned", "scene_changed"]:
		B.connect(s, _on_progress.unbind(_arity(s)))
	B.cine_started.connect(func(_id: String, _d: float): _cine = true)
	B.cine_ended.connect(func(_id: String): _cine = false; stall = 0.0)


func _exit_tree() -> void:
	if Services.hints == self:
		Services.hints = null


static func _arity(sig: String) -> int:
	match sig:
		"fact_learned", "lead_changed", "item_changed":
			return 2
	return 1


func _on_progress() -> void:
	stall = 0.0


func _process(delta: float) -> void:
	if not get_tree().paused:
		tick(delta)


func tick(delta: float) -> void:
	var E := get_node("/root/Episode")
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		var cur := Objectives.current_id(E)
		if cur != objective_id:
			objective_id = cur
			fired = {}
			stall = 0.0
			objective_changed.emit(cur)
		var z: String = E.hero_zone
		if z != "" and not _visited.has(z):
			_visited[z] = true
			stall = 0.0
	if not enabled or objective_id == "" or _busy():
		return
	stall += delta
	var nudges: Array = get_node("/root/Data").objectives.get(objective_id, {}).get("nudges", [])
	for i in nudges.size():
		var n: Dictionary = nudges[i]
		if fired.has(i) or stall < float(n.get("after", 90.0)):
			continue
		if n.has("zone") and String(n.zone) != String(E.hero_zone):
			continue
		if n.has("if") and not Conditions.check(n["if"], E):
			continue
		fired[i] = true
		stall = 0.0
		var pl := get_node_or_null("/root/Debug/PlaytestLog")
		if pl:
			pl.write("hint_thought", {"objective": objective_id, "text": String(n.text)})
		get_node("/root/Bus").thought_requested.emit(String(n.text), Data.line_duration(String(n.text)) + 0.8)
		return


## Never interrupt a conversation, a cine, a line in progress or the chase.
func _busy() -> bool:
	if Services.conversation and (Services.conversation.is_active() or not Services.conversation.current_line.is_empty()):
		return true
	return _cine
