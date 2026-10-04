# PLAYTEST LOG

Status legend: ✅ verified by Claude (automated SIM / headless boot / screenshot) · 👤 needs human playtest.
Build under test: `main` (see `git log -1`). Every scene boots headless without errors (`-- --scene S01 … EPI`).
Each item below takes < 2 minutes. Use F2 (scene jump) to get there, F1 to watch state.

## Global
- AT-PLAY-01 ✅/👤 New game (`godot --path .`): the hero sits at stool 3; any movement key stands him up at once; the title is drawn on the rainy window. No fade lockout.
- AT-PLAY-02 👤 Walk/fast(Caps)/run(Shift)/crouch(Ctrl)/slide(Shift+Ctrl)/vault(Space at a yellow-striped box — laundry table, kitchen islands, finale table)/ramps (service stair)/doors (walk into arches, E on doors). Hold a direction through a camera change (bar ↔ lobby arch, 307 ↔ bathroom): the direction must not flip until you release the key.
- AT-ROB-01 ✅ (SIM save/load round-trip) / 👤 F6 at a scene start, F7 to reload: F1 dump identical.
- AT-ROB-02 👤 F2 → each scene id → Enter: the scene starts with seeded state.
- AT-ROB-03 👤 Walk away mid-chip from any exchange (it ends cleanly); stand in an NPC's path (they pause ≤ 2.5 s, say «Позвольте.» and pass).

## S01 — The watch (logic ✅ test_s01)
- AT-PLAY-03 👤 four runs: (1) stand next to Hale with Selin close, chip «Камеры?» → PUBLIC; (2) wait until Hale goes to the WC corridor (≈70 s), follow, «Камеры?» → aside → «Выкупи тихо» → «Извинись перед ним» → PRIVATE; (3) Kai: «Это ты» → WRONG; (4) only READ for 4:30 → Jules breaks → OBSERVE_ONLY. Each ends with a 6 s Adrian two-shot.
- READ check: hold F/RMB, aim at Hale's left wrist from his left side, at Jules's head when Hale shouts about the watch, at the dome camera above the bar.

## S02 — The client (logic ✅ test_s02_s03)
- AT-PLAY-04 👤 Follow Adrian through the lobby (he waits if you lag > 6.5 m). Chips appear while walking. In the elevator (≈30 s, floor indicator ticks) try SILENCE (deep line if trust ≥ 1), «Вы мне врёте», «Вдвое больше», «Она звонила мне» (grab). Doors open on 3 with the keycard.

## S03 — Room 307 (logic ✅ test_s02_s03)
- AT-PLAY-05 👤 ≥ 12 interactions (glasses, bottle, slip, shower valve, towels, charger, phone under bed, two shoes, window close/lean, pills, mattress, bag, curtain, TV + map photo, 308 tag/lighter/coffee).
- AT-PLAY-06 👤 Pick up the wet shoe before checking the sill/leaning out → the wrong thread «ОНА УШЛА ЧЕРЕЗ ОКНО» is offered. Captions never conclude.
- AT-PLAY-07 👤 After 5 interactions Lina enters and works (desk → bin → bathroom → bed); follow her while talking; if you never looked at the glasses and don't say «Оставь», she takes them.
- Exit to the hall: Daniel walks toward you and talks; the hub opens when he leaves.

## S04/S05 — Hub (logic ✅ test_s04_hub)
- AT-PLAY-08 👤 Do the leads in any order: Nico (bar; help pour or join his smoke break for warmth), Eva (roof → follow her down the stairs), security (behind the reception desk).
- AT-PLAY-09 👤 Eva: «615» → slip. With suspicion ≥ 2 (e.g. after «Где Лукас?» twice) she calls it and leaves; the hub still works.
- AT-PLAY-10 👤 Tail Eva down the service stair (crouch behind railings); at landing 1 stand within 5 m unseen → her call. Let her see you → «Ты за мной ходишь?».
- AT-PLAY-11 👤 Security: catch the door as Pavel passes (3 s), house phone in the bar («На третьем драка»), Lina's cart, staff door with a keycard (Lina ALLY or the laundry hook, hold E), peek the code from the planter with READ (two entries) or from ≤ 3 m. Get seen twice → Daniel escort.
- AT-PLAY-12 👤 In the security room: E on the chair; W/S cameras, A/D scrub, 1–5 timestamps; at HALL 3F 01:10 open the phone (Tab) → «Сфотографировать монитор». Radio cues at T-20 / T-8.

