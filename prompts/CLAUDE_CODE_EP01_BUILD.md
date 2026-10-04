# CLAUDE CODE — BUILD EPISODE 01 "ROOM 307"

You are the lead engineer on a small indie team. Your job in this session, and in the sessions that follow it, is to **build a playable game episode**. You are not here to write design documents; that work is already done.

---

## 1. What this project is

An episodic **cinematic 2.5D psychological thriller**. The player is a ~36-year-old man who has lived many lives (bars, cards, rich people, con artists, failed businesses). He reads people and engineers social situations in which they reveal themselves. He is not a detective, not a cop and not a mentalist.

Episode 01, "ROOM 307", is set in one hotel over one rainy night and runs 35–45 minutes. The player:

- reads a fake watch theft in a bar;
- is hired by Adrian Vale to find his daughter Mara;
- investigates a staged hotel room;
- works three social leads in a hub (a bartender, a lying friend, the security room);
- stops Thomas, the old chauffeur, and learns that Adrian was driving in a fatal accident seven years ago;
- escapes Daniel's men through the service areas;
- finds Mara, who has the dashcam recording and was made to believe *she* had been driving;
- stages a confrontation in the empty restaurant that exposes Daniel;
- physically decides what happens to the recording, which is the ending.

**Core law:** the player plays; the player does not read. Conversations happen while everyone moves. There are no evidence boards, no long dialogue trees, no cutscenes over 15 s, and no ending menus.

## 2. Sources of truth (read them in this order before writing code)

1. `docs/EP01_IMPLEMENTATION_PLAN.md`: milestone order, repo layout, how to run.
2. `docs/EP01_STATE_MODEL.md`: every data structure, the JSON formats, the social resolver, the trap model.
3. `docs/EP01_GAMEPLAY_SPEC.md`: what each scene must do.
4. `docs/EP01_LEVEL_LAYOUT.md`: the zones, connections, camera rigs and graybox conventions.
5. `docs/EP01_INFORMATION_GRAPH.md`: the facts and their sources. Progression must never be single-path fragile.
6. `docs/EP01_CHARACTER_BEHAVIOR.md`, `docs/EP01_DIALOGUE_AND_TRAPS.md`, `docs/EP01_ACTION_SEQUENCE.md`: content.
7. `docs/EP01_ASSET_MANIFEST.md`: use only the GRAYBOX column for now.
8. `docs/EP01_ACCEPTANCE_TESTS.md`: the definition of done.

When the docs conflict: the ACCEPTANCE_TESTS win on *what must work*, the STATE_MODEL wins on *how data is shaped*, and the GAMEPLAY_SPEC wins on *what a scene contains*. Note any conflict in `docs/PROGRESS.md` under "Decisions" and move on.

All in-game text is Russian (in `data/ep01/lines_ru.json`). Code and comments are in English.

## 3. First steps (M0)

1. **Inspect the repository before changing anything.**
   - Is there an engine project (`project.godot`, `*.uproject`, a Unity `Assets/`, or other)?
   - What language is used? Is there a player controller, an interaction system, a dialogue system, a camera system or prototype mechanics?
   - What is the folder structure and the art pipeline?
2. Write `docs/REPO_AUDIT.md`. For each existing system, record what it does, whether it works, and whether to reuse, extend or wrap it, mapped against the plan's systems.
3. **Do not throw away working systems. Do not switch engines.** Extend the existing architecture, and adapt the file layout in the plan to it.
4. Only if the repo is greenfield: create a Godot 4.x project with GDScript, the folder layout from IMPLEMENTATION_PLAN §0, the autoloads `Episode`, `Bus`, `Data` and `Debug`, the test runner `tests/run_tests.gd`, and `docs/PROGRESS.md`.
5. Find out how to run Godot in this environment (`godot`, `godot4`, or a path; check `which godot godot4`). If no Godot binary exists and you are allowed to install one, download the official Linux headless/editor build and record the command in PROGRESS.md. If you cannot run the engine at all, still write code and tests, keep a clear list of "unverified at runtime" items in PROGRESS.md, and never claim something works without having run it.

## 4. How to work

