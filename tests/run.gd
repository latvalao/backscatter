## Headless test runner.
##   godot --headless --import          # once, builds the class_name cache
##   godot --headless -s res://tests/run.gd [-- --filter=<substring>]
## Exit code 0 = all passed, 1 = failures.
extends SceneTree

const TEST_DIR: String = "res://tests"


func _initialize() -> void:
	var filter: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr("--filter=".length())

	var files: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()

	var total: int = 0
	var failed: int = 0
	var start_ms: int = Time.get_ticks_msec()
	for f: String in files:
		var script: GDScript = load(TEST_DIR.path_join(f)) as GDScript
		if script == null:
			printerr("FAIL  could not load %s" % f)
			failed += 1
			continue
		var methods: PackedStringArray = PackedStringArray()
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and (filter == "" or (f + ":" + mname).contains(filter)):
				methods.append(mname)
		methods.sort()
		for mname: String in methods:
			var tc: TestCase = script.new() as TestCase
			tc.current_test = "%s:%s" % [f, mname]
			tc.before_each()
			var t0: int = Time.get_ticks_msec()
			tc.call(mname)
			var dt: int = Time.get_ticks_msec() - t0
			total += 1
			if tc.failures.is_empty():
				print("ok    %s (%d ms)" % [tc.current_test, dt])
			else:
				failed += 1
				for msg: String in tc.failures:
					printerr("FAIL  %s" % msg)

	print("\n%d tests, %d failed (%d ms)" % [total, failed, Time.get_ticks_msec() - start_ms])
	quit(1 if failed > 0 or total == 0 else 0)
