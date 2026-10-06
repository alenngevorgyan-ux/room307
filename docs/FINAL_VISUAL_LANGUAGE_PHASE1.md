# ROOM 307 — Final Visual Language V1 · Phase 0 + Phase 1 (BAR) evidence packet

Branch `final-visual-language-v1`, created from the expected baseline
`5f82d7269d7f0bd205511b9fe915166708431789` (`visual-integration-v1-motion-polish`, unchanged, not
advanced). `main` and the source branch are untouched. Implements ROOM307_FINAL_VISUAL_HANDOFF_V1,
**Phase 0 and Phase 1 only**. Rollout STOPS here for visual review; Phase 2 (Room 307) has not started.

All characters remain **PROXY** (procedural). Nothing in this phase is a final character model.

---

## Phase 0 — evidence baseline

| Item | Value |
|---|---|
| Baseline SHA | 5f82d7269d7f0bd205511b9fe915166708431789 (pinned in the separate worktree `../room307-testrun`) |
| Engine | Godot 4.7.2.stable.official.ed1daf0bf, `gl_compatibility`, 1280×720 (project.godot) |
| Machine | macOS 12.7.5, Intel HD Graphics 6000 (1536 MB shared), debug build, capture viewport 1280×720 off-screen, vsync off during measurement |
| Baseline tests | 114 unit/SIM, 23 world checks, autopilots A_MARA / B_THOMAS / C_DESTROY / D_ADRIAN PASS (0 pops) |
| Baseline captures | `docs/final_visual_v1/bar/stills/*__BEFORE_5f82d72.png`, motion frames, `perf/*__BEFORE.json` |

### Asset inventory
The repository contains **no** meshes, glTF, textures or material resources. Every
visual is procedural (`level_builder`, `VesperLook`, `VesperDress`, `BodyVisual`). Missing for final
fidelity (production dependency, not supplied by the handoff): authored hero props (counter, stool,
bottle kit) as beveled meshes; painted texture sets (wood ×3, stone ×2, carpet, paint, service,
patina/wet masks, cloth atlas); **all character heads, bodies, hair, rigs and textures** (EL first,
then the cast). This phase adds three baked, tileable detail maps (see below). They are authored
procedural maps, not hand-painted production textures.

### Touched vs protected files

| Touched in Phase 1 | Purpose |
|---|---|
| `src/world/vesper_art.gd` (new) | Rollout gate: `ROLLOUT = ["BAR"]`, `--art-v1` / `/tmp/room307_art_v1` rollback, rig-only visual toggle |
| `src/world/vesper_surface.gdshader` | Authored detail layer (new uniforms only; old uniforms, fade dither, wet/ripple unchanged; `detail_mix 0` = V1) |
| `src/world/vesper_look.gd` | Final material profiles + BAR-only aliases of old names, profile textures, softer BAR light falloff, glow-only BAR sconces |
| `src/world/vesper_dress.gd` | BAR hero kit, bottle MultiMesh, contact/glint cards, opening backdrop, downlights, BAR chair silhouettes |
| `src/npc/body_visual.gd` | Proxy bridge (construction/material only). Pivots, anchors, pose/gaze/mood/footfall/work_beat untouched |
| `src/world/hotel_world.gd` | +1 line in `_process`: `VesperArt.tick(self)` (visual toggle) |
| `src/world/vesper_time.gd` | +1 type: practical lights cast to `Light3D` (lets the BAR downlights dim with dawn). Palette/stages/timing unchanged |
| `assets/vesper/textures/*.png(+.import)` | Baked detail maps, mipmapped. `.gitignore` gets an `assets/**/*.import` exception |
| `tools/bake_vesper_textures.gd` (new), `tools/capture_shots.gd` | Map baker; new capture recipes `s_60_bar_art`, `s_61_bar_motion`, `s_62_perf`, `s_63_perf_short` (existing recipes unchanged) |

**Protected (diff vs baseline is empty, verified with `git diff 5f82d72..HEAD -- <paths>`):**
`src/camera/*`, `src/player/*`, `src/npc/npc_controller.gd`, `body_motion.gd`, `body_language.gd`,
`src/world/vesper_motion.gd`, `src/dialogue/*`, `src/chase/*`, `src/core/cine_player.gd`,
`scene_manager.gd`, `src/scenes_logic/*`, `src/world/level_builder.gd`, `src/main.gd`, `scenes/*`,
and **all of `data/`** (rigs, markers, cines, chase, schedules, interactions, observations, lights,
proxies.json).

