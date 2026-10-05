extends Node
## Visual Integration V1.8 (Pass 12) — the finale as social chess, not a frozen table.
## While the meeting is live, people do not sit still: one of them stands, takes a step toward
## the window or watches the exit, turns to someone, then settles back. Small, readable moves
## (≤ 1.3 m), so seats, hearing, addressing and Daniel's flight logic keep working unchanged.

const BEAT_MIN := 11.0
const BEAT_MAX := 19.0
const AWAY := 7.5

## npc -> list of beats: [marker to lean toward, look target, step length]
const BEATS := {
	"adrian": [["RESTAURANT:stand_window", "RESTAURANT:stand_window", 1.2], ["RESTAURANT:table_center", "mara", 0.5]],
	"daniel": [["RESTAURANT:kitchen_door", "RESTAURANT:kitchen_door", 0.9], ["RESTAURANT:main_door", "RESTAURANT:main_door", 0.8]],
	"thomas": [["RESTAURANT:kitchen_door", "RESTAURANT:kitchen_door", 0.6], ["RESTAURANT:table_center", "mara", 0.4]],
	"mara": [["RESTAURANT:table_center", "adrian", 0.35], ["RESTAURANT:table_center", "daniel", 0.3]],
}

var logic: Node
var _t := 6.0
var _i := 0
var _away: Dictionary = {}   # npc -> seconds until they settle back


func _ready() -> void:
	logic = get_parent()


func _D() -> Node:
	return get_node("/root/Data")


func _cmd(npc: String, cmd: String, args: Dictionary) -> void:
	get_node("/root/Bus").npc_command.emit(npc, cmd, args)


func _process(delta: float) -> void:
	var E := get_node("/root/Episode")
	var ph: String = E.phase_name()
	if not (ph == "S09_LIVE" or ph == "S09_DECISION") or not logic.get("live_started"):
		return
	for n in _away.keys():
		_away[n] -= delta
		if _away[n] <= 0.0:
			_away.erase(n)
			_settle(n)
	_t -= delta
	if _t > 0.0:
		return
	_t = BEAT_MIN + fmod(float(_i) * 3.7, BEAT_MAX - BEAT_MIN)
	var order: Array = BEATS.keys()
	for k in order.size():
		var npc: String = order[(_i + k) % order.size()]
		if _can_move(npc):
			_beat(npc)
			break
	_i += 1


func _can_move(npc: String) -> bool:
	var F = get_node("/root/Episode").finale
	if _away.has(npc) or not logic.seated.has(npc) or not Presence.is_present(npc):
		return false
	if npc == "daniel" and String(F.daniel_state) in ["fleeing", "escaped", "confessed", "cornered"]:
		return false
	if Services.world == null:
		return false
	var n: Node = Services.world.npc(npc)
	return n != null and n.spawned and not n.external_control and n.at_goal()


func _beat(npc: String) -> void:
	var list: Array = BEATS[npc]
	var b: Array = list[_i % list.size()]
	if not _D().has_marker(String(b[0])):
		return
	var seat: Vector3 = _D().marker(logic._seat_marker(npc))
	var toward: Vector3 = _D().marker(String(b[0]))
	var step := (toward - seat)
	step.y = 0
	if step.length() > 0.05:
		step = step.normalized() * minf(float(b[2]), step.length())
	_cmd(npc, "goto_pos", {"pos": seat + step, "speed": "slow"})
	var look := String(b[1])
	_cmd(npc, "look", {"target": look})
	_away[npc] = AWAY


func _settle(npc: String) -> void:
	if not Presence.is_present(npc) or Services.world == null:
		return
	var n: Node = Services.world.npc(npc)
	if n == null or n.external_control:
		return
	_cmd(npc, "goto_pos", {"pos": _D().marker(logic._seat_marker(npc)), "speed": "slow"})
	_cmd(npc, "look", {"target": "RESTAURANT:table_center"})
