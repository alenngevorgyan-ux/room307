# ROOM 307 — Episode 01 (graybox)

A cinematic 2.5D psychological thriller built in **Godot 4.7** (GDScript, GL Compatibility renderer).
One hotel, one rainy night: read people, set social traps, play the truth out of them — and decide
physically what happens to the recording. All in-game text is Russian.

## Play

- **Builds:** see the rolling [`playtest` release](../../releases/tag/playtest) (Web / Windows / macOS / Linux), produced by CI on every push to `main`.
- **From source:** `godot --path .` (or open `project.godot`). Jump to any scene: `godot --path . -- --scene S04`.

| Action | Keys |
|---|---|
| Move (camera-relative) | WASD / arrows |
| Fast walk (toggle) · Run (hold) | Caps Lock · Shift |
| Crouch / slide while running | Ctrl or C |
| Context (vault, doors, struggle) | Space |
| Interact / talk / pick up / place | E |
| READ (hold) + aim with the mouse | Right mouse button or F |
| Dialogue chips | 1–4 (or click) |
| Phone (invites, photo, messages) | Tab |
| Threads: pin (tap) / expand (hold) | Q |
| Pause | Esc |
| Debug: state · scene jump · fact grant · pacing · reload data · save · load | F1 · F2 · F3 · F4 · F5 · F6 · F7 |

## Develop

- Tests (data validator + unit + SIM, incl. a full bar→ending playthrough for all 4 endings): `./run_tests.sh`
- Content lives in `data/ep01/` (JSON: lines, exchanges, traps, facts, level blocks …). Code in `src/`.
- Design docs: `docs/EP01_*.md`. Status: `docs/PROGRESS.md`. Manual checks: `docs/PLAYTEST_LOG.md`.
