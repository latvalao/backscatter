## Low-poly nature and world props (offline, used by tools/model_forge.gd).
## Foliage clumps use soft normals (no faceted 90s look); trunks, rocks and
## buildings stay flat shaded. Each tree also gets a cheap far-LOD mesh.
class_name ForgeNature
extends RefCounted

const R: int = ForgeModels.ROW_NATURE
const N: int = ForgeModels.ROW_NEUTRAL


static func mesh() -> ForgeMesh:
	var m: ForgeMesh = ForgeMesh.new()
	m.row = R
	return m


## Returns {name: [ForgeMesh near, ForgeMesh far]} for every tree species.
static func trees() -> Dictionary:
	var out: Dictionary = {}
	out["pine"] = [pine(false), pine(true)]
	out["spruce"] = [spruce(false), spruce(true)]
	out["birch"] = [birch(false, ForgeModels.BIRCH_LEAF), birch(true, ForgeModels.BIRCH_LEAF)]
	out["aspen"] = [birch(false, ForgeModels.ASPEN), birch(true, ForgeModels.ASPEN)]
	out["juniper"] = [juniper(false), juniper(true)]
	return out


static func pine(far: bool) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	var hgt: float = 17.0
	m.cyl(Vector3(0, -0.5, 0), Vector3(0.15, hgt * 0.82, 0.05), 0.28, 0.1, 4 if far else 6, ForgeModels.BARK)
	if far:
		m.blob(Vector3(0.2, hgt * 0.8, 0), Vector3(2.6, 2.8, 2.6), 6, 3, ForgeModels.NEEDLE, true)
		return m
	m.cyl(Vector3(0.05, hgt * 0.55, 0), Vector3(1.6, hgt * 0.68, 0.4), 0.07, 0.05, 4, ForgeModels.BARK)
	m.blob(Vector3(0.3, hgt * 0.83, 0.1), Vector3(2.4, 1.9, 2.3), 8, 4, ForgeModels.NEEDLE, true, false, 0.12, 1)
	m.blob(Vector3(1.4, hgt * 0.7, 0.4), Vector3(1.6, 1.2, 1.5), 7, 4, ForgeModels.NEEDLE, true, false, 0.12, 2)
	m.blob(Vector3(-1.0, hgt * 0.74, -0.6), Vector3(1.5, 1.2, 1.6), 7, 4, ForgeModels.NEEDLE, true, false, 0.12, 3)
	m.blob(Vector3(0.2, hgt * 0.95, 0.0), Vector3(1.3, 1.2, 1.3), 7, 4, ForgeModels.NEEDLE, true, false, 0.1, 4)
	return m


static func spruce(far: bool) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	var hgt: float = 18.0
	m.cyl(Vector3(0, -0.5, 0), Vector3(0, hgt * 0.3, 0), 0.3, 0.2, 4 if far else 6, ForgeModels.BARK)
	var layers: int = 2 if far else 5
	for i: int in range(layers):
		var f: float = float(i) / layers
		var base: float = hgt * (0.12 + f * 0.7)
		var rad: float = 3.3 * (1.0 - f * 0.78)
		var top: float = base + hgt * (0.42 if far else 0.3)
		var rings: Array[PackedVector3Array] = [
			ForgeMesh.circle(rad, rad, 7 if far else 9, base, Vector3.ZERO, i * 0.4),
			ForgeMesh.circle(rad * 0.55, rad * 0.55, 7 if far else 9, base - 0.6, Vector3.ZERO, i * 0.4 + 0.3),
			ForgeMesh.circle(0.001, 0.001, 7 if far else 9, top, Vector3.ZERO, 0.0)]
		# ring order bottom (droop) first for the loft: reorder to y-ascending
		var ordered: Array[PackedVector3Array] = [rings[1], rings[0], rings[2]]
		m.loft(ordered, ForgeModels.SPRUCE, PackedInt32Array(), false, Transform3D.IDENTITY, true, false)
	return m


