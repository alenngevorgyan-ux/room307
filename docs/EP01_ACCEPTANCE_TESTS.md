# EP01 — ACCEPTANCE TESTS

Types:

- **AUTO** = a headless Godot test (`godot --headless -s tests/run_tests.gd`) or the data validator.
- **SIM** = a scripted state simulation (no rendering) through `tests/sim/`.
- **MANUAL** = a human or Claude-driven playthrough, recorded in `docs/PLAYTEST_LOG.md`.

The episode is "playable" when **all AUTO and SIM tests pass** and **every MANUAL test is checked in the log at least once on the current build**.

## A. Data integrity (AUTO)

| ID | Test |
|---|---|
| AT-DATA-01 | All JSON in `data/ep01/` parses, and every referenced ID (fact, obs, thread, claim, exchange, trap, item, npc, zone, line key) exists. |
| AT-DATA-02 | Every fact marked `required: true` has ≥ 2 grant sites, or one grant site flagged `guaranteed: true`. |
| AT-DATA-03 | Every grant site listed in a fact's `sources` exists in exchanges, traps, overhears or interactables. |
| AT-DATA-04 | No exchange chains > 2 chip nodes without an intervening line ≥ 2 s or a movement node. |
| AT-DATA-05 | Every `play_cine` action references a CINE ≤ 15 s (the 20 s hard cap triggers a validator error). |
| AT-DATA-06 | Every observation caption is ≤ 8 words and contains none of the forbidden words: «врёт», «лжёт», «виновен», «доказывает», «значит». |
| AT-DATA-07 | Every chip label is ≤ 4 words; every hero line is ≤ 8 words. |
| AT-DATA-08 | Every exchange has `silence` and `leave` branches on every chip node. |

## B. Progression & information graph (SIM)

