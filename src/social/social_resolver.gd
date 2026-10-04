class_name SocialResolver
extends RefCounted
## Deterministic social resolution (STATE_MODEL §6).

const CALLED := "CALLED"
const SLIP := "SLIP"
const TELL := "TELL"
const DEFLECT := "DEFLECT"
const TRAP := "TRAP"


static func _ep() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Episode")


static func _data() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Data")


static func _bus() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Bus")


static func claim_is_true(claim: Dictionary) -> bool:
	if claim.has("is_true_if"):
		return Conditions.check(claim.is_true_if, _ep())
	return bool(claim.get("is_true", true))


static func fear_weight(npc_id: String, claim: Dictionary) -> int:
	var tag: Variant = claim.get("fears", {}).get(npc_id)
	if tag == null:
		return 0
	return int(_data().character(npc_id).get("fears", {}).get(String(tag), 0))


static func feared_audience_present(npc_id: String, audience: Array) -> bool:
	for a in _data().character(npc_id).get("feared_audience", []):
		if audience.has(String(a)):
			return true
	return false


## The pressure number (exposed for AT-SOC-03).
static func pressure(npc_id: String, claim_id: String, audience: Array) -> int:
	var claim: Dictionary = _data().claims.get(claim_id, {})
	var c: CharacterState = _ep().ch(npc_id)
	var p := fear_weight(npc_id, claim) + c.stress
	if feared_audience_present(npc_id, audience):
		p += 1
	if c.believes_hero_knows.has(String(claim.get("about", ""))):
		p += 1
	p -= int(_data().character(npc_id).get("savvy", 0))
	if c.caught_hero_lying:
		p -= 1
	return p


## Resolve a claim spoken to npc_id with the given audience. Applies side effects, emits npc_reaction.
static func resolve(npc_id: String, claim_id: String, audience: Array = []) -> String:
	var claim: Dictionary = _data().claims.get(claim_id, {})
	var c: CharacterState = _ep().ch(npc_id)
	if c == null or claim.is_empty():
		return DEFLECT
	var reaction := ""
	# 1. authored overrides
	for o in claim.get("overrides", {}).get(npc_id, []):
		if Conditions.check(o.get("if"), _ep()):
			reaction = String(o.reaction)
			ActionRunner.run(o.get("do", []), {"npc": npc_id})
			break
	var is_true := claim_is_true(claim)
	# 2. contradiction
	if reaction == "" and not is_true:
		var contra: Array = claim.get("contradicted_by", [claim.get("about", "")])
		for f in contra:
			if c.knows.has(String(f)):
				reaction = CALLED
				break
	# 3-4. pressure
	if reaction == "":
		var p := pressure(npc_id, claim_id, audience)
		if p >= 4:
			reaction = SLIP
		elif p >= 2:
			reaction = TELL
		else:
			reaction = DEFLECT
	# 5. side effects
	if reaction == CALLED:
		c.caught_hero_lying = true
		c.add_suspicion(1)
		c.add_trust(-1)
	else:
		if reaction in [TELL, SLIP]:
			c.add_stress(1)
		var about := String(claim.get("about", ""))
		if about != "" and not c.believes_hero_knows.has(about):
			c.believes_hero_knows.append(about)
		var tag: Variant = claim.get("fears", {}).get(npc_id)
		if tag != null:
			c.fear_hit(String(tag))
	_bus().npc_reaction.emit(npc_id, reaction)
	return reaction


## Hero speaks a claim: emits claim_spoken, gives traps first dibs, else resolves.
## Returns {"reaction": String, "trap": String}.
static func speak_claim(claim_id: String, addressee: String, audience: Variant = null) -> Dictionary:
	var aud: Array = audience if audience != null else Presence.audience_of("hero", [addressee])
	if not aud.has(addressee) and addressee != "":
		pass
	_bus().claim_spoken.emit(claim_id, "hero", addressee, aud)
	_bus().player_decision.emit("claim")
	if Services.traps:
		var fired: String = Services.traps.try_bait({"event": "claim_spoken", "claim": claim_id,
			"addressee": addressee, "audience": aud})
		if fired != "":
			return {"reaction": TRAP, "trap": fired}
	if addressee == "" or _ep().ch(addressee) == null:
		return {"reaction": DEFLECT, "trap": ""}
	return {"reaction": resolve(addressee, claim_id, aud), "trap": ""}