static func birch(far: bool, leaf: int) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	var hgt: float = 14.0
	var lean: Vector3 = Vector3(0.5, hgt * 0.62, 0.25)
	m.cyl(Vector3(0, -0.5, 0), lean + Vector3(0.1, 2.0, 0.05), 0.2, 0.07, 4 if far else 6, ForgeModels.BIRCH_BARK)
	if far:
		m.blob(lean + Vector3(0, 1.0, 0), Vector3(3.0, 4.4, 3.0), 6, 3, leaf, true)
		return m
	m.cyl(lean * 0.6, lean * 0.6 + Vector3(-1.6, 2.4, 0.3), 0.07, 0.03, 4, ForgeModels.BIRCH_BARK)
	m.cyl(lean * 0.7, lean * 0.7 + Vector3(1.6, 2.1, -0.6), 0.07, 0.03, 4, ForgeModels.BIRCH_BARK)
	m.blob(lean + Vector3(0, 2.2, 0), Vector3(2.3, 2.6, 2.3), 8, 4, leaf, true, false, 0.15, 5)
	m.blob(lean + Vector3(-1.6, 0.4, 0.5), Vector3(2.0, 2.2, 1.9), 7, 4, leaf, true, false, 0.15, 6)
	m.blob(lean + Vector3(1.5, -0.2, -0.6), Vector3(1.9, 2.1, 1.9), 7, 4, leaf, true, false, 0.15, 7)
	m.blob(lean + Vector3(0.3, -1.6, 1.0), Vector3(1.6, 1.8, 1.6), 7, 3, leaf, true, false, 0.15, 8)
	m.blob(lean + Vector3(-0.4, -2.4, -0.8), Vector3(1.3, 1.5, 1.3), 7, 3, leaf, true, false, 0.15, 9)
	return m


static func juniper(far: bool) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.blob(Vector3(0, 1.4, 0), Vector3(1.1, 1.9, 1.1), 6 if far else 8, 3 if far else 4, ForgeModels.SPRUCE, true, false, 0.15, 9)
	if not far:
		m.blob(Vector3(0.7, 0.7, 0.3), Vector3(0.8, 1.0, 0.8), 7, 3, ForgeModels.SPRUCE, true, false, 0.15, 10)
	return m


static func reeds() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i: int in range(14):
		var p: Vector3 = Vector3(rng.randf_range(-1.6, 1.6), -0.2, rng.randf_range(-1.6, 1.6))
		var tip: Vector3 = p + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(1.2, 2.0), rng.randf_range(-0.3, 0.3))
		m.cyl(p, tip, 0.06, 0.0, 3, ForgeModels.REED)
	return m


static func rock(seed_v: int) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.blob(Vector3(0, 0.2, 0), Vector3(2.2, 1.4, 1.8), 7, 4, ForgeModels.GRANITE, false, false, 0.25, seed_v)
	m.blob(Vector3(1.6, 0.0, 0.8), Vector3(1.1, 0.8, 1.0), 6, 4, ForgeModels.LICHEN, false, false, 0.25, seed_v + 1)
	return m


static func fallen_tree() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.cyl(Vector3(0, 0.3, 0), Vector3(0, 0.25, -12.0), 0.28, 0.08, 6, ForgeModels.BARK)
	m.cyl(Vector3(0, 0.0, 0.2), Vector3(0, 0.9, 0.3), 0.32, 0.25, 6, ForgeModels.BARK)
	m.blob(Vector3(0.3, 0.8, -10.5), Vector3(1.8, 1.1, 2.4), 7, 4, ForgeModels.NEEDLE, true, false, 0.2, 12)
	return m


static func stump() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.cyl(Vector3(0, -0.3, 0), Vector3(0, 0.7, 0), 0.32, 0.26, 6, ForgeModels.BARK)
	m.cyl(Vector3(0, 0.7, 0), Vector3(0.15, 1.3, 0.05), 0.2, 0.02, 5, ForgeModels.BARK)
	return m


## Karelian wooden village house.
static func house(variant: int) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	var w: float = 7.0 if variant == 0 else 9.0
	var d: float = 6.0
	var wall: int = ForgeModels.PLANK if variant == 0 else ForgeModels.PLASTER
	m.box(Vector3(0, -0.5, 0), Vector3(w + 0.2, 0.9, d + 0.2), ForgeModels.N_CONCRETE, 0.04)
	m.box(Vector3(0, 0.4, 0), Vector3(w, 3.0, d), wall, 0.06)
	m.box(Vector3(0, 3.4, 0), Vector3(w + 0.8, 2.6, d + 0.9), ForgeModels.ROOF, 0.0, Vector2(1.0, 0.02))
	m.box(Vector3(w * 0.25, 3.8, 0.8), Vector3(0.6, 2.4, 0.6), ForgeModels.N_CONCRETE, 0.03)
	for i: int in range(3):
		var x: float = -w * 0.32 + i * w * 0.32
		m.box(Vector3(x, 1.4, -d * 0.5 - 0.03), Vector3(0.9, 1.1, 0.08), ForgeModels.WINDOW, 0.01)
		m.box(Vector3(x, 1.3, -d * 0.5 - 0.06), Vector3(1.1, 0.12, 0.12), ForgeModels.BIRCH_BARK, 0.01)
	m.box(Vector3(w * 0.5 + 0.03, 0.4, 0), Vector3(0.08, 2.1, 1.0), ForgeModels.PLANK, 0.01)
	if variant == 1:
		m.box(Vector3(-w * 0.5 - 1.6, -0.3, 1.0), Vector3(2.8, 2.4, 3.0), ForgeModels.PLANK, 0.05)
		m.box(Vector3(-w * 0.5 - 1.6, 2.1, 1.0), Vector3(3.2, 0.9, 3.4), ForgeModels.N_RUST, 0.0, Vector2(1.0, 0.02))
	return m