| ID | Test |
|---|---|
| AT-GRAPH-01 | Shortest path: a sim that takes only guaranteed actions reaches ENDING A, B, C and D (with D's prerequisites seeded through the minimal fear-hit route). |
| AT-GRAPH-02 | For each pair of hub leads {A,B}, {A,C}, {B,C}, the sim reaches Scene 06. |
| AT-GRAPH-03 | Lead C FAILED_DONE (caught twice) + Lead A → Scene 06 reachable. |
| AT-GRAPH-04 | F_THOMAS_LOCATION is obtainable by ≥ 2 independent routes when the fallbacks are disabled. |
| AT-GRAPH-05 | With all optional facts withheld, the 90 s fallback grants F_THOMAS_LOCATION. |
| AT-GRAPH-06 | The TR_FINAL_MAIN chip is NOT available unless F_MARA_BELIEVED_SHE_DROVE and F_ADRIAN_THINKS_MARA_FORGOT are both known. |
| AT-GRAPH-07 | The finale cannot start without Adrian, Mara and Daniel invited (Mara line plays). |
| AT-GRAPH-08 | `ending_d_available()` is false when trust < 0, fear hits < 2, Daniel unresolved, or no phone; it is true otherwise (table test). |
| AT-GRAPH-09 | A failed Eva bluff (CALLED) does not prevent reaching Scene 06 (via Lead A + C). |
| AT-GRAPH-10 | Skipping Room 307 interactions entirely still opens the hub and reaches the end. |
| AT-GRAPH-11 | Uninvited Thomas makes Ending B unavailable; A, C, D remain reachable. |
| AT-GRAPH-12 | Daniel ESCAPED with the card on the table: the card is still recoverable and all endings are reachable. |

## C. Social systems (AUTO unit tests)

| ID | Test |
|---|---|
| AT-SOC-01 | A false claim contradicting NPC knowledge returns CALLED, with suspicion +1 and trust −1. |
| AT-SOC-02 | C_MARA_CALLED_FROM_615 on Eva with suspicion < 2 returns SLIP; with suspicion ≥ 2 returns CALLED or DEFLECT. |
| AT-SOC-03 | The feared audience present raises pressure by exactly 1. |
| AT-SOC-04 | After an uncalled claim, `believes_hero_knows` contains `claim.about`. |
| AT-SOC-05 | Stress decays 1 per 45 s outside conversation, not below the start value. |
| AT-SOC-06 | TR_FINAL_MAIN with Mara outside hearing produces outcome 2 (Daniel deflect) and the retry path exists. |
| AT-SOC-07 | Daniel's pressure ≥ 5 gives CONFESSED; flee blocked gives CORNERED then CONFESSED; an open exit and unblocked gives ESCAPED. |

## D. Moment-to-moment playability (MANUAL)

| ID | Test | Pass criterion |
|---|---|---|
| AT-PLAY-01 | Opening without a cutscene | The player moves the hero within 2 s of a new game start. |
| AT-PLAY-02 | Movement feel | Walk, fast walk, run, crouch, vault, stairs, doors all work in every zone; no stuck spots in a 10 min free roam (camera direction lock prevents flip-flop at rig blends). |
| AT-PLAY-03 | S01 resolutions | All 4 S01 resolutions are reachable in separate runs. |
| AT-PLAY-04 | S02 in motion | The player has movement control during ≥ 80% of Scene 02. |
| AT-PLAY-05 | Room 307 density | ≥ 12 meaningful interactions, ≥ 14 observations; at least 3 interactions change later state (charger/phone, window, connecting door/308, glasses vs Lina). |
| AT-PLAY-06 | READ doesn't tell | No caption interprets; a playtester can form a wrong thread (T_SHE_LEFT_BY_WINDOW). |
| AT-PLAY-07 | Lina interruption | Lina moves during the conversation; the hero can follow; she removes the glasses if not stopped. |
| AT-PLAY-08 | Hub freedom | Leads can be done in any order; all 3 are reachable in one run. |
| AT-PLAY-09 | Eva bluff | The 615 bluff produces the slip; a failed bluff produces a new situation (Eva leaves, mara_wary), not a dead end. |
| AT-PLAY-10 | Tail | The Eva tail can be done unseen; being seen triggers the confrontation exchange. |
| AT-PLAY-11 | Security approaches | ≥ 4 of the 5 security approaches work; being caught escorts the hero; the second catch triggers the Daniel escort. |
| AT-PLAY-12 | Video room | The camera keys and the jog wheel work; Daniel can be photographed; the Pavel timer cues are audible. |
| AT-PLAY-13 | Thomas stop | Each of the 5 stop methods works; silence advances Thomas. |
| AT-PLAY-14 | Chase routes | Routes A, B and C are each completable. |
| AT-PLAY-15 | Chase fail-forward | Grab #2 → interrogation → escape → chase resumes. No reload screen exists anywhere in the episode. |
| AT-PLAY-16 | Chase tools | ≥ 10 tools functional; the freezer lock, breaker, radio bluff and elevator decoy are each verified. |
| AT-PLAY-17 | Mara defuse | Mara circles to keep the table between; the clip is scrubbable; Thomas arrives. |
| AT-PLAY-18 | Finale staging | Place cards, recorder, card spot, 3 doors, lights and invites all change outcomes as specified. |
| AT-PLAY-19 | Positional addressing | Facing or proximity changes the addressee ring; the same chip addressed to a different person has a different effect. |
| AT-PLAY-20 | Finale trap | TR_FINAL_MAIN produces Adrian's genuine «Что?» and the Daniel tells window. |
| AT-PLAY-21 | Daniel flight | The hero can stop Daniel by vault, door or chair; letting him go produces ESCAPED. |
| AT-PLAY-22 | Physical endings | All 4 endings are reachable by physical action only; no ending menu exists; walking out with the card is blocked. |
| AT-PLAY-23 | Epilogue | Controllable; the phone call plays; ending variant details are visible. |

## E. Pacing (MANUAL + telemetry)

| ID | Test | Pass |
|---|---|---|
| AT-PACE-01 | Decision cadence | Telemetry: the gap between `player_decision` events is ≤ 60 s for ≥ 95% of the session (excluding the pause menu). |
| AT-PACE-02 | Control ratio | Time with player control ≥ 65% of total runtime (telemetry counts CINE and locked-input time). |
| AT-PACE-03 | Cinematic length | No CINE > 15 s (runtime assert in debug). |
| AT-PACE-04 | Episode length | A first-time internal playtest takes 35–45 min (a speed run of 15–20 min is acceptable). |
| AT-PACE-05 | Activity shifts | The dominant activity changes at least every 8 min (map the run against the rhythm table in the GAMEPLAY_SPEC). |

## F. Robustness (MANUAL)

| ID | Test |
|---|---|
| AT-ROB-01 | The quick-save/load at any scene start restores state exactly (F1 dump diff is empty). |
| AT-ROB-02 | The F2 debug scene jump to every scene works with seeded minimum state. |
| AT-ROB-03 | No softlock found by: leaving each conversation mid-chip, walking away during every walk-and-talk, closing doors on NPC paths (NPCs open doors), and standing in NPC paths (NPCs route around or wait ≤ 3 s, then bark and sidestep). |
| AT-ROB-04 | Graybox-to-art swap: replacing one zone's visual meshes leaves all gameplay tests passing. |
