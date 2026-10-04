class_name CinePlayer
extends Node
## Short cinematic beats (≤ 15 s, asserted). Letterbox, input lock, optional camera rig, lines.
## cines.json: {id: {dur, lines:[keys], camera:"ZONE:rig", lock:true, after:[actions], at:[{t, do}]}}

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
	t_left = minf(float(c.get("dur", 4.0)), 15.0)
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
		ActionRunner.run([{"line": k}])
	ActionRunner.run(c.get("start", []), {"source": id})


func _process(delta: float) -> void:
	if active == "":
		return
	_elapsed += delta
	for e in _timed.duplicate():
		if _elapsed >= float(e.t):
			_timed.erase(e)
			ActionRunner.run(e.get("do", []), {"source": active})
	t_left -= delta
	if t_left <= 0.0:
		_finish()


func skip() -> void:
	if active != "":
		t_left = 0.0


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
