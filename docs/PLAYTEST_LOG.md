# PLAYTEST LOG

Status legend: ✅ verified by Claude (automated screenshot/sim) · 👤 needs human playtest.

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
