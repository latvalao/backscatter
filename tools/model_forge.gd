## Builds every low-poly model and writes them under res://presentation/assets/.
##   godot --headless --path . -s res://tools/model_forge.gd [-- --only=nc_mbt_2a]
## Units/structures -> assets/{faction}/{id}/{id}.scn (nodes Hull, Turret/Gun …)
## Nature/props     -> assets/nature/{name}.res and {name}_far.res (ArrayMesh)
## The output is committed; rerun after changing tools/forge/*.gd.
extends SceneTree

const ROOT: String = "res://presentation/assets"

var _only: String = ""
var _report: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
	var db: DefDb = DefLoader.load_default()
	for u: UnitStats in db.units:
		if _only != "" and u.id != _only:
			continue
		var md: ForgeModels.Model
		var folder: String
		if u.is_structure:
			var cell: float = SimGrid.CELL_MM * 0.001
			md = ForgeModels.structure(u.id, u.footprint_w * cell, u.footprint_h * cell)
			folder = "structures"
		else:
			md = ForgeModels.build(u.id, u.faction, u.role, TerrainTable.MOBILITY_NAMES[u.mobility_class])
			folder = u.faction
		if md == null:
			_report.append("MISSING %s" % u.id)
			continue
		_save_model(md, "%s/%s/%s" % [ROOT, folder, u.id])
	if _only == "" or _only == "nature":
		_nature()
	print("\n".join(_report))
	quit(0)


func _save_model(md: ForgeModels.Model, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var root: Node3D = Node3D.new()
	root.name = md.id
	for k: String in md.meta.keys():
		root.set_meta(k, md.meta[k])
	var tris: int = 0
	var names: Dictionary = {"hull": "Hull", "soldier_a": "SoldierA", "soldier_b": "SoldierB", "prop": "Prop"}
	for part: String in md.parts.keys():
		var fm: ForgeMesh = md.parts[part]
		tris += fm.tri_count()
		if part == "turret" or part == "gun":
			continue
		if part == "rotor":
			var rn: Node3D = Node3D.new()
			rn.name = "Rotor"
			rn.position = md.pivots["rotor"]
			root.add_child(rn)
			rn.owner = root
			var rm: MeshInstance3D = MeshInstance3D.new()
			rm.name = "RotorMesh"
			rm.mesh = fm.commit(-1.0, md.rust)
			rn.add_child(rm)
			rm.owner = root
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = names.get(part, part)
		mi.mesh = fm.commit(md.dirt_height, md.rust)
		root.add_child(mi)
		mi.owner = root
	if md.parts.has("turret"):
		var tn: Node3D = Node3D.new()
		tn.name = "Turret"
		tn.position = md.pivots["turret"]
		root.add_child(tn)
		tn.owner = root
		var tm: MeshInstance3D = MeshInstance3D.new()
		tm.name = "TurretMesh"
		var tfm: ForgeMesh = md.parts["turret"]
		tm.mesh = tfm.commit(md.dirt_height - 1.4, md.rust)
		tn.add_child(tm)
		tm.owner = root
		var gn: Node3D = Node3D.new()
		gn.name = "Gun"
		gn.position = md.pivots["gun"]
		tn.add_child(gn)
		gn.owner = root
		var gm: MeshInstance3D = MeshInstance3D.new()
		gm.name = "GunMesh"
		var gfm: ForgeMesh = md.parts["gun"]
		gm.mesh = gfm.commit(-1.0, md.rust)
		gn.add_child(gm)
		gm.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	var path: String = "%s/%s.scn" % [dir, md.id]
	var err: Error = ResourceSaver.save(ps, path, ResourceSaver.FLAG_COMPRESS)
	root.free()
	_report.append("%-20s %5d tris  %s" % [md.id, tris, "ok" if err == OK else "ERR %d" % err])


func _nature() -> void:
	var dir: String = ROOT + "/nature"
	DirAccess.make_dir_recursive_absolute(dir)
	var trees: Dictionary = ForgeNature.trees()
	for name: String in trees.keys():
		var pair: Array = trees[name]
		var near: ForgeMesh = pair[0]
		var far: ForgeMesh = pair[1]
		_save_mesh(near, "%s/%s.res" % [dir, name], 0.6)
		_save_mesh(far, "%s/%s_far.res" % [dir, name], 0.6)
	_save_mesh(ForgeNature.reeds(), dir + "/reeds.res", 0.3)
	for i: int in range(3):
		_save_mesh(ForgeNature.rock(30 + i * 7), "%s/rock_%d.res" % [dir, i], 0.4)
	_save_mesh(ForgeNature.fallen_tree(), dir + "/fallen_tree.res", 0.4)
	_save_mesh(ForgeNature.stump(), dir + "/stump.res", 0.4)
	_save_mesh(ForgeNature.house(0), dir + "/house_0.res", 0.8)
	_save_mesh(ForgeNature.house(1), dir + "/house_1.res", 0.8)
	_save_mesh(ForgeNature.border_post(), dir + "/border_post.res", 0.8)
	_save_mesh(ForgeNature.plant(), dir + "/plant.res", 3.0)


func _save_mesh(fm: ForgeMesh, path: String, dirt: float, ao: float = 0.8) -> void:
	var m: ArrayMesh = fm.commit(dirt, 0.0, ao)
	var err: Error = ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
	_report.append("%-20s %5d tris  %s" % [path.get_file(), fm.tri_count(), "ok" if err == OK else "ERR %d" % err])
