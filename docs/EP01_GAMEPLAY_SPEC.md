# EP01 — ROOM 307 — GAMEPLAY SPECIFICATION

Source of truth for narrative: `EPISODE 01 — ROOM 307` scenario (RU). This document turns it into playable scenes.
Companion docs: LEVEL_LAYOUT, STATE_MODEL, INFORMATION_GRAPH, CHARACTER_BEHAVIOR, DIALOGUE_AND_TRAPS, ACTION_SEQUENCE.

Language note: design docs are in English; in-game text is authored in Russian (the source language). All player-facing strings live in data files under `data/ep01/` with keys, so localisation can be added later.

---

## 0. Canon additions (decided here, consistent with the scenario)

The scenario leaves some gaps that gameplay needs filled. These are now canon for EP01:

1. **Why everyone is in the hotel tonight.** The Vale Foundation charity gala ended at midnight in the hotel's banquet hall. Adrian has a suite on floor 5. Daniel and two of his contractors (Brody, Sato) are on site for the gala. Banquet rooms are "closed after event", which is why Mara can hide in one.
2. **The accident.** Seven years ago a cyclist (Leon Brandt, 34) died on a country road. Adrian was driving after dinner. Mara (17) had driven the first half of the trip on a learner's permit, then swapped to the back seat and fell asleep. She woke after the impact with a concussion and a memory gap.
3. **Daniel's "insurance".** Daniel told Mara: "You were driving. Your father moved you to the back and called Thomas. He saved you." The learner-permit swap made it plausible. Daniel told Adrian: "She remembers nothing." Each of them believes a different story; only Daniel holds both.
4. **The recording.** Thomas had installed an interior-facing dashcam in the car that week. Nobody else knew. Mara found the card in the glove box while clearing the stored car for sale three weeks ago. It shows Adrian at the wheel and Mara asleep in the back.
5. **Room 307 was staged by Mara and Eva.** It was staged to look like a panicked flight or an abduction (open window, wet shoe), so that Adrian's people would search outside the hotel while Mara waits inside for an 08:00 meeting with a journalist. Mara wrote the message on the mirror, and she meant her father by "him". Eva booked the connecting room 308 under "E. Marsh".
6. **Adrian knows Mara has something.** Mara texted him a single frame from the video with the words "Я знаю." That phone message is what he touches in his inside pocket. He hires the hero to find her *and* the card, and he invents the "blackmailing ex-boyfriend" to explain urgency.
7. **Daniel searched 307** at 01:10, looking for the card. He checked the vent with a small screwdriver.
8. **Who recommended the hero.** Nico did, to the hotel night manager, who passed it to Adrian. This is an optional fact.
9. **Scene 01 bartender** is Jules (evening shift). Nico arrives for the night shift at about 03:00, which is why he "notices" the hero only in the hub.

The hero is never named on screen. NPCs address him by role or by pronoun, and Nico uses an old nickname ("профессор", ironic).

---

## 1. Global rules applied to every scene

