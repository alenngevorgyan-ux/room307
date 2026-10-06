# ROOM 307 — EP01 · Design + Motion Polish V1

Branch `visual-integration-v1-motion-polish` (from Visual Integration V1 `16131aa`). `main` and the
V1 checkpoint are untouched. No new episodes, mechanics, story logic or topology were added, and the
four endings are unchanged. This pass polishes the existing game: fewer pops, more intention, and
a night that moves.

Rule of thumb for every change: **visual/audio only**. Collision, navigation, perception, noise
radii, timings that gameplay reads, and the story state machine stay as V1 had them. Everything
new is covered by headless world checks (17 → 22).

---

## 1. Changes by scene

| Scene | What changed |
|---|---|
| **S01 Bar (opening)** | Fades up from black (1.6 s) before the card. The opening card sits above the subtitle band and no longer overlaps the first line. The backlit bottle wall is now a gradient (bright at the counter, falling off toward the ceiling) instead of a flat orange slab. Its lamp sits above and behind the shelf, so it never blooms on Nico when he reaches for a bottle. Windows carry rain streaks, beads and the occasional sweep of passing headlights. When the bar has people, a positional murmur plays. Nico/Jules work the bar (polish, set down, turn to bottles, lean), and a glass clinks when Nico sets one down. |
| **S03 Room 307** | The camera is lowered from 36° to 29°. The curtain breathes into the room while the window is open and settles when EL closes it. Rain at the glass is a positional loop that drops away when the window is closed. The door swings when anyone passes. |
| **S04 Hub (3F hall, lobby, mezzanine)** | Scene changes no longer move EL on screen: he stays put if he is already close, otherwise the move happens under a cut. Doors and elevator doors animate when NPCs come and go, with sound if EL is in that room. |
| **S05 Rooftop** | HVAC fans turn, the shelter tube stutters now and then, rain eases with the hour, and puddles show ring ripples while it rains. Eva's cigarette smokes. |
| **S05/S06 Security** | Footsteps sound on the service floor. Tube stutter in the service corridor. |
| **S06 Loading dock / Thomas** | Lit under the canopy (two strong lights instead of one weak one). The wet concrete is lighter (V1's was near-black and swallowed every lamp), so Thomas and EL read against the ground. Rain no longer falls in the camera-side strip, where it read as screen scratches. The lighter rain material keeps it in the background. |
| **S07 Kitchen chase** | Camera lowered from 47° to 31°. Steam rises from the stove line and fryer into the hood. The extractor hum is positional. The swing doors flap through and settle when Daniel or EL pass. Running footsteps sound on tile in time with the stride. |
| **S07 Laundry / cold storage** | Cameras lowered (45° to 30°). The steam press breathes out a puff with a hiss every 5–9 s, and the sheets sway. |
| **S08 Mara / Orchid, banquet hall** | Banquet camera lowered from 43° to 30°. The pre-dawn sky shows in the windows. |
| **S09 Restaurant finale** | Camera lowered from 34° to 28°. The light is one long dawn: over the finale (~7 min, floored at the LIVE and DECISION beats), cold morning slowly takes the room from the warm lamps (lamps 1.0 → 0.6, window spill rises, ambient lift). Dust hangs in the morning light. |
| **Epilogue** | Clearly morning: dawn sky, no rain, lamps down, exterior lift. The end card fades in slowly with spaced type, and the summary follows a beat later. |

## 2. Camera (Pass B, I, J)

- **Spring rig**: position, look and FOV are three critically damped springs (SmoothDamp)
  instead of lerps. Position 0.34 s, look 0.24 s, FOV 0.5 s. No snapping and no floating.
- **Look-ahead**: the frame leads in the direction of travel (≤ 1.1 m, 0.2 s of velocity).
  The look gets the full lead and the position 60%, so the camera turns before it travels.
  Damped by 70% during conversations so the frame holds on the pair.
- **Recomposition**: when the rig target jumps (rig change, room-to-room), springs slow to
  ≥ 0.62 s for 1.4 s and the camera recomposes calmly. Worst-case step on a rig change dropped
  from 0.175 m/frame to < 0.12 (world check `camera_never_snaps`).
- **Arrival settle**: after a door the camera starts slightly wider and higher, then settles.
- **Mode blends**: social, chase and READ weights ramp, then smoothstep, so they never switch.
  Shake is a smooth tremor, not jitter.
- **Composition**: no follow camera is steeper than 33° (world check `camera_pitch`). The
  mezzanine is the one deliberate exception (looking down over the rail).
- **Movement feel**: per-gait acceleration (walk 11, fast 14, run 20, crouch 10, slide 30),
  stronger deceleration (22) when stopping or reversing, and a 10 rad/s turn rate. Walk reaches
  speed in 5–24 frames and stops in 2–14 (world check `movement_feel`).
- **Scene transitions**: there is never a visible teleport. A reposition happens under a
  0.45 s cut to black, or EL simply stays if he is already within 6 m in the same zone.

## 3. Character motion (Pass C, D)

Every character has a `motion` profile in `data/ep01/proxies.json` covering: weight-shift
cadence, glance rate and duration, what they look at (people, exits, windows, down), fidgets
and how often (calm vs stressed), talk gestures, conversation stance angle, reaction to EL
approaching, turn-away tendency, and work routine.

- **EL**: angles his body 28° off the person he talks to, and his eyes go to their hands now
  and then. Before answering a choice he looks away for a beat. In READ his gaze goes to the
  focus and his hand goes to his chin. After the chase he breathes hard for 5 s.
- **Nico**: works through conversations (polish, set down, bottles, lean) and stays
  at his work rather than turning to face EL. A warm glance, lots of talk gestures.
- **Adrian**: composed. Faces you almost square (12°), heavy stillness, a rare lapel/cuff
  touch. Under stress the fidgets come every 6 s and the control breaks.
- **Mara**: a wide angle (42°), looks to the windows, half turns away while listening, and
  her arms cross and uncross.
- **Daniel**: the stillest body in the hotel (weight shift every 15 s), eyes on the exits,
  almost square to you. Stressed, he works his cuff. Cornered, he takes a wide stance.
- **Eva**: restless (weight every 2.6 s, fidget every 5 s), checks her pocket, touches her
  hair, glances at exits, turns away. A smoking pose with real smoke.
- **Thomas**: looks down, turns his eyes *away* when EL approaches, slow and heavy.
- **Layers** (BodyVisual): gait (arm pump and lean when running), weight shifts, exertion
  breathing, idle gaze with a torso twist that follows it, fidgets, speaking gestures and nods,
  and the work routine. Visual only.
- **Conversation staging**: nobody squares off face to face. NPCs face EL at an offset on a
  stable side, workers don't turn from their work, and NPCs turn before they walk off
  (0.3 s), so there is no sliding. When an NPC leads, a "this way" beckon plays while they wait.

## 4. Environmental motion (Pass E)

All in `src/world/vesper_motion.gd` (one node, cheap, visual/audio only) and two shaders:

- `vesper_window.gdshader`: night sky gradient by the hour, rain streaks running down the
  glass and beads catching light, passing-car light sweeps (per-pane timing), and a skyline
  mode (scattered lit windows, slow change).
- `vesper_surface.gdshader`: raindrop ring ripples in puddles, following the rain.
- Doors swing on their hinge (ease out, hold, ease shut, soft thud). Kitchen swing doors flap
  through and settle. Elevator doors slide open and closed. This triggers for anyone passing,
  NPCs included.
- Steam (kitchen stove line and fryer, laundry press puffs), cigarette smoke, dawn dust.
- Fluorescent stutter in the service corridor, the staff corridor and the roof shelter.
- Cloth: the Room 307 curtain (only while the window is open, billowing into the room) and
  the laundry sheets. Roof HVAC fans turn.

## 5. UI motion (Pass F)

- Subtitles ease in (0.15 s, 6 px rise) and fade out. A new page dips softly instead of blinking.
- The objective slides in with a chime, stays bright for 7 s, then settles to a quiet reminder.
- Hints fade in at the top centre and fade out. Toasts (phone messages) slide in from the right.
- READ: grade change (desaturation, slight dim) and a vignette. The reticle closes in as READ
  ramps up and fades on exit.
- The phone rises 24 px and fades in on open.
- Thread updates flash warm, then settle.
- The opening card stays clear of subtitles. Episode Complete is quieter: spaced type, slow
  fade, summary a beat later.

## 6. Lighting progression (Pass G)

`src/world/vesper_time.gd`. Five stages (night, deep night, late night, pre-dawn, dawn)
map onto the scenes. The world **drifts** toward each target (≈ 3 s to settle) and never
jumps, except on debug jumps and builds. Each stage drives: window sky (top/bottom), window
glow, cool window spill colour and energy, warm practical lamps, the ambient tint and
exterior lift, fog colour, the moon/sun key, rain intensity (particle amount, glass streaks,
puddle ripples) and the positional rain loop.

The finale runs a continuous pre-dawn → dawn mix over the restaurant scene clock, so the warm
artificial light slowly loses dominance to cold morning. The epilogue is full morning. Dawn
glow was lowered (0.75) so windows no longer blow out white.

## 7. Sound / motion sync (Pass H)

- Footsteps fire on the walk cycle's foot plants (BodyVisual `footfall`), not on a timer.
  Seven surfaces (carpet, wood, stone, tile, concrete, wet concrete, metal) × walk/run.
  NPCs within 10 m in EL's room are audible too. Gameplay noise radii are unchanged.
- Door and elevator sounds for NPC traversals in EL's room, plus a soft door-shut thud.
- Positional rain at the nearest window. The bar murmur only plays when there are people.
  Kitchen extractor. Laundry press hiss with the puff. A glass set down in time with Nico.

## 8. Visual QA: BEFORE / AFTER

All frames are in `docs/design_motion_polish_v1/`. `before/` is V1 (`16131aa`), `after/` is this
branch. Both use the same capture recipes (`tools/capture_shots.gd`: `s_50_qa`, `s_51_qa_motion`)
and the gameplay camera only. `after/` also has `s_52_qa_extra`, covering rooms whose camera,
light or motion changed.

| Scene | BEFORE | AFTER |
|---|---|---|
| Opening bar | `before/qa_01_bar_opening.jpg` | `after/qa_01_bar_opening.jpg` (opening card clear of subtitles) |
| Bar, Nico at work | `before/qa_02_bar_nico.jpg` | `after/qa_02_bar_nico.jpg` (bottle-wall gradient, rain on the windows) |
| Room 307 | `before/qa_03_room307.jpg` | `after/qa_03_room307.jpg`, `after/qa_17_room307_window.jpg` (camera 36° → 29°, rain at the glass) |
| Lobby (walk) | `before/qm_01_lobby_walk_*.jpg` | `after/qm_01_lobby_walk_*.jpg`, `after/qa_15_lobby.jpg` |
| Hub 3F | `before/qa_04_hub.jpg` | `after/qa_04_hub.jpg` |
| Rooftop | `before/qa_05_rooftop.jpg` | `after/qa_05_rooftop.jpg` (puddle ripples, lighter rain) |
| Security | `before/qa_06_security.jpg` | `after/qa_06_security.jpg` |
| Loading dock / Thomas | `before/qa_07_loading_thomas.jpg` | `after/qa_07_loading_thomas.jpg` (readable ground, figures separate) |
| Kitchen chase | `before/qa_08_chase_start.jpg`, `before/qm_08_kitchen_run_*.jpg` | `after/qm_08_kitchen_run_*.jpg`, `after/qa_13_kitchen_steam.jpg`, `after/qm_14_kitchen_door_*.jpg` (47° → 31°, steam, swing door) |
| Laundry / cold storage | — | `after/qa_11_laundry.jpg`, `after/qa_12_cold.jpg` (45° → 30°) |
| Banquet / Mara | `before/qa_09_mara_orchid.jpg` | `after/qa_09_mara_orchid.jpg`, `after/qa_10_banquet.jpg` (Orchid windows show the night, banquet 43° → 30°) |
| Restaurant finale | `before/40_finale_live.jpg`, `before/41_finale_life_beat.jpg` | `after/qa_16_restaurant_staging.jpg`, `after/40_finale_live.jpg`, `after/41_finale_life_beat.jpg` (dawn sky instead of a blown-out white wall) |
| Epilogue | `before/42_epilogue_dawn.jpg` | `after/42_epilogue_dawn.jpg` (morning through the revolving door instead of a white slab) |
| Conversation in motion | `before/qm_02_nico_talk_*.jpg` | `after/qm_02_nico_talk_*.jpg` (Nico works through the talk, no face-to-face stand-off) |

### Problems found by eye during QA (all fixed before the release)

1. **Windows rendered black.** The new window shader is unshaded, and Godot ignores `EMISSION` in
   unshaded mode. The colour now goes to `ALBEDO`.
2. **The camera could fly across the whole map** after a conversation, when a cut followed
   (scene change or door). The eased social framing kept pulling toward the old partner's
   position in another room. It is now ignored past 6 m, and any target farther than 25 m is a
   hard cut. Regression check: `check_camera_no_fly_after_talk`. Without the fix the camera ends up
   245 m from EL.
3. **Loading dock still read as a black void.** The cause was the near-black wet-concrete
   albedo, not the lights. Brightened, and the canopy lights strengthened.
4. **An orange bloom ball on the bottle wall** whenever Nico reached for a bottle. His new work
   routine brought his head next to the bottle-wall lamp. The lamp was moved above and behind
   the shelf, and the passing-headlight sweep was made fainter.
5. **Service-room foreground silhouettes** loomed too large at the lower camera. They are
   now low trolley edges.
6. A broken shader during development (ripple code that the GL Compatibility compiler rejects
   silently, blanking every surface) was caught by eye and rewritten as a function.

Checked on every frame: no black or broken materials, no character clipping through furniture
in the captured frames, subtitles and UI readable, scenes not darker than V1 (dock, Orchid,
restaurant and epilogue are brighter and more legible).

## 9. Tests

| Run | Result |
|---|---|
| Unit / SIM | 114 tests, 0 failed |
| World checks | 23, 0 failed (new: camera never snaps, movement feel, scene change hides reposition, characters feel alive, conversation staging, world keeps moving, light drifts, footsteps follow feet, UI eases, camera pitch, camera never flies after a talk) |
| Autopilots (headless, fixed 60 fps, fail on any NPC pop) | A_MARA PASS · B_THOMAS PASS · C_DESTROY PASS · D_ADRIAN PASS, 0 script errors |
| Packaged Mac app | `--autopilot=A_MARA` headless: PASS |
| Web build | headless Chrome: loads and plays S01, 0 console errors |

## 10. Remaining limitations

- Characters are still the V1.6 primitive proxies. Motion makes intention readable, but there
  is no facial animation, cloth sim or IK foot planting. Production rigs can replace
  `body_visual.gd` 1:1 (same public surface).
- Door panels animate visually only. Doors still have no collision panel (as in V1), and
  south-side (camera-side) doors are threshold strips with nothing to swing.
- Elevator doors are a single retracting leaf, not a centre-opening pair.
- Steam, smoke and dust use CPU particles with a soft radial sprite, tuned for GL
  Compatibility. There is no volumetric light.
- Audio is still synthesized placeholder (now spatial and synced). Final foley and music are
  production work.
- Dawn is a palette and energy mix. There is no moving sun direction or shadows (shadows are
  off for the Compatibility target).
