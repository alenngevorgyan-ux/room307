extends SceneTree
## Persistent, unobtrusive screenshot server for visual QA.
## One tiny borderless window (240x135, bottom-right corner, never takes focus, sound off) stays
## open; the game renders into an off-screen 1280x720 SubViewport. Requests are JSON files:
##   <inbox>/req.json  {"id": "...", "out": "/abs/dir", "only": ["01_opening", ...], "reload": true}
## For each new id the server (optionally) reloads changed scripts/shaders, rebuilds the game,
## runs the shots (tools/capture_shots.gd) and writes <inbox>/done_<id>.txt.
## Start once:  open -g -n -a Godot.app --args --path <project> --audio-driver Dummy
##              -s res://tools/capture_server.gd -- --inbox=/abs/dir --no-playtest-log
## Client:      tools/cap.sh <out_dir> [shot,shot]

const SHOTS := "res://tools/capture_shots.gd"

var inbox := ""
var sv: SubViewport
var main: Node
var shots: Node
var busy := false
var last_id := ""
var _poll := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--inbox="):
			inbox = a.substr(8)
	DirAccess.make_dir_recursive_absolute(inbox)
	AudioServer.set_bus_mute(0, true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.borderless = true
	root.unfocusable = true
	root.size = Vector2i(240, 135)
	var r := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	root.position = r.position + r.size - Vector2i(250, 145)
	sv = SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var preview := TextureRect.new()
	preview.texture = sv.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	_boot()
	_write("server_ready.txt", "pid %d" % OS.get_process_id())


func _boot() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	sv.add_child(main)
	shots = (load(SHOTS) as GDScript).new()
	shots.main = main
	shots.view = sv
	root.add_child(shots)


func _teardown() -> void:
	if shots:
		root.remove_child(shots)
		shots.free()
		shots = null
	if main:
		sv.remove_child(main)
		main.free()
		main = null
	paused = false
	Engine.time_scale = 1.0
	Services.clear()
	Presence.clear()
	ActionRunner.reset()
	root.get_node("Episode").reset()
	root.get_node("Data").reload()
	# (resolved at run time: this script compiles before the autoloads exist)
	load("res://src/world/vesper_look.gd").call("reset_cache")


## Refresh every changed script / shader from disk (no instances exist at this point).
func _reload_code() -> void:
	var files: Array = []
	_collect("res://src", files)
	files.append(SHOTS)
	for p in files:
		var src := FileAccess.get_file_as_string(p)
		if p.ends_with(".gd"):
			var sc := load(p) as GDScript
			if sc and sc.source_code != src:
				sc.source_code = src
				var err := sc.reload(false)
				print("[server] reloaded ", p, " ", err)
		elif p.ends_with(".gdshader"):
			var sh := load(p) as Shader
			if sh and sh.code != src:
				sh.code = src
				print("[server] reloaded ", p)


func _collect(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)


func _process(delta: float) -> bool:
	_poll -= delta
	if busy or _poll > 0.0:
		return false
	_poll = 0.5
	var req_path := inbox.path_join("req.json")
	if not FileAccess.file_exists(req_path):
		return false
	var req: Variant = JSON.parse_string(FileAccess.get_file_as_string(req_path))
	if typeof(req) != TYPE_DICTIONARY or String(req.get("id", "")) == last_id:
		return false
	last_id = String(req.id)
	if req.get("quit", false):
		return true
	_handle(req)
	return false


func _handle(req: Dictionary) -> void:
	busy = true
	if req.get("reload", true):
		_teardown()
		_reload_code()
		_boot()
		for i in 10:
			await process_frame
	if shots == null or not shots.has_method("run_shots"):
		_write("done_%s.txt" % last_id, "error: shots script failed to load (see server.log)")
		busy = false
		return
	await shots.run_shots(String(req.out), Array(req.get("only", [])))
	_write("done_%s.txt" % last_id, "ok")
	busy = false


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(inbox.path_join(name), FileAccess.WRITE)
	if f:
		f.store_string(text)
