# EP01 — CHARACTER BEHAVIOUR SPEC

Tells are implemented with **graybox-friendly signals only**: head direction, gaze target, hand position (two hand cylinders on the capsule), posture (lean/straighten), stop/start walking, object handling, voice pause (audio gap), and camera framing. No facial capture is required.

Each NPC's runtime numbers are in `data/ep01/characters.json` (see STATE_MODEL).

---

## THE HERO (player)

| | |
|---|---|
| Voice | Short, dry, unhurried. Never explains himself. Humour is a deflection tool, not a personality. |
| Fragments of past | Nico: Prague; Jules recognises him as "a bartender at Savoy, years ago?"; Daniel: «Монако, девятнадцатый год? Нет?»; Thomas: «У тебя руки картёжника.»; Selin (S1, PUBLIC_EXPOSE): «Вы откуда это знаете?» → «Я разносил часы под залог. В другой жизни.» |
| Never | A flashback, a biography, the word "менталист", or reading thoughts aloud. He states what he saw, not what it means. |
| Can be wrong | His wrong chips (from wrong threads) are delivered with the same confidence. |

---

## ADRIAN VALE, 55

| Field | Spec |
|---|---|
| Personality | Controlled, courteous, used to buying outcomes. Real love for his daughter, entangled with self-preservation. |
| Visible objective | Find Mara; she is "in danger from a blackmailing ex". |
| Hidden objective | Recover the recording before 08:00 and talk Mara down without anyone else learning. |
| Fear | Losing his name (`LOSES_NAME`); losing Mara (`LOSE_MARA`, the deeper one, used by Ending D). |
| Secret | He was driving. He paid Thomas. |
| Knows | F_ADRIAN_WAS_DRIVING, F_THOMAS_TOOK_BLAME, F_THOMAS_PAID_SON, F_RECORDING_EXISTS (partially: "a frame"). |
| Falsely believes | Mara remembers nothing (F_ADRIAN_THINKS_MARA_FORGOT is his *belief*); Daniel is loyal and honest with him. |
| Thinks hero knows | Initially nothing. Grows via `believes_hero_knows`. |
| Calm | Walks slowly and makes the hero come to him. Hands behind his back. Eye contact steady. |
| Pressured | Right hand to the inside breast pocket (O_S2_POCKET_TOUCH). Turns his body away while keeping his head toward the hero. Clipped sentences. |
| Caught lying | Doesn't deny it; reframes: «Есть вещи, которые вас не касаются.» Offers money. |
| READ tells | pocket touch; a flat non-reaction to danger questions; a pause before the invented name «Лукас»; ring (non-tell, payoff); in the finale, genuine confusion (head tilt, a step toward Mara: an *honest* tell). |
| Schedule | S02: lead walk. Hub: lobby armchair phone call (min 2–4), then F5 suite (off-map); returns to the lobby lounge on a hero text or at minute 7 for a "report" exchange; finale: invited. |
| Key interactions | S02 walk; hub report (optional); photo reaction; finale MAIN bait; Ending D phone. |
| State transitions | trust/respect per choices. `doubts_daniel = true` after the photo or after seeing Daniel's escort scene. Ending D gate (STATE_MODEL §10). |
| Motivation (non-villain) | He made a cowardly choice at 48 to save his daughter's future (he believed she'd be dragged through the trial as a witness and that the press would destroy her) and his own. He has paid Thomas's family ever since. He genuinely doesn't know what Daniel did to Mara. |

---

## MARA VALE, 24

| Field | Spec |
|---|---|
| Personality | Sharp, exhausted, morally furious, scared of her own resolve. |
| Visible objective | Hide until 08:00. |
| Hidden objective | Publish the truth *and* look her father in the eye first. |
| Fear | Being talked out of it; being taken before 08:00 (`TAKEN`); that she is still somehow guilty (`STILL_GUILTY`). |
| Secret | She has the card; she staged 307; Eva is helping her. |
| Knows | F_ADRIAN_WAS_DRIVING (from the clip), F_DANIEL_TOLD_MARA, F_MARA_BELIEVED_SHE_DROVE. |
| Falsely believes | That her father orchestrated her guilt (so "DON'T TRUST HIM" = Adrian). |
| Thinks hero knows | That he is Adrian's man. If `mara.wary`, also that he tricked Eva. |
| Calm | Paces with a purpose, packs things, talks while busy. |
| Pressured | Keeps furniture between herself and the hero. Grips the extinguisher. Checks the door. |
| Caught lying | Rarely lies; when she does (about having a copy) she looks at the laptop. |
| READ tells | glance at the laptop (copy exists); thumb on the scar on her forehead (the accident); hands shaking only when she says «я убила его». |
| Schedule | Orchid Room only (S07 end to S09). Finale: enters from the guest corridor, sits per place card. |
| Key interactions | S08 defuse → clip → story → plan; finale SILENCE line; Ending A. |
| Transitions | `trust` starts at 0 (−1 if `mara.wary`). +1 for the phone return, honesty, letting her control the clip. The card is handed over at trust ≥ 1. |

