## Headless test runner.
##   godot --headless --import          # once, builds the class_name cache
##   godot --headless -s res://tests/run.gd [-- --filter=<substring>] [--fast | --slow]
## --fast skips tests named test_slow_* (long acceptance/soak runs); --slow runs only those.
## Exit code 0 = all passed, 1 = failures.
extends SceneTree

const TEST_DIR: String = "res://tests"


## Counts engine/script errors so a test that triggers one fails (Godot 4.5+ Logger).
class ErrorCounter:
	extends Logger
	var count: int = 0
	var last: String = ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		count += 1
		last = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _errors: ErrorCounter = ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	var filter: String = ""
	var speed: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr("--filter=".length())
		elif arg == "--fast" or arg == "--slow":
			speed = arg

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
		if script == null or not script.can_instantiate():
			printerr("FAIL  could not load %s" % f)
			failed += 1
			continue
		var methods: PackedStringArray = PackedStringArray()
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			var slow: bool = mname.begins_with("test_slow_")
			if speed == "--fast" and slow or speed == "--slow" and not slow:
				continue
			if mname.begins_with("test_") and (filter == "" or (f + ":" + mname).contains(filter)):
				methods.append(mname)
		methods.sort()
		for mname: String in methods:
			var tc: TestCase = script.new() as TestCase
			tc.current_test = "%s:%s" % [f, mname]
			tc.before_each()
			var t0: int = Time.get_ticks_msec()
			var errs0: int = _errors.count
			tc.call(mname)
			var dt: int = Time.get_ticks_msec() - t0
			if _errors.count > errs0:
				tc.failures.append("%s: %d engine/script error(s), last: %s" % [tc.current_test, _errors.count - errs0, _errors.last])
			total += 1
			if tc.failures.is_empty():
				print("ok    %s (%d ms)" % [tc.current_test, dt])
			else:
				failed += 1
				for msg: String in tc.failures:
					printerr("FAIL  %s" % msg)

	print("\n%d tests, %d failed (%d ms)" % [total, failed, Time.get_ticks_msec() - start_ms])
	quit(1 if failed > 0 or (total == 0 and filter == "") else 0)
