# EP01 — STATE MODEL & DATA STRUCTURES

Design goals:

- Small. A designer should be able to read the whole runtime state on one debug screen.
- **Data lives in JSON** under `data/ep01/`. Code lives in `src/`. Writing scene content should mean editing JSON, not GDScript.
- IDs are `StringName`s with prefixes: `F_` fact, `O_` observation, `T_` thread, `TR_` trap, `C_` claim, `X_` exchange, `ITEM_` item, `BEAT_` world beat.
- No per-scene boolean soup. Facts, observations and flags are **sets**. Character state uses a handful of small ints and enums.

---

## 1. Autoloads

| Autoload | Role |
|---|---|
| `Episode` (`src/core/episode_state.gd`) | Owns all runtime state below. Has save/load to JSON (debug quick-save). |
| `Bus` (`src/core/event_bus.gd`) | Signals only. Every system talks through it. |
| `Data` (`src/core/data_db.gd`) | Loads and validates all JSON at boot. Fails loudly on missing IDs. |
| `Debug` (`src/core/debug_overlay.gd`) | F1 overlay (state), F2 scene jump, F3 fact grant, F4 pacing log. Debug builds only. |

### Bus signals (complete list for EP01)

```gdscript
signal fact_learned(fact_id: StringName, source: StringName)
signal observation_noticed(obs_id: StringName)
signal thread_offered(thread_id: StringName)
signal thread_pinned(thread_id: StringName)
signal claim_spoken(claim_id: StringName, speaker: StringName, addressee: StringName, audience: Array)
signal npc_reaction(npc_id: StringName, reaction: StringName)
signal exchange_started(exchange_id: StringName)
signal exchange_ended(exchange_id: StringName, outcome: StringName)
signal item_changed(item_id: StringName, holder: StringName)
signal stage_point_changed(point_id: StringName, value: StringName)
signal world_beat(beat_id: StringName)
signal player_detected(by_npc: StringName, severity: int)
signal player_decision(kind: StringName)   # pacing telemetry
signal ending_reached(ending_id: StringName)
```

---

## 2. EpisodeState

```gdscript
class_name EpisodeState
var phase: Phase                       # enum below
var scene_id: StringName               # "S01".."S09","EPI"
var beats: Dictionary = {}             # beat_id -> true (world beats that happened, e.g. BEAT_HUB_OPEN)
var facts: Dictionary = {}             # fact_id -> {source: StringName, t: float}
var observations: Dictionary = {}      # obs_id -> {t: float}
var threads_available: Array[StringName] = []
var threads_pinned: Array[StringName] = []   # max 3
var items: Dictionary = {}             # item_id -> holder ("hero", npc_id, "world:<point>")
var leads: Dictionary = {"A": LeadState.NONE, "B": LeadState.NONE, "C": LeadState.NONE}
var s1_resolution: StringName = &""    # PUBLIC_EXPOSE | PRIVATE_DEAL | WRONG_ACCUSE | OBSERVE_ONLY
var flags: Dictionary = {}             # small misc: window_closed, phone_307_charged, mara_wary, plan_finale ...
var characters: Dictionary = {}        # npc_id -> CharacterState
var threat: ThreatState
var trap_state: Dictionary = {}        # trap_id -> TrapRuntime
var finale: FinaleState
var ending: EndingState
var clock_sec: float                   # play time (telemetry, overhear loops)
```

```gdscript
enum Phase { S01_WATCH, S02_CLIENT, S03_ROOM, S04_HUB, S05_VIDEO, S06_THOMAS, S07_CHASE, S08_MARA, S09_STAGING, S09_LIVE, S09_DECISION, EPILOGUE, DONE }
enum LeadState { NONE, ACTIVE, DONE, FAILED_DONE }   # FAILED_DONE counts as done
```

`leads_completed()` returns the count of `DONE` plus `FAILED_DONE`.

---

## 3. CharacterState

One object per NPC. A dozen fields, no more.

