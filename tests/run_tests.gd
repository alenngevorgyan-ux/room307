extends SceneTree
## Headless test runner: godot --headless --path . -s res://tests/run_tests.gd [-- filter]
## Exit code 0 = all pass.

var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array = []
	for dir in ["res://tests/unit", "res://tests/sim"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd"):
				files.append(dir + "/" + f)
	files.sort()
	files.push_front("res://tests/validate_data.gd")
	var total := 0
	var failed := 0
	var fail_lines: Array = []
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			fail_lines.append("LOAD FAILED " + path)
			failed += 1
			continue
		var inst = script.new()
		inst.tree = self
		var methods: Array = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_") and not methods.has(m.name):
				methods.append(m.name)
		for m in methods:
			if filter != "" and not (path + ":" + m).contains(filter):
				continue
			total += 1
			inst.current = path.get_file() + ":" + m
			inst.failures = []
			inst.before_each()
			inst.call(m)
			inst.after_each()
			if inst.failures.is_empty():
				print("  ok   ", inst.current)
			else:
				failed += 1
				print("  FAIL ", inst.current)
				for f in inst.failures:
					print("       ", f)
					fail_lines.append(f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
	return true
