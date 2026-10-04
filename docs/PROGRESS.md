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
