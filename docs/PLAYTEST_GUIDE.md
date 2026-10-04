# ROOM 307 · EP01 · Graybox playtest — how to play

Build: **ep01-graybox-playtest-v1** (graybox: characters are capsules, rooms are boxes; audio is placeholder).
All in-game text is **Russian**. Expected playtime: **35–45 min** first time (speed run ~15–20 min).

## macOS
1. Download **`ROOM307_EP01_GRAYBOX_PLAYTEST_MAC_v1.zip`** from the private GitHub release.
2. Double-click the zip → you get **`Room 307.app`** (+ this guide). Move the app anywhere (e.g. Applications).
3. First launch: the app is not notarized, so macOS blocks a double-click.
   - **Right-click (Ctrl-click) `Room 307.app` → Open → Open.** (Once; later double-click works.)
   - If there is no "Open" button: System Settings → Privacy & Security → scroll down → **Open Anyway**.
   - Terminal alternative: `xattr -dr com.apple.quarantine "/path/to/Room 307.app"`
4. The game starts directly in Episode 01 (bar, 02:17). No editor needed. Windowed; Cmd+Ctrl+F or the green button for full screen.

## Web (for later hosting)
**`ROOM307_EP01_GRAYBOX_PLAYTEST_WEB_v1.zip`** contains only the files to host (`index.html` + `.js/.wasm/.pck` + audio worklets + icons).
Single-threaded build: works on any static host (itch.io "HTML" upload, or `python3 -m http.server` in the unzipped folder → http://localhost:8000). Opening index.html via `file://` does not work. Chrome/Edge/Firefox desktop recommended.

## Controls
| Action | Keys |
|---|---|
| Move | W A S D / arrows (relative to the camera) |
| Fast walk (toggle) | Caps Lock |
| Run (hold) | Shift |
| Crouch · slide when running | Ctrl (or C) |
| Context: vault a yellow-striped object, doors, struggle | Space |
| Interact / talk / pick up / place | E |
| READ — notice details (hold) and aim with the mouse | Right mouse button **or F** |
| Dialogue choices (they time out = silence; walking away = leaving) | 1 2 3 4 or click |
| Phone: messages, invitations, photo, map | Tab (↑↓ Enter or click) |
| Pin a thread (tap) / list threads (hold) | Q |
| Pause menu | Esc |

## Restart / save / quit (Esc menu)
- **Начать эпизод заново** — restart Episode 01 from the bar.
- **Загрузить последний чекпоинт** — the game saves automatically at the start of every scene (from Scene 02 on); this reloads that point. Works after quitting and relaunching too (press Esc right after launch).
- **Папка с логами плейтеста** — opens the folder with the playtest logs.
- **Выйти** — quit (or Cmd+Q).

## Playtest log (local only, nothing is sent anywhere)
`~/Library/Application Support/Room307/playtest/`
- `ep01_<date>_<time>.jsonl` — event per line (scenes, leads, facts, bluffs, READ, stalls, chase, ending)
- `ep01_<date>_<time>_summary.txt` — written when the episode ends or the app quits.
Please send both files after your run.

## Developer overlay (off for players)
**Ctrl+Shift+D** toggles developer mode: F1 state (scene, objective, flags, NPC states, playtime) · F2 scene jump · F3 grant fact · F4 pacing · F6/F7 quick save/load.

## Your first playthrough
1. Launch. You're seated at a bar; an argument about a "stolen" watch is happening around you. Press any movement key to stand.
2. Hold **F** (or right mouse) to READ: aim the circle at people and objects. Notes appear in the world; two related notes offer a *thread* (top-left, **Q** to pin).
3. Walk up to people and press **E** to talk. Choose with **1–4**, or say nothing — silence is a choice.
4. Play naturally; don't consult the design docs. If you're stuck for more than ~2 minutes, note where (the log records it too).
5. In the restaurant finale: prepare the room (E on objects), invite people with the **phone (Tab)**, then E on the table «Начать».
6. When it's over (black screen "EPISODE 01 COMPLETE"), quit and send the two log files plus your notes: where you were confused, bored, or delighted.
