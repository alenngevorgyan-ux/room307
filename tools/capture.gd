extends SceneTree
## One-shot screenshot capture (opens a window for its run; prefer tools/cap.sh, which talks to the
## persistent unobtrusive tools/capture_server.gd):
##   godot --path . --audio-driver Dummy -s res://tools/capture.gd -- --out=/abs/dir [--only=a,b]


func _initialize() -> void:
	var out := "user://captures"
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var shots: Node = (load("res://tools/capture_shots.gd") as GDScript).new()
	shots.main = main
	shots.view = root
	root.add_child(shots)
	_go.call_deferred(shots, out, only)


func _go(shots: Node, out: String, only: Array) -> void:
	await shots.run_shots(out, only)
	quit()
