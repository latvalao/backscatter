## Loads forged models (res://presentation/assets/…) and dresses them with the
## shared scale-model material. Purely presentation; one cached PackedScene
## per unit id, one material per (faction row, camo style).
## An artist-made glTF dropped next to the .scn ({id}.glb with the same node
## names: Hull, Turret, Gun, SoldierA, SoldierB, Prop) takes precedence.
class_name ModelLibrary
extends RefCounted

const ROOT: String = "res://presentation/assets"
const SHADER: String = "res://presentation/look/shaders/scale_model.gdshader"
const FOLIAGE_SHADER: String = "res://presentation/look/shaders/foliage.gdshader"
## Units are drawn ~1.35x larger than buildings/trees for readability (§10).
const UNIT_SCALE: float = 1.35

static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _ghost: ShaderMaterial


static func faction_row(faction: String) -> int:
	match faction:
		"nc":
			return 0
		"ec":
			return 1
		"mr":
			return 2
	return 3


static func camo_style(faction: String) -> int:
	match faction:
		"nc":
			return 0
		"ec":
			return 1
		"mr":
			return 2
	return 3


static func material(row: int, camo: int) -> ShaderMaterial:
	var key: int = row * 10 + camo
	if not _materials.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load(SHADER) as Shader
		m.set_shader_parameter("palette", LookPalette.texture())
		m.set_shader_parameter("palette_row", row)
		m.set_shader_parameter("camo_style", camo)
		_materials[key] = m
	return _materials[key]


static func ghost_material() -> ShaderMaterial:
	if _ghost == null:
		var sh: Shader = Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.85, 0.82, 0.7, 0.28);
void fragment() { ALBEDO = tint.rgb; ALPHA = tint.a * (0.6 + 0.4 * COLOR.g); }
"""
		_ghost = ShaderMaterial.new()
		_ghost.shader = sh
	return _ghost


static func scene_path(def: UnitStats) -> String:
	var folder: String = "structures" if def.is_structure else def.faction
	return "%s/%s/%s/%s" % [ROOT, folder, def.id, def.id]


## A fresh instance of the unit's model, or null when no asset exists.
static func instantiate(def: UnitStats) -> Node3D:
	var base: String = scene_path(def)
	if not _scenes.has(def.id):
		var ps: PackedScene = null
		if ResourceLoader.exists(base + ".glb"):
			ps = load(base + ".glb") as PackedScene
		elif ResourceLoader.exists(base + ".scn"):
			ps = load(base + ".scn") as PackedScene
		_scenes[def.id] = ps
	var packed: PackedScene = _scenes[def.id]
	if packed == null:
		return null
	return packed.instantiate() as Node3D


## Assigns a material to every MeshInstance3D below `node`.
static func dress(node: Node, mat: Material) -> void:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		mi.material_override = mat
	for c: Node in node.get_children():
		dress(c, mat)


## Nature / prop mesh by name (assets/nature/{name}.res).
static func mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		var p: String = "%s/nature/%s.res" % [ROOT, name]
		_meshes[name] = load(p) as Mesh if ResourceLoader.exists(p) else null
	return _meshes[name]
