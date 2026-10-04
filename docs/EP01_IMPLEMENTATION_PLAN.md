# EP01 — IMPLEMENTATION PLAN

**Engine:** Godot 4.x (latest stable 4.x available), GDScript, Forward+ (or Mobile renderer if perf requires), unless an existing repository dictates otherwise (see M0).

**Rule:** every milestone ends with something you can **run and play**. Commit at each green milestone, plus intermediate commits for each sub-step that runs.

## 0. Target repository layout (greenfield)

```
project.godot
src/
  core/        episode_state.gd, event_bus.gd, data_db.gd, action_runner.gd, debug_overlay.gd, pacing_telemetry.gd
  player/      player_controller.gd, player_states.gd, vault_point.gd, cover_point.gd
  camera/      camera_director.gd, camera_rig.gd, camera_zone.gd
  world/       doorway.gd, door.gd, elevator.gd, zone.gd, interactable.gd, stage_point.gd, seat_point.gd
  read/        read_system.gd, observable.gd, caption_3d.gd
  dialogue/    conversation_director.gd, chip_ui.gd, subtitle_ui.gd, bark.gd
  social/      social_resolver.gd, trap_director.gd
  npc/         npc_controller.gd, schedule.gd, perception.gd, look_at.gd, tell_driver.gd
  chase/       chase_director.gd, pursuer.gd, chase_tool.gd, tools/*.gd
  ui/          hud.gd, threads_ui.gd, phone_ui.gd, context_prompt.gd, fade.gd
  scenes_logic/ s01_watch.gd ... s09_finale.gd (thin: only glue that data can't express)
data/ep01/
  facts.json observations.json threads.json claims.json characters.json items.json
  exchanges/s01.json ... s09.json   traps.json   overhears.json   schedules.json
  interactables.json  chase.json  finale.json  lines_ru.json  cines.json
scenes/
  ep01/hotel_world.tscn
  ep01/blocks/{ground,service,f2,f3,roof}.tscn
  player/hero.tscn  npc/npc_base.tscn  ui/hud.tscn
tests/
  run_tests.gd   unit/*.gd   sim/*.gd   validate_data.gd
docs/   (the EP01_* documents + PROGRESS.md + PLAYTEST_LOG.md)
```

Conventions:

- `snake_case` files, `PascalCase` class_names, signals via `Bus`.
- No logic in `.tscn` beyond node wiring.
- All tunables go in JSON or `@export`.

How to run:

- Game: `godot --path . ` (or `godot --path . --scene res://scenes/ep01/hotel_world.tscn`).
- Tests: `godot --headless --path . -s res://tests/run_tests.gd` (exit code 0 = pass).

---

## Milestones

Each milestone lists: **Goal**, **Build**, **Done when** (playable check), **Tests**.

### M0 — Repository audit & skeleton (½ day)
- **Goal:** know what exists; create the skeleton without breaking anything.
- **Build:** inspect the repo (engine, language, controllers, dialogue, camera, folders, art pipeline) and write `docs/REPO_AUDIT.md` (what exists, what to reuse, mapping of existing systems to this plan). If greenfield: create the Godot project, folders, autoloads (`Episode`, `Bus`, `Data`, `Debug`), the test runner and `docs/PROGRESS.md` (checklist M0–M15).
- **Done when:** the project opens and runs an empty test scene; the test runner runs with 1 dummy test passing.
- **Tests:** the runner exits 0.

### M1 — Movement + camera (1–2 days)
- **Goal:** movement feels good in a graybox lobby + corridor + stair.
- **Build:** a `CharacterBody3D` hero with walk, fast walk, run, crouch, slide, vault (VaultPoint), stairs (ramps), camera-relative input with the direction lock on rig blend; CameraDirector with CameraZones/Rigs and 0.6 s blends; Doorway teleport with fade. Graybox LOBBY, BAR, HALL_3F and SERVICE_STAIR blocks.
- **Done when:** you can walk from the bar through the lobby, into the elevator (fake), along Hall 3F and down the service stair, and the camera never flips the input unexpectedly.
- **Tests:** unit-test that input mapping stays stable during a blend; manual AT-PLAY-02 (partial).

### M2 — Interaction system + action runner (1 day)
- **Goal:** the world reacts.
- **Build:** `Interactable` (prompt, conditions, actions), `ContextPrompt` UI, `ActionRunner` (core verbs: give_fact, flag, give_item, take_item, sfx, set_schedule stub, goto_scene), `Episode` facts/items/flags, the F1 debug overlay (state dump), the data loader + validator skeleton.
- **Done when:** in a test room, opening a door, toggling a window (rain audio change) and picking up a phone all update state visible in F1.
- **Tests:** AT-DATA-01 skeleton; unit tests on ActionRunner.

