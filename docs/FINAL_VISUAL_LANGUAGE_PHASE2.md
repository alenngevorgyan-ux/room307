# ROOM 307 — Final Visual Language V1 · Phase 2 (Room 307) evidence packet

Branch `final-visual-language-v1`. BEFORE is the **accepted Phase 1** state, `1a85f9e` (Room 307 not yet in the rollout). AFTER is `3527116`. Same approved language as the BAR, the same gameplay cameras (follow rig + bath fixed rig) and the same motion. `main` is untouched.
Rollout STOPS here for visual review. Phase 3 (service / laundry / security) has not started.
Characters remain **PROXY**.

## What changed (visual only, inside each prop's footprint)
`VesperArt.ROLLOUT = ["BAR", "ROOM_307"]`. Inside Room 307 the old material names alias to final profiles. Geometry, collision, navigation, markers, interactables and all data are unchanged (`git diff 5f82d72..HEAD` on the protected paths is empty).

| Request | Change |
|---|---|
| More painterly walls, wood, fabric, glass, bathroom | **Walls:** brush-painted warm plaster (`v_room_wall`, brush map) replaces the regular wallpaper grid. **Dado:** painted cream panels with soft wear. **Carpet:** muted field, lattice contrast down from .35 to .16, lighter than V1 so figures read on it. **Wood:** walnut profiles on bed plinth, desk, nightstand, headboard and wardrobe (these were oxblood red in V1 because of their tint). **Fabric:** matte linen bedding, a separate duvet tone, heavy rose curtain with gathered folds. **Glass:** a half-drunk water glass and a faint shower screen. **Bathroom:** tile floor and tiled lower walls (on the perimeter walls only), stone vanity with ceramic basin and drain, brass tap and shower head, a painted mirror (dark depth plus one soft highlight; the evidence text stays readable). |
| Warm interior + cool rain light from the window | The warm wall lamps, desk lamp and nightstand lamp are unchanged. New: a walnut sill and a faint **cool window light lying on the floor** (pane shape, mullion, rain shadows sliding down; additive, unshaded, low). The cool data lights and the window spill are unchanged. |
| A recently occupied room | Duvet turned back and pushed aside on one side, folded corner, pillows askew (one dented), throw across the foot, half-drunk water glass on the nightstand. Restrained, with no clutter added on routes. |
| Small interactables more readable, no detective vision | The nightstand lamp **moved off the pills** (in V1 it stood on top of them). Every small clue (glasses, bottle, slip, pills, phone, shoes, charger, towels, bag, the TV-side clue) gets a faint contact shadow, which hides with the clue when it is taken. No glow, no outline, no tint. READ is still only a grade change (frame `r307_06_read_desk`). |
| EL's face/silhouette reads better, camera unchanged | Two broad highlight groups in EL's curls (crown, left fringe) so the hair reads as volume. The lighter carpet makes his dark silhouette separate from the ground everywhere in the room. The Phase 1 bridge stays (lid lines, brow ridge, collar, rim confined to EL). Head scale and camera are unchanged. In these views EL faces the desk or window away from the camera, so identity reads by silhouette, hair and collar (head ≈ 20–24 px). See `crops/`. |
| Don't overload, don't change geometry/routes | Nothing is placed on a clue or on a route. The camera-side foreground silhouette is now a low reading chair instead of a 1.6 m black slab. |
| Occluders | The wardrobe (a camera occluder) is now **one consolidated mesh**: body, raised doors, cornice, plinth, pulls. It wears its own duplicated material, so the camera fades the whole thing. V1's separate door lines and handles did not fade. The tile cladding avoids the bath partitions, which can fade. |
| Performance | Static decor of each dressed prop and the room's look-root merged per material (227 → 205 draws). An A/B in one session shows it is visually neutral (`merge_ab_visually_neutral.jpg`). |

Also fixed: the Phase 1 rule "sconces glow-only" is now restricted to the BAR. The first Room 307 pass had silently removed the warm wall-lamp pool there; caught by eye and fixed before this packet.

## Evidence (`docs/final_visual_v1/room307/`)
- `stills/`: six gameplay views, BEFORE (`1a85f9e`) and AFTER. Desk, window, bed, room from the door, bathroom (fixed bath rig), and READ held at the desk. Auto-exchanges are off in both runs, so framing is deterministic.
- `motion/`: EL walking from the door toward the window (10 fps, 3 s) and the curtain breathing at the open window (4 fps, 4 s), before on the left, after on the right. All after frames are in `frames_after/`. Camera path, framing and timing match the baseline.
- `crops/EL_desk_window_before_after.jpg`: EL at the desk and the window at native pixels.
- `merge_ab_visually_neutral.jpg`: no-merge / merge / no-merge in one session.
- `perf/`: raw JSON.

**Capture caveat:** separate capture sessions of S03 differ slightly in overall warmth and exposure, because the scene state at capture time varies. Compare BEFORE/AFTER as pairs, and use the same-session A/B for the merge claim.

## Tests (`3527116`, separate worktree, headless)
| Suite | Result |
|---|---|
| `./run_tests.sh` unit/SIM | 114 tests, 0 failed |
| World checks | 23, 0 failed |
| Autopilots A_MARA / B_THOMAS / C_DESTROY / D_ADRIAN | PASS ×4, 0 script errors (fail on any NPC pop) |
| `pop_audit.gd --autopilot=A_MARA` | 0 pops, ending PASS (also B_THOMAS on `2e46542`: 0 pops) |
| GL backend | All captures on gl_compatibility / macOS / Intel HD 6000: 0 shader errors, no black frames |

## Performance (Intel HD 6000, 1280×720, vsync off, wall ms of one game-view draw, Room 307 desk view)
The machine was under heavy background load during part of this phase (load average 10–33: system video decoding, QuickLook, Spotlight indexing). Isolated runs contradicted each other. The decisive measurement is **interleaved** (baseline, candidate, baseline, candidate; 10 s warm-up + 3 × 20 s each) under the same load:

| Build | Median | p95 | CPU ms | Draw calls | Texture MB |
|---|---|---|---|---|---|
| Baseline `1a85f9e` (2 runs) | 25.30 | 39.09 | 9.12 | 188 | 32.5 |
| Candidate `3527116` (2 runs) | 26.07 (+3.0%) | 31.81 | 8.96 | 205 (+9%) | 32.5 |

Within budget (median ≤ +10%, p95 ≤ +15%). The single earlier quiet-machine pair (base 24.3 / candidate 22.0 ms) and a heavily loaded pair (17.9 / 22.8 ms) are kept in `perf/` for transparency. Neither is used for the claim. No new texture memory (the Phase 1 maps are reused).

## Remaining gaps
- Proxies remain proxies. In Room 307 EL is mostly seen from behind (desk, window), so the face is not the readable feature at this camera; silhouette and hair are. Real likeness needs authored heads and hair.
- The bathroom is now readable but plain: no towel rail or shower glass reflections; mirror and glass are painted approximations.
- The floor carpet is a procedural field without a border. A painted carpet texture is a production asset.
- The cool window light is a floor card and does not fall on the bed or characters. Real light shaping (projector textures) is not available on this renderer path.
- The motion frames were captured just before the draw-call merge. The same-session A/B shows the merge does not change the image.

## Rollback
- Runtime: `-- --art-v1` (or `/tmp/room307_art_v1` in debug) returns the whole art layer to Motion Polish V1. To keep the BAR and roll back only Room 307, remove `"ROOM_307"` from `VesperArt.ROLLOUT` (one line).
- Code: `git revert 3527116 0c75550 2e46542` returns to the accepted Phase 1 (`1a85f9e`).
