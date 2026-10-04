# EP01 PROGRESS

Run: `godot --path .` · Tests: `./run_tests.sh` · Jump: `godot --path . -- --scene S04` (F2 in game).

## Milestones

- [x] M0 — skeleton, autoloads (Episode, Bus, Data, Debug), test runner, validator
- [x] M1 — movement + camera (walk/fast/run/crouch/slide/vault/ramps/doors, rig blends + direction lock)
- [x] M2 — interaction + ActionRunner + F1 overlay + data loader/validator
- [x] M3 — READ (time 0.6, low-pass, vignette, reticle, dwell, LOS, TELL windows, captions, threads)
- [x] M4 — conversation in motion (exchanges, chips, silence/leave, social resolver, traps)
- [ ] M5 — Scene 01
- [ ] M6 — Scene 02 + Room 307
- [ ] M7 — hotel hub navigation
- [ ] M8 — NPC state, leads A & B
- [ ] M9 — security route + video room
- [ ] M10 — Thomas
- [ ] M11 — chase
- [ ] M12 — Mara
- [ ] M13 — finale trap
- [ ] M14 — endings + epilogue
- [ ] M15 — pacing, sound, polish

## Decisions

- **IDs are plain `String`s**, not `StringName` (JSON keys are Strings; avoids dictionary key mismatches).
- **Bus has extra presentation signals** (line_started, chips_shown, npc_command, …) beyond the STATE_MODEL list so logic stays headless-testable.
- **Level geometry is data** (`data/ep01/level/*.json`) built at runtime by `LevelBuilder` instead of hand-authored `.tscn` blocks. `scenes/main.tscn` boots `HotelWorld`. Blocks sit 100 m apart on a grid.
- **Every data category may be split** into `<cat>.json` and `<cat>/*.json` (merged; duplicate ids are errors).
- **Anchor hero lines** from DIALOGUE_AND_TRAPS longer than 8 words (H_CAMERAS, MAIN, PHOTO …) are kept verbatim and flagged `"anchor": true`; AT-DATA-07 exempts only those.
- **NPCs don't physically collide with the hero** (one-way): the hero can't be shoved into a softlock; NPCs pause politely ≤ 2.5 s then pass.
- **Renderer: GL Compatibility** (required for the web build).
- **Audio is synthesized at runtime** (rain/ambience beds, music states as tonal loops, SFX) — no asset dependency.
- READ is also bound to **F** (trackpads can't comfortably hold RMB).

## Known issues

- (tracked per milestone)

## Dialogue line count

See `./run_tests.sh` LINE-BUDGET (≤ 450).

## M10 / M11 (branch feat/thomas-chase)

- [x] M10 — Scene 06 Thomas: 5 stop methods (block ×2 / «Мара.» / police lie / «Дэниел знает» TR_THOMAS_DANIEL / keys on the dock edge, 4 s window), fragments 1–7 in one exchange (`X_S06_TALK`), silence advances him (5.5–6 s windows), 70 s no-input guarantee in `s06_thomas.gd`, police lie skips the personal fragment, fail-forward "drove off" → van blocks → compressed guarantee lines, 8 s van CINE → S07.
- [x] M11 — Scene 07 chase: `ChaseDirector` + `Pursuer` FSM, heat 0–3 (music CHASE_1..3, +0/3/6/9 % speed), cross-door arrivals (distance / speed + door blocks), rubber-band re-entry (Brody 9 s / Sato 6 s off-screen), close-follow slow-down, public-zone walking (route C), grab #1 struggle (Space ×3 in 1.2 s), grab #2 → cold-storage interrogation (chips, crates, freezer shove, Thomas worst case) → chase resumes at heat 3, BCORR end (safe 1 s or 30 s) → Mara pull CINE → `S08`.
- Tools (20): car alarm (phone, Volvo keys), dock roll-cart, laundry cart in doorway, steam press, hanging sheets (LOS break), pot rack noise, bottle pick/throw lure + improvised hit, fire suppression, freezer tray lure + latch lock-in, breaker blackout, radio pick + radio bluff (DOUBT/CALLED), shout bluff (phone), lockers hide (2nd time found), fire alarm staff crowd, fire door lock (staff keycard), cart wall, freight decoy + freight ride (cabin panel I_FREIGHT_*), stair drop, tablecloth hide, shove.

### Decisions (M10/M11)
- Tools are implemented as one `ChaseDirector.apply_tool(name)` dispatcher fed by `trap_bait("chase_tool", {tool})` from interactables/phone, instead of one ChaseTool class per tool (same contract: use → effect, one-shot tracked in `used_tools`).
- Thomas fragments run inside a single exchange with a 45 m leave radius; the 70 s rule forces the current chip window to resolve as silence.
- Pursuers don't use NavigationLink vault links: navmesh paths route around obstacles for both; Sato's vault advantage is modelled in tools (cart wall, laundry cart: 0.6 s vs Brody 3–4 s).
- Pursuers left in another zone re-enter at the hero's zone door off-screen (also the stuck fallback).
- `DOCK_LAUNDRY` is locked during S06 so the hero can't wander off mid-confession.
- Known: on this branch `goto_scene S08` (chase end CINE) points at a scene defined on main.
