class_name BodyLanguage
extends Node
## Visual Integration V1.7 — authored body-language states on the proxy rigs (no mocap needed).
## NPC moods come from data/ep01/proxies.json "moods" (condition rules, first match wins).
## EL reacts to what he does: sudden attention when READ notices something, the bluff stance
## while a bluff lands, a flicker of uncertainty when one is called; otherwise relaxed observation.
## Bartenders keep working while they talk.

const TICK := 0.25

var _t := 0.0
var _hero_mood := ""
var _hero_t := 0.0
var _claims: Dictionary = {}   # npc -> claim id the hero just made to them


func _ready() -> void:
	var B := get_node("/root/Bus")
	B.observation_noticed.connect(func(_o: String): _hero("attention", 1.8))
	B.claim_spoken.connect(_on_claim)
	B.npc_reaction.connect(_on_reaction)


func _on_claim(claim: String, speaker: String, addressee: String, _aud: Array) -> void:
	if speaker != "hero":
		return
	_claims[addressee] = claim
	if String(get_node("/root/Data").claims.get(claim, {}).get("verb", "")) == "BLUFF":
		_hero("bluff", 2.6)


func _on_reaction(npc: String, reaction: String) -> void:
	if reaction == "CALLED" and _claims.has(npc):
		_hero("uncertain", 2.8)


func _hero(m: String, dur: float) -> void:
	_hero_mood = m
	_hero_t = dur


func _process(delta: float) -> void:
	if Services.world == null:
		return
	if _hero_t > 0.0:
		_hero_t -= delta
		if _hero_t <= 0.0:
			_hero_mood = ""
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	if Services.hero and Services.hero.body_vis.mood != _hero_mood:
		Services.hero.body_vis.set_mood(_hero_mood)
	var E := get_node("/root/Episode")
	var talking := String(Services.conversation.active.get("npc", "")) if Services.conversation and Services.conversation.is_active() else ""
	for id in Services.world.npcs:
		var n: NPC = Services.world.npcs[id]
		if not n.spawned:
			continue
		var bv: BodyVisual = n.body_vis
		var md: Dictionary = bv.spec.get("moods", {})
		var want := String(md.get("default", ""))
		for r in md.get("rules", []):
			if Conditions.check(r.get("when"), E):
				want = String(r.mood)
				break
		if bv.mood != want:
			bv.set_mood(want)
		# working while talking: hands keep polishing instead of waiting
		if md.get("work_while_talking", false):
			if talking == id and bv.pose == "rest":
				bv.set_pose("polish")
				n.set_meta("bl_polish", true)
			elif talking != id and n.has_meta("bl_polish"):
				n.remove_meta("bl_polish")
				if bv.pose == "polish":
					bv.set_pose("rest")