### M3 — READ (1–2 days)
- **Goal:** the signature perception mechanic.
- **Build:** ReadSystem (hold, time scale 0.6, audio low-pass on the Ambience bus, vignette, reticle aiming, dwell detection, LOS), Observable (STATIC/TELL), Caption3D, threads (offer/pin, max 3) with ThreadsUI, the READ_ASSIST option.
- **Done when:** in a graybox room with 5 observables and 1 NPC who opens a TELL window every 8 s, the player can notice all of them and pin an offered thread.
- **Tests:** unit tests for dwell, LOS and TELL windows; AT-DATA-06.

### M4 — Conversation in motion (2 days)
- **Goal:** talk while moving.
- **Build:** NPC base (capsule, look-at, hand tells, schedule waypoint walker, FOLLOW_LEAD mode), ConversationDirector (exchange JSON, lines, chips with timeout, SILENCE and LEAVE, `npc_keeps_schedule`), SubtitleUI, ChipUI, Bark, SocialResolver v1 (claims, CALLED, pressure, reactions), positional addressing (addressee ring).
- **Done when:** a test NPC walks a 3-waypoint loop while talking; the player follows, picks chips, lets them time out (silence) or walks away (leave); a bluff gets CALLED or works per the NPC's knowledge.
- **Tests:** AT-SOC-01..05; AT-DATA-04, 07, 08.

### M5 — Scene 01 playable (1–2 days)
- **Goal:** the first real scene, end to end.
- **Build:** BAR scene content: Hale, Selin, Kai, Jules, Adrian background; schedules; all observables; S01 exchanges; TR_S1_* via TrapDirector v1 (claim bait plus hearing-radius audience); 4 resolutions; context hints; Scene 02 handoff stub.
- **Done when:** all 4 resolutions are reachable (AT-PLAY-03) and control starts within 2 s (AT-PLAY-01).
- **Tests:** a sim for each resolution; manual run logged.

### M6 — Scene 02 + Room 307 playable (2–3 days)
- **Goal:** the client walk and the first sandbox.
- **Build:** S02 walk-and-talk (location-triggered beats, elevator cabin rig), relationship effects; Room 307 + 308 with all interactables and observables, the mirror fog shader, Lina interruption (moving NPC, glasses removal), the Daniel hallway encounter, threads T_307_STAGED / T_SHE_LEFT_BY_WINDOW / T_SOMEONE_SEARCHED_307.
- **Done when:** AT-PLAY-04, 05, 06 and 07 pass.
- **Tests:** a sim for the threads offer logic; AT-GRAPH-10.

### M7 — Hotel hub navigation (2 days)
- **Goal:** the whole graybox hotel is walkable.
- **Build:** all blocks per LEVEL_LAYOUT (roof, mezzanine, service corridor, security room shell, laundry, dock, kitchen, cold storage, staff corridor, freight elevator, banquet corridor/hall, Orchid Room, restaurant); doorway graph; NPC schedules for the hub (Pavel, Daniel, Nico, Eva, Lina, Adrian) beat-driven; overhear zones (Adrian call, Daniel/Brody); TV map; phone UI (contacts, map photo).
- **Done when:** the player can visit every zone, and the NPCs loop believably without blocking paths (AT-ROB-03 partial).
- **Tests:** navigation smoke test (a sim teleports through each doorway pair and checks the target exists).

### M8 — NPC state, Leads A & B, social traps (2–3 days)
- **Goal:** the social heart of the hub.
- **Build:** Nico lead (working NPC, warmth gating, bar pour flourish), Eva lead (moving exchange, TR_EVA_615, TR_EVA_308, tail with LOS + noise detection, burner call overhear, confrontation), the 307 phone SMS, lead states, hub fallbacks (Nico text, Eva visibility, Lina/PA Thomas location).
- **Done when:** AT-PLAY-08, 09, 10 pass; AT-GRAPH-02 for {A,B}.
- **Tests:** AT-GRAPH-05, 09.

### M9 — Security route + Video room (2 days)
- **Goal:** social stealth and footage.
- **Build:** Perception (cones, noise radii, cover), Pavel loop, keypad, staff door, the 5 approaches (catch door, phone distraction TR_PAVEL_FAKE_FIGHT, cart cover, staff door, code peek via TELL), the caught escort + Daniel escort fail-forward, Video room (camera keys, timestamps, jog wheel, FootagePlayer with recorded capsule paths), photo item, Pavel return timer.
- **Done when:** AT-PLAY-11, 12; AT-GRAPH-03.
- **Tests:** a perception unit test; a sim for FAILED_DONE.

