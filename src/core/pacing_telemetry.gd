class_name PacingTelemetry
extends RefCounted
## Decision cadence + control ratio (AT-PACE-01/02).

var decisions: Array = []        # [{t, kind}]
var locked_time := 0.0
var total_time := 0.0
var lock_reasons: Dictionary = {}
var cine_log: Array = []         # [{id, dur}]


func on_decision(kind: String, t: float) -> void:
	decisions.append({"t": t, "kind": kind})


func tick(delta: float) -> void:
	total_time += delta
	if not lock_reasons.is_empty():
		locked_time += delta


func set_lock(reason: String, locked: bool) -> void:
	if locked:
		lock_reasons[reason] = true
	else:
		lock_reasons.erase(reason)


func gaps() -> Array:
	var out: Array = []
	var prev := 0.0
	for d in decisions:
		out.append(d.t - prev)
		prev = d.t
	return out


## Fraction of decision gaps <= 60 s.
func cadence_ok_ratio() -> float:
	var g := gaps()
	if g.is_empty():
		return 1.0
	var ok := 0
	for x in g:
		if x <= 60.0:
			ok += 1
	return float(ok) / g.size()


func control_ratio() -> float:
	if total_time <= 0.0:
		return 1.0
	return 1.0 - locked_time / total_time


func report() -> String:
	var g := gaps()
	var mx := 0.0
	for x in g:
		mx = maxf(mx, x)
	return "decisions %d | max gap %.1fs | gaps<=60s %.0f%% | control %.0f%% | play %.0fs" % [
		decisions.size(), mx, cadence_ok_ratio() * 100.0, control_ratio() * 100.0, total_time]
