class_name VesperArt
extends RefCounted
## FINAL VISUAL LANGUAGE V1 — the rollout gate (docs/FINAL_VISUAL_LANGUAGE_PHASE1.md).
## Visual only. The final material/prop language is switched on per zone, phase by phase; the
## character proxy refinement is one switch for the whole cast (a character is the same object in
## every room). Everything here is reversible:
##   `-- --art-v1`                     run with the Motion Polish V1 look (rollback / A-B)
##   /tmp/room307_art_v1 (debug only)  same, picked up by the persistent capture server
## No reference to Data or other autoload-dependent classes (tests compile this before autoloads).

const ROLLOUT := ["BAR", "ROOM_307"]   # Phase 1 BAR (accepted), Phase 2 ROOM_307. Later zones after validation.


static func enabled() -> bool:
	if "--art-v1" in OS.get_cmdline_user_args():
		return false
	return not (OS.is_debug_build() and FileAccess.file_exists("/tmp/room307_art_v1"))


static func zone_on(zone_id: String) -> bool:
	return enabled() and zone_id in ROLLOUT


static func characters_on() -> bool:
	return enabled()


## Per-frame visual upkeep that depends on what the (unchanged) camera is showing.
## The BAR opening looks from behind the counter toward the room's camera side, which the follow
## rig never sees: a backdrop wall exists only for that fixed rig, so it can never occlude play.
static func tick(world: Node) -> void:
	var cd: Node = world.get("camera_director")
	if cd == null:
		return
	var key := String(cd.get("rig_key"))
	for n in world.get_tree().get_nodes_in_group("vesper_rig_only"):
		(n as Node3D).visible = String(n.get_meta("rig", "")) == key