```gdscript
class_name CharacterState
var id: StringName
var zone: StringName                 # current zone id
var activity: StringName             # schedule activity id, e.g. "polish_glass", "smoke", "follow_lead"
var schedule: StringName             # active schedule id
var disposition: Disposition         # CALM, GUARDED, PRESSURED, HOSTILE, OPEN, GONE
var stress: int = 0                  # 0..3
var trust: int = 0                   # -2..+2 (toward hero)
var respect: int = 0                 # -2..+2 (Adrian, Daniel use it; others ignore)
var suspicion: int = 0               # 0..3 (how much they think the hero is playing them)
var knows: Array[StringName]         # fact ids the NPC knows (static from data + runtime additions)
var believes_hero_knows: Array[StringName]
var fear_hits: Dictionary = {}       # fear_tag -> count (e.g. LOSE_MARA)
var caught_lying: bool = false       # hero caught THIS npc lying (slip/contradiction)
var caught_hero_lying: bool = false  # this npc called the hero's bluff at least once
var memory: Array[StringName] = []   # short-term notable events: "hero_ran_past", "hero_in_security"
```

**Disposition transitions** (generic; per-NPC overrides live in the character JSON):

```
CALM --(stress>=2 or PRESS hit)--> PRESSURED
PRESSURED --(fear hit with audience)--> OPEN   (slips, confessions)
PRESSURED --(bluff called / insulted)--> HOSTILE
any --(trust>=1 and stress<=1)--> CALM
HOSTILE --(leave radius 60s)--> GUARDED
any --(story exit)--> GONE
```

### Static character data (`data/ep01/characters.json`)

```json
{
  "daniel": {
    "display": "Дэниел",
    "savvy": 2,
    "fears": {"ADRIAN_LEARNS_TRUTH": 3, "MARA_PUBLISHES": 2, "LOSES_POSITION": 1},
    "feared_audience": ["adrian"],
    "knows": ["F_ADRIAN_WAS_DRIVING","F_DANIEL_TOLD_MARA","F_ADRIAN_THINKS_MARA_FORGOT","F_RECORDING_EXISTS","F_DANIEL_SEARCHED_307"],
    "start": {"trust": 0, "respect": 0, "suspicion": 0, "stress": 1, "disposition": "CALM"},
    "tells": {"stress2": ["O_DANIEL_PHONE_DOWN"], "exposed": ["O_DANIEL_EXIT_GLANCE","O_DANIEL_PHONE","O_DANIEL_AVOIDS_ADRIAN","O_DANIEL_WEIGHT_SHIFT"]}
  }
}
```

---

## 4. KnowledgeState (hero)

The hero's knowledge is `Episode.facts`, `Episode.observations` and `Episode.threads_*`. Facts are the only things that gate progression.

**Fact definition** (`data/ep01/facts.json`):

```json
{
  "F_THOMAS_LOCATION": {
    "text": "Седой ждёт у погрузки",
    "truth": true,
    "required": true,
    "sources": ["video_cam_service", "nico", "eva_call", "phone_307_text", "eva_confront", "fb_lina", "fb_pa"]
  }
}
```

`sources` is documentation and validator input; the actual grant happens in exchange, overhear and interactable data via `give_fact` actions. The validator (see ACCEPTANCE_TESTS) checks that every `sources` entry corresponds to at least one real grant site.

---

## 5. ObservationState & the READ system

**Observable** (`src/read/observable.gd`, attached as an `ObservablePoint` Node3D):

```gdscript
@export var obs_id: StringName
@export var caption_key: String          # RU caption via data
@export var mode: Mode                    # STATIC (always available) | TELL (time window)
@export var focus_radius: float = 0.35    # metres around point that counts as "focused"
@export var dwell: float = 0.4            # seconds of focus (real time) to notice
@export var max_distance: float = 6.0
@export var requires: Array[StringName]   # facts/obs that must exist first (rare)
var window_open := false                  # TELL: opened by animation event / script
```

**READ loop** (in `src/read/read_system.gd`):

1. Holding READ sets `Engine.time_scale = 0.6`, applies a low-pass to the "Ambience" audio bus, shows a vignette and makes the focus reticle visible.
2. The reticle is moved by mouse or right stick in screen space and is clamped to a 45% radius around the hero's head projection.
3. Each frame, for observables within `max_distance` that are on screen with clear line of sight and (for TELLs) `window_open`, compute the screen distance to the reticle. If it is within `focus_radius` (projected), accumulate dwell. At `dwell`, emit `observation_noticed`.
4. On notice, a caption is drawn in world space near the point (handwritten font, 2.5 s fade). There is no glow, ever. The only exception is the accessibility setting `READ_ASSIST`, which adds a faint shimmer to in-range observables.
5. READ has no resource meter. Its limit is that time slows only to 0.6 and the player must aim. Holding READ also halves movement speed, so you cannot READ and run.

