class_name SpeakerNames
extends RefCounted
## Who the subtitles say is speaking (playtest findings 6–7: names above heads covered dialogue).
## Names live only in the bottom subtitle. A character is shown by name once the hero could know it:
##   - "known": true in characters.json (staff with a badge role, silhouettes), or
##   - one of their "aliases" is heard in any spoken line (Daniel: «…Дэниел. Безопасность…»), or
##   - "known_after_talk": true and an exchange with them has ended (name badges: Nico, Lina, Pavel).
## Until then the subtitle uses their "stranger" label («НЕЗНАКОМЕЦ», «БАРМЕН», «ГОРНИЧНАЯ» …).
## Knowledge is stored as Episode flags "known.<npc>" so it survives checkpoints.

const HERO := "ЭЛ"
## Speakers that are not characters. "" = show the text without a name line.
const PSEUDO := {"voice": "НЕЗНАКОМЕЦ", "pa": "ГРОМКАЯ СВЯЗЬ", "tv": "ТЕЛЕВИЗОР", "screen": ""}


static func _ep() -> Node:
	return Engine.get_main_loop().root.get_node("Episode")


static func _data() -> Node:
	return Engine.get_main_loop().root.get_node("Data")


static func is_known(npc: String) -> bool:
	if npc == "hero":
		return true
	var c: Dictionary = _data().character(npc)
	if c.is_empty() or c.get("known", false):
		return true
	return bool(_ep().flags.get("known." + npc, false))


static func mark_known(npc: String) -> void:
	if npc == "" or npc == "hero" or not _data().characters.has(npc):
		return
	_ep().flags["known." + npc] = true


## Upper-case subtitle label for a speaker id.
static func label(speaker: String) -> String:
	if speaker == "hero":
		return HERO
	if PSEUDO.has(speaker):
		return String(PSEUDO[speaker])
	var c: Dictionary = _data().character(speaker)
	if c.is_empty():
		return speaker.to_upper()
	if is_known(speaker):
		return String(c.get("display", speaker)).to_upper()
	return String(c.get("stranger", "НЕЗНАКОМЕЦ"))


## A spoken line can introduce people by name (including the speaker introducing themself).
static func observe_line(text: String) -> void:
	var D := _data()
	for npc in D.characters:
		var c: Dictionary = D.characters[npc]
		for a in c.get("aliases", []):
			if has_word(text, String(a)):
				mark_known(npc)
				break


## Whole-word match («Нико» must not match «Никогда»). Aliases list the declined forms explicitly.
static func has_word(text: String, word: String) -> bool:
	var i := text.find(word)
	while i >= 0:
		var before := text[i - 1] if i > 0 else " "
		var after := text[i + word.length()] if i + word.length() < text.length() else " "
		if not _is_letter(before) and not _is_letter(after):
			return true
		i = text.find(word, i + 1)
	return false


static func _is_letter(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper()


static func on_exchange_ended(npc: String) -> void:
	if bool(_data().character(npc).get("known_after_talk", false)):
		mark_known(npc)
