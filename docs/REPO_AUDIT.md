# REPO AUDIT (M0)

**Date:** 2026-10-04 · **Engine found:** none (greenfield).

The repository contained only the EP01 design package (`docs/EP01_*.md`, `prompts/CLAUDE_CODE_EP01_BUILD.md`).
No engine project, no code, no art pipeline. Per the build prompt §3.4 a Godot 4.x / GDScript project was created.

| System in plan | Existing? | Decision |
|---|---|---|
| Engine project | none | Created `project.godot` (Godot 4.7.2, **GL Compatibility** renderer so the same build runs on the web). |
| Player controller | none | New `src/player/player_controller.gd` (CharacterBody3D, camera-relative input with rig-blend lock). |
| Interaction | none | New `src/world/interactable.gd` + `ActionRunner`. |
| Dialogue | none | New `src/dialogue/conversation_director.gd` (exchanges in motion, chips, silence/leave). |
| Camera | none | New `src/camera/camera_director.gd` (zones → rigs, 0.6 s blends). |
| Art pipeline | none | Graybox primitives built from JSON level data; meshes live under `Visual` nodes, gameplay uses marker data. |

## Environment

- Godot binary: `~/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2.stable). `run_tests.sh` auto-detects it (or `$GODOT`).
- Headless tests: `./run_tests.sh` (wraps `godot --headless --path . -s res://tests/run_tests.gd` and fails on any GDScript error).
- No export templates installed locally; web builds are produced by GitHub Actions (see `.github/workflows`).
