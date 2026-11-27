## Prints terrain composition of the procedural test map.
extends SceneTree


func _initialize() -> void:
	var g: SimGrid = MapGen.generate(7, 500, 500)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(TerrainTable.COUNT)
	for i: int in range(g.cell_count()):
		counts[g.terrain[i]] += 1
	for t: int in range(TerrainTable.COUNT):
		print("%-7s %5.1f%%" % [TerrainTable.NAMES[t], 100.0 * counts[t] / g.cell_count()])
	quit()
