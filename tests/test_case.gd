## Minimal test base. Test files are tests/test_*.gd, extend TestCase, and
## define methods named test_*. Run: godot --headless -s res://tests/run.gd
class_name TestCase
extends RefCounted

var failures: PackedStringArray = PackedStringArray()
var current_test: String = ""


func before_each() -> void:
	pass


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("expected %s, got %s %s" % [str(expected), str(actual), msg])


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("did not expect %s %s" % [str(unexpected), msg])


func assert_near(actual: int, expected: int, tolerance: int, msg: String = "") -> void:
	if absi(actual - expected) > tolerance:
		fail("expected %d ±%d, got %d %s" % [expected, tolerance, actual, msg])
