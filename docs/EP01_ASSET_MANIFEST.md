# EP01 — ASSET MANIFEST

Two tiers:

- **GRAYBOX:** required for the episode to be fully playable. Everything here should be primitives, placeholder audio, or free CC0 assets.
- **POLISH:** final art and audio. Must drop in without code changes (see the marker-node contract in LEVEL_LAYOUT §8).

---

## 1. Characters

| Character | GRAYBOX | POLISH |
|---|---|---|
| Hero | Capsule + head sphere + nose wedge + 2 hand cylinders, charcoal band | Stylised realistic model, coat, 1 outfit |
| Adrian | Capsule, dark-blue band, a ring stud on the right hand | Suit, signet ring (visible detail) |
| Mara | Capsule, red band | Hoodie over an evening dress (from the gala), forehead scar |
| Thomas | Capsule, brown band | Old raincoat, grey hair |
| Daniel | Capsule, black band, pocket stud (screwdriver) | Suit, earpiece |
| Eva | Capsule, yellow band | Leather jacket |
| Nico | Capsule, green band, apron box | Bartender vest |
| Lina | Capsule, light-blue band | Housekeeping uniform |
| Pavel | Capsule, grey band, cap | Guard uniform |
| Brody, Sato | Capsules, dark-red bands (Brody 1.15× scale) | Dark coats |
| Hale, Selin, Kai, Jules | Capsules with bands | Simple models (reuse bodies with swaps) |
| Silhouette guests and staff ×6 | Flat-shaded capsules | Low-detail models, backlit silhouettes |

## 2. Animations

The graybox "animation" is tween-driven transforms on capsule parts (head yaw/pitch, hand positions, body lean). Each is a named state so the polish phase can swap in AnimationTree clips.

**Hero (GRAYBOX required):** idle, walk, fast walk, run, crouch idle and move, slide, vault (lerp along an arc), stair up/down (ramp), door open (hand reach), pick up, place, push cart (attach), shove, struggle, throw, sit or stand (chair), lean on wall (cover), phone up, read pose (head tilt slightly), fall/landing stun, dragged (interrogation).

**NPC shared (GRAYBOX required):** idle, walk, fast walk, run (pursuers), sit, stand, talk gesture (hand lift), smoke (hand to head loop), phone call (hand to ear), phone look (hand front), polish glass, pour, carry towels, push cart, grab/hold, stunned, freeze (tell), head-turn to target (procedural look-at), hand-to-pocket (Adrian, Eva), hand reach (Daniel to the card), weight shift.

**Specific tells (GRAYBOX, procedural):** a look-at target swap (to door, person, phone), hand-to-point (pocket, table edge, photo), stop walking, a breath pause (an audio gap plus a 0.3 s freeze), turn away.

**POLISH:** mocap or keyframed clips for all of the above, plus the hero's signature idle (coin roll / card shuffle in his fingers), Adrian's hands-behind-back walk, Thomas's steering-wheel hands, Mara's extinguisher stance, Daniel's confession sit-down.

## 3. Environments

| Zone | GRAYBOX | POLISH |
|---|---|---|
| Street | Box facade, revolving-door frame, car silhouettes | Wet asphalt, neon reflection, facade detail |
| Lobby | Boxes: pillars, planter, armchairs, desk, fountain cylinder, elevator doors | Art-deco hotel, marble, brass |
| Bar | Counter, stools, booths, windows (glass plane) | Warm wood, backlit bottles |
| Security room | Desk, chair, 6 monitor planes (SubViewport) | CRT/LCD mix, cables |
| Elevator cabin | Box with mirror plane | Brass cabin, floor dial |
| Hall 3F | Long corridor, 16 door frames, ice alcove | Carpet pattern, sconces |
| Room 307 | Bed, desk, wardrobe, window, bathroom with mirror (fog shader) | Full furnished room |
| Room 308 | Duplicate of 307 (mirrored) | Dressing variant |
| Service stair | Vertical section of 5 landings | Concrete, emergency lights |
| Roof | Deck, HVAC boxes, parapet, skyline cards | City backdrop layers |
| Mezzanine | Balcony strip and railing | — |
| Service corridor | Long strip, door frames, crates | Industrial corridor |
| Laundry | Machine boxes, tables, hanging sheet planes (cloth not required) | — |
| Loading dock | Raised dock, yard, gate, van box, Volvo box | Rain, sodium lamp |
| Kitchen | Islands, hood, racks, swing door | Steel kitchen |
| Cold storage | Shelving, a walk-in box with a door | Frost |
| Staff corridor | Lockers, breaker box, bench | — |
| Freight elevator | Cage box with a panel | — |
| Banquet corridor and hall | Corridor, round tables, cloth boxes | Post-gala mess |
| Orchid room | Chair stacks, round table, windows | Moody purple lighting |
| Restaurant | Four-top, bar shelf, doors, light panel | Dawn-lit restaurant |

## 4. Props (interactive; GRAYBOX = coloured primitives with a label3D in debug)