## Wooden power-line pole with a cross-arm and insulators.
static func pole() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.cyl(Vector3(0, -0.5, 0), Vector3(0, 9.0, 0), 0.16, 0.12, 6, ForgeModels.BARK)
	m.box(Vector3(0, 8.3, 0), Vector3(2.6, 0.16, 0.16), ForgeModels.PLANK, 0.02)
	for x: float in [-1.1, 0.0, 1.1]:
		m.cyl(Vector3(x, 8.46, 0), Vector3(x, 8.75, 0), 0.06, 0.05, 5, ForgeModels.N_CONCRETE)
	return m


## A 6 m run of weathered wooden fence (along local X).
static func fence() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	for i: int in range(3):
		m.box(Vector3(-3.0 + i * 3.0, -0.2, 0), Vector3(0.14, 1.5, 0.14), ForgeModels.PLANK, 0.02)
	m.box(Vector3(0, 0.55, 0), Vector3(6.1, 0.12, 0.06), ForgeModels.PLANK, 0.01)
	m.box(Vector3(0, 1.0, 0), Vector3(6.1, 0.12, 0.06), ForgeModels.PLANK, 0.01)
	return m


## Abandoned car, stripped and rusting.
static func car(variant: int) -> ForgeMesh:
	var m: ForgeMesh = mesh()
	var body: int = ForgeModels.N_RUST if variant == 0 else ForgeModels.PLASTER
	m.box(Vector3(0, 0.25, 0), Vector3(1.7, 0.65, 4.3), body, 0.12, Vector2(1.0, 0.95))
	m.box(Vector3(0, 0.9, 0.25), Vector3(1.5, 0.55, 2.1), body, 0.12, Vector2(0.85, 0.75), Vector2(0, 0.1))
	m.box(Vector3(0, 0.95, -0.82), Vector3(1.35, 0.42, 0.05), ForgeModels.WINDOW, 0.0, Vector2(1.0, 1.0), Vector2(0, 0.2))
	for z: float in [-1.35, 1.35]:
		for x: float in [-0.8, 0.8]:
			m.cyl(Vector3(x - 0.1 * signf(x), 0.32, z), Vector3(x + 0.1 * signf(x), 0.32, z), 0.32, 0.32, 8, ForgeModels.BARK)
	return m


## Round hay bales in a little row.
static func bales() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	for i: int in range(3):
		var x: float = -2.2 + i * 2.2
		m.cyl(Vector3(x, 0.75, -0.7), Vector3(x, 0.75, 0.7), 0.78, 0.78, 10, ForgeModels.REED, true)
	return m


## Collective-farm barn: long plank shed with a rusty roof.
static func barn() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.box(Vector3(0, -0.4, 0), Vector3(14.0, 5.2, 8.0), ForgeModels.PLANK, 0.08)
	m.box(Vector3(0, 4.8, 0), Vector3(14.8, 2.6, 8.8), ForgeModels.N_RUST, 0.0, Vector2(1.0, 0.02))
	m.box(Vector3(0, -0.2, -4.03), Vector3(3.6, 3.6, 0.08), ForgeModels.BARK, 0.01)
	return m