- **Implement milestone by milestone: M0 → M15**, in the order of the plan. You may reorder only when the repo audit makes it necessary, and you must write down why.
- **Each milestone must end in something playable**, together with the tests it lists.
- **Keep changes small and reviewable.** Aim for one logical change per commit, and stay under ~400 changed lines per commit where you can. Use commit messages of the form `M5: Hale pacing schedule + restroom detour`.
- **Run the project after every meaningful change**, at minimum the headless test runner and a headless boot of the main scene: `godot --headless --path . --quit-after 120` (or the equivalent) to catch script errors.
- **Fix regressions before you continue.** A red test blocks the next milestone.
- **Keep `docs/PROGRESS.md` current.** It holds a checklist of M0–M15 with sub-tasks, the status of each acceptance test, decisions, known issues and a dialogue line count (budget ≤ 450).
- **Content goes in JSON (`data/ep01/`), not code.** Scene scripts in `src/scenes_logic/` are thin glue. If you are about to hard-code a scene's facts or lines in GDScript, stop and put them in data instead.
- **Use placeholders freely**: capsule characters with a head, a nose wedge and hand cylinders; box geometry; CC0 or silent placeholder audio; Label3D captions. Gameplay must not depend on final art: reference marker nodes (`InteractPoint`, `ObservablePoint`, `SeatPoint`, `StagePoint`, `CoverPoint`), never meshes.
- **Do not stop to ask questions you can answer from the docs** or from reasonable judgement. Make the decision, log it under "Decisions" and continue. Ask the human only when something is truly blocking, such as a missing engine binary with no install rights, or a requirement contradiction that changes the story.
- **Continue autonomously** through the plan until all milestones are done or you hit a real blocker. At natural stopping points (end of a milestone), post a short status: what is playable now, which tests pass, and what comes next. Then keep going.

## 5. Absolute rules

- **DO NOT merely create design documents.** The design is done.
- **DO NOT return mockups instead of functionality.**
- **DO NOT replace gameplay with menus.** There must be no trap-selection menu, no evidence board, no ending menu and no dialogue screen that freezes the player for long sequences.
- **DO NOT stop after making the first room.**
- **DO NOT create fake buttons, prompts or interactables that do nothing.** Every visible interaction must change state or give feedback.
- **DO NOT attempt the entire episode in one giant unsafe patch.**
- **BUILD THE ACTUAL PLAYABLE EPISODE IN ITERATIONS.**
- READ must never show a conclusion. The validator bans captions containing «врёт», «лжёт», «виновен», «доказывает» or «значит».
- No cinematic may run longer than 15 s. Add a debug assert for this.
- No game over and no reload: every failure branches into a new situation, as specified in each scene's fail-forward section.
- Never let the player's progress depend on a single missable interaction. The information graph lists the redundancy; the validator and the sims must prove it.

## 6. Verification per milestone

For every milestone:

1. The automated tests listed in the plan pass (`godot --headless --path . -s res://tests/run_tests.gd` exits 0).
2. The data validator passes (AT-DATA-*).
3. The main scene boots headless without errors.
4. You use the debug tools to exercise the new feature: F1 state dump, F2 scene jump, F3 fact grant, F4 pacing log. Where possible, write a **SIM test** that drives the same path through `Episode` and `Bus` without rendering.
5. You record the manual acceptance items for this milestone in `docs/PLAYTEST_LOG.md`, marked "needs human playtest" if you cannot play interactively. Describe exactly what to press and what should happen, so a human can verify it in under two minutes.

Before marking a milestone done, ask yourself: **"Is the player actually doing something interesting here?"** If the answer is "they read", "they watch" or "they click through dialogue", redesign that piece within the spirit of the docs and log the change.

## 7. Priorities when time is short

1. The core loop works end to end in graybox (S01 → endings), even if rough.
2. Every acceptance test in sections A–C passes.
3. The feel of movement, READ, conversation in motion, the chase and the finale staging.
4. Pacing (telemetry).
5. Polish.

Never trade (1) for (5).

## 8. Key technical decisions already made (do not relitigate)

- Movement is a `CharacterBody3D` with camera-relative XZ input and authored walkable geometry. There is no rail or lane code; lanes are level-design strips. Input direction locks during camera blends.
- The camera system consists of CameraZones (Area3D) that select CameraRigs, with 0.6 s blends. No free camera.
- The whole hotel is one world scene with blocks as child scenes, all loaded. Doorways teleport behind a 0.25 s fade or wipe.
- NPC schedules are beat-driven waypoint loops, not a simulated clock.
- Social resolution follows the deterministic pressure formula in STATE_MODEL §6, with authored overrides.
- Traps are JSON condition sets plus bait events, evaluated by the TrapDirector. They are never presented as a menu.
- One shared action vocabulary is used by interactables, exchanges and traps (ActionRunner).
- Tests use a custom minimal runner. GUT is optional only if it is already in the repo.

## 9. Definition of done for Episode 01

- All AUTO and SIM acceptance tests pass.
- All MANUAL tests are described in PLAYTEST_LOG.md, and those you could verify yourself are checked.
- A human can launch the game, play from the bar at 02:17 to the street at dawn, and reach any of the four endings through physical action, in 35–45 minutes, without a reload, a menu choice or a cutscene longer than 15 s.

Start now with M0.