## S06 — Thomas (👤 needs human playtest; logic ✅ by SIM test_s06_thomas)
- AT-PLAY-13: `godot --path . -- --scene S06`. Thomas walks from the laundry door to the Volvo.
  1. Walk into his path twice (he sidesteps once, then stops: «Отойди.»).
  2. Or wait until he is within 7 m and press the chip «Мара.» / «Полиция едет» / «Дэниел знает» / «Томас.» (if known).
  3. Or grab the keys on the dock edge while he unlocks (E on the gold key, 4 s window).
  4. Then stay silent: every ~6 s he says the next fragment by himself; the van CINE (8 s) follows «От справедливости.».
  5. Let him reach the car without stopping him: the van blocks him and the short version plays.

## S07 — Chase (👤 needs human playtest; logic ✅ by SIM test_s07_chase + unit test_chase_pursuer)
- AT-PLAY-14 routes from the dock (`-- --scene S07`):
  A: laundry → kitchen → cold storage → staff corridor → service stair (landing 2 door) → banquet corridor.
  B: laundry → service corridor → freight elevator (press 2) → banquet corridor.
  C: dock → kitchen (side yard door) → restaurant → lobby (walk: pursuers walk too) → guest stair → mezzanine → banquet corridor.
- AT-PLAY-15: let Brody grab you twice (don't tap Space) → cold-storage interrogation → choose «Запись у Адриана» → Space on the crates → run.
- AT-PLAY-16: freezer (drop the tray inside, step out, E «Захлопнуть» while a pursuer is inside), breaker (staff corridor), radio (pick on bench, Space near a pursuer), elevator decoy (service corridor panel «Отправить пустым»).

## S08 — Mara (logic ✅ test_s08_s09)
- AT-PLAY-17 👤 Walk around the table: Mara keeps it between you. Stay still → she lowers the extinguisher. E on the laptop → play/pause, A/D scrub; READ the ring and the back seat on the footage. Thomas enters through the service door after her story.

## S09 — Finale (logic ✅ test_s08_s09, test_zz_full_episode)
- AT-PLAY-18 👤 Carry place cards (E at the bar stack → E on a seat), hide the recorder (vase/basket/shelf), card on the table/bar, kitchen door open/closed/jammed, keys behind the bar → lock main doors / unlock terrace, lights. Invite via Tab. «Отодвинуть стул · Начать».
- AT-PLAY-19 👤 While chips are up, a ring marks the addressee: turn/move to change it. «Скажи ей наконец» to Daniel ≠ to Adrian.
- AT-PLAY-20 👤 MAIN to Adrian with Mara + Daniel close → «Что? …» → READ Daniel's 4 tells (≈6 s).
- AT-PLAY-21 👤 Stand in the door he looked at → cornered → confession. Or let him run: chair (Space), slam the kitchen door, or catch him; otherwise he escapes (Mara: «У меня копия»).
- AT-PLAY-22 👤 Pick up the card; walk to Mara / Thomas (E), the bar sink or the kitchen burner; Ending D: approach Adrian (needs trust ≥ 0, 2 fear hits) → chip → E with the phone. Main doors block you with the card.
- AT-PLAY-23 👤 Epilogue: walk the street (ending detail on screen), answer the phone (E), cut to black.

## Pacing (telemetry F4)
- AT-PACE-01/02 👤 Play a full run with F4 open; record the "gaps ≤ 60 s" % and control %. AT-PACE-03 ✅ (CINE ≤ 15 s is validated + asserted). AT-PACE-04/05 👤.
