extends SceneLogic
## S06 glue: the physical "block his path" stop (sidestep once, then stop) and the 70 s
## self-advance guarantee (if the hero gives no input for 70 s, Thomas speaks the next fragment).

const BLOCK_DIST := 1.3
const GUARANTEE := 70.0

var _sidestepped := false
var _block_t := 0.0
var _idle := 0.0


func enter() -> void:
	bus().player_decision.connect(func(_k): _idle = 0.0)


func tick(delta: float) -> void:
	var E := ep()
	if not E.flags.get("th_stopped", false):
		try_block(delta)
		return
	if E.flags.get("th_done", false):
		return
	_idle += delta
	if _idle >= GUARANTEE:
		_idle = 0.0
		var c: Node = Services.conversation
		if c and c.active_id == "X_S06_TALK":
			# force the current window to resolve as silence
			c.chips_deadline = c.exchange_t
		elif c:
			c.start("X_S06_TALK", true)


## Block = the hero stands in Thomas's lane, ahead of him. First time he sidesteps, then he stops.
func try_block(delta: float) -> void:
	if not Presence.pos.has("thomas") or not Presence.pos.has("hero"):
		return
	if Presence.in_zone("hero") != "LOADING_DOCK":
		return
	var tp: Vector3 = Presence.pos.thomas
	var hp: Vector3 = Presence.pos.hero
	var fwd := Vector3.ZERO
	var n := npc_node("thomas")
	if n:
		fwd = n.facing_dir()
		if Vector3(n.velocity.x, 0, n.velocity.z).length() < 0.3 and not get_meta("force", false):
			_block_t = 0.0
			return
	var to := hp - tp
	to.y = 0
	var ahead := fwd == Vector3.ZERO or (to.length() > 0.01 and fwd.dot(to.normalized()) > 0.4)
	if to.length() <= BLOCK_DIST and ahead and absf(hp.y - tp.y) < 1.0:
		_block_t += delta
		if _block_t < 0.3:
			return
		_block_t = 0.0
		if not _sidestepped:
			_sidestepped = true
			run([{"line": "TH_STEP_ASIDE"}])
			if n:
				var side := Vector3(fwd.z, 0, -fwd.x)
				n.global_position += side * 1.1
			bus().player_decision.emit("block")
		else:
			run([{"flag": "th_stopped"}, {"flag": ["th_method", "block"]}, {"set_schedule": ["thomas", "thomas_lean"]},
				{"start_exchange": "X_S06_TALK"}])
			bus().player_decision.emit("block")
	else:
		_block_t = 0.0