**TELL windows:** NPC animation states call `open_tell(obs_id, duration)` on their observable child. In graybox this is driven from the exchange JSON (`"tell": {"obs": "O_S2_POCKET_TOUCH", "at": 0.8, "dur": 1.6}`). Durations are in real seconds, but READ slows them, which is the mechanical reward.

**Threads** (`data/ep01/threads.json`):

```json
{
  "T_307_STAGED": {
    "text": "НОМЕР 307 ПОСТАВЛЕН",
    "offer_when": {"any_n": 2, "of": ["O_307_GLASS_ONE_USED","O_307_TOWELS_DRY","O_307_SILL_DRY","O_307_SHOE_CLEAN","O_307_MSG_CONDENSATION"]},
    "truth": true,
    "unlocks_chips": ["CH_LINA_STAGED","CH_EVA_STAGED","CH_ADRIAN_STAGED"]
  },
  "T_SHE_LEFT_BY_WINDOW": {
    "text": "ОНА УШЛА ЧЕРЕЗ ОКНО",
    "offer_when": {"all": ["O_307_ONE_WET_SHOE","FLAG_WINDOW_SEEN_OPEN"], "none": ["O_307_SILL_DRY","O_307_NO_ESCAPE"]},
    "truth": false,
    "unlocks_chips": ["CH_ADRIAN_WINDOW"]
  }
}
```

An offered thread appears as a small line under the Threads HUD with the prompt `[Q] закрепить`. At most 3 can be pinned; pinning a fourth replaces the oldest after a confirmation tap. Pinned threads unlock chips. Wrong threads unlock wrong chips, which is how the player draws a wrong conclusion and gets consequences.

---

## 6. Relationship / Suspicion / Social resolution

Relationship and suspicion live in `CharacterState` (trust, respect, suspicion, stress, fear_hits). There is no separate store.

### Claims

**Claim** (`data/ep01/claims.json`): something the hero can assert.

```json
{
  "C_MARA_CALLED_FROM_615": {
    "text": "Мара позвонила мне из 615.",
    "verb": "BLUFF",
    "about": "F_MARA_LOCATION",
    "is_true": false,
    "fears": {"eva": "MARA_FOUND"},
    "requires": [],
    "available_to": ["eva"]
  },
  "C_CAMERAS_RECORDED": {
    "text": "Камеры всё записали.",
    "verb": "BLUFF",
    "about": "F_CAMERA_FOOTAGE",
    "is_true_if": "ITEM_PHOTO_DANIEL_307",
    "fears": {"hale": "EXPOSED", "daniel": "ADRIAN_LEARNS_TRUTH"},
    "available_to": ["hale","daniel","jules"]
  }
}
```

### Resolution algorithm

`SocialResolver.resolve(npc, claim, audience) -> Reaction`. It is deterministic and readable:

```
1. override = Data.reaction_override(npc.id, claim.id, context)  # authored special-cases first
   if override: return override
2. if claim is false AND npc.knows(contradicting fact):
       npc.caught_hero_lying = true; npc.suspicion += 1; npc.trust -= 1
       return CALLED
3. pressure  = claim.fear_weight_for(npc)       # 0..3 from npc.fears
            + npc.stress                         # 0..3
            + (1 if any feared_audience present) # audience matters
            + (1 if claim.about in npc.believes_hero_knows)  # "he already knows" compounding
            - npc.savvy                          # 0..2
            - (1 if npc.caught_hero_lying)
4. if pressure >= 4: reaction = SLIP      # involuntary truth (Eva "не была на шестом")
   elif pressure >= 2: reaction = TELL    # visible tell + guarded answer
   else: reaction = DEFLECT
5. side effects: npc.stress = min(3, npc.stress+1) on TELL/SLIP;
                 npc.believes_hero_knows.append(claim.about) unless CALLED;
                 fear_hits[fear] += 1
6. Bus.npc_reaction.emit(npc.id, reaction)
```