---

## THOMAS REED, 58

| Field | Spec |
|---|---|
| Personality | Quiet, proud, self-punishing. Speaks in short, physical sentences. Silence makes him talk. |
| Visible objective | Leave the hotel. |
| Hidden objective | Make sure the truth stays buried, to protect his son's future and the deal he chose. |
| Fear | Losing what the sacrifice bought (`SACRIFICE_WASTED`); Daniel (`DANIEL`); re-prosecution. |
| Secret | Wasn't driving; consented; installed the dashcam himself. |
| Knows | Almost everything except Daniel's lie to Mara (he learns it in S08 from Mara and is shaken: «Он что?»). Confirms F_ADRIAN_NEVER_ASKED because Adrian once told him «она ничего не помнит, пусть так и остаётся». |
| Falsely believes | Mara's publication can only hurt everyone. |
| Calm | Smokes, leans on the car, looks at the rain. |
| Pressured | Walks away; hands go to the "10 and 2" grip on anything. |
| Caught lying | Admits immediately: «Ладно. Да.» (He hates lying; it's what he did for seven years.) |
| READ tells | hands like on a steering wheel; looks away when Adrian's name comes up; touches the photo of his son. |
| Schedule | Hub: smoking under the dock canopy (visible from the laundry window), occasionally pacing to the laundry door. S06: leaving. S07: escapes by car or gate. S08: arrives by freight elevator. Finale: if invited, sits apart; else absent. |
| Key interactions | S06 stop and fragments; S08 confirmation; finale: blocks thugs (trust ≥ 0); Ending B. |
| Transitions | trust −1 for the police lie or taking his keys; +1 for silence, the name, the photo question. |

---

## DANIEL KROSS, 50

| Field | Spec |
|---|---|
| Personality | Calm, polite, professional. Believes loyalty justifies anything. Not sadistic: he thinks of himself as the adult in the room. |
| Visible objective | Head of Vale security: find Mara safely. |
| Hidden objective | Recover and destroy the card; keep Mara quiet; keep Adrian from learning what Daniel did. |
| Fear | `ADRIAN_LEARNS_TRUTH` (3), `MARA_PUBLISHES` (2), `LOSES_POSITION` (1). |
| Secret | He told Mara she drove. He searched 307. He disabled the service-stair camera? *(Left ambiguous: footage shows "no signal at 00:15"; Daniel will neither confirm nor deny. Mara did it.)* |
| Knows | Everything except where Mara is and where the card is. |
| Falsely believes | The hero is a bought tool who can be redirected with money or authority. |
| Thinks hero knows | Updated by `believes_hero_knows` (the S03 PROVOKE adds F_SECURITY_IN_307). |
| Calm | Phone held face down; stands near doors and walls; scans rooms on entry. |
| Pressured | Smiles more. Becomes helpful («Давайте я вам помогу»). Positions himself between the hero and what he wants. |
| Caught lying | Never admits outright; reframes as duty («Я делал свою работу»). Confesses only in the finale under audience pressure or when cornered. |
| READ tells | glance at the 307 door; screwdriver in the breast pocket; phone face down; in the finale: exit glance, reaching for the phone, stops looking at Adrian, weight shift. |
| Schedule (hub) | ~3 min loop: lobby → HALL_3F (stops at 307) → service stair → service corridor → security (talks with Pavel) → lobby. Shadow mode (if suspicion ≥ 2): his loop shortens and he takes the path closest to the hero's zone (once per 2 min, he "happens" to pass by). |
| Key interactions | S03 hallway; Lead C escort (fail-forward); overheard with Brody; the finale. |
| Transitions | suspicion from the hero's provokes and from being caught in security. `daniel_knows_hero_met_thomas` after S06 (the chase starts with that). Finale pressure model. |
| Motivation | Fifteen years with the family. He cleaned up the accident; Adrian's plan was Thomas; Daniel added Mara's guilt because, in his view, a guilty witness never talks, and that protected *her* too. He would say he loves this family. |

---

## EVA MARSH, 25

| Field | Spec |
|---|---|
| Personality | Fierce, impulsive, terrible liar, loyal to the bone. |
| Visible objective | Leave the hotel; "I'm here by chance." |
| Hidden objective | Keep Mara hidden until 08:00; get Thomas to leave. |
| Fear | `MARA_FOUND` (3), betraying Mara by accident (2). |
| Secret | She helped stage 307; she is in 308; she carries a burner. |
| Knows | Mara's location (Orchid Room), the plan, Thomas is at the dock. Not the full accident truth. |
| Calm | Smoking, phone, sarcasm. |
| Pressured | Walks faster; pats her pocket (the burner); answers before the question ends. |
| Caught lying | Freezes mid-word, then gets aggressive: «Ну и что? Ты кто вообще?» |
| READ tells | pocket pat; lighter from the rooftop bar (matches 308); a glance down the stairwell (toward the F2 landing) when Mara is mentioned. |
| Schedule | Roof (start) → on approach, down the service stair → landing 1 burner call → service corridor → laundry door (checks Thomas) → guest stair up → roof. If not approached for 6 min, she comes down to the lobby (fallback visibility). |
| Key interactions | TR_EVA_615; 308 evidence; tail; confrontation. |
| Transitions | suspicion ≥ 2 sets `mara_wary`. CAUGHT means PRESSURED. Honesty leads to a soft ally. |

---

## NICO, ~40, night bartender

| Field | Spec |
|---|---|
| Personality | Tired, warm under the sarcasm, owes the hero something and resents it. |
| Visible objective | Get through the shift. |
| Hidden objective | Keep the hero out of trouble (and himself). |
| Fear | `PRAGUE` (whatever happened there; never explained), losing his job. |
| Knows | F_MARA_MET_OLDER_MAN, F_MARA_ASKED_CAMERAS, F_DANIEL_ASKING, F_THOMAS_LOCATION (Volvo), Lina's gossip (if Lina was scared), F_NICO_RECOMMENDED. |
| Calm | Works constantly; talks to the glass he polishes. |
| Pressured | Stops working (a big tell for him), lowers his voice. |
| READ tells | stops polishing; glances at the service door (Daniel uses it). |
| Schedule | Bar circuit; smoke break at the service door every ~3 min for 60 s. |
| Transitions | warmth (= trust) gates info. |

---

## LINA, ~30, housekeeping

| Field | Spec |
|---|---|
| Personality | Careful, observant, afraid of losing her job; quietly decent. |
| Visible objective | Finish her rooms. |
| Fear | `TROUBLE_WITH_MANAGEMENT`. |
| Knows | F_MARA_LEFT_ALIVE, F_SECURITY_IN_307, F_SERVICE_STAIR, later F_THOMAS_LOCATION (fallback). |
| Calm | Works the room methodically (glasses, towels, bin). |
| Pressured | Clutches the towel stack; backs toward the door. |
| Schedule | S03 307 entry → HALL_3F cart route → freight alcove → linen room (SCORR). |
| States | ALLY / NEUTRAL / SCARED (see GAMEPLAY_SPEC S03). |

---

## PAVEL, ~45, hotel night security guard

| Field | Spec |
|---|---|
| Personality | Bored, rule-follower, likes Daniel because Daniel tips. |
| Visible objective | Watch the monitors; rounds. |
| Fear | `BLAME` for incidents on his shift. |
| Knows | The door code; that Daniel asked to see footage. |
| Calm | Slouched at the monitors. |
| Suspicious | Follows the hero at 5 m, radio in hand. |
| Detection | Vision cone 70°/9 m (a 5 m "peripheral" band notices only running), hearing per noise radius. Detection takes 1.2 s of continuous sight inside forbidden areas. In public zones he only notices running past him. |
| Schedule | ~100 s loop (see LEVEL_LAYOUT). Distraction phone call sends him to 3F for 90 s. |
| Caught behaviour | 1st: escort to the lobby. 2nd: call Daniel. |

---

## BRODY (~40) & SATO (~32): Daniel's contractors

| | Brody | Sato |
|---|---|---|
| Role | Muscle. Slow, relentless. | Fast, smart, radio carrier. |
| Chase speed | 0.9× hero run | 1.05× hero run (but stops to check side doors) |
| Weakness | Long recovery when tripped (2.5 s). Can't vault: goes around. | Trusts the radio: vulnerable to the bluff «Дэниел сказал прекратить». |
| Grab | 1 s struggle window. | — (he radios Brody, never grabs alone) |
| Motivation | Paid; believes the hero stole something from the client. | Same; secretly uneasy (in the bluff branch he hesitates longer: 3 s). |
| Finale | Wait outside the main doors if the "Мара здесь" invite was sent. | same |

---

## Scene 01 minor cast

| NPC | Trait | Tells | Behaviour |
|---|---|---|---|
| Hale | Drunk, desperate to look rich in front of Selin | looks at Selin; left wrist tan; snaps at the bartender | paces; restroom detours twice |
| Selin | Bored, sharp, half-leaving | puts her coat on and off | leaves at PUBLIC_EXPOSE |
| Kai | Proud, broke-looking student, innocent | doesn't flee | shoves on wrong accusation |
| Jules | Young bartender, kind, illegally took the pawn | glances under the counter | breaks under silence; recognises the hero vaguely |