| Rule | Implementation |
|---|---|
| Player controls hero ≥ 65% of runtime | All conversations are "in motion" (see STATE_MODEL §Conversation). Only flagged `CINE` beats lock input, and each one is ≤ 15 s. |
| Activity change every 30–60 s | The pacing monitor (debug overlay) logs gaps between `player_decision` events, and acceptance test AT-PACE-01 checks it. |
| READ never states conclusions | Observation captions are noun phrases or verb phrases describing what is seen, never inferences. |
| No hard fail | Every "caught/failed" branch maps to a `consequence` scene state (see each scene's Fail-forward). |
| Choices without menus | Dialogue chips are ≤ 4, ≤ 6 words each, and time out. Leaving the radius equals LEAVE, and letting chips expire equals SILENCE. |
| Endings by action | The ending is decided by which actor or object the hero physically hands the card to, or uses it on. |

### Controls (keyboard / gamepad)

| Action | KB/M | Pad |
|---|---|---|
| Move (screen-relative, depth on W/S) | WASD | LS |
| Fast walk (toggle) | Caps / double-tap direction | LS click |
| Run (hold) | Shift | RT |
| Crouch / slide (when running) | Ctrl | B / Circle |
| Context action (vault, door, push) | Space | A / Cross |
| Interact / pick up / place | E | X / Square |
| READ (hold) + aim focus | RMB + mouse | LT + RS |
| Dialogue chips | 1–4 | D-pad |
| Phone (invitations, photo, map) | Tab | Back/View |
| Threads glance | hold Q | hold RB |

**Social running rule.** Running in public zones (lobby, bar, guest hallway, restaurant) is allowed, but staff and guests notice it: it adds `+1 attention` to every NPC with line of sight, decaying after 10 s. Running past Pavel twice makes him follow the hero. This gives the different walk speeds a social meaning.

---

## SCENE 01 — THE WATCH

| Field | Spec |
|---|---|
| Duration | 3–5 min |
| Start | Hero seated at the bar counter, stool 3 of 6. The first input stands him up. There is no fade-in lockout: control starts at 0.0 s, while the title card is drawn in-world on the rainy window. |
| Immediate objective | None displayed. The argument is loud and staged around the hero. A diegetic hint appears only if the player idles for 20 s: "Hold READ" near Hale. |
| Space | `BAR` (ROOM mode). Counter runs left to right in the mid lane. Stools sit in the foreground lane. Booths are in the background lane along rain windows. There is a service hatch to the kitchen at the right end and an arch to `LOBBY` on the left. |
| Entry | Start position. |
| Exits | Lobby arch. If the hero leaves before resolution, Adrian intercepts him in the lobby (Scene 02 starts with the variant line). |
| NPCs | **Hale** (drunk businessman), **Selin** (his girlfriend), **Kai** (accused, ~25), **Jules** (bartender), **Adrian** (background booth, observing), two silhouette guests. |
| NPC initial state | Hale is pacing between the counter and Kai, gesturing (stress 2). Selin is standing, putting her coat on and off (stress 1, wants to leave). Kai stands with arms open and doesn't move toward the exit (stress 2). Jules is polishing the same glass and glancing under the counter (stress 2). Adrian is seated with his drink untouched, watching the hero rather than the fight. |

**Player verbs:** walk, fast walk, READ, talk (chips), bluff, provoke, silence, leave, interact (bar receipt spike, dome camera, house phone, Hale's coat on stool).

**Interactive objects**

| Object | Interaction | Result |
|---|---|---|
| Receipt spike on counter | E (look) | Shows Hale's open tab: "18 400 ₽, не оплачен". Gives observation `O_S1_UNPAID_TAB`. |
| Under-counter drawer | Jules blocks it while he is behind the bar. Accessible only if Jules is distracted (sent to the kitchen hatch for ice by a Selin interaction). | Opening it reveals the watch wrapped in a napkin, which gives `F_WATCH_PAWNED` directly (the hard-evidence route). |
| Ceiling dome camera | READ | `O_S1_DOME_NO_LED`: the camera has no status light. The bluff "cameras will show" stays possible, but the hero now *knows* it is a bluff. |
| Hale's coat | E | Wallet is empty. Gives `O_S1_EMPTY_WALLET`. |
| House phone | E | Unused in S1; becomes the distraction tool in the hub. A tooltip shows only after S1. |

**READ observations** (caption text in RU, in quotes)

| ID | Source | Caption | Window |
|---|---|---|---|
| O_S1_WRIST_TAN | Hale's left wrist | «след от часов — ровный, без царапин» | always |
| O_S1_HALE_LOOKS_SELIN | Hale head-turn tell | «смотрит на неё, а не на него» | every 8–12 s while talking |
| O_S1_JULES_UNDER | Jules gaze tell | «смотрит под стойку» | triggered when the watch is mentioned |
| O_S1_KAI_STAYS | Kai stance | «не делает ни шага к выходу» | always |
| O_S1_UNPAID_TAB | receipt | «счёт не оплачен» | after the receipt is read |
| O_S1_DOME_NO_LED | camera | «камера без индикатора» | always |
| O_S1_ADRIAN_DRINK | Adrian | «не притронулся к стакану» | always (foreshadow) |

**Conversation opportunities.** Each NPC gets one exchange of at most 2 chip windows before the exchange closes. Re-approaching opens a new exchange only after a new observation or fact.

- Hale: PRESS «Где ты их снял?», PROVOKE «Тогда вызываем полицию…» (camera bluff), DEFLECT «Красивая история».
- Selin: «Он часто так?», BLUFF «Он сказал мне, что проигрался». This bluff only works if `O_S1_UNPAID_TAB` or `O_S1_EMPTY_WALLET` is known; otherwise Selin calls it.
- Kai: «Покажи руки», «Почему не уходишь?»
- Jules: PRESS «Он ведь оставил их тебе?» (requires `O_S1_JULES_UNDER` OR `O_S1_UNPAID_TAB`, otherwise the chip doesn't appear), or SILENCE (stand at the counter and stare; after 6 s Jules breaks).

**Possible bluffs:** the camera bluff (to Hale or to everyone), "he told me he lost money" (to Selin), and "I saw you take it off" (to Hale, high-risk).

**Possible social traps** (see DIALOGUE_AND_TRAPS)

- `TR_S1_CAMERAS`: camera bluff with Hale as target and Selin as audience. Hale grabs the hero's arm and tries to stop him: an observable panic that reads as guilt.
- `TR_S1_PAWN_PUBLIC`: the pawn line said to Jules while Selin is within 4 m. Selin hears it, and the outcome is public exposure.
- `TR_S1_PAWN_PRIVATE`: the pawn line said to Hale alone (Selin > 6 m away, e.g. after Hale walks to the restroom corridor). Hale retracts quietly and the outcome is a private deal.

**Movement gameplay.** The scene is small but full of positioning. The player has to walk around the group to see Hale's left wrist (it is hidden from the start camera) and to get Selin within or out of earshot. Hale paces, and twice (at about 70 s and 150 s) he walks to the restroom corridor to "call his lawyer", which creates the private window.

**Stealth / action:** none. A shove can happen in the wrong-accusation branch; it is a scripted 3 s physical beat that still allows input.

**Camera.** Start: close three-quarter on the hero at the counter (FOV 40). On first movement it eases out to the bar master rig (side-on, FOV 50). In READ it pushes in 5% with a vignette. There is no cut except at the Adrian approach (≤ 6 s two-shot).

**Audio.** Rain on glass, quiet lounge piano loop, argument barks layered as a positional source. READ applies a low-pass at 900 Hz to ambience with dialogue unaffected. When an observation is noticed, a soft "pen scratch" sting plays.

**Music state:** `BAR_AMBIENT` (diegetic piano) and `TENSION_LOW` (on any PROVOKE).

**Story information**

- Required: none. The scene always resolves.
- Optional: `F_WATCH_PAWNED`, `F_HERO_READS_PEOPLE` (Adrian's evaluation).

**Resolutions** (they set `S1_RESOLUTION`)

| Value | How | Consequence |
|---|---|---|
| PUBLIC_EXPOSE | TR_S1_PAWN_PUBLIC or TR_S1_CAMERAS with Selin present | Selin leaves Hale. Adrian: «Жёстко. Но точно.» `adrian.respect +1`. |
| PRIVATE_DEAL | TR_S1_PAWN_PRIVATE | Hale pays and Kai is freed. Adrian: «Вы дали ему сохранить лицо. Это редкость.» `adrian.trust +1`. Jules keeps his job and Nico later warms by +1. |
| WRONG_ACCUSE | Hero accuses Kai or Selin | Kai shoves the hero, and Jules calls Pavel, who escorts Kai out and stares at the hero (`pavel.suspicion +1`). Adrian: «Неверно. Но быстро.» `adrian.respect 0`. |
| OBSERVE_ONLY | No decisive action for 4:30, or the player only READs | Jules breaks by himself and confesses. Adrian: «Вы поняли раньше всех. Почему молчали?» Hero chip: «Хотел посмотреть, кто сломается первым.» `adrian.respect +1`. |

**Fail-forward:** every resolution leads to Scene 02, and the wrong accusation only makes the security route harder.

**State changes:** `S1_RESOLUTION`, `adrian.trust/respect`, `pavel.suspicion`, `nico.warmth` (deferred).

**Advance condition:** any resolution reached, then a 6 s CINE two-shot as Adrian sits down next to the hero.

**Modifies later:** Adrian's opening tone, Pavel's suspicion (security route difficulty), and Nico's warmth.

**Tech notes**

- The scene is driven by `scene_s01.json`: NPC schedules, exchanges, traps, resolution rules.
- Hale's pacing is a `Schedule` with 3 waypoints plus the restroom detour.
- "Within earshot" is an Area3D radius on each NPC (`hearing_radius`) plus a wall occlusion raycast.
- Tutorial hints are `ContextHint` nodes: max 1 visible, 4 words, auto-hidden after use.

---

## SCENE 02 — THE CLIENT

| Field | Spec |
|---|---|
| Duration | 3–4 min |
| Start | Bar counter. Adrian is seated beside the hero. |
| Objective | Diegetic: follow Adrian. If the hero lags more than 6 m behind, Adrian stops and turns (tell: impatience). |
| Space | BAR, then LOBBY (lounge, reception, pillar lane), then ELEVATOR_A (interior), then HALL_3F (exit). |
| Exits | Elevator to floor 3. Adrian stays in the elevator (going to 5). |
| NPCs | Adrian (walking lead), Daniel (far side of lobby, on the phone), the night receptionist (silhouette), Pavel (if he was summoned in S1). |
| NPC initial state | Adrian: calm, controlled, stress 1, trust per S1. Daniel: watches the hero for 3 s and then turns away (READ: `O_S2_DANIEL_WATCHES`). |

**Flow (walk-and-talk beats tied to locations)**

1. **Bar (seated, 10 s CINE max):**
   > Adrian: «Мне сказали, вы умеете находить людей.»
   > Hero: «Вам соврали.» (pause) «Но продолжайте.»

   Adrian stands: «Пройдёмся.» Control returns.
2. **Bar → lobby (beat A, ~40 s walk).** Adrian gives the brief while walking: daughter Mara, 24, missing, last point Room 307, ex-boyfriend «Лукас» blackmails, no police. Chip window 1: «Она в опасности?» / «Почему без полиции?» / «Имя бывшего?» / silence.
3. **Lobby mid (beat B).** Daniel is in view. Chip window 2: «Что она взяла с собой?» (triggers the pocket-touch tell) / «Кто это?» (about Daniel: «Мой человек. Не обращайте внимания.») / «Сколько?»
4. **Elevator (beat C, ~35 s ride, floors tick).** Confined three-quarter camera. The hero can still move about 1 m in the cabin, and READ is fully usable. Chip window 3 (decisive): CALL LIE «Вы мне врёте.» / SILENCE / RAISE PRICE «Тогда это стоит вдвое больше.» / BLUFF «Она звонила мне час назад.» (always available, big tell).
5. **Doors open on 3:** Adrian hands over the 307 keycard: «Номер 307. Дальше — вы.» Doors close.

**READ observations**

| ID | Caption | Trigger |
|---|---|---|
| O_S2_FLAT_ON_DANGER | «вопрос об опасности — без реакции» | after «Она в опасности?» |
| O_S2_POCKET_TOUCH | «рука к внутреннему карману» | after «Что она взяла?»; also once during the BLUFF |
| O_S2_NAME_PAUSE | «пауза перед именем» | after «Имя бывшего?» |
| O_S2_DANIEL_WATCHES | «тот человек смотрит на тебя, не на него» | lobby beat |
| O_S2_RING | «перстень на правой руке» | always (pays off in Scene 08: the ring is visible on the dashcam) |

**Conversation variations by S1**

- PUBLIC_EXPOSE: Adrian is wary: «Надеюсь, со мной вы будете деликатнее.»
- PRIVATE_DEAL: warm.
- WRONG_ACCUSE: transactional.
- Left early: Adrian intercepts in the lobby: «Вы ушли до самого интересного.»

**Optional deep line** (`F_OLD_ACCIDENT`, `F_ADRIAN_THINKS_MARA_FORGOT`, early route). If the hero PRESSes about "why would an ex have leverage" twice, or if `adrian.trust ≥ 1` and the hero chooses SILENCE in the elevator:
> «Была старая история. Авария. Ей было семнадцать, она спала сзади. Она ничего не помнит. Слава богу.»

**Bluff:** «Она звонила мне час назад.» Adrian grabs the hero's forearm: «Что она сказала?» This gives `O_S2_GRAB`, `F_ADRIAN_EXPECTS_CONTACT`, `adrian.suspicion +1`, and `adrian.believes_hero_knows += F_MARA_CONTACT`. The hero must follow up with DEFLECT («Что ищет вас.») or admit the bluff («Ничего. Мне нужно было увидеть ваше лицо.»). Admitting it costs `adrian.trust -1` and gains `respect +1`.

**Fear hits (for Ending D):** «Если она прячется, то не от бывшего.» (available after O_S2_FLAT_ON_DANGER) counts as `adrian.fear_hits.LOSE_MARA +1`.

**Threads offered**

- `T_EX_BOYFRIEND` (default, Adrian's story; wrong).
- `T_ADRIAN_FEARS_WHAT_SHE_HAS` (requires O_S2_POCKET_TOUCH or O_S2_GRAB).

**Elevator decision → relationship**

| Choice | trust | respect | suspicion | Later effect |
|---|---|---|---|---|
| CALL LIE | -1 | +1 | +1 | Adrian is guarded in hub reports, but is the easiest to push to Ending D (he already knows the hero sees him). |
| SILENCE | +1 | 0 | 0 | May trigger the optional deep line. |
| RAISE PRICE | 0 | +1 | -1 | Adrian treats the hero as a mercenary. The finale line «Сколько ещё?» becomes available. |
| BLUFF | 0 | 0 | +1 | Grab tell (see above). |

**Camera:** walking two-shot rail through the lobby (side, tracking). Elevator: locked three-quarter with mirror-wall reflections.

**Audio:** the lobby has a fountain murmur and rain muffled. The elevator has hum and a floor ding. Music: `CLIENT_THEME_SPARSE` (cello drone).

**Fail-forward:** none needed; the hero cannot fail here. If he walks away mid-walk, Adrian calls after him once: «Триста седьмой. Ключ у меня.» If he still walks away, Adrian leaves the keycard at reception, and the receptionist hands it over when he comes back.

**Advance:** the doors open on floor 3 with the keycard in the hero's inventory.

**Tech notes:** `ConversationDirector` binds exchanges to `trigger_volumes` along Adrian's path. Adrian's path is a `Schedule` in FOLLOW_LEAD mode: he moves only when the hero is within 6 m and waits otherwise. The elevator is a moving platform scene: the cabin interior is static, and the floor indicator and shake fake the motion.

---

## SCENE 03 — ROOM 307

| Field | Spec |
|---|---|
| Duration | 5–7 min |
| Start | HALL_3F, at the elevator. Walk 20 m to 307 (corridor lanes: foreground has room-service trays and an ice machine, background has doors). |
| Objective | None. The player explores. |
| Space | ROOM_307 (ROOM mode). Entry foreground-left. Desk left. Bed centre-back. Window back-right. Bathroom door right, with the mirror visible through the door when open. Wardrobe mid-left. Connecting door to 308 on the left wall. |
| Exits | The 307 door to the hallway. The connecting door to 308, whose other door leads to the hallway. |
| NPCs | Lina (housekeeping, arrives at the trigger). Daniel (hallway, on exit). |

**Interactive objects & observations**

| Object | Verbs | READ observation(s) | Designer meaning (never shown) |
|---|---|---|---|
| Two wine glasses on desk | look, pick up | O_307_GLASS_ONE_USED «пил один — второй сухой» | staged "visitor" |
| Wine bottle | look | O_307_BOTTLE_THIRD «выпита треть» | — |
| Bathroom: shower | turn hot water on/off | O_307_FLOOR_WET «пол душевой мокрый» | the shower ran |
| Towels | look, take | O_307_TOWELS_DRY «полотенца сухие, сложены» | nobody showered |
| Mirror message «DON'T TRUST HIM» | look (always visible); READ; re-steam with hot water | O_307_MSG_CONDENSATION «написано пальцем по конденсату»; after re-steam O_307_MSG_HEIGHT «на уровне её глаз» | written after the steam, by a woman of about 165 cm |
| Charger | pull/plug | O_307_CHARGER_PULLED «зарядка выдернута» | — |
| Old phone under bed (dead) | pick up, plug into charger | — | Mara's second phone. If charged, it later receives Eva's text (see hub). |
| Shoes | pick up each | O_307_ONE_WET_SHOE «одна туфля мокрая»; O_307_SHOE_CLEAN «вода чистая — ни песка, ни грязи» | dipped, not walked outside |
| Window (open) | close, lean out | O_307_SILL_DRY «подоконник почти сухой»; O_307_NO_ESCAPE «третий этаж, ни пожарной лестницы» | opened minutes ago; nobody climbed out |
| Pills (blister) | look | O_307_PILL_MISSING «одной не хватает»; label «Vale, M.» | anxiety meds; she took one (true) |
| Mattress | look, lift corner | O_307_MATTRESS_SHIFTED «матрас сдвинут на пару сантиметров» | Daniel searched |
| Travel bag (wardrobe) | open | O_307_ZIP_WRONG «бегунок молнии не с той стороны» | re-zipped by someone else |
| AC vent | look | O_307_VENT_SCRATCH «свежие царапины на винтах» | Daniel checked the vent |
| Curtain | move | reveals the vent and the window latch | — |
| TV | on/off | hotel info channel with a floor map | diegetic map: marks rooftop smoking area, service stair |
| Connecting door to 308 | open (unlocked from the 307 side) | O_308_SAME_LIGHTER «зажигалка с логотипом бара на крыше» (in 308); O_308_TWO_COFFEE | Eva's room. Route to the Eva lead. |
| Room service slip | look | O_307_SLIP «два бокала, 23:10» | — |

**Housekeeping interruption (Lina)**

Trigger: 150 s in the room OR 5 meaningful interactions, whichever comes first. If the hero is in the bathroom with the water running, she waits in the doorway: «Есть кто?»

Lina enters with towels, assumes the room is vacated, and starts working: she collects the glasses, opens the bin and swaps towels. This is a soft evidence-loss timer. If the hero hasn't looked at the glasses, she takes them. «Оставь.» stops her.

Chips (Lina keeps working throughout, so the hero follows her around):

- CALM «Я не из полиции. Ищу девушку.»
- BLUFF «Я из охраны отеля.» Lina knows every guard, so this is CALLED unless the hero shows Adrian's keycard (E on Lina while holding the card). With the card she accepts it as "a guest of Mr. Vale".
- PRESS «Кто ещё сюда заходил?»
- RELEASE «Иди. Я тебя не видел.»

Facts from Lina:

- F_MARA_LEFT_ALIVE: «Она сама попросила полотенца в полдвенадцатого. Потом ушла. Спокойная.»
- F_SECURITY_IN_307: «Потом заходил из охраны. Не наш — в дорогом костюме.»
- F_SERVICE_STAIR: «Она спрашивала про служебную лестницу.»

Outcomes:

| Lina state after | How | Effect |
|---|---|---|
| ALLY | CALM, then RELEASE or kindness | Later in the hub she lends her cart and staff keycard (Security route), and she is the fallback source of Thomas's location. |
| NEUTRAL | mixed | She gives facts but no help later. |
| SCARED | PRESS twice or a called bluff | She flees and leaves her cart in the hallway (the cart stays usable). Her facts become available from Nico instead ("Лина рассказывала…"). |

**Exit encounter: Daniel (guaranteed).** On first exit from 307 (or 308), Daniel walks from the service-stair end of HALL_3F toward the elevator. This is a walk-and-talk lasting until the elevator, 25–40 s.

> Daniel: «Вы, должно быть, наш новый друг. Дэниел. Отвечаю за безопасность мистера Вейла. Нашли что-нибудь?»

Chips:

- LIE «Пусто.»
- TRUTH-PARTIAL «Она ушла сама.»
- PROVOKE «Ваши люди плохо застёгивают сумки.» (requires O_307_ZIP_WRONG)
- SILENCE.

READ tells:

- O_DANIEL_GLANCE_307 «смотрит на дверь 307»
- O_DANIEL_SCREWDRIVER «отвёртка в нагрудном кармане»
- O_DANIEL_PHONE_DOWN «кладёт телефон экраном вниз»

Effects:

- PROVOKE: Daniel stops and smiles: «Внимательный. Это хорошо.» `daniel.suspicion +2` and `daniel.believes_hero_knows += F_SECURITY_IN_307`. In the hub he shadows the hero more often, which makes stealth harder but gives more READ opportunities on him.
- LIE: `daniel.suspicion +0`.
- TRUTH-PARTIAL: `daniel.suspicion +1`, and Daniel radios Brody (audible: «Она в здании.»). This sets `F_DANIEL_KNOWS_SHE_IS_INSIDE`, which shortens the chase spawn delay in Scene 07.

**Threads offered**

- T_307_STAGED: any 2 of {GLASS_ONE_USED, TOWELS_DRY+MSG_CONDENSATION, SILL_DRY, SHOE_CLEAN}.
- T_SHE_LEFT_BY_WINDOW (wrong): ONE_WET_SHOE + window seen open, *without* SILL_DRY or NO_ESCAPE.
- T_SOMEONE_SEARCHED_307: any 2 of {MATTRESS_SHIFTED, ZIP_WRONG, VENT_SCRATCH, F_SECURITY_IN_307}.

**Camera:** ROOM rig (three-quarter, from a high corner, FOV 55). The bathroom gets its own rig, with the mirror as a hero shot when the water steams. In READ the camera nudges toward the focused object.

**Audio:** rain through the open window (it drops sharply when the window is closed, a satisfying change). The shower hiss. The TV channel's soft muzak. Music: `INVESTIGATE_MINIMAL` (a pulse that rises with each new observation, capped).

**Story information**

- Required: none. The hub opens regardless.
- Optional: everything above. The key optional items are F_SERVICE_STAIR (also obtainable from the TV map), F_SECURITY_IN_307, T_307_STAGED, the Eva room link, and Mara's charged phone.

**Fail-forward:**

- Leaving immediately: Daniel's encounter still happens, and the hub still opens.
- Lina scared: info routed through Nico.
- Missing the glasses: no loss; T_307_STAGED has other inputs.

**State changes:** observations, threads, `lina.state`, `daniel.suspicion`, `phone_307_charged`, `window_closed` (cosmetic: rain audio in the hallway), `F_EVA_ROOM_308`.

**Advance:** the Daniel encounter ends and `EPISODE.phase = HUB`.

**Tech notes**

- The re-steam effect is a mirror material with a `fog_amount` parameter animated by the shower state. The message is a decal whose opacity is tied to `fog_amount`.
- Every object is an `Interactable` and every observation is an `Observable` (see STATE_MODEL).

---

## SCENE 04 — HOTEL HUB

| Field | Spec |
|---|---|
| Duration | 7–10 min (including Scene 05 if taken) |
| Start | HALL_3F at the elevator, after Daniel leaves. |
| Objective | Diegetic. The Threads HUD shows the current hypotheses. A one-time phone text from Adrian reads: «Новости?» (no checklist). |
| Space | LOBBY, BAR, HALL_3F, GUEST_STAIR, SERVICE_STAIR (vertical), ROOF_SMOKING, SERVICE_CORRIDOR (ground), SECURITY_ROOM (locked), BALCONY (floor-2 mezzanine overlooking the lobby, for eavesdropping). |
| NPCs | Nico (bar, from the hub start, shift change), Eva (roof, then moving), Pavel (security loop), Daniel (roaming), Adrian (lobby lounge phone call, then the suite), Lina (per state), Brody (loading area, out of sight until Scene 06), silhouette guests. |

**Leads.** There are three. Any order. Completing (or failing to conclusion) any 2 opens Scene 06, provided the hero also knows where Thomas is.

### LEAD A — NICO (bar)

Nico is working: two late guests, restocking, a smoke break at the service-corridor door (at hub time ~3:00 for 60 s; the timer starts when the hub opens).

> Nico (first look): «Господи. Только не ты.»
> Hero: «Я тоже рад тебя видеть.»

Gameplay:

- Nico won't stop working. Talk to him while he moves along the bar.
- The hero can step behind the bar and pour a drink for the waiting guest (E on the bottle, then E on the guest). Nico: «Положи. Мой бар.» He is secretly grateful: `nico.warmth +1`. This is a skill flourish hinting at the hero's past.
- Nico's info is gated by warmth ≥ 1. Sources of warmth: S1 PRIVATE_DEAL, helping at the bar, or joining him on his smoke break (follow him to the service door). The BLUFF «Адриан Вейл сказал, ты в курсе» is CALLED: Nico knows Adrian never speaks to staff, and `nico.warmth -1`, but he still gives one fact out of pity.

Facts:

- F_MARA_MET_OLDER_MAN: «Седой. Пил чай. Руки держал как водитель — на десяти и двух, даже на столе.»
- F_MARA_ASKED_CAMERAS: «Спрашивала, где камеры. Два раза.»
- F_DANIEL_ASKING: «Потом пришёл этот ваш Дэниел. Задавал те же вопросы. Только про неё.»
- F_THOMAS_LOCATION (route 2): «Седой спросил, где служебный выезд. У погрузки стоит старое Volvo — не наше.»
- F_NICO_RECOMMENDED (optional, warmth 2): «Это я сказал менеджеру про тебя. Прости.»
- Past fragment: «После истории в Праге я думал, ты больше никогда…» / Hero: «Не сегодня, Нико.»

**Lead A complete** when the hero has F_MARA_MET_OLDER_MAN.

### LEAD B — EVA (roof → service stair)

Eva is on ROOF_SMOKING, alone, with a cigarette, on her phone. She sees the hero and stubs the cigarette out: she wants to leave. Conversation in motion: she walks from the roof door down SERVICE_STAIR, and the hero follows.

Her claims: she doesn't know where Mara is, she came by chance, Mara told her nothing.

READ:

- O_EVA_POCKET «трогает карман — второй телефон?»
- O_EVA_LIGHTER «зажигалка с крыши… такая же в 308» (only if O_308_SAME_LIGHTER is known)

**Bluff trap TR_EVA_615:**

> Hero: «Мара позвонила мне из 615.»
> Eva: «Она вообще не была на шестом…» (stops)

This gives F_MARA_NOT_ON_6 and F_EVA_KNOWS_WHERE, and Eva's state becomes CAUGHT.

Other bluffs: «Мара сказала мне, что ты её прячешь» is CALLED (Mara would never say that): `eva.suspicion +2` and Eva texts Mara, which sets `mara.wary = true` (Scene 08 starts colder). Evidence instead of a bluff: «Ты живёшь в 308» (requires F_EVA_ROOM_308) also gives CAUGHT, without needing a lie.

After the conversation Eva leaves down the service stair. **Tail:**

- Stay out of her line of sight using landings, doors and the crouch-behind-railing spots.
- At the floor-1 landing she makes a burner call. The hero can overhear it if within 5 m and unseen: «Томас ещё здесь? …У прачечной. Скажи ему, пусть уезжает. …Нет, она в порядке.»
- This gives F_THOMAS_NAME, F_THOMAS_LOCATION (route 3) and F_EVA_PROTECTING_MARA.

Tail detected: Eva turns: «Ты за мной ходишь?» This opens a new exchange. Honest «Её отец заплатил мне. На твоём месте я бы тоже её прятал.» (requires Eva not CALLED) leads to «Поговори с Томасом. Он у прачечной. И не смей…», which gives the same facts. If she has called a bluff earlier, she just leaves, but the phone in 307 (if charged) receives her text: «Он у прачечной. Уходи через кухню, если что.» That is route 4.

**Lead B complete** when the hero has F_EVA_KNOWS_WHERE OR F_EVA_PROTECTING_MARA.

### LEAD C — SECURITY ROOM

The security room is behind reception (ground floor), with a keypad door (code 3071) and a second staff door from SERVICE_CORRIDOR (staff keycard).

**Pavel's loop (~100 s):** monitors (55 s) → reception chat (15 s) → walks the lobby (20 s) → back. On every exit the door closes in 3 s.

Approaches (all valid):

1. **Catch the door.** Follow Pavel back and slip in within 3 s. He must not have line of sight: wait for him to sit, since the chair faces the monitors.
2. **Distract.** Use the bar's house phone to call reception: «На третьем драка.» Pavel leaves by elevator for about 60 s.
3. **Cart cover.** With Lina's cart (from the ALLY or SCARED state), the hero pushes it through the lobby. Pavel ignores staff, so the hero reaches the reception back door unchallenged.
4. **Staff door.** Lina's keycard (ALLY), or the laundry key-hook (SERVICE_CORRIDOR; takes a few seconds and is visible to the laundry worker silhouette, who doesn't care).
5. **Peek the code.** Stand in the lobby foreground lane behind the palm planter while Pavel types. In READ, focus on his hand: O_PAVEL_CODE_A «3… 0…» on the first entry and O_PAVEL_CODE_B «…7… 1» on the second. Both are needed unless the player is close (≤ 3 m, risky), which gives the full code.

**Stealth model:** line-of-sight cones on Pavel, reception and Daniel; a noise radius (running 6 m, fast walk 3 m, walk 1.5 m); positional cover (planters, pillars, desk).

**Caught** (Pavel sees the hero inside or at the keypad):

- First time: «Сюда нельзя.» Pavel escorts the hero to the lobby (walk together, 15 s; the hero can still talk). `pavel.suspicion +1`. The door code changes only if it was seen being entered.
- Second time (or `pavel.suspicion ≥ 2` from S1): Pavel calls Daniel. Daniel arrives and walks the hero out:
  > «Мистер Вейл платит вам за дочь, а не за наши записи.»

  `daniel.suspicion +1`. Lead C is then complete in FAILED state, but Daniel's escort gives a new READ opportunity (O_DANIEL_CAMERA_CONCERN «он торопит тебя от мониторов») and the thread T_DANIEL_HIDES_SOMETHING.

**Lead C complete:** Scene 05 completed, or FAILED as above.

### Ambient hub opportunities (optional, observation without dialogue)

- **Adrian's lobby phone call** (hub minutes 2–4, lounge armchair). Overhear from behind the pillar or from the BALCONY above: «Она ничего не помнит, Дэниел. Ничего. Найди карту, и всё.» This gives F_ADRIAN_THINKS_MARA_FORGOT, F_RECORDING_EXISTS (partial: "карта") and F_ADRIAN_DANIEL_COORDINATE.
- **Daniel and Brody** (ROOF door or service corridor, hub minute ~5): «Если не найдём до семи — она сама всё выложит.» This gives F_DEADLINE_MORNING.
- **Report to Adrian** (optional conversation in the lobby lounge). The hero can lie, tell part of the truth, or hit his fear:
  - «Она прячется от вас.» counts as fear_hits.LOSE_MARA +1.
  - «Покажите, что у вас в кармане.» (PRESS, requires T_ADRIAN_FEARS_WHAT_SHE_HAS): Adrian shows the frame Mara sent, a blurry car interior, «Я знаю.», and pockets it fast. This gives F_RECORDING_EXISTS and F_OLD_ACCIDENT, at `adrian.trust -1` and `respect +1`.
- **Photo of Daniel entering 307** (from Scene 05): show it to Adrian (E with the phone out). Adrian goes very still. Later he is seen arguing with Daniel by the elevator (observable). The finale variant is `adrian.doubts_daniel = true`, which makes Daniel's exposure land faster.

### Hub progression rule

```
if leads_completed >= 2 and has(F_THOMAS_LOCATION): enable trigger THOMAS_START at the service corridor → loading door
if leads_completed >= 2 and not has(F_THOMAS_LOCATION): after 90 s, fallback FB_LINA:
   Lina (any state except gone) approaches the hero in the nearest public zone:
   «Тот пожилой… он сидит в машине у погрузки уже час.» → F_THOMAS_LOCATION
   If Lina is gone: the hotel PA asks "owner of grey Volvo at loading bay" — a diegetic fallback.
```

**Camera:** each zone has a master rig. The service stair is a vertical side-section ("dollhouse"). The roof is wide side-on with the city skyline layers. The balcony is high-angle down onto the lobby.

**Audio:** the lobby fountain, distant gala clean-up clatter from the service corridor, rain stronger on the roof, and the stairwell with reverb and echoing footsteps. Footstep noise becomes audible gameplay information when tailing.

**Music:** `HUB_EXPLORE` (layered: base pulse, plus a layer per completed lead), `TAIL_TENSION` (while a tail target is active), `STEALTH_LOW`.

**Fail-forward summary**

| Failure | Result |
|---|---|
| Eva bluff called | Eva leaves. The tail is still possible. Phone 307 route. Mara is wary later. |
| Tail detected | New confrontation exchange, which can still yield facts. |
| Caught at security | Escort, then a Daniel escort, then Lead C is FAILED but counts. |
| Nico cold | One pity fact. Lina or Eva supply Thomas's location. |
| No Thomas location | Lina or PA fallback after 90 s. |

**Tech notes:** NPC schedules are beat-driven (not clock-driven): each NPC's hub schedule loops until a `world_beat` changes it. The overhear system uses `AudioZone` areas: a conversation plays positionally, subtitles appear only while the hero is inside the zone and unseen, and facts are granted at specific line indices (no fact if the hero arrives late, but most overheards loop once more after 60 s).

---

## SCENE 05 — VIDEO ROOM

| Field | Spec |
|---|---|
| Duration | 2–4 min |
| Start | Inside SECURITY_ROOM. |
| Objective | Diegetic: the monitors. A soft clock: Pavel's return. Audio cues are footsteps and radio chatter outside at T-20 s and T-8 s. The timer is 75 s from entry if Pavel was distracted, 50 s if he is on his loop, and unlimited if he left via the elevator distraction and is still on floor 3 (he returns after 90 s). |
| Space | A small room: monitor wall, desk with jog wheel, chair, staff door to SERVICE_CORRIDOR (exit), front door to reception. |

**Interaction.** Sit (E). This is still "in control": the hero can stand up at any time, and the camera keeps his silhouette in the foreground. There are 4 camera buttons (physical keys on the desk), 4 timestamp tabs and a jog wheel: hold left or right to scrub at 8×, tap to step.

| Cam | Time | What the player sees |
|---|---|---|
| LOBBY | 23:05 | Mara enters alone with a big bag. |
| HALL 3F | 23:40 | Mara and Eva walk into 307 and 308 (if Eva not yet identified this gives F_EVA_INVOLVED). |
| BAR | 00:20 | Mara with a grey-haired man (Thomas) arguing; he grips the table edge (O_VID_HANDS «руки на краю стола — как на руле»). |
| SERVICE CORR | 00:31 | Both walk toward the loading area (F_THOMAS_LOCATION route 1). |
| HALL 3F | 01:10 | Daniel enters 307 with a keycard. He exits 9 min later putting a screwdriver away (F_DANIEL_SEARCHED_307). |
| SERVICE STAIR | 00:15 onward | "NO SIGNAL" (O_VID_STAIR_DEAD «камеру на служебной лестнице отключили в 00:15»). Deliberately ambiguous. |

**Optional:** photograph the monitor with the phone (Tab, then the photo action) while Daniel is on screen. This gives the item `ITEM_PHOTO_DANIEL_307`, used as a bluff or evidence object for Adrian or in the finale. It also makes "Камера всё записала" TRUE against Daniel.

**Exit.** By the staff door to SERVICE_CORRIDOR, which leads naturally toward the loading area, or by the front door if Pavel isn't there.

**Caught** (Pavel returns while the hero is seated): the same as Lead C caught, except that facts already seen are kept.

**Required:** none. **Grants:** F_THOMAS_LOCATION, F_DANIEL_SEARCHED_307, F_MARA_MET_OLDER_MAN (if not from Nico), F_EVA_INVOLVED.

**Camera:** over-the-shoulder side-on. The footage itself is in-world on the monitor mesh (SubViewport textures of pre-baked graybox clips).

**Audio:** monitor hum and Pavel's radio. Music: `STEALTH_LOW`, rising on the timer cues.

**Tech:** footage clips are short pre-rendered videos (Ogg Theora) or SubViewport replays of recorded NPC animation tracks. For graybox, use a `FootagePlayer` that animates capsules along recorded paths (cheap, art-replaceable).

---

## SCENE 06 — THOMAS

| Field | Spec |
|---|---|
| Duration | 3–5 min |
| Start | The hero enters LOADING_DOCK from SERVICE_CORRIDOR or via LAUNDRY. |
| Objective | Thomas is walking from the laundry door to his grey Volvo, keys in hand. He is leaving. |
| Space | LOADING_DOCK: a wide side-on view. Raised dock in the foreground, the yard and the Volvo in the mid lane, the rolling gate in the background, rain, a sodium light. The laundry door is on the left and the gate on the right. |
| NPCs | Thomas. Brody and Sato arrive at the end. |

**Make him stop (the first 30–60 s).** Thomas walks at fast-walk speed and the hero gets about 25 m before he reaches the car. Any of these stop him:

| Action | Thomas reaction | Relationship |
|---|---|---|
| Block his path (stand in his lane or push a laundry cart across) | He sidesteps once, then stops: «Отойди.» | 0 |
| Say «Мара.» | He stops and doesn't turn. | +1 |
| Lie: «Полиция уже едет.» | He stops, then turns cold: «Тогда мне нечего терять.» He talks, but skips the personal parts. | -1 |
| «Дэниел знает, что ты здесь.» | He stops and scans the yard (fear tell). He talks faster. | 0, sets `thomas.fear_daniel` |
| Take the Volvo keys (he puts them on the dock edge while unlocking the gate chain, a 4 s window) | He stops and must talk to get them back. | -1, but gives the hero leverage |

**Conversation in motion.** Thomas leans on the car and smokes. The hero can walk around the car, and READ targets are distributed around it:

- O_THOMAS_PHOTO «фото подростка на приборной панели»
- O_THOMAS_WRIST «выцветшая тюремная татуировка на запястье»
- O_THOMAS_HANDS «держит сигарету как руль»
- O_THOMAS_PILLS «счёт из клиники на сиденье»

**Revelation in fragments.** Each fragment is unlocked by a player act, not by a menu walk:

1. Any stop method gives «Мне нечего тебе сказать.» Then the chip is «Ты был водителем Вейлов.» (requires F_MARA_MET_OLDER_MAN or F_THOMAS_NAME). Or SILENCE: Thomas fills the silence himself after 5 s. Silence works on him; that is his trait.
2. «Семь лет назад. Авария. Человек погиб. Я сидел полтора года.» (F_THOMAS_TOOK_BLAME)
3. «За рулём был не я.» Chip: PRESS «Адриан.» He looks away (O_THOMAS_LOOKAWAY). This gives F_ADRIAN_WAS_DRIVING (as a claim, confirmed in Scene 08).
4. Personal: READ the photo, then «Твой сын?» opens: «Деньги Вейла вытащили его. Я согласился сам. Слышишь? Сам.» (F_THOMAS_PAID_SON, F_THOMAS_CONSENTED). Skipped if the police lie was used.
5. «У неё запись. С камеры в машине. Я сам её поставил, идиот.» (F_RECORDING_EXISTS)
6. **Guaranteed line** (key for the finale): «Адриан думает, она ничего не помнит. Она спала. Он так и сказал Дэниелу: пусть спит дальше.» (F_ADRIAN_THINKS_MARA_FORGOT)
7. Climax:
   > Thomas: «Останови её.»
   > Hero: «От чего?»
   > Thomas: «От справедливости.»

**Guarantee rule:** if 70 s pass without new player input, Thomas delivers the next fragment himself (silence is valid). Fragments 2, 3, 5, 6 and 7 always play.

**End beat** (CINE, 8 s): headlights sweep the gate and a van stops. Brody and Sato get out. Thomas: «Уходи. Они не за мной.» He gets into the Volvo (or, if the hero took the keys, walks off through the gate), and Scene 07 starts with control already in hand.

**Fail-forward:**

- The hero lets Thomas drive away before stopping him: Thomas's car is blocked by the van arriving early. He gets out, swearing, and the conversation happens beside the van while Brody waits. This is a compressed version, with the guarantee lines only, and the chase starts with Brody already close.
- Hostile Thomas still gives the guarantee lines.

**State:** `thomas.trust`, `thomas.fear_daniel`, `ITEM_VOLVO_KEYS` (used in the chase: the car alarm makes a distraction), all facts above, `T_TWO_STORIES` (formed once F_ADRIAN_THINKS_MARA_FORGOT is known and Mara is later heard; see the info graph).

**Camera:** wide dock side-view, pushing to a two-shot when Thomas leans on the car. Rain foreground streaks.

**Audio:** heavy rain on metal, the gate chain, the van engine as a leitmotif for the threat. Music: `THOMAS_SORROW` (sparse guitar), cut hard to `CHASE_START` on the headlights.

---

## SCENE 07 — ACTION SEQUENCE: THE SERVICE CHASE

Full design in `EP01_ACTION_SEQUENCE.md`.

| Field | Spec |
|---|---|
| Duration | 4–6 min |
| Start | LOADING_DOCK. Brody and Sato are at the van, 15 m away. |
| Objective | Diegetic: get away. They want Mara's location and the recording. |
| Space | LOADING_DOCK → LAUNDRY → KITCHEN → COLD_STORAGE → STAFF_CORRIDOR → (FREIGHT_ELEVATOR or SERVICE_STAIR) → BANQUET_CORRIDOR_F2 → ORCHID_ROOM door. |
| End | All routes converge on BANQUET_CORRIDOR_F2. Mara opens the Orchid Room door and pulls the hero in (8 s CINE), and the pursuers run past. Scene 08 starts. |
| Fail-forward | Caught twice leads to an interrogation in cold storage with an escape opportunity, after which the chase resumes. There is no game over. |

---

## SCENE 08 — MARA

| Field | Spec |
|---|---|
| Duration | 3–4 min |
| Start | ORCHID_ROOM, dark: a closed banquet room with stacked chairs, a round table with her laptop, and city light through tall windows. |
| Objective | None. Mara holds a fire extinguisher like a club. |
| NPCs | Mara, and Thomas (arrives at about 90 s through the service door; he circled back on the freight elevator). |
| Mara initial state | `mara.wary` is true or false (from the Eva outcome). Stress 3. |

**Phase 1: defuse (30–60 s).** Mara keeps the table between herself and the hero and circles as he moves. This is physical: if the hero steps toward her she steps away. Options:

- Stay still and SILENCE: she lowers the extinguisher after 6 s.
- «Твой отец меня нанял. Я ещё не решил, на кого работаю.» (honest)
- «Эва сказала, где ты.» (BLUFF; CALLED if `mara.wary`, in which case she backs toward the door: the hero must block the door or calm her)
- Put the 307 phone on the table, if it was taken: «Ты забыла.» That earns trust +1.

**Phase 2: the clip.** She opens the laptop: «Смотри.» The hero controls playback (hold to play, release to pause, scrub). The clip is 12 s long. In READ:

- O_CLIP_RING «перстень на руке водителя» (matches O_S2_RING)
- O_CLIP_BACKSEAT «девочка спит на заднем сиденье»

This gives F_ADRIAN_WAS_DRIVING (confirmed).

**Phase 3: her story** (she paces; conversation in motion):

> «Семь лет я думала, что это я. Что я убила его.» (F_MARA_BELIEVED_SHE_DROVE)
> «Дэниел сказал мне. В больнице. "Твой отец спас тебя."» (F_DANIEL_TOLD_MARA)
> «В восемь у меня встреча с журналистом. Я всё расскажу.» (F_MARA_WILL_PUBLISH)

**Thomas arrives** at about 90 s, or immediately after phase 3. He and Mara face off: one short exchange, at most 2 lines each. He confirms:

> «Адриан никогда не просил меня внушать тебе, что ты была за рулём. Он думал, ты не помнишь. Это был Дэниел.»

This gives F_ADRIAN_NEVER_ASKED.

The thread `T_TWO_STORIES` forms: «ОНА ДУМАЛА, ЧТО ВИНОВАТА / ОН ДУМАЛ, ЧТО ОНА НЕ ПОМНИТ». It is shown as two lines, not a conclusion.

**Phase 4: the ask.** The hero chips:

- «Дай мне час. Я хочу, чтобы они сказали это сами.» (gives `PLAN_FINALE`; Mara's trust ≥ 0 required, else she needs a second argument)
- «Публикуй. Прямо сейчас.» (Mara: «Не раньше, чем посмотрю ему в глаза.» The plan still happens; this keeps the finale mandatory.)
- «Отдай мне карту.» (if trust ≥ 1 she gives it; else she keeps it and will bring it to the restaurant herself)

**Card custody:** `CARD_HOLDER = hero | mara`. Either works for the finale (if Mara holds it she places it on the table when seated).

**Fail-forward:** low trust only changes who holds the card and how Mara sits (closer to the door, harder to "address"). It never blocks.

**Camera:** low-key, a single practical light (laptop glow), side-on with stacked chairs as foreground silhouettes.

**Music:** `MARA_THEME` (piano, the same motif as the bar piano, now in a minor key).

---

## SCENE 09 — SET THE TRAP (FINALE)

| Field | Spec |
|---|---|
| Duration | 5–7 min |
| Start | The hero enters RESTAURANT (ground floor, closed, chairs up, pre-dawn blue light) through the kitchen swing door. Mara and Thomas wait in the Orchid Room until invited. |
| Objective | Diegetic: prepare the room, then invite. |
| Space | RESTAURANT (ROOM mode): long room. A four-top by the window in the centre. Bar shelf on the left. Kitchen swing door back-left. Main doors to the lobby on the right. Terrace door back-right (locked, key behind the bar). Light panel by the main doors. |

### Phase A: Staging (free roam, no timer, 1–3 min typical)

**Stage points** (all physical; E to place or take; a world-space marker only shows while the hero carries the related item):

| Stage point | Options | Effect |
|---|---|---|
| Place cards (4 seats + "standing" by window) | Drag cards (carry one at a time) to seats S1–S4 | Determines who faces whom, who is near which exit, and who can see the card on the table. |
| Recording phone | vase / bread basket / bar shelf / none | Vase: clear audio. Basket: muffled. Shelf: too far. Sets `recording_quality`. |
| The card (SD card) | table centre / hero pocket / bar | On the table: Daniel's eyes go to it (tells), and he may try to grab it. In the pocket: Daniel will ask for it. Bar: Daniel's escape route passes it. |
| Kitchen swing door | open / closed / jammed with chair | Daniel's preferred escape. Jammed means he goes for the main doors. |
| Main doors | open / closed / locked (key from bar) | Locked keeps Brody and Sato out if Daniel brings them. |
| Terrace door | locked (default) / unlocked | An alternate escape for Daniel. |
| Lights | dim / full | Full: READ tells are easier to catch (wider focus radius). Dim: Daniel is more comfortable, so his suspicion rises more slowly. |
| Photo of Daniel in 307 (if owned) | phone face-up at Adrian's seat or not | Pre-seeds Adrian's doubt. |

**Invitations** (phone, Tab, then contacts). Each contact has 2–3 message templates. Send order equals arrival order (with 20 s spacing).

| Contact | Templates | Effect |
|---|---|---|
| Adrian | «Ресторан. Сейчас. Она будет.» / «Ресторан. Один.» | "Она будет" makes Adrian arrive emotional (stress +1). |
| Daniel | «Ресторан. У меня то, что вы ищете.» / «Мистер Вейл хочет вас в ресторане.» / «Мара здесь.» | "Мара здесь" makes Daniel bring Brody and Sato, who wait outside the main doors (they enter if the doors are not locked when Daniel signals). "То, что вы ищете" makes Daniel arrive focused on the card. "Вейл хочет" makes Daniel arrive relaxed (suspicion 0). |
| Mara | «Пора.» | — |
| Thomas | «Пора.» / no invitation | If not invited, Thomas is absent and Ending B becomes unavailable. A soft warning appears once when the hero starts the meeting: «Томаса нет.» |

**Start meeting:** the hero takes his own position (standing at the window, at the bar, or seated in the free seat) and presses E on "Начать" at the table. That is just the diegetic act of pulling out his chair. NPCs arrive in invite order and walk to their card seats; anyone uncarded stands.

### Phase B: Live (2–4 min)

**Positional addressing.** The hero's lines go to the NPC he is facing and is nearest to (a highlight ring under the addressee while chips are up). Everyone within hearing radius hears it, which is the AUDIENCE element. Moving around the table changes the addressee and the angle of READ.

**Bait options** (chip availability is gated by knowledge; see DIALOGUE_AND_TRAPS):

| Bait | Addressee | Requires | Outcome |
|---|---|---|---|
| MAIN «Скажи ей наконец, зачем ты семь лет заставлял её верить, что за рулём была она.» | Adrian, with Mara AND Daniel in hearing | F_MARA_BELIEVED_SHE_DROVE + F_ADRIAN_THINKS_MARA_FORGOT | Success path (TR_FINAL_MAIN) |
| DIRECT «Это ты сказал ей, что она была за рулём.» | Daniel | F_DANIEL_TOLD_MARA | Daniel denies calmly. Adrian defends him («Дэниел двадцать лет…»). Pressure phase. |
| CARD BAIT (silent) | — | card on the table | Stay silent for 8 s. Daniel's hand drifts toward the card (O_DANIEL_HAND_CARD). Calling it out («Не трогай.») raises pressure. |
| PHOTO | Adrian | ITEM_PHOTO_DANIEL_307 | «Ваш человек обыскивал её номер, пока вы платили мне за поиски.» Adrian doubts Daniel; a cheap pressure +1 on Daniel. |
| WRONG «Адриан, ты заплатил Дэниелу, чтобы он…» | Adrian | — | Adrian is offended and Daniel relaxes (the misread consequence). Recoverable via MAIN or DIRECT. |

**TR_FINAL_MAIN beat:**

> Adrian (genuine): «Что?» (pause) «Она никогда не думала, что была за рулём.»
> Mara turns to Daniel.

Daniel tells (READ, 6 s window, slowed): O_DANIEL_EXIT_GLANCE «смотрит на выход», O_DANIEL_PHONE «берёт телефон», O_DANIEL_AVOIDS_ADRIAN «перестал смотреть на Адриана», O_DANIEL_WEIGHT_SHIFT «перенёс вес — готов идти».

Player options (chips plus physical moves):

- PROVOKE «Расскажи им про больницу.» (requires F_DANIEL_TOLD_MARA)
- BLOCK EXIT: physically walk to the exit Daniel glanced at. If the hero is between Daniel and the exit, Daniel's flee check fails.
- CALL OUT «Ты смотришь на дверь, Дэниел.» (requires O_DANIEL_EXIT_GLANCE noticed)
- SILENCE: let Mara speak. She says «Ты сидел у моей кровати.» This is the strongest line if `mara.trust ≥ 1`.

**Daniel resolution** (pressure model, see STATE_MODEL):

- Pressure ≥ threshold: **CONFESSION**.
  > «Она бы заговорила. Рано или поздно. Вина — единственное, что держит человека молча. Я защищал эту семью. Вас обоих.»

  This gives F_DANIEL_CONFESSED (recorded if the recording phone is placed).
- Exit open and not blocked when his flee check fires: **FLIGHT.** Daniel moves toward the exit, grabbing the card if it's on the table and on his path. This is a quick physical beat: the hero can vault the table (Space at the table edge), slam the swing door (if it's adjacent) or trip him with a chair (E on the chair in his path). Stopped leads to CONFESSION (cornered). Not stopped means Daniel escapes. Escaped with the card means Mara has a backup copy («У меня копия в облаке.»), so the endings still work, but Ending A changes text and Daniel's escape is noted in the epilogue.
- Brody and Sato inside (doors unlocked plus the "Мара здесь" invite): they step in on Daniel's signal. Thomas stands up and blocks them (his trust ≥ 0) or Adrian orders them out («Вон.»), but only if Adrian already doubts Daniel. Otherwise there is a brief standoff that ends with Adrian ordering everyone to stay.

### Phase C: The decision (physical)

After confession or flight resolution, the card is on the table, or in Daniel's dropped hand, or in the hero's pocket. The hero picks it up (it is always recoverable: Daniel drops it in any struggle). No prompt appears. People react to where the hero walks:

| Ending | Action | Notes |
|---|---|---|
| A | Walk to Mara and offer (E) | She leaves for her 08:00 meeting. |
| B | Walk to Thomas and offer | Requires Thomas present. He looks at it a long time and pockets it. Epilogue ambiguity. |
| C | Walk to the bar sink (water, E) or the kitchen burner (E: ignite, then E: drop) | Mara: «Ты такой же, как они.» Thomas exhales. Adrian closes his eyes. |
| D | Requires `adrian.trust ≥ 0`, `adrian.fear_hits.LOSE_MARA ≥ 2` and Daniel resolved. The chip appears near Adrian: «Если она расскажет — ты потеряешь имя.» (pause) «Если не расскажешь ты — потеряешь её.» Then hold out the phone (E on Adrian with the phone item). | Adrian takes it, calls his lawyer and starts speaking. The card goes on the table between him and Mara; Mara doesn't take it. |

**Walking out with the card** (main doors) is not an ending. Whoever is closest blocks the door gently: Mara «Не с этим.» or Thomas. This avoids a non-designed fifth ending while respecting the physical choice.

**Camera:** staging uses a wide master (overhead three-quarter, FOV 60) to read the layout. The live phase uses a table rig that orbits ±25° toward the hero's position, so the faces he can see are the faces the camera favours. The confession gets a slow push (≤ 12 s).

**Audio:** dawn birds faintly start in Phase C. The rain has stopped (a world state since the end of Scene 08). Music: `FINALE_STAGING` (minimal clock-like pulse), `FINALE_LIVE` (strings, ducking under dialogue), then silence at the decision. Music stops when the hero picks up the card; only footsteps remain.

---

## EPILOGUE

About 60 s and controllable. The hero exits through the lobby onto the street. The rain has ended and puddles reflect. The player walks for at least 8 s. The phone rings (an unknown number); answering is E (it auto-answers after 6 s).

> Голос: «Это вы тот человек, который решил проблему семьи Вейл?»
> Герой: «Зависит от того, кто спрашивает.»
> Голос: «У меня немного странная проблема.»
> Герой (смотрит на часы): «Насколько странная?»

CUT TO BLACK. «EPISODE 01 COMPLETE».

Ending-variant ambient details on the street:

- A: a news van parks.
- B: a grey Volvo passes slowly.
- C: nothing; Nico's voice from the bar door: «Береги себя.»
- D: Adrian's car with a lawyer getting in.
- Daniel escaped: a black car pulls away.

---

## Emotional rhythm (summary; detail in IMPLEMENTATION_PLAN pacing checks)

| Time | Scene | Dominant activity | Feeling |
|---|---|---|---|
| 0–4 | S01 | observe, position, bluff | curiosity → confidence |
| 4–7 | S02 | walk-and-talk, READ a client | suspicion |
| 7–13 | S03 | sandbox investigation, interruption | discovery |
| 13–22 | S04/05 | freedom, tailing, stealth, social provocation | freedom → tension |
| 22–26 | S06 | stop a man, pull a confession out in fragments | reversal |
| 26–31 | S07 | chase, improvisation | adrenaline |
| 31–34 | S08 | defuse, watch, listen | emotional reveal |
| 34–40 | S09 | stage, provoke, decide | control → moral uncertainty |
| 40–41 | Epilogue | walk | aftermath |
