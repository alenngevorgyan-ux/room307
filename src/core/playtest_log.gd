class_name PlaytestLog
extends Node
## Local human-playtest log. No network, no SDK. Writes one JSON object per line to
## user://playtest/ep01_<date>_<time>.jsonl and a readable summary .txt when the episode ends
## (and on quit). On the Web build the same lines go to the browser console as "[playtest] …".
##   macOS desktop: ~/Library/Application Support/Room307/playtest/
##
## Records: scene start/end + durations, total time, leads, optional facts discovered, bluffs
## (failed = CALLED, successful = trap/slip/tell), READ observations, threads, stalls (> 90 s with
## no player decision), chase grabs / interrogations / caught, restarts, ending.

const STALL_SEC := 90.0

var path := ""
var _f: FileAccess
var started_ms := 0
var scene_starts: Dictionary = {}     # scene -> t
var scene_durations: Dictionary = {}  # scene -> seconds (summed if revisited)
var current_scene := ""
var bluffs_ok: Array = []
var bluffs_failed: Array = []
var claims_pending: Dictionary = {}   # npc -> claim id (resolved on npc_reaction)
var observations: Array = []
var facts: Array = []
var stalls: Array = []
var grabs := 0
var interrogations := 0
var caught: Array = []
var ending := ""
var _last_decision_t := 0.0
var _stall_open := false
var _summary_written := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started_ms = Time.get_ticks_msec()
	if "--no-playtest-log" in OS.get_cmdline_user_args():
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	if OS.get_name() != "Web":
		DirAccess.make_dir_recursive_absolute("user://playtest")
		path = "user://playtest/ep01_%s.jsonl" % stamp
		_f = FileAccess.open(path, FileAccess.WRITE)
	var B := get_node("/root/Bus")
	B.scene_changed.connect(_on_scene)
	B.lead_changed.connect(func(l: String, s: int): write("lead", {"lead": l, "state": Episode.LeadState.keys()[s]}))
	B.fact_learned.connect(_on_fact)
	B.observation_noticed.connect(func(o: String): observations.append(o); write("read", {"obs": o}))
	B.thread_pinned.connect(func(t: String): write("thread_pinned", {"thread": t}))
	B.claim_spoken.connect(_on_claim)
	B.npc_reaction.connect(_on_reaction)
	B.trap_fired.connect(_on_trap)
	B.player_decision.connect(_on_decision)
	B.player_detected.connect(func(n: String, sev: int): caught.append(n); write("detected", {"by": n, "severity": sev}))
	B.exchange_started.connect(_on_exchange)
	B.ending_reached.connect(func(e: String): ending = e; write("ending", {"ending": e}))
	write("session_start", {"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"os": OS.get_name(), "args": OS.get_cmdline_user_args()})


func _now() -> float:
	return (Time.get_ticks_msec() - started_ms) / 1000.0


func write(ev: String, data: Dictionary = {}) -> void:
	var E := get_node("/root/Episode")
	var row := {"t": snappedf(_now(), 0.1), "ev": ev, "scene": E.scene_id, "zone": E.hero_zone}
	row.merge(data)
	var line := JSON.stringify(row)
	if _f:
		_f.store_line(line)
		_f.flush()
	elif OS.get_name() == "Web":
		print("[playtest] ", line)


func _on_scene(sid: String) -> void:
	var t := _now()
	if current_scene != "":
		var d: float = t - float(scene_starts.get(current_scene, t))
		scene_durations[current_scene] = float(scene_durations.get(current_scene, 0.0)) + d
		write("scene_end", {"ended": current_scene, "duration": snappedf(d, 0.1)})
	current_scene = sid
	scene_starts[sid] = t
	write("scene_start", {"started": sid})


func _on_fact(f: String, source: String) -> void:
	facts.append(f)
	var fd: Dictionary = get_node("/root/Data").facts.get(f, {})
	write("fact", {"fact": f, "source": source, "required": fd.get("required", false)})


func _on_claim(claim: String, _speaker: String, addressee: String, audience: Array) -> void:
	claims_pending[addressee] = claim
	write("claim", {"claim": claim, "to": addressee, "audience": audience,
		"verb": String(get_node("/root/Data").claims.get(claim, {}).get("verb", ""))})


func _on_reaction(npc: String, reaction: String) -> void:
	var claim := String(claims_pending.get(npc, ""))
	claims_pending.erase(npc)
	if claim == "":
		return
	var verb := String(get_node("/root/Data").claims.get(claim, {}).get("verb", ""))
	write("reaction", {"npc": npc, "claim": claim, "reaction": reaction})
	if verb == "BLUFF":
		if reaction == "CALLED":
			bluffs_failed.append("%s→%s" % [claim, npc])
		elif reaction in ["SLIP", "TELL"]:
			bluffs_ok.append("%s→%s (%s)" % [claim, npc, reaction])


func _on_trap(trap: String, outcome: int) -> void:
	write("trap", {"trap": trap, "outcome": outcome})
	for npc in claims_pending.keys():
		var claim := String(claims_pending[npc])
		if String(get_node("/root/Data").claims.get(claim, {}).get("verb", "")) == "BLUFF":
			if outcome == 0:
				bluffs_ok.append("%s→%s (trap %s)" % [claim, npc, trap])
			else:
				bluffs_failed.append("%s→%s (trap %s outcome %d)" % [claim, npc, trap, outcome])
		claims_pending.erase(npc)


func _on_decision(kind: String) -> void:
	if _stall_open:
		write("stall_end", {"after": snappedf(_now() - _last_decision_t, 0.1)})
		_stall_open = false
	_last_decision_t = _now()
	if kind in ["restart", "load_checkpoint"]:
		write(kind)
		_summary_written = false
		ending = ""


func _on_exchange(xid: String) -> void:
	if xid == "X_S07_INTERROG":
		interrogations += 1
		write("chase_interrogation", {"n": interrogations})


func _process(_d: float) -> void:
	if get_tree().paused:
		_last_decision_t += _d   # pause time is not a stall
		return
	if not _stall_open and _now() - _last_decision_t > STALL_SEC:
		_stall_open = true
		var E := get_node("/root/Episode")
		stalls.append({"t": snappedf(_now(), 1), "scene": E.scene_id, "phase": E.phase_name(), "zone": E.hero_zone})
		write("stall", {"phase": E.phase_name(), "since": snappedf(_last_decision_t, 0.1),
			"leads": E.leads.duplicate(), "objective": get_node("/root/Debug").objective()})
	var E := get_node("/root/Episode")
	if E.threat.grabs != grabs and E.scene_id == "S07":
		grabs = E.threat.grabs
		write("chase_grab", {"grabs": grabs})
	if E.phase_name() == "DONE" and not _summary_written:
		write_summary()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if not _summary_written and _f:
			write("session_end", {"total": snappedf(_now(), 1)})
			write_summary()


func write_summary() -> void:
	_summary_written = true
	var E := get_node("/root/Episode")
	if current_scene != "":
		scene_durations[current_scene] = float(scene_durations.get(current_scene, 0.0)) + _now() - float(scene_starts.get(current_scene, _now()))
	var optional: Array = []
	var D := get_node("/root/Data")
	for f in facts:
		if not D.facts.get(f, {}).get("required", false):
			optional.append(f)
	var lines: Array = []
	lines.append("ROOM 307 — EP01 playtest summary (%s)" % ProjectSettings.get_setting("application/config/version", ""))
	lines.append("Total playtime: %s   Ending: %s   Daniel: %s   Recorded: %s" % [_fmt(_now()), ending if ending != "" else "(not reached)", E.finale.daniel_state, E.ending.recorded])
	lines.append("In-game clock: %s (excludes pause)" % _fmt(E.clock_sec))
	lines.append("S1 resolution: %s" % E.s1_resolution)
	lines.append("")
	lines.append("Scenes:")
	for s in scene_durations:
		lines.append("  %-4s %s" % [s, _fmt(float(scene_durations[s]))])
	lines.append("Leads: A=%s B=%s C=%s" % [Episode.LeadState.keys()[int(E.leads.A)], Episode.LeadState.keys()[int(E.leads.B)], Episode.LeadState.keys()[int(E.leads.C)]])
	lines.append("Facts: %d (optional %d): %s" % [facts.size(), optional.size(), ", ".join(optional)])
	lines.append("Observations noticed (READ or inspecting): %d: %s" % [observations.size(), ", ".join(observations)])
	lines.append("Threads pinned: %s · struck: %s" % [E.threads_pinned, E.threads_struck])
	lines.append("Bluffs OK (%d): %s" % [bluffs_ok.size(), "; ".join(bluffs_ok)])
	lines.append("Bluffs failed (%d): %s" % [bluffs_failed.size(), "; ".join(bluffs_failed)])
	lines.append("Chase: grabs %d, interrogations %d" % [E.threat.grabs, interrogations])
	lines.append("Caught/detected: %s" % [caught])
	lines.append("Stalls (> %ds without a decision): %d" % [int(STALL_SEC), stalls.size()])
	for st in stalls:
		lines.append("  at %s in %s / %s (%s)" % [_fmt(float(st.t)), st.scene, st.phase, st.zone])
	var T: PacingTelemetry = get_node("/root/Debug").telemetry
	lines.append("Pacing: %s" % T.report())
	var txt := "\n".join(lines)
	if path != "":
		var f := FileAccess.open(path.replace(".jsonl", "_summary.txt"), FileAccess.WRITE)
		if f:
			f.store_string(txt)
	else:
		print("[playtest] SUMMARY\n", txt)
	write("summary_written")


static func _fmt(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]
