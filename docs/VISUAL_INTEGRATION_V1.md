# ROOM 307 — VISUAL INTEGRATION V1

Branch `visual-integration-v1`, from the verified playable baseline `691e462` (`ep01-graybox-playtest-v1`).
The graybox is not rebuilt: every gameplay system, route, collision box, interaction, schedule, trap,
chase rule, finale rule and ending is preserved. Visual Integration V1 is a layer on top of it, plus
targeted fixes for the confirmed human-playtest findings.

Goal of the next human playtest: the player can always answer **Where am I? What am I doing right now?
Why am I going there?** — without the game explaining the mystery.

---

## Milestones (one commit each)

| Milestone | Commit | What |
|---|---|---|
| V1.2a reset / teleport bug | `38d62e1` | Root cause found and fixed; in-engine regression checks |
| V1.1 + V1.2b UX clarity, NPC pop-in | `1646ceb` | Subtitles, no floating names, one objective, 3-level hints, opening card; on-camera pop audit 8 → 0 |
| V1.3 camera language | `d40d97a` | Five camera modes on the zone rigs |
| V1.4 materials + lighting | `8b69fb4` | THE VESPER art layer: wings, procedural surfaces, motivated light, occluder fade |
| V1.5 environment dressing | `03c7fb7` | Walls, windows, signage plaques, props on existing boxes, foreground layer |
| V1.6 character proxies | `e4ec133` | Canon-based, differentiated cast (temporary proxies) |
| V1.7 body language | `e51eb5a` | Authored mood states, walk cycle, data-driven rules |
| V1.8 atmosphere + polish | see `git log` | Night → dawn, rain, READ grade, threads, finale life |

---

## Pass 3 — the "thrown back toward the start" bug (root cause)

Reproduced in the real 3D world: holding a direction key through the **BAR ↔ LOBBY** arch bounced EL
between the two rooms about three times per second (11 crossings in 4 s). The bar is the starting area,
so the player experienced it as being thrown back to the start. Same on SERVICE_STAIR ↔ STAFF_CORRIDOR,
and LAUNDRY ↔ KITCHEN once that door became reachable.

**Cause:** the door's control lock zeroed input, which reset the camera-relative input basis; the still
held key was then re-read in the arrival camera's basis and, for door pairs whose two sides face the same
way, pointed straight back into the arrival doorway, which auto-traversed again.

**Fix (not masked):** a key held through a door keeps walking *into* the new room until released
(`InputBasis.carry_through`); the arrival door re-arms only after EL steps 1.5 m away; a gameplay teleport
issued during a door fade wins over the stale door transition. Related causes found on the way: the
security catch teleported EL across the lobby to the bar arch with no cut (now: cut to black, escort to the
front of reception); the laundry machines walled off the kitchen door and arrivals spawned inside them;
four door spawns landed inside props (physics shoves).

**Regression:** `tests/world/world_checks.gd` (real world + physics) crosses every auto door with the key
held and requires exactly one crossing; mutation-tested (fails with 11 crossings without the fix).

## Pass 1 — UX clarity

- **Subtitles at the bottom only**: speaker label line in spaced caps above the line, at most two lines
  (longer lines page at sentence ends), soft dark band. `НИКО / Да уж. Только не ты.`
- **Names only in subtitles, only once known**: strangers read `НЕЗНАКОМЕЦ / БАРМЕН / ГОРНИЧНАЯ /
  МУЖЧИНА У СТОЙКИ`; a name appears once it is spoken (whole-word aliases) or after talking to staff with a
  name badge. EL is `ЭЛ`. The unknown caller in the epilogue is `НЕЗНАКОМЕЦ`.
- **No floating names**: NPC head bubbles removed (barks become subtitles when EL is near); prompts are
  `E  поговорить`, `E  осмотреть · чек`, `Space  перепрыгнуть` — never a name, kept above the subtitle area,
  hidden while choosing what to say; finale place cards are small table cards during staging only.
- **One restrained objective** (`data/ep01/objectives.json`), bright for a few seconds when it changes, then a
  quiet line: «Разберись, что произошло у бара.» → «Иди за Адрианом Вейлом.» → «Найди Мару Вейл. /
  Последнее известное место: номер 307.» → «Выясни, куда ушла Мара.» → «Найди водителя. / Погрузочная зона — за
  прачечной.» → «Не дай ему уехать.» → «Выслушай его.» → «Уходи от них.» → «Поговори с Марой.» →
  «Спустись в ресторан.» → «Подготовь зал. Потом позови их.» → «Пусть скажут это сами.» → «Реши, что будет с
  записью.»
