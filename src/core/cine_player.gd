class_name CinePlayer
extends Node
## Short cinematic beats (≤ 15 s, asserted). Letterbox, input lock, optional camera rig, lines.
## cines.json: {id: {dur, lines:[keys], camera:"ZONE:rig", lock:true, after:[actions], at:[{t, do}]}}
## A cine's lines are an authored sequence: they never expire from the queue, and the cine holds
## (up to the 15 s cap) until they have been said — no line is cut or silently dropped.

const MAX_DUR := 15.0
const LINE_TTL := 30.0

var active := ""
var t_left := 0.0
var _def: Dictionary = {}
var _timed: Array = []
var _elapsed := 0.0


func _ready() -> void:
	get_node("/root/Bus").cine_requested.connect(play)


func play(id: String) -> void:
	var D := get_node("/root/Data")
	var c: Dictionary = D.cines.get(id, {})
	if c.is_empty():
		push_warning("unknown cine " + id)
		return
	if active != "":
		_finish()
	active = id
	_def = c
	t_left = minf(float(c.get("dur", 4.0)), MAX_DUR)
	_elapsed = 0.0
	_timed = c.get("at", []).duplicate(true)
	var B := get_node("/root/Bus")
	B.cine_started.emit(id, float(c.get("dur", 4.0)))
	if c.get("lock", true):
		B.control_lock.emit("cine", true)
	if Services.hud:
		Services.hud.letterbox(true)
	if c.has("camera"):
		B.camera_hint.emit({"rig": String(c.camera), "dur": t_left + 0.3})
	for k in c.get("lines", []):
		ActionRunner.run([{"line": k}], {"ttl": LINE_TTL})
	ActionRunner.run(c.get("start", []), {"source": id, "ttl": LINE_TTL})


func _process(delta: float) -> void:
	if active == "":
		return
	_elapsed += delta
	for e in _timed.duplicate():
		if _elapsed >= float(e.t):
			_timed.erase(e)
			ActionRunner.run(e.get("do", []), {"source": active})
	t_left -= delta
	if t_left <= 0.0 and not (_lines_pending() and _elapsed < MAX_DUR):
		_finish()


func _lines_pending() -> bool:
	var conv: Node = Services.conversation
	return conv != null and (not conv.current_line.is_empty() or not conv.world_queue.is_empty() or not conv.line_queue.is_empty())


func skip() -> void:
	if active != "":
		t_left = 0.0
		_elapsed = MAX_DUR


func _finish() -> void:
	var id := active
	var c := _def
	active = ""
	_def = {}
	var B := get_node("/root/Bus")
	if c.get("lock", true):
		B.control_lock.emit("cine", false)
	if Services.hud:
		Services.hud.letterbox(false)
	B.cine_ended.emit(id)
	ActionRunner.run(c.get("after", []), {"source": id})
