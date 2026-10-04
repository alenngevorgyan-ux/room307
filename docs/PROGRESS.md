# EP01 PROGRESS

Run: `godot --path .` · Tests: `./run_tests.sh` · Jump: `godot --path . -- --scene S04` (F2 in game).

## Milestones

- [x] M0 — skeleton, autoloads (Episode, Bus, Data, Debug), test runner, validator
- [x] M1 — movement + camera (walk/fast/run/crouch/slide/vault/ramps/doors, rig blends + direction lock)
- [x] M2 — interaction + ActionRunner + F1 overlay + data loader/validator
- [x] M3 — READ (time 0.6, low-pass, vignette, reticle, dwell, LOS, TELL windows, captions, threads)
- [x] M4 — conversation in motion (exchanges, chips, silence/leave, social resolver, traps)
- [x] M5 — Scene 01: Hale/Selin/Kai/Jules/Adrian, schedules + restroom detours (70 s, 150 s), 8 observations, TR_S1_CAMERAS / PAWN_PUBLIC / PAWN_PRIVATE, all 4 resolutions (SIM), Adrian two-shot CINE, leave-early variant
- [x] M6 — Scene 02 walk-and-talk (FOLLOW_LEAD, location beats, elevator ride with floor ticks, CALL LIE / SILENCE / PRICE / BLUFF-grab, deep line) + Room 307/308 (18 interactables, 17 observations, mirror re-steam, Lina interruption with glasses loss, ALLY/NEUTRAL/SCARED, Daniel hallway encounter incl. skip-room path)
- [x] M7 — 24 graybox zones, doorway graph, NPC routing through doors, runtime navmesh per zone; navigation smoke test
- [x] M8 — Lead A Nico (warmth gates, pour flourish, smoke break, pity fact, Lukas correction), Lead B Eva (615 / 308 / hide traps, tail with perception, burner-call overhear, confrontation, 307-phone text), fallbacks (Nico text 4 min, Eva to lobby 6 min, Lina 90 s, PA)
- [x] M9 — Lead C: Pavel loop + door window, house-phone distraction (once per 5 min), cart cover, staff keycard (Lina ALLY / key hook hold), code peek via TELLs, caught ×1 escort / ×2 Daniel escort → FAILED_DONE; Scene 05 video room (5 cams, 5 timestamp tabs, jog wheel, live diorama footage, photo, Pavel return cues)
- [x] M10 — Thomas (see below)
- [x] M11 — chase (see below)
- [x] M12 — Scene 08 Mara: table keep-away, extinguisher, silence / honest / bluff (wary → door flight → block or calm), phone return, scrubbable 12 s dashcam clip with READ tells, guaranteed story lines, Thomas arrival (+ hero phone return after interrogation), T_TWO_STORIES auto-pin, the ask + card custody by trust
- [x] M13 — Scene 09 finale: place cards, recorder, SD card spot, 3 doors, lights, photo, phone invitations with templates and arrival order, start gate (AT-GRAPH-07) + «Томаса нет» warning, positional addressing ring, TR_FINAL_MAIN (3 outcomes + retry), DIRECT, PHOTO, WRONG, CARD BAIT, Daniel tells window, pressure model, flee check / block / chair trip / door slam / catch, cornered → confession, escape (+ Mara's copy), thugs + Thomas/Adrian responses
- [x] M14 — physical endings A/B/C/D (no menu), walking out with the card is blocked, epilogue street with ending variants, phone call, cut to black
- [~] M15 — pacing telemetry (F4), synthesized music states / ambience / SFX, checkpoints at scene starts, options in pause menu. **Needs a human playtest** for feel, timing and the 35–45 min target.

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

- **RECEPTION BACK** is merged into the LOBBY as the area behind the reception desk (forbidden area); the keypad door to SECURITY sits on the lobby's back wall so the code peek from the planter works with line of sight.
- **Scene 05** is a phase inside the S04 hub (the security room), not a separate world load; F2 "S05" jumps into the hub and teleports into the room.
- **Kitchen ↔ Restaurant** is a doorway (teleport) rather than a seamless shared block.
- **Arrival spacing** in the finale is 12 s (spec 20 s) to keep the decision cadence under 60 s; flee checks start once the reveal lines end (first after the 6 s tells window, then every 4 s).
- **Hearing in the restaurant** is reduced to 55 % while the kitchen swing door is open (kitchen noise) — this is how "Mara out of earshot" is staged.
- Debug overlay (F1–F7) stays enabled in exported playtest builds.

## Playtest prep (ep01-graybox-playtest-v1)

- Sato vaults vaultable boxes on his direct line to the hero (0.6 s hop); Brody paths around via navmesh.
- «Дэниел знает»: Thomas opens with a hurried line, keeps scanning the gate, and his silences/chip windows are 30 % shorter (exchange `pace`).
- Developer mode OFF by default (Ctrl+Shift+D or `-- --dev`); local playtest log + summary in `user://playtest` (macOS: ~/Library/Application Support/Room307/playtest); pause menu: restart episode / load last checkpoint / open log folder.
- In-engine autopilot (`-- --autopilot=<ENDING>`) runs in CI for all four endings.

## Known issues

- Feel, camera composition per zone and route timing are verified only by SIM + screenshots; a human playtest is needed (see PLAYTEST_LOG).
- Audio is placeholder synthesis; there is no voice acting.

## Dialogue line count

360 / 450 lines (`LINE-BUDGET` check in the validator).

## Test status

`./run_tests.sh` — **99 tests, 0 failed** (AT-DATA-01..08 + budget, AT-SOC-01..07, AT-GRAPH-01..12 as SIMs incl. a full bar → epilogue playthrough per ending, scene SIMs S01–S09, chase tools/FSM, navigation smoke).

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
