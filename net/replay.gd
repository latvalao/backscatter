## Replays (§7.4): match settings + every tick's commands + periodic checksums.
## Lockstep makes this free: replaying the inputs reproduces the match exactly.
class_name ReplayRecorder
extends RefCounted

const FORMAT: int = 1

var settings: Dictionary = {}
var ticks: Dictionary = {}       # tick -> PackedByteArray (encoded commands); only ticks with commands
var checksums: Dictionary = {}   # tick -> checksum
var final_tick: int = 0


func _init(p_settings: Dictionary = {}) -> void:
	settings = p_settings


func record_tick(t: int, cmds: Array[SimCommand]) -> void:
	final_tick = t + 1
	if not cmds.is_empty():
		ticks[t] = CommandCodec.encode(cmds)


func record_checksum(t: int, sum: int) -> void:
	checksums[t] = sum


func to_dict() -> Dictionary:
	return {"format": FORMAT, "settings": settings, "ticks": ticks, "checksums": checksums, "final_tick": final_tick}


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(to_dict())
	f.close()
	return OK


static func load_file(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	f.close()
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func default_path() -> String:
	return "user://replays/last.replay"