---

## Phase 1 — BAR

### What changed (all visual, all inside the original prop footprints)
1. **Light and face contrast first.**
   - Existing room lights in the BAR get a softer falloff and 10% more range, so the warm pools reach floor, stools and faces.
   - One warm face fill at guest face height in front of the counter.
   - Two warm ceiling downlights over the guest floor. They take the slots of the two side-window cool spills, which lit the hidden back-bar corner.
   - The middle window keeps its cool spill (warm/cool split).
   - The three wall sconces behind the bar and the booth-table lamp are glow-only.
   - Net effect: the BAR floor went from 16 to 12 lights per object, below the GL cap of 16 with headroom. The engine had been swapping lights at the cap, which produced a one-frame cool flash as EL walked.
   - Bloom was not increased.
2. **Silhouettes:**
   - **Counter:** quiet green marble top with a rounded walnut nose, panelled walnut front, brass foot rail with brackets, dark kick recess.
   - **Stools:** crowned oxblood cushion on a brass ring, tapered post, flared base, foot ring.
   - **Shelving:** grouped bottles, 3–7 per group with gaps and varied heights. Body + shoulder + neck mesh, all in **one MultiMesh**. Brass shelf lips.
   - **Booths:** rolled seat front, channelled back, walnut cap.
   - **Tables:** walnut top with brass edge.
   - Bodies, collision and footprints are untouched.
3. **Material library (shared profiles, small atlas/mask stack):**
   - Profiles: `v_wood_floor`, `v_wood_dark`, `v_wood_panel`, `v_marble_dark`, `v_marble_cream`, `v_brass_aged` (patina lowers bare-metal response), `v_oxblood`, `v_bar_wall`. Colour ranges come from MATERIAL_LIBRARY.md.
   - Maps (512², tileable, mipmapped, R value / G wear·vein·patina / B roughness deviation):
     - `wood.png`: uneven grain in stroke groups;
     - `marble.png`: mineral clouds with a few broken veins, replacing the old sine stripes;
     - `brush.png`: 26° directional strokes plus a patina mask.
   - In the BAR, old material names are aliased to these profiles. Old names keep the V1 look everywhere else.
   - Subdued glass: an opaque dark core lit by the backlit "liquid" colour, with a painted bright rim. No transparency.
4. **Contact:**
   - Soft radial contact cards under stools, booths, tables, counter and back bar, and under every character's feet.
   - Blurred warm floor glints below the counter lamps suggest polish. No probe, no mirror.
   - **Shadowed key: measured and rejected.** One shadowed downlight took the opening to median +12% (budget +10%). Kept as a debug-only probe (`/tmp/room307_bar_shadow`).
5. **Proxy bridge (temporary, explicitly PROXY):**
   - Jaw/cheek mass and a brow ridge on the head.
   - Dark upper-lid lines with small dark irises instead of bead eyes; a mouth line.
   - Shirt collar, plus suit lapels or an open overshirt collar depending on the jacket.
   - One shoulder yoke instead of two balls.
   - Trouser hems breaking over the shoe; EL gets the wider canon hem.
   - EL's curls consolidated into a cap plus 5 shaped clumps (was 13 balls).
   - Rim .45 → .12 on all proxies.
   - EL's cool rim light is now confined to EL's own render layer. It used to tint the floor and counter around him.
   - Nico and Jules keep distinct specs. No casting change.
6. **Kept:** the work routines and the camera/staging are unchanged, rain on the panes and passing traffic still run, and the opening UI is the same.
   - **Opening only:** the opening fixed camera (BAR:start, unchanged) looks toward the room's camera side, which the follow rig never sees. That void now gets a wall with banquette backs, sconces and mirrors. It is visible **only while that rig is live** and lit on its own render layer, so it can never occlude play or take a light slot.
   - **Foreground:** the BAR club-chair silhouettes are now shaped. They were black boxes that read as blocks once the floor was lit.

