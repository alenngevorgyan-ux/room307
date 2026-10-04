# EP01 — DIALOGUE BEATS, BLUFFS & SOCIAL TRAPS

Only necessary lines are written here. They are the anchor lines; the remaining barks (reactions, idle chatter) are written during implementation in the same tone, max 12 words each.

## 0. Writing rules

1. An NPC line is ≤ 20 words; ≤ 12 is preferred. A hero line is ≤ 8 words.
2. Chip labels are ≤ 4 words and show the *intent*, not the full line («Камеры?», «Залог?», «615», «Молчать»).
3. No exchange has more than 2 chip windows in a row without a movement or action beat between.
4. Every line has a speaker position in the world (a bark bubble near their head plus a bottom subtitle).
5. Exposition is split across characters. No character explains the plot.
6. Silence is written: what an NPC says or does if the player says nothing (`silence` node).

Verb icons on chips: PRESS ▲, DEFLECT ↺, BLUFF ◆, PROVOKE ✶, CALM ○, RELEASE →, SILENCE (no chip: wait), LEAVE (walk away).

---

## 1. Anchor lines by scene

### S01 — THE WATCH

| ID | Speaker | Line |
|---|---|---|
| HALE_01 | Hale | «Часы за сорок тысяч. Были на руке. Теперь их нет. А он стоял рядом.» |
| KAI_01 | Kai | «Обыщите меня. Давайте. Я никуда не ухожу.» |
| SELIN_01 | Selin | «Гриша, поехали. Пожалуйста.» |
| JULES_01 | Jules | «Господа, давайте без полиции, а?» |
| H_CAMERAS ◆✶ | Hero → Hale | «Тогда вызываем полицию. Они посмотрят камеры за последние два часа.» |
| HALE_CAM_REACT | Hale (grabs arm) | «Подожди. Не надо полиции. Не надо… разберёмся.» |
| H_PAWN ▲ | Hero → Jules | «Он ведь оставил их тебе?» |
| JULES_BREAK | Jules | «…В залог. Он не мог оплатить. Я не хотел…» |
| H_PRIVATE ○ | Hero → Hale (alone) | «Выкупи их тихо. И я ничего не видел.» |
| HALE_PRIVATE | Hale | «…Сколько ты хочешь?» / Hero: «Чтобы ты извинился перед парнем.» |
| ADRIAN_S1_* | Adrian | per resolution (see GAMEPLAY_SPEC) |

### S02 — THE CLIENT

| ID | Speaker | Line |
|---|---|---|
| ADR_01 | Adrian | «Мне сказали, вы умеете находить людей.» |
| H_01 | Hero | «Вам соврали.» … «Но продолжайте.» |
| ADR_BRIEF_1 | Adrian (walking) | «Моя дочь. Мара. Двадцать четыре. Её номер — триста седьмой. Её там нет.» |
| ADR_BRIEF_2 | Adrian | «Её бывший. Лукас. Он шантажирует семью. Полиция исключена.» |
| H_DANGER ▲ | Hero | «Она в опасности?» → ADR: «Найдите её.» (flat, O_S2_FLAT_ON_DANGER) |
| H_TOOK ▲ | Hero | «Что она взяла с собой?» → ADR: «Сумку. Телефон. Не знаю.» (pocket touch) |
| H_NOT_FROM_EX ✶ | Hero | «Если она прячется — то не от бывшего.» (fear hit LOSE_MARA) → ADR: «…Найдите её.» |
| H_CALL_LIE ✶ | Hero (elevator) | «Вы мне врёте.» → ADR: «Я вам плачу. Это лучше, чем правда.» |
| H_PRICE ◆ | Hero | «Тогда это стоит вдвое больше.» → ADR: «Втрое. Если до утра.» |
| H_CALLED ◆ | Hero | «Она звонила мне час назад.» → ADR (grabs): «Что она сказала?» |
| ADR_DEEP | Adrian | «Была старая история. Авария. Ей было семнадцать, она спала сзади. Она ничего не помнит. Слава богу.» |
| ADR_KEY | Adrian | «Триста седьмой. Дальше — вы.» |

### S03 — ROOM 307