Each `(npc, reaction)` maps to an authored line set plus optional tells and fact grants in the exchange JSON. PRESS, PROVOKE and DEFLECT use the same pipeline with `is_true = true` claims (they are "statements" rather than lies). This gives designers one knob set for all social verbs.

**Stress decay:** `-1` every 45 s outside conversation (not below the NPC's start value).

### ThreatState (stealth & chase)

```gdscript
class_name ThreatState
var alert: Dictionary = {}     # npc_id -> Alert enum {UNAWARE, CURIOUS, SEARCHING, PURSUIT, STUNNED, DOUBT, CONTAINED}
var heat: int = 0              # 0..3 chase intensity (drives music & pursuer speed)
var grabs: int = 0             # times hero was grabbed this chase (2 → caught → interrogation)
var caught_count: Dictionary = {"pavel": 0}
var daniel_knows_hero_met_thomas: bool = false
```

---

## 7. Conversation (Exchange) model

Data: `data/ep01/exchanges/*.json`, one file per scene.

```json
{
  "X_S03_LINA": {
    "npc": "lina",
    "trigger": {"type": "npc_enters_radius", "radius": 4.0},
    "radius_leave": 6.0,
    "npc_keeps_schedule": true,
    "nodes": {
      "start": {"line": "LINA_01", "tell": null, "next": "chips1"},
      "chips1": {
        "timeout": 5.0,
        "chips": [
          {"id": "CH_LINA_CALM", "verb": "CALM", "label": "Я не из полиции", "claim": "C_NOT_POLICE", "next": "calm1"},
          {"id": "CH_LINA_SEC",  "verb": "BLUFF", "label": "Я из охраны", "claim": "C_HOTEL_SECURITY", "next_by_reaction": {"CALLED": "called", "*": "sec_ok"}},
          {"id": "CH_LINA_WHO",  "verb": "PRESS", "label": "Кто ещё заходил?", "next": "who"},
          {"id": "CH_LINA_GO",   "verb": "RELEASE", "label": "Иди", "next": "release"}
        ],
        "silence": "silence1",
        "leave": "end_leave"
      },
      "who": {"line": "LINA_WHO", "actions": [{"give_fact": "F_SECURITY_IN_307"}, {"stress": ["lina", 1]}], "next": "chips2"}
    }
  }
}
```

Runtime rules:

- Only **one exchange is active at a time**, but the hero can walk away (LEAVE branch). Other NPCs speak barks only.
- Chips render near the bottom centre as 2–4 compact pills with a verb icon. While chips are up, time runs normally; the hero can move and READ.
- `timeout` expiry follows `silence`. Leaving the radius for more than 1.5 s follows `leave`.
- A node may say `"repeat_lock": true`, after which this chip never reappears.
- **Rule:** no exchange may chain more than 2 chip nodes without an intervening line of at least 2 s or a movement beat. The validator checks this.
- Lines are `{speaker, text_key, dur}`, shown as subtitles plus a bark bubble near the speaker. No portraits.

---

## 8. TrapState

A trap is an **armed condition set** that waits for a **bait event**. Players never select a trap: they create the conditions.

```json
{
  "TR_EVA_615": {
    "target": "eva",
    "bait": {"event": "claim_spoken", "claim": "C_MARA_CALLED_FROM_615", "addressee": "eva"},
    "environment": {"zones": ["SERVICE_STAIR","ROOF_SMOKING"]},
    "audience": {"forbid": ["daniel"]},
    "object": null,
    "timing": {"after_beat": "BEAT_HUB_OPEN"},
    "outcomes": [
      {"if": {"npc_state": {"eva": {"suspicion_lt": 2}}},
       "do": [{"line": "EVA_SLIP_615"}, {"give_fact": "F_MARA_NOT_ON_6"}, {"give_fact": "F_EVA_KNOWS_WHERE"}, {"set_disposition": ["eva","PRESSURED"]}, {"lead": ["B","DONE"]}]},
      {"else": true,
       "do": [{"line": "EVA_CALLS_BLUFF"}, {"stress": ["eva",1]}, {"flag": "mara_wary"}]}
    ]
  }
}
```

```gdscript
class TrapRuntime:
  var armed: bool        # conditions currently satisfied (re-evaluated on relevant bus events)
  var fired: bool
  var outcome_index: int
```

**TrapDirector** subscribes to `claim_spoken`, `stage_point_changed`, `item_changed` and `world_beat`. On a bait event it looks up armed traps matching it, picks the first outcome whose `if` passes, and executes its `do` actions with the same action vocabulary as exchanges.

### Action vocabulary (shared by exchanges, traps, interactables)

`line`, `bark`, `give_fact`, `notice` (force an observation), `offer_thread`, `flag`, `unflag`, `trust [npc,±n]`, `respect`, `suspicion`, `stress`, `fear_hit [npc,tag]`, `set_disposition`, `set_schedule [npc,schedule]`, `give_item`, `take_item`, `lead [A|B|C, state]`, `beat`, `start_exchange`, `play_cine [id]` (≤ 15 s, validated), `camera_hint`, `music [state]`, `sfx`, `teleport_npc`, `spawn [npc,point]`, `goto_scene`.

These are about 25 verbs, implemented once in `src/core/action_runner.gd`.

---

## 9. FinaleState

```gdscript
class_name FinaleState
var seats: Dictionary = {"S1": &"", "S2": &"", "S3": &"", "S4": &""}   # npc ids
var standing: Array[StringName] = []
var recorder: StringName = &"none"     # vase | basket | shelf | none
var card_spot: StringName = &"pocket"  # table | pocket | bar
var doors: Dictionary = {"kitchen": &"open", "main": &"closed", "terrace": &"locked"}  # open|closed|jammed|locked
var lights: StringName = &"dim"        # dim | full
var invites: Array = []                # [{to, template, t}]
var started: bool = false
var daniel_pressure: int = 0
var daniel_state: StringName = &"seated"   # seated | wary | fleeing | cornered | confessed | escaped
var thugs_inside: bool = false
```

**Daniel flee/confess model:**

```
On TR_FINAL_MAIN success: daniel.stress = 3; pressure = 2
Each of: PROVOKE hospital line (+2), CALL OUT exit glance (+1), Mara SILENCE line (+2 if mara.trust>=1 else +1),
         photo shown earlier (+1), card bait noticed & called (+1), adrian.doubts_daniel (+1)
Each READ tell noticed during the 6s window: +0 (information only — tells guide the player's choice, not the score)
Flee check every 4 s after exposure: if not blocked AND nearest_exit_open_for_daniel AND pressure < 5 → FLEE
Confession when pressure >= 5, or when cornered (flee attempted but blocked/stopped).
Escaped when he reaches an open exit.
```

"Blocked" means the hero is within 1.2 m of the exit line Daniel picked, or the door is jammed or locked.

## 10. EndingState

```gdscript
class_name EndingState
var id: StringName = &""            # A_MARA | B_THOMAS | C_DESTROY | D_ADRIAN
var daniel_outcome: StringName      # confessed | escaped | exposed_silent
var recorded: StringName            # none | muffled | clear
var thomas_present: bool
var adrian_relationship: int        # trust + respect snapshot
var mara_trust: int
```

**Ending D gate** (single function, unit-tested):

```gdscript
func ending_d_available() -> bool:
    var a := Episode.characters.adrian
    return a.trust >= 0 and a.fear_hits.get(&"LOSE_MARA", 0) >= 2 \
        and Episode.finale.daniel_state in [&"confessed", &"escaped"] \
        and Episode.has_item(&"ITEM_HERO_PHONE")
```

The hero's phone is always held, unless confiscated during the chase interrogation (in which case Thomas returns it; see ACTION_SEQUENCE).

---

## 11. What is NOT tracked (deliberately)

- No per-line "seen" flags (exchanges use `repeat_lock` per chip instead).
- No time-of-day simulation (beat-driven schedules).
- No inventory UI. Items are few (keycard, Mara's phone, Volvo keys, photo, SD card, hero phone, staff keycard, cart). They are shown as small icons near the phone glance.
- No affinity meters on screen. Relationships show only through behaviour.

## 12. Save model

The debug quick-save serialises `Episode` to `user://ep01_save.json`. For the shipping episode, auto-checkpoints at scene starts and the hub entry (same JSON). On load, the player respawns at the scene's entry point with the current state.