### M10 — Thomas scene (1–2 days)
- **Goal:** stop a man and get the truth in fragments.
- **Build:** the dock scene, Thomas walk-to-car, the 5 stop methods, the fragments with the 70 s self-advance guarantee, READ props on/around the car, TR_THOMAS_DANIEL, keys item, the van arrival CINE (≤ 8 s).
- **Done when:** AT-PLAY-13; all guaranteed facts are granted in every path.
- **Tests:** a sim: silence-only playthrough grants F_ADRIAN_THINKS_MARA_FORGOT.

### M11 — Chase (3–4 days)
- **Goal:** a 4–6 min improvisational escape.
- **Build:** ChaseDirector (heat, rubber-band, cross-door spawning), Pursuer FSM with NavigationAgent3D + vault links, the grab/struggle, the interrogation fail-forward scene, all ChaseTools per ACTION_SEQUENCE, the edge indicator, the chase music layers, chase.json hot reload.
- **Done when:** AT-PLAY-14, 15, 16.
- **Tests:** a pursuer FSM unit test; tools unit tests (each tool applies its effect); a manual timing log.

### M12 — Mara scene (1–2 days)
- **Goal:** emotional reveal through play.
- **Build:** the Orchid Room, Mara keep-away movement (stays opposite the table), the extinguisher stance, defuse options, the clip player (hold/scrub, READ tells on video), Thomas's arrival via freight, plan choice, card custody, the T_TWO_STORIES auto-offer.
- **Done when:** AT-PLAY-17; facts F2/F3 granted on every path.
- **Tests:** a sim for card custody by trust.

### M13 — Finale trap (3 days)
- **Goal:** the signature social trap.
- **Build:** the staging phase (StagePoints: place cards, recorder, card, doors, lights), phone invitations with templates and arrival order, the start gate, live phase NPC seating, positional addressing, TR_FINAL_MAIN/DIRECT/CARD_BAIT/PHOTO/WRONG, the Daniel pressure model, flee check, interception (vault, door slam, chair trip), thugs logic, the outcome 2/3 retries.
- **Done when:** AT-PLAY-18, 19, 20, 21; AT-GRAPH-06, 07; AT-SOC-06, 07.
- **Tests:** a finale sim matrix (doors × invites × bait).

### M14 — Endings + epilogue (1–2 days)
- **Goal:** physical decisions.
- **Build:** card pickup, give-to-NPC (A, B), destroy at the sink or burner (C), the Ending D chip sequence + phone hand-over, the door block, ending state, the epilogue street (controllable), variant details, the phone call, cut to black.
- **Done when:** AT-PLAY-22, 23; AT-GRAPH-01, 08, 11, 12.
- **Tests:** the full sims for all endings.

### M15 — Pacing, sound, polish pass (ongoing, 3+ days)
- **Goal:** it feels like the game.
- **Build:** pacing telemetry review and fixes (AT-PACE-01..05), music state machine, ambience beds, the tells' audio cues, camera composition pass per zone, lighting moods (rain, sodium, dawn), subtitle timing, the options menu, quick-save checkpoints, a full playthrough log.
- **Done when:** all AT tests pass and a full playthrough is logged in `PLAYTEST_LOG.md`.

After M15 comes the art replacement pass (not part of this plan): replace `Visual` subtrees zone by zone, re-running AT-ROB-04 each time.

---

## Parallelisable tracks (if more than one agent session)

- Track 1 (systems): M1–M4 → M9 perception → M11 chase.
- Track 2 (content): after M4, write JSON for S01–S09 exchanges and traps against the docs (validator-driven).
- Track 3 (levels): after M1, graybox all blocks (M7) early.

## Risk register

| Risk | Mitigation |
|---|---|
| Camera-relative depth movement feels mushy | Direction lock on blends; tune per rig; allow a rig-specific `input_basis` override. |
| Conversation + movement desync (NPC walks off mid-line) | Lines are attached to the NPC, and the director pauses the NPC's schedule only if the line is flagged `hold`. The hero leaving the radius means LEAVE. |
| The trap system becomes a menu | No UI lists traps. Traps only exist as JSON conditions on world state + bait events. |
| Chase AI gets stuck | Navmesh per block, vault links, a 3 s stuck detector → reposition off-screen. |
| Scope creep in dialogue | Line budget: ≤ 450 lines total for EP01 (including barks). Track the count in PROGRESS.md. |
| Pacing drift | Telemetry from M5 onward; the F4 overlay shows decision gaps live. |