Bar: receipt spike, under-counter drawer, watch in napkin, dome camera, house phone, Hale's coat, bottles (pourable), glass.
307: two glasses, wine bottle, shower (valve), towels, mirror + message decal, charger, Mara's old phone, shoes ×2, window (open/close), pills blister, mattress (liftable corner), travel bag (zip), AC vent, curtain, TV (on/off with map texture), room service slip, connecting door.
308: lighter, coffee cups ×2, luggage tag.
Hub: keypad, staff door (keycard reader), housekeeping cart, laundry key hook, planter (cover), armchair, balcony railing, roof HVAC, Lina's staff keycard.
Security: camera buttons ×4, timestamp tabs ×4, jog wheel, chair, monitors.
Dock: Volvo (keys, alarm), photo of Thomas's son, clinic bill, van, gate chain, roll-cart.
Chase: laundry carts, folding tables, hanging sheets, steam press, pots rack, bottles, fire-suppression pull, freezer door and latch, breaker, staff radio, lockers, fire alarm pull, metal fire door, freight panel, banquet tables, tablecloths.
Orchid: fire extinguisher, laptop (clip player), SD card.
Restaurant: place cards ×5, vase, bread basket, bar shelf spot, recording phone, door wedge chair, terrace key, light panel, bar sink, kitchen burner.
Hero items: hero phone, Adrian keycard, Mara's phone, Volvo keys, photo (virtual), SD card.

## 5. VFX

| VFX | GRAYBOX | POLISH |
|---|---|---|
| Rain (exterior, windows) | GPUParticles quads + simple window-streak shader | Layered rain, splashes, drips |
| Mirror fog | Shader param `fog_amount` (lerp grey overlay); message decal | Realistic condensation |
| Shower steam | Particle puffs | Volumetric |
| READ vignette | Post-process: vignette + slight desaturation | Custom ink-edge effect |
| Observation caption | Label3D (handwritten font), fade | Animated ink write-on |
| Sprinkler/foam | Particles + fog volume | — |
| Steam press burst | Particles | — |
| Blackout | Light energy to 0; emergency red omni lights | — |
| Headlights sweep | Spotlight anim | Volumetric beams |
| Dawn | Directional light color/angle tween in the restaurant | Sky grade |
| Lighter flame / burner | Small particle | — |

## 6. SFX

GRAYBOX (CC0 placeholders acceptable): footsteps (carpet, tile, metal stair, wet concrete) × walk/run, door open/close (wood, metal, swing), elevator ding/hum/doors, keypad beeps, keycard accept/deny, cart roll, glass clink, pour, shower on/off, window open/close (rain volume change), TV muzak, phone vibrate/ring/SMS, camera button click, jog wheel tick, car alarm, van engine, gate chain, freezer latch, breaker thunk, fire alarm bell, sprinkler hiss, pots crash, bottle smash, shove/impact, struggle grunt, radio squelch/chatter, lighter, paper (receipt), card slide, place-card tap, observation "pen scratch" sting, thread-pinned soft chime.

POLISH: everything re-recorded/layered; Foley for the NPC tells (fabric rustle on the pocket touch: these sound cues reinforce tells).

Ambience beds: bar rain + piano, lobby fountain, hallway HVAC, 307 rain (window state), stairwell reverb, roof heavy rain, back-of-house machinery, dock rain on metal, kitchen hum, cold-room compressor, banquet silence, restaurant dawn birds.

## 7. Music states (vertical layering in Godot via AudioStreamSynchronized or a stem player)

| State | Use | GRAYBOX |
|---|---|---|
| BAR_AMBIENT | S01 diegetic piano | CC0 piano loop |
| TENSION_LOW | provoke moments | drone stem |
| CLIENT_THEME_SPARSE | S02 | cello drone |
| INVESTIGATE_MINIMAL | S03 | pulse + layers per observation |
| HUB_EXPLORE (+3 layers) | S04 | layered loop |
| TAIL_TENSION, STEALTH_LOW | tails, security | stems |
| THOMAS_SORROW | S06 | guitar |
| CHASE_START, CHASE_1..3 | S07 | drum and string stems |
| MARA_THEME | S08 | piano, minor |
| FINALE_STAGING, FINALE_LIVE | S09 | pulse; strings |
| SILENCE | decision | — |
| EPILOGUE | street | sparse piano |

## 8. UI components (minimal, diegetic-leaning)

| Component | GRAYBOX | Notes |
|---|---|---|
| Context prompt | Small key glyph + verb near the object | max 1 at a time |
| Context hint (tutorial) | 3–4 words, fades | S01 only + first uses |
| Subtitles | Bottom centre, speaker name colour | always on by default |
| Bark bubble | Small text near the NPC head (optional) | for off-screen direction an arrow is used |
| Dialogue chips | 2–4 pills with verb icon + label + timeout ring | bottom centre-right |
| Addressee ring | Circle decal under the addressed NPC | finale + any multi-NPC exchange |
| READ reticle | Thin circle | — |
| Observation caption | Label3D | — |
| Threads HUD | 3 lines top-left; expands on Q | — |
| Phone overlay | Contacts (4), messages, camera, map (TV map photo) | Tab |
| Item glance | Icons row near the phone | — |
| Pursuer edge indicator | Red chevron | chase only |
| Struggle prompt | Glyph + fill bar | — |
| Fade / door wipe | Full-screen rect | — |
| Debug overlay | State dump, scene jump, fact grant, pacing log | debug builds |
| Title and ending cards | In-world text on the window / black card | — |
| Pause menu | Resume, options (READ assist, subtitles size, invert), quit | — |
