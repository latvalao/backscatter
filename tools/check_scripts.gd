## Loads every .gd script in the project so parse/type errors surface with paths.
##   godot --headless --path . -s res://tools/check_scripts.gd
extends SceneTree

const SKIP: Array[String] = ["res://.godot", "res://addons"]


func _initialize() -> void:
	var bad: int = 0
	var files: PackedStringArray = PackedStringArray()
	_collect("res://", files)
	files.sort()
	for f: String in files:
		var s: Script = load(f) as Script
		if s == null or not s.can_instantiate():
			printerr("BROKEN %s" % f)
			bad += 1
	print("check_scripts: %d scripts, %d broken" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir: String, out: PackedStringArray) -> void:
	for skip: String in SKIP:
		if dir.begins_with(skip):
			return
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