### Captures (native 1280×720, same recipes and states on baseline and candidate)
- `docs/final_visual_v1/bar/stills/`: opening 4 s and 10 s (close opening camera, unchanged), hub ordinary view at the guest table and in front of the counter (follow rig; auto-exchanges disabled during these stills in **both** runs so the framing is deterministic).
- `docs/final_visual_v1/bar/motion/`:
  - EL walking along the bar (10 fps, 3 s) and the Nico conversation with his work routine (6 s), before on the left, after on the right.
  - All after frames are in `frames_after/`.
  - There is no video encoder on this machine, so motion evidence is frame sequences.
- `docs/final_visual_v1/bar/rollback_art_v1_vs_baseline.jpg`: with the rollback switch the BAR renders as the baseline.

**Camera/motion evidence:**
- The walk and conversation sequences show the same camera path, framing, subtitle and choice timing in baseline and candidate.
- Nico's polish / set-down / bottle reach / lean cycle runs as before, and the bloom ball no longer appears when he reaches.
- The protected-source diff is empty.

### Tests (candidate `7d3a685`, separate worktree, headless)
| Suite | Result |
|---|---|
| `./run_tests.sh` unit/SIM | 114 tests, 0 failed |
| `tests/world/world_checks.gd` | 23 world checks, 0 failed (camera never snaps, no fly after talk, camera pitch, movement feel, doors/steam, light drift, footfalls, UI easing, staging …) |
| Autopilots A_MARA / B_THOMAS / C_DESTROY / D_ADRIAN | PASS ×4, 0 script errors (autopilot fails on any NPC pop) |
| `tests/world/pop_audit.gd --autopilot=A_MARA` | 0 pops reported, ending PASS |
| GL backend (V18) | All captures on `gl_compatibility` / macOS / Intel HD 6000: 0 shader errors, no black frames |

### Face size at gameplay distance (handoff step 1: measured before any head change)
Measured on the captures: the opening camera shows heads at about 45–55 px tall (conversation range, so brow, lids and collar read). In the ordinary hub view heads are about 12–16 px (long range, judged by silhouette, collar and hair mass). Head scale was **not** changed, and the camera was not changed.

### Performance (Intel HD 6000, 1280×720, vsync off, wall time of one draw of the game viewport, ms)
GPU timer queries return 0 on this GL driver, so wall time of the forced draw is the comparable metric. Hub: 30 s warm-up then 3 × 60 s. Opening (dialogue playing): 3 s warm-up then 3 × 15 s.

| View | Baseline median / p95 | Candidate median / p95 | Δ median / Δ p95 | frames > 33.3 ms per window |
|---|---|---|---|---|
| BAR hub | 23.14 / 27.91 | 22.29 / 26.52 | −3.7% / −5.0% | base 5/5/5 → 3/5/3 |
| BAR opening | 28.83 / 34.51 | 28.04 / 33.34 | −2.7% / −3.4% | base 27/22/23 → 12/15/15 |
| *Probe: + one shadowed key* | — | opening 32.30 / 37.51 | **+12% / +8.7%** | rejected (over budget) |

Draw calls: hub 395 → 335 and opening 423 → 369 (bottle MultiMesh). Texture memory +2.9 MB (budget 128 MB). Video memory +1.4 MB.

### Remaining gaps (honest)
- **Faces and bodies are still proxies.** At hub distance the cast reads by silhouette, collars and heads. Likeness (V05/V06) needs authored heads, hair and rigs (CHARACTER_PRODUCTION_PLAN.md). Dark wardrobe guests (the "guest" spec) are still very dark in the hub.
- The ordinary hub view is better grounded (floor, stools, people), but it is still a dark, mood-first frame. The ceiling-less top band of the frame remains empty night colour.
- Detail maps are procedural bakes. Painted production texture sets are still an external need.
- No shadowed key (unaffordable on this GPU). Grounding comes from contact cards only.
- The marble specular hot spot nearest the opening camera is bright. It is a lamp reflection, tunable.
- No 10–20 s video file (no encoder on this machine). Frame sequences instead.
- The proxy bridge applies to the whole cast (a character is one object in every room), so EL's improved proxy also appears outside the BAR. Environment changes are BAR-only.

### Rollback
- Runtime: start with `-- --art-v1` (or create `/tmp/room307_art_v1` in a debug build). The BAR, its materials, lights and the character proxies return to the Motion Polish V1 look.
- Code: `git revert 7d3a685 8e8f1c2` (or check out `5f82d72`). Nothing outside the touched list above depends on these commits.