| ID | Speaker | Line |
|---|---|---|
| LINA_01 | Lina | «Ой. Простите, мне сказали, номер свободен.» |
| LINA_LEFT | Lina | «Она сама попросила полотенца, в полдвенадцатого. Потом ушла. Спокойная была.» |
| LINA_SEC | Lina | «Потом заходил один… из охраны. Не наш. В дорогом костюме.» |
| LINA_STAIR | Lina | «Спрашивала, где служебная лестница. Я показала. Это плохо?» |
| LINA_CALLED | Lina | «Я всех наших знаю. Вы не наш.» (backs to the door) |
| H_RELEASE → | Hero | «Иди. Я тебя не видел.» → LINA: «…Спасибо.» |
| DAN_01 | Daniel | «Вы, должно быть, наш новый друг. Дэниел. Безопасность мистера Вейла. Нашли что-нибудь?» |
| H_ZIP ✶ | Hero | «Ваши люди плохо застёгивают сумки.» |
| DAN_ZIP | Daniel (smiles) | «Внимательный. Это хорошо. Внимательные долго живут — если не мешают.» |
| DAN_PAST | Daniel | «Мы не встречались? Монако, девятнадцатый год?» / Hero: «Я бы запомнил.» |

### S04 — HUB

| ID | Speaker | Line |
|---|---|---|
| NICO_01 | Nico | «Господи. Только не ты.» / Hero: «Я тоже рад тебя видеть.» |
| NICO_MAN | Nico | «Седой. Пил чай. Руки держал как водитель — на десяти и двух, даже на столе.» |
| NICO_CAMS | Nico | «Спрашивала, где камеры. Два раза.» |
| NICO_DANIEL | Nico | «Потом пришёл этот ваш Дэниел. Те же вопросы. Только про неё.» |
| NICO_VOLVO | Nico | «Седой спрашивал служебный выезд. У погрузки стоит старое Volvo. Не наше.» |
| NICO_PRAGUE | Nico | «После истории в Праге я думал, ты больше никогда…» / Hero: «Не сегодня, Нико.» |
| NICO_BAR | Nico | «Положи. Мой бар.» |
| EVA_01 | Eva | «Нет. Я её не видела. Я здесь вообще случайно. Пусти.» |
| H_615 ◆ | Hero | «Мара позвонила мне из 615.» |
| EVA_SLIP | Eva | «Она вообще не была на шестом…» (stops) |
| EVA_SLIP_AFTER | Eva | «…Ты кто вообще? Отстань от неё.» |
| EVA_CALLED | Eva (laughs) | «Мара? Тебе? Она даже отцу не звонит.» |
| EVA_CALL | Eva (burner, overheard) | «Томас ещё здесь? …У прачечной. Скажи ему, пусть уезжает. …Нет, она в порядке.» |
| EVA_TAILED | Eva | «Ты за мной ходишь?» |
| H_HONEST ○ | Hero | «Её отец заплатил мне. На твоём месте я бы тоже её прятал.» |
| EVA_HONEST | Eva | «…Поговори с Томасом. Он у прачечной. И не смей её трогать.» |
| PHONE307_TXT | Eva (SMS on Mara's 2nd phone) | «Т. у прачечной. Уходи через кухню, если что.» |
| ADR_CALL | Adrian (phone, overheard) | «Она ничего не помнит, Дэниел. Ничего. Найди карту — и всё.» |
| DAN_BRODY | Daniel (overheard) | «Если не найдём до семи — она сама всё выложит.» |
| PAVEL_STOP | Pavel | «Сюда нельзя. Пройдёмте.» |
| DAN_ESCORT | Daniel | «Мистер Вейл платит вам за дочь. Не за наши записи.» |
| LINA_FB | Lina | «Тот пожилой… он сидит в машине у погрузки уже час.» |

### S06 — THOMAS

| ID | Line |
|---|---|
| TH_01 | «Мне нечего тебе сказать.» |
| TH_SILENCE | (after 5 s of silence) «…Ты от него, да? От Вейла.» |
| TH_BLAME | «Семь лет назад. Авария. Человек погиб. Я сидел полтора года.» |
| TH_NOTME | «За рулём был не я.» |
| TH_SON | «Деньги Вейла вытащили моего сына. Я согласился сам. Слышишь? Сам.» |
| TH_CARD | «У неё запись. С камеры в машине. Я сам её поставил. Идиот.» |
| TH_FORGOT | «Адриан думает, она ничего не помнит. Она спала. Он так и сказал Дэниелу: пусть спит дальше.» |
| TH_STOP | «Останови её.» / Hero: «От чего?» / «От справедливости.» |
| TH_GO | «Уходи. Они не за мной.» |
| TH_POLICE | «Полиция? Тогда мне нечего терять.» |
| TH_CARDSHARK | «У тебя руки картёжника.» |

### S08 — MARA

| ID | Line |
|---|---|
| MARA_01 | «Ещё шаг — и я проверю, крепкая ли у тебя голова.» |
| MARA_CLIP | «Смотри.» |
| MARA_DROVE | «Семь лет я думала, что это я. Что я убила его.» |
| MARA_DANIEL | «Дэниел сказал мне. В больнице. "Твой отец спас тебя."» |
| MARA_8AM | «В восемь у меня встреча с журналистом. Я всё расскажу.» |
| TH_TO_MARA | «Адриан никогда не просил внушать тебе это. Он думал, ты не помнишь. Это был Дэниел.» |
| MARA_TH | «Ты сидел полтора года за него. И теперь просишь меня молчать?» |
| H_HOUR ○ | Hero: «Дай мне час. Я хочу, чтобы они сказали это сами.» |
| MARA_HOUR | «Час. И я хочу видеть его лицо.» |

### S09 — FINALE

| ID | Line |
|---|---|
| MAIN ✶ | Hero → Adrian: «Скажи ей наконец, зачем ты семь лет заставлял её верить, что за рулём была она.» |
| ADR_WHAT | Adrian: «Что?» … «Она никогда не думала, что была за рулём.» |
| MARA_LOOK | Mara (turning to Daniel): «…Дэниел?» |
| H_HOSPITAL ✶ | Hero → Daniel: «Расскажи им про больницу.» |
| H_DOOR ✶ | Hero → Daniel: «Ты смотришь на дверь, Дэниел.» |
| MARA_BED | Mara: «Ты сидел у моей кровати. Ты держал меня за руку.» |
| DAN_CONFESS | Daniel: «Она бы заговорила. Рано или поздно. Вина — единственное, что держит человека молча. Я защищал эту семью. Вас обоих.» |
| ADR_TO_DAN | Adrian: «Двадцать лет…» (doesn't finish) |
| DIRECT ✶ | Hero → Daniel: «Это ты сказал ей, что она была за рулём.» |
| DAN_DENY | Daniel: «Мистер Вейл, этот человек играет с вами с первой минуты.» |
| ADR_DEFEND | Adrian: «Дэниел двадцать лет со мной.» |
| H_CARD | Hero (Daniel reaches): «Не трогай.» |
| PHOTO | Hero → Adrian: «Ваш человек обыскивал её номер, пока вы платили мне за поиски.» |
| WRONG | Hero → Adrian: «Ты заплатил Дэниелу, чтобы он…» → ADR: «Вы забываетесь.» |
| D_1 | Hero → Adrian: «Если она расскажет — ты потеряешь имя.» |
| D_2 | (pause) «Если не расскажешь ты — потеряешь её.» |
| D_ADR | Adrian (takes the phone): «…Марк. Это Адриан. Записывай. Семь лет назад…» |
| A_MARA | Mara (takes the card): «Спасибо.» (leaves without looking back) |
| B_THOMAS | Thomas (long look): «…Ты отдал это не тому человеку. Или как раз тому.» |
| C_MARA | Mara: «Ты такой же, как они.» |
| BLOCK_DOOR | Mara/Thomas: «Не с этим.» |

### EPILOGUE

| Line |
|---|
| «Это вы тот человек, который решил проблему семьи Вейл?» |
| «Зависит от того, кто спрашивает.» |
| «У меня немного странная проблема.» |
| «Насколько странная?» |

---

## 2. Bluff catalogue

| Claim | Target(s) | True? | Contradicting knowledge (→ CALLED) | Fear touched | Typical outcome |
|---|---|---|---|---|---|
| C_CAMERAS_RECORDED «Камеры всё записали» | Hale, Jules, Daniel | Hale: false (dome dead); Daniel: true only with the photo | Jules knows the dome is dead → CALLED by Jules only | Hale EXPOSED, Daniel ADRIAN_LEARNS_TRUTH | Hale panics; Daniel TELL (phone) |
| C_HALE_LOST_MONEY «Он сказал, что проигрался» | Selin | false | — | — | SLIP: «Опять?!» (if tab/wallet known), else DEFLECT |
| C_MARA_CALLED_ME «Она звонила мне» | Adrian | false | — | LOSE_MARA, LOSES_NAME | grab tell |
| C_HOTEL_SECURITY «Я из охраны» | Lina, Pavel | false | Lina, Pavel know the staff → CALLED (unless the keycard is shown to Lina) | — | — |
| C_MARA_CALLED_FROM_615 | Eva | false | — | MARA_FOUND | SLIP |
| C_MARA_SAID_YOU_HIDE_HER | Eva | false | Eva knows Mara wouldn't → CALLED | — | mara_wary |
| C_ADRIAN_SENT_ME (to Nico) | Nico | false | Nico knows Adrian never talks to staff → CALLED | — | warmth −1, one pity fact |
| C_POLICE_COMING | Thomas, Pavel | false | — | Thomas SACRIFICE_WASTED | Thomas talks, but cold |
| C_DANIEL_KNOWS_YOU_HERE | Thomas | true-ish | — | DANIEL | Thomas fast-talks |
| C_DANIEL_SAID_STOP «Дэниел сказал прекратить. Проверь телефон.» | Sato, Brody (chase) | false | Brody: savvy 0, never calls; Sato: calls if `daniel_knows_hero_met_thomas` AND heat ≥ 3 | — | DOUBT window |
| C_EVA_TOLD_ME | Mara | false | Mara (if wary) → CALLED | TAKEN | — |
| C_DANIEL_FOOTAGE (finale) «Камера всё записала, Дэниел.» | Daniel | true with the photo | — | ADRIAN_LEARNS_TRUTH | pressure +1 |

---

## 3. Social traps (each is a TrapDefinition JSON)

Format: **Target / Bait / Environment / Audience / Object / Timing → Outcomes**.

### TR_S1_CAMERAS
- Target: Hale. Bait: C_CAMERAS_RECORDED. Env: BAR. Audience: anyone. Object: — . Timing: S01.
- Outcomes: if Selin is in hearing, Hale's panic is seen by Selin, giving PUBLIC_EXPOSE. Else Hale pulls the hero aside, giving the PRIVATE window (the H_PRIVATE chip appears).

### TR_S1_PAWN_PUBLIC / TR_S1_PAWN_PRIVATE
- Target: Jules / Hale. Bait: the pawn line. Audience decides: Selin in hearing → PUBLIC, Selin absent → PRIVATE.
- Teaches: **audience is a variable you control by moving**.

### TR_S2_MARA_CALLED
- Target: Adrian. Bait: C_MARA_CALLED_ME. Env: elevator (confined, no escape for him). → grab, F_ADRIAN_EXPECTS_CONTACT, thread.

### TR_S03_ZIP
- Target: Daniel. Bait: the zip provoke. Requires O_307_ZIP_WRONG. → Daniel's suspicion +2 and shadow mode. A **deliberately double-edged** trap: more tells to READ, harder stealth.

### TR_LINA_KEYCARD
- Target: Lina. Bait: C_HOTEL_SECURITY. Object: Adrian's keycard shown (E while holding it). With the object → accepted ("guest of Mr. Vale"). Without it → CALLED.

### TR_EVA_615
- See STATE_MODEL §8. Env: service stair or roof. Audience: Daniel must not be present (if Daniel is passing on his loop, Eva clams up: DEFLECT). → SLIP.

### TR_EVA_308 (evidence, not bluff)
- Bait: «Ты живёшь в 308.» Requires F_EVA_ROOM_308. → CAUGHT without suspicion cost.

### TR_PAVEL_FAKE_FIGHT
- Target: Pavel. Bait: house phone call «На третьем драка». Env: BAR phone. Timing: Pavel at the monitors. → Pavel leaves for F3 for 90 s. A second use within 5 min: Pavel ignores it ("опять?"), so the player needs another approach.

### TR_PHOTO_TO_ADRIAN
- Target: Adrian. Object: ITEM_PHOTO_DANIEL_307 (phone shown). Env: hub lobby (Daniel *not* present) or finale (Daniel present).
- Hub → `adrian.doubts_daniel`, and an observable Adrian–Daniel argument at the elevator (min +1).
- Finale with Daniel present → Daniel pressure +1, Adrian turns to Daniel.

### TR_THOMAS_DANIEL
- Target: Thomas. Bait: C_DANIEL_KNOWS_YOU_HERE. → Thomas stops and talks faster (fragments 2–6 come with 30% shorter gaps), `thomas.fear_daniel`.

### TR_CHASE_RADIO
- Target: the nearest pursuer. Bait: C_DANIEL_SAID_STOP (spoken while holding the dropped radio, or shouted). → DOUBT window 2 s (Brody) or 3 s (Sato), or CALLED. See ACTION_SEQUENCE.

### TR_CHASE_CAR_ALARM
- Object: ITEM_VOLVO_KEYS. Use (press) during the dock or laundry chase → the car alarm sounds; the pursuers check the yard for 4 s.

### TR_FINAL_MAIN (signature trap)
- Target: Daniel, *through* Adrian. Bait: the MAIN line addressed to Adrian. Required audience: Mara AND Daniel within hearing (same table zone). Requires T_TWO_STORIES.
- Env modifiers: the doors (escape), the lights (tell readability), the recorder (proof).
- Object modifiers: card on the table (grab temptation), photo.
- Outcomes:
  1. Audience complete: ADR_WHAT → MARA_LOOK → the Daniel tells window → pressure phase.
  2. Mara not in hearing (e.g. seated at the far end with the kitchen door open and noise, or standing outside): Adrian answers, but Mara doesn't hear. Daniel immediately cuts in: «Мистер Вейл, давайте не здесь.» Daniel's stress +1, and the bait is consumed. The player can **move Mara** (E on Mara: «Сядь сюда.») and retry with DIRECT or a re-phrased MAIN («Повтори это при ней.»). Fail-forward.
  3. Daniel not in hearing: Adrian and Mara have the moment; Mara says «Дэниел говорил…». Daniel enters on cue (he was hovering by the door) and the pressure phase begins at pressure 1 instead of 2.

### TR_FINAL_DIRECT
- Target: Daniel. Bait: DIRECT. → DAN_DENY + ADR_DEFEND. Pressure is set to 1. To push further the hero needs PROVOKE hospital, MARA_BED (Silence), the photo or the card bait.

### TR_FINAL_CARD_BAIT
- Object: the card on the table. Bait: hero SILENCE ≥ 8 s during the live phase. → Daniel's hand drifts (O_DANIEL_HAND_CARD). If the hero says «Не трогай.» → pressure +1 and Adrian notices (`doubts_daniel`).

### TR_FINAL_RECORD
- Passive: the recorder's position determines `ending.recorded`. With a clear recording plus Ending A, the epilogue news van line references «аудио». Ending D with a clear recording → Adrian's lawyer also takes the phone.

---

## 4. Variation by state (cheap reactivity)

These are **line swaps**, not branches:

- Adrian's first line in S2 by `s1_resolution` (4 variants).
- Nico's greeting if S1 was PRIVATE_DEAL: «Жюль сказал, ты его спас. Не жди благодарности.»
- Daniel's first line if `T_SOMEONE_SEARCHED_307` is pinned: he glances at the hero's hands first (an extra tell).
- Thomas's opening if the police lie was used (cold variants).
- Mara's opener if `mara_wary`: «Ты тот, кто врал Эве.»
- Finale arrival barks by invite template («Вы сказали, она будет?» / «Что у вас?»).
- Epilogue street details by ending.