- **Three-level guidance**: (1) the world — light, open doors, signage, NPC movement, sound; (2) the
  objective line; (3) only after a long stall, one short EL thought per nudge, zone/lead-aware, never during
  a conversation or cine, never a solution («307 должна быть на этом этаже.»).
- **Opening**: `THE VESPER / 02:17` card, no exposition. The hire is unmistakable: Adrian introduces himself
  («Адриан Вейл.») and the objective switches to «Найди Мару Вейл» as he gives the brief.
- Fixed on the way: cine lines expired from the 6 s ambient queue (the hire scene silently dropped
  «Пройдёмся.»); hotel renamed Меридиан → Веспер; the playtest log records objective changes and hints.

## Pass 2 — NPC pop-in

An on-camera probe (hero's zone, camera frustum, line of sight ignoring cutaway walls, black fades)
reports any NPC appearing, vanishing or jumping while visible. Generic rules instead of per-site hacks:
a visible despawn walks out through the nearest real door or `exit_*` marker (logic sees the NPC gone at
once); a visible spawn enters through the nearest door; a short visible teleport becomes a brisk walk; a
visible cross-zone arrival steps in through the door; the stuck-recovery never snaps on camera; scene starts
with a hero placement are camera cuts. Audit over all four endings: **8 pops → 0**. The autopilot now fails
on any pop, so CI guards it for every ending.

## Pass 4 — camera (five modes on the existing rigs, 2.5D kept)

A **Exploration Wide** (the zone rig) · B **Social Medium** (conversation: frame the pair, push in, same
direction) · C **READ Focus** (tighter, a lean toward what is studied) · D **Chase Wide** (higher, wider,
more lead) · E **Finale Social Stage** (the specced-but-unwired table orbit, favouring EL's side).
Tall props between camera and EL dither out (lobby pillars), never hard-pop.

## Passes 5–6 — THE VESPER, scene by scene

One identity by wing (`src/world/vesper_look.gd`, procedural surfaces in `vesper_surface.gdshader`, no
texture assets): **public** dark timber, stone, aged brass, warm 2700 K, smoked green, dirty cream ·
**guest** patterned carpet, cooler quiet walls, cream dado, 3000 K · **service** two-tone paint, tile, steel,
flat fluorescent, exposed pipes · **exterior** wet concrete with puddle reflections, brick, sodium.
Dressing (`src/world/vesper_dress.gd`) is collision-free and only decorates existing boxes, walls and the
unreachable foreground beyond the camera-side cutaway.

| Scene / zone | Changes |
|---|---|
| BAR | timber floor, smoked-green wallpaper, walnut wainscot + brass rail; backlit amber bottle wall; green-marble bar top, brass foot rail; oxblood stools and booths; table lamps; brass pendants; cool rain windows; foreground chair backs |
| LOBBY | stone floor, cream wallpaper, walnut wainscot; THE VESPER brass logotype; reception with marble top, lamp, bell; pillar bases, pillars dither out in front of EL; planter; armchairs; sconces + pendants |
| ELEVATOR | brass doors, walnut panelling, warm dome |
| HALL 3F (hub) | guest carpet, taupe wallpaper, cream dado, room-number plaques, flush lights + sconces |
| ROOM 307 / 308 | room carpet, warm walls, dado; made beds with pillows and throws; bedside and desk lamps; wardrobe doors; window with mullions and cool spill |
| ROOFTOP | wet concrete, brick, HVAC grilles, sodium heads, rain |
| SECURITY | service paint, fluorescent tubes, dim monitor wall with screen spill |
| SERVICE CORRIDOR | two-tone paint band, pipes, tubes, linen carts, plaques |
| LOADING DOCK | wet concrete and puddles, brick, sodium lamp, the Volvo's wheels and tail lights, rain |
| LAUNDRY | tile, machine drums, cool window; kitchen door now reachable (gap in the machine row) |
| KITCHEN | tile, steel, burners, hood heat lamps, hanging pans |
| BANQUET (corridor, hall, Orchid) | carpet, cream wallpaper, wainscot, round tablecloths with brass centrepieces, chair stacks |
| RESTAURANT (finale) | timber floor, window wall going from night to dawn, table orbit camera, finale life |
| EPILOGUE (street) | wet street, cold dawn, rain stopped |

## Pass 7 — READ
A grade change, not detective vision: world desaturates (−35 %) and dims slightly, ambience low-passes,
time slows, the soft vignette and a thin reticle remain; captions are small notes by the object.
Interpretive captions rewritten as observations («встаёт между тобой и мониторами», «трогает карман.
Опять.», «перенёс вес на дальнюю ногу»…). READ's line of sight no longer fails on invisible cutaway walls.

## Pass 8 — threads
Hypotheses, not objectives: sentence case («Мара ушла сама?» style: «Её шантажирует бывший?», «Кто-то
обыскивал 307.»), at most three lines, shown for a few seconds when something changes, then folded away;
holding Q shows them.

## Passes 9–10 — characters and body language
`data/ep01/proxies.json` from VESPER_EP01_CHARACTER_CANON_v1 (corrected Nico, driver Thomas): height, build,
wardrobe layers and colours, hair mass, identity cues, resting posture; EL is `ЭЛ` with dark curls, a lean
silhouette, a short dark overshirt, dark relaxed trousers, the subtle ring — no detective costume. Authored
body-language states: EL relaxed observation / sudden attention / bluffing / uncertainty; Adrian controlled
authority → control breaking; Mara guarded → defiant; Thomas withdrawn → solid when cornered; Daniel minimal
movement → stress leakage; Eva restless, guarding her pocket; Nico works while talking.

## Pass 11 — light and atmosphere
One night in five steps: 02:17 night (S01–S03) → deep night (S04–S05) → late night (S06–S07) → pre-dawn
(S08–S09 staging) → cold dawn (finale live/decision, epilogue). Window glass and its cool spill, fog, the
exterior light and ambient change; rain falls until the story stops it. Glow is limited to practicals.

## Pass 12 — finale
Social chess instead of a frozen table: people stand, step toward the window or watch an exit, turn to
someone, and settle back (≤ 1.3 m, so seats, hearing, addressing and Daniel's flight logic are unchanged).
EL keeps free movement throughout.

---

## Placeholder assets (still temporary)

- **All characters are proxies** built from primitives (`src/npc/body_visual.gd` + `data/ep01/proxies.json`).
  Requiring true 3D production (rigged, skinned, with faces): EL (photo references are the facial authority),
  Adrian, Mara, Nico, Daniel, Eva, Thomas, housekeeping, Vesper security (Richard / Maya / Jonas types), and the
  S01 bar cast (Hale, Selin, Kai, Jules). Replacement contract: keep `head`, `hand_l`, `hand_r`, `set_pose`,
  `set_mood`, `set_crouch`, `look_target`.
- **Materials** are procedural shader patterns (no textures); **props** are primitive compositions; **signage**
  uses the default font; **sky/skyline** remain blocks; no character animation clips (procedural poses only).
- Final art can replace any of it without touching gameplay: everything visual lives under `Visual` / `Look`
  nodes; `-- --graybox` switches the art layer off.

## Tests and tools

- `./run_tests.sh` — 114 unit/SIM tests (incl. objective trail for all four endings, subtitle paging of every
  line, speaker labels, hint director, proxy distinctness) + in-engine world checks (doors, catch escort,
  NPC transitions, camera modes, occluder fade, dressing has no collision, body language, time of day, READ).
- Autopilot A/B/C/D in the real world; fails on any NPC pop.
- `tools/cap.sh` + `tools/capture_server.gd` — screenshots through one tiny, silent, unfocusable window;
  `tools/contact_sheet.gd` builds review sheets headless.

## Current screenshots
`docs/visual_integration_v1/` — opening card, stranger subtitle + prompt, the hire and objective, an EL
thought, Room 307, social camera, READ grade, chase framing, the cast line-ups (proxies), the finale live,
the dawn epilogue, and a tour of the main zones. Captured in-engine with `tools/cap.sh`.

## Builds
Local exports with the official 4.7.2 templates: **Web** (`index.html` + wasm + pck) and **macOS**
(`Room307.zip`, smoke-tested headless: boots and runs with no script errors). CI (`.github/workflows/build.yml`)
builds Web/Windows/Linux/macOS on `main` and tags; it was not triggered from this branch, because a manual
run on a branch republishes the public rolling `playtest` release.
