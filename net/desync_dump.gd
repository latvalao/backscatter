## Writes a readable state dump on desync to user://desync/ (§7.4) so the two
## peers' files can be diffed (tools/desync_diff.py).
class_name DesyncDump
extends RefCounted


static func write(world: SimWorld, tick: int, mine: int, other_player: int, theirs: int) -> String:
	DirAccess.make_dir_recursive_absolute("user://desync")
	var path: String = "user://desync/desync_t%d_p%d.txt" % [tick, other_player]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_line("tick %d local %08x remote(player %d) %08x" % [tick, mine, other_player, theirs])
	f.store_string(dump(world))
	f.close()
	return ProjectSettings.globalize_path(path)


## One line per entity per component, stable order — diff-friendly.
static func dump(world: SimWorld) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("rng %s" % str(world.rng.get_state()))
	for p: int in range(world.players.count()):
		lines.append("player %d team %d supply %d manpower %d defeated %d" % [p, world.players.team[p],
			world.players.supply[p], world.players.manpower[p], world.players.defeated[p]])
	var stores: Array[ComponentStore] = world.component_stores()
	for id: int in world.entities.ids():
		for i: int in range(stores.size()):
			if stores[i].has(id):
				var h: Checksum = Checksum.new()
				stores[i].hash_entity(id, h)
				lines.append("e%d c%d %08x" % [id, i, h.value])
		if world.transform.has(id):
			lines.append("e%d pos %d %d h %d hp %d" % [id, world.transform.x[id], world.transform.y[id],
				world.transform.heading[id], world.units.hp[id] if world.units.has(id) else 0])
	return "\n".join(lines) + "\n"