## Ruined Soviet-era border post (beauty corner).
static func border_post() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.box(Vector3(0, -0.3, 0), Vector3(4.0, 0.5, 4.0), ForgeModels.N_CONCRETE, 0.05)
	m.box(Vector3(-1.4, 0.2, 0), Vector3(0.3, 2.8, 3.6), ForgeModels.N_CONCRETE, 0.04)
	m.box(Vector3(1.4, 0.2, 0.6), Vector3(0.3, 2.1, 2.4), ForgeModels.N_CONCRETE, 0.04, Vector2(1.0, 0.6), Vector2(0, 0.4))
	m.box(Vector3(0, 0.2, 1.65), Vector3(3.0, 2.8, 0.3), ForgeModels.N_CONCRETE, 0.04)
	m.box(Vector3(-0.4, 3.0, 0.4), Vector3(3.2, 0.25, 2.8), ForgeModels.N_CONCRETE, 0.03, Vector2(0.7, 0.9), Vector2(-0.3, 0.1),
		Vector2.ONE, Vector2.ZERO, Transform3D(Basis(Vector3.FORWARD, 0.18), Vector3.ZERO))
	m.box(Vector3(0, 0.2, -1.7), Vector3(1.4, 1.4, 0.1), ForgeModels.WINDOW, 0.01)
	# striped barrier pole, broken off
	m.box(Vector3(3.2, -0.2, -2.2), Vector3(0.5, 1.1, 0.5), ForgeModels.N_CONCRETE, 0.05)
	for i: int in range(4):
		var a: Vector3 = Vector3(3.2 + i * 1.2, 1.0 - i * 0.22, -2.2)
		m.cyl(a, a + Vector3(1.2, -0.22, 0), 0.08, 0.08, 6, ForgeModels.BIRCH_BARK if i % 2 == 0 else ForgeModels.N_RUST)
	# rusty sign
	m.cyl(Vector3(-3.0, -0.3, -2.6), Vector3(-3.1, 2.6, -2.6), 0.05, 0.05, 4, ForgeModels.N_RUST)
	m.box(Vector3(-3.1, 2.2, -2.62), Vector3(1.2, 0.8, 0.05), ForgeModels.N_RUST, 0.01)
	m.blob(Vector3(2.0, -0.2, 2.6), Vector3(1.2, 0.5, 0.9), 6, 3, ForgeModels.N_CONCRETE, false, false, 0.3, 21)
	return m


## Kaarnavaara nuclear plant: reactor hall, vent stack, two cooling towers.
static func plant() -> ForgeMesh:
	var m: ForgeMesh = mesh()
	m.box(Vector3(0, -1.0, 0), Vector3(70.0, 31.0, 44.0), ForgeModels.N_CONCRETE, 0.4)
	m.box(Vector3(-10, 30.0, 0), Vector3(34.0, 10.0, 30.0), ForgeModels.N_CONCRETE, 0.3, Vector2(0.92, 0.92))
	m.box(Vector3(30, -1.0, 6), Vector3(26.0, 18.0, 30.0), ForgeModels.PLASTER, 0.2)
	# breached sarcophagus patch
	m.box(Vector3(-14, 39.5, 4), Vector3(16.0, 4.0, 14.0), ForgeModels.N_RUST, 0.2, Vector2(0.8, 0.7))
	m.cyl(Vector3(10, 29.0, -8), Vector3(10, 82.0, -8), 3.6, 2.6, 10, ForgeModels.N_CONCRETE, true)
	for i: int in range(5):
		m.cyl(Vector3(10, 34.0 + i * 10.0, -8), Vector3(10, 34.6 + i * 10.0, -8), 3.9 - i * 0.18, 3.8 - i * 0.18, 10,
			ForgeModels.N_RUST if i % 2 == 0 else ForgeModels.BIRCH_BARK)
	for t: Vector3 in [Vector3(-80, 0, -60), Vector3(-130, 0, -10)]:
		_cooling_tower(m, t)
	for k: int in range(6):
		m.box(Vector3(-35 + k * 14, -0.5, 40), Vector3(9.0, 6.0, 12.0), ForgeModels.N_CONCRETE, 0.2)
	return m


static func _cooling_tower(m: ForgeMesh, c: Vector3) -> void:
	var rings: Array[PackedVector3Array] = []
	var hgt: float = 90.0
	for i: int in range(7):
		var f: float = float(i) / 6.0
		var r: float = 34.0 * (1.0 - 0.58 * sin(minf(f, 0.85) / 0.85 * PI * 0.5)) + (f - 0.85) * 25.0 * float(f > 0.85)
		rings.append(ForgeMesh.circle(r, r, 20, c.y - 2.0 + f * hgt, c, 0.0))
	m.loft(rings, ForgeModels.N_CONCRETE, PackedInt32Array(), false, Transform3D.IDENTITY, false, false)
	m.cyl(c + Vector3(0, hgt - 2.5, 0), c + Vector3(0, hgt - 2.4, 0), 17.0, 17.0, 20, ForgeModels.WINDOW)
