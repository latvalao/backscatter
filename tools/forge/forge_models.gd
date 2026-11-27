## Parametric low-poly model library (offline, used by tools/model_forge.gd).
## Real-world scale in metres, front = -Z, origin = ground centre.
## Silhouettes follow the unit roles in docs/DESIGN.md; proportions are loosely
## "Cold War scale model", geometry stays very low poly (palette-atlas look).
class_name ForgeModels
extends RefCounted

# Palette swatch columns (presentation/look/palette.json)
const CAMO: int = 0
const CAMO_DARK: int = 1
const CAMO_3: int = 2
const METAL: int = 3
const RUBBER: int = 4
const CANVAS: int = 5
const SKIN: int = 6
const UNIFORM: int = 7
const GEAR: int = 8
const HELMET: int = 9
const GLASS: int = 10
const CONCRETE: int = 11
const WOOD: int = 12
const RUST: int = 13
const EARTH: int = 14
const MARK: int = 15
# Nature row columns
const NEEDLE: int = 0
const SPRUCE: int = 1
const BIRCH_LEAF: int = 2
const BIRCH_BARK: int = 3
const BARK: int = 4
const MOSS: int = 5
const REED: int = 6
const ASPEN: int = 7
const GRANITE: int = 8
const LICHEN: int = 9
const ROOF: int = 10
const PLASTER: int = 11
const PLANK: int = 12
const N_RUST: int = 13
const N_CONCRETE: int = 14
const WINDOW: int = 15

const ROW_NC: int = 0
const ROW_EC: int = 1
const ROW_MR: int = 2
const ROW_NEUTRAL: int = 3
const ROW_NATURE: int = 4


## One built model: named parts (hull / turret / gun / soldier variants…),
## pivots for articulated parts, and free-form metadata.
class Model:
	extends RefCounted
	var id: String = ""
	var parts: Dictionary = {}    # name -> ForgeMesh
	var pivots: Dictionary = {}   # name -> Vector3 (turret, gun)
	var meta: Dictionary = {}
	var rust: float = 0.0
	var dirt_height: float = 1.2

	func part(name: String, row: int) -> ForgeMesh:
		if not parts.has(name):
			var m: ForgeMesh = ForgeMesh.new()
			m.row = row
			parts[name] = m
		return parts[name]


static func row_for(faction: String) -> int:
	match faction:
		"nc":
			return ROW_NC
		"ec":
			return ROW_EC
		"mr":
			return ROW_MR
	return ROW_NEUTRAL


static func build(id: String, faction: String, role: String, mobility: String) -> Model:
	var row: int = row_for(faction)
	match id:
		"nc_mbt_2a":
			return tracked(id, row, {"L": 7.7, "W": 3.7, "H": 0.75, "th": 1.05, "wheels": 7, "wr": 0.36, "glacis": 1.5,
				"turret": "wedge", "tw": 3.1, "tl": 4.2, "tth": 0.85, "tz": 0.4, "gun_l": 5.6, "gun_r": 0.09, "sleeve": true, "skirts": true, "smoke": true})
		"ec_mbt_72":
			return tracked(id, row, {"L": 6.9, "W": 3.5, "H": 0.6, "th": 0.95, "wheels": 6, "wr": 0.4, "glacis": 1.6,
				"turret": "dome", "tw": 2.9, "tl": 3.0, "tth": 0.8, "tz": -0.1, "gun_l": 5.2, "gun_r": 0.085, "sleeve": true, "era": true, "drums": true, "smoke": true, "snorkel": true})
		"mr_mbt_55":
			return tracked(id, row, {"L": 6.4, "W": 3.3, "H": 0.65, "th": 0.95, "wheels": 5, "wr": 0.42, "glacis": 1.4,
				"turret": "dome", "tw": 2.6, "tl": 2.7, "tth": 0.85, "tz": -0.4, "gun_l": 4.2, "gun_r": 0.08, "evacuator": true, "drums": true, "rust": 0.8})
		"nc_ifv_90":
			return tracked(id, row, {"L": 6.6, "W": 3.2, "H": 1.25, "th": 0.9, "wheels": 7, "wr": 0.3, "glacis": 1.3,
				"turret": "box", "tw": 2.2, "tl": 2.4, "tth": 0.7, "tz": -0.1, "gun_l": 2.9, "gun_r": 0.05, "skirts": true, "smoke": true, "rear_door": true})
		"ec_ifv_2":
			return tracked(id, row, {"L": 6.7, "W": 3.1, "H": 0.75, "th": 0.8, "wheels": 6, "wr": 0.3, "glacis": 2.3, "ribbed": true,
				"turret": "small_dome", "tw": 1.9, "tl": 1.9, "tth": 0.6, "tz": 0.4, "gun_l": 2.7, "gun_r": 0.04, "atgm": true, "smoke": true})
		"mr_ifv_captured":
			return tracked(id, row, {"L": 6.7, "W": 3.1, "H": 0.75, "th": 0.8, "wheels": 6, "wr": 0.3, "glacis": 2.3, "ribbed": true,
				"turret": "small_dome", "tw": 1.9, "tl": 1.9, "tth": 0.6, "tz": 0.4, "gun_l": 2.7, "gun_r": 0.04, "rust": 0.9, "junk": true})
		"nc_spg_155":
			return tracked(id, row, {"L": 7.9, "W": 3.5, "H": 0.85, "th": 1.0, "wheels": 7, "wr": 0.36, "glacis": 1.2,
				"turret": "spg", "tw": 3.2, "tl": 4.2, "tth": 1.35, "tz": 1.0, "gun_l": 8.0, "gun_r": 0.1, "muzzle_brake": true, "skirts": true})
		"ec_spg_122":
			return tracked(id, row, {"L": 7.0, "W": 2.9, "H": 0.7, "th": 0.8, "wheels": 7, "wr": 0.3, "glacis": 1.0,
				"turret": "spg", "tw": 2.4, "tl": 2.6, "tth": 1.0, "tz": 1.2, "gun_l": 4.6, "gun_r": 0.07, "muzzle_brake": true})
		"nc_engineer_veh":
			return tracked(id, row, {"L": 7.6, "W": 3.6, "H": 1.0, "th": 1.0, "wheels": 7, "wr": 0.36, "glacis": 1.0,
				"turret": "none", "blade": true, "crane": true, "skirts": true, "boxes": true})
		"ec_engineer_veh":
			return tracked(id, row, {"L": 7.2, "W": 3.4, "H": 0.8, "th": 0.95, "wheels": 6, "wr": 0.4, "glacis": 1.4,
				"turret": "none", "blade": true, "crane": true, "drums": true})
		"ec_spaa_23":
			return tracked(id, row, {"L": 6.5, "W": 3.1, "H": 0.7, "th": 0.75, "wheels": 6, "wr": 0.33, "glacis": 1.1,
				"turret": "aa", "tw": 2.9, "tl": 2.6, "tth": 0.9, "tz": 0.3, "gun_l": 2.3, "gun_r": 0.035})
		"nc_supply_truck":
			return truck(id, row, {"L": 8.5, "W": 2.5, "axles": 3, "body": "cargo", "cab": "flat"})
		"ec_supply_truck":
			return truck(id, row, {"L": 7.6, "W": 2.5, "axles": 3, "body": "cargo", "cab": "hood"})
		"ec_ew_truck":
			return truck(id, row, {"L": 7.6, "W": 2.5, "axles": 3, "body": "shelter", "cab": "hood", "mast": true})
		"nc_cbr_radar":
			return truck(id, row, {"L": 8.0, "W": 2.5, "axles": 3, "body": "radar", "cab": "flat"})
		"mr_technical":
			return truck(id, row, {"L": 5.2, "W": 1.9, "axles": 2, "body": "pickup", "cab": "pickup", "rust": 0.9})
		"nc_uav_quad":
			return quad_drone(id, row)
		"nc_uav_fixed":
			return fixed_drone(id, row)
	if role in ["infantry", "at_infantry", "scout", "indirect", "support"]:
		return squad(id, row, role, faction)
	return null


# ---------------------------------------------------------------- tracked

static func tracked(id: String, row: int, p: Dictionary) -> Model:
	var md: Model = Model.new()
	md.id = id
	md.rust = p.get("rust", 0.0)
	md.dirt_height = 1.4
	var h: ForgeMesh = md.part("hull", row)
	var L: float = p["L"]
	var W: float = p["W"]
	var H: float = p["H"]
	var th: float = p["th"]
	var tw: float = W * 0.21
	var tx: float = W * 0.5 - tw * 0.5
	var wr: float = p["wr"]
	var n: int = p["wheels"]
	# tracks: convex side profile (z, y), extruded across the track width
	for side: float in [-1.0, 1.0]:
		var prof: PackedVector2Array = PackedVector2Array([
			Vector2(-L * 0.5 + 0.1, th * 0.92), Vector2(-L * 0.5 - 0.1, th * 0.62), Vector2(-L * 0.5 + 0.55, 0.0),
			Vector2(L * 0.5 - 0.55, 0.0), Vector2(L * 0.5 + 0.05, th * 0.58), Vector2(L * 0.5 - 0.15, th * 0.92)])
		h.extrude_x(prof, side * tx - tw * 0.5, side * tx + tw * 0.5, RUBBER)
		var span: float = L - 1.5
		for i: int in range(n):
			var z: float = -span * 0.5 + span * i / maxf(1.0, n - 1)
			h.wheel(Vector3(side * (W * 0.5 + 0.03), wr + 0.04, z), wr, 0.12, 9, CAMO_DARK, METAL)
		# drive sprocket (rear) and idler (front)
		h.wheel(Vector3(side * (W * 0.5 + 0.02), th * 0.62, L * 0.5 - 0.3), 0.32, 0.14, 8, METAL)
		h.wheel(Vector3(side * (W * 0.5 + 0.02), th * 0.6, -L * 0.5 + 0.3), 0.3, 0.14, 8, METAL)
		if p.get("skirts", false):
			h.box(Vector3(side * (W * 0.5 + 0.08), th * 0.48, 0.1), Vector3(0.06, th * 0.5, L * 0.86), CAMO, 0.02)
	# lower hull between tracks
	h.box(Vector3(0, 0.42, 0), Vector3(W - tw * 2.0 + 0.1, th - 0.42 + 0.05, L * 0.92), CAMO_DARK, 0.05, Vector2.ONE, Vector2.ZERO, Vector2(1.0, 0.9))
	# upper hull with glacis and fenders, full width
	var g: float = p["glacis"]
	var sz: float = 1.0 - g / L
	if p.get("ribbed", false):
		# BMP-style long ribbed glacis: a low wedge
		h.box(Vector3(0, th, 0.2), Vector3(W, H, L - 0.4), CAMO, 0.08, Vector2(0.94, 1.0 - g / (L - 0.4)), Vector2(0, g * 0.5))
		for i: int in range(4):
			var zz: float = -L * 0.5 + 0.45 + i * 0.35
			h.box(Vector3(0, th + 0.02 + i * 0.09, zz), Vector3(W * 0.8, 0.06, 0.08), CAMO_DARK, 0.01)
	else:
		h.box(Vector3(0, th, 0), Vector3(W, H, L), CAMO, 0.08, Vector2(0.96, sz), Vector2(0, g * 0.5))
	var deck: float = th + H
	# engine deck grille + rear stowage
	h.box(Vector3(0, deck - 0.02, L * 0.32), Vector3(W * 0.55, 0.08, L * 0.22), CAMO_DARK, 0.02)
	# headlights / periscope
	for side2: float in [-1.0, 1.0]:
		h.box(Vector3(side2 * W * 0.36, th + H * 0.55, -L * 0.5 + g * 0.45), Vector3(0.18, 0.14, 0.14), GLASS, 0.02)
	h.box(Vector3(W * 0.22, deck - 0.03, -L * 0.5 + g + 0.15), Vector3(0.35, 0.12, 0.25), METAL, 0.02)
	# tow cables / tools on fenders
	for side3: float in [-1.0, 1.0]:
		h.box(Vector3(side3 * (W * 0.5 - 0.15), deck, L * 0.05), Vector3(0.16, 0.12, L * 0.45), GEAR, 0.03)
	if p.get("drums", false):
		for s4: float in [-1.0, 1.0]:
			h.cyl(Vector3(s4 * W * 0.4, deck + 0.32, L * 0.5 + 0.12), Vector3(s4 * (W * 0.4 - 0.95), deck + 0.32, L * 0.5 + 0.12), 0.3, 0.3, 8, CAMO_DARK, true)
	if p.get("rear_door", false):
		h.box(Vector3(0, th + 0.1, L * 0.5 - 0.02), Vector3(W * 0.42, H * 0.8, 0.08), CAMO_DARK, 0.02)
	if p.get("boxes", false) or p.get("junk", false):
		h.box(Vector3(-W * 0.25, deck, L * 0.3), Vector3(0.9, 0.5, 0.7), CANVAS if not p.get("junk", false) else RUST, 0.05)
		h.box(Vector3(W * 0.2, deck, L * 0.38), Vector3(0.7, 0.4, 0.6), WOOD, 0.04)
	if p.get("snorkel", false):
		h.cyl(Vector3(-W * 0.42, deck + 0.1, L * 0.47), Vector3(W * 0.2, deck + 0.1, L * 0.47), 0.1, 0.1, 6, CAMO_DARK)
	if p.get("blade", false):
		var bz: float = -L * 0.5 - 0.55
		h.box(Vector3(0, 0.05, bz), Vector3(W + 0.3, 1.1, 0.3), CAMO_DARK, 0.05, Vector2(1.0, 0.6), Vector2(0, -0.15))
		for side4: float in [-1.0, 1.0]:
			h.cyl(Vector3(side4 * W * 0.3, 0.6, bz + 0.15), Vector3(side4 * W * 0.3, th + 0.2, -L * 0.5 + 0.5), 0.09, 0.09, 6, METAL)
	md.meta["muzzle"] = Vector3(0, deck + 0.5, -L * 0.5)
	md.meta["exhaust"] = Vector3(W * 0.3, deck, L * 0.5)
	md.meta["length"] = L
	if p.get("crane", false):
		h.box(Vector3(W * 0.25, deck, L * 0.1), Vector3(0.6, 0.5, 0.6), CAMO_DARK, 0.05)
		h.cyl(Vector3(W * 0.25, deck + 0.4, L * 0.1), Vector3(W * 0.25, deck + 2.1, -L * 0.25), 0.13, 0.1, 6, CAMO)
		h.cyl(Vector3(W * 0.25, deck + 2.1, -L * 0.25), Vector3(W * 0.25, deck + 1.2, -L * 0.35), 0.03, 0.03, 4, METAL)
		h.box(Vector3(-W * 0.2, deck, -L * 0.15), Vector3(1.3, 0.75, 1.4), CAMO, 0.1, Vector2(0.85, 0.8))
		h.box(Vector3(-W * 0.2, deck + 0.75, -L * 0.15), Vector3(0.5, 0.2, 0.5), METAL, 0.04)
	var tt: String = p.get("turret", "none")
	if tt == "none":
		return md
	var tz: float = p["tz"]
	md.pivots["turret"] = Vector3(0, deck, tz)
	var t: ForgeMesh = md.part("turret", row)
	var gn: ForgeMesh = md.part("gun", row)
	var tw2: float = p["tw"]
	var tl: float = p["tl"]
	var tth: float = p["tth"]
	var gun_y: float = tth * 0.5
	var gun_z: float = -tl * 0.5
	match tt:
		"wedge":
			t.box(Vector3(0, 0, 0.1), Vector3(tw2, tth, tl), CAMO, 0.08, Vector2(0.9, 0.95), Vector2(0, 0.05), Vector2(0.97, 1.0))
			for s: float in [-1.0, 1.0]:
				var b: Basis = Basis(Vector3.UP, s * 0.55)
				t.box(Vector3(0, 0, 0), Vector3(tw2 * 0.42, tth * 0.92, 1.1), CAMO, 0.05, Vector2(0.9, 0.6), Vector2(0, 0.15), Vector2.ONE, Vector2.ZERO, Transform3D(b, Vector3(s * tw2 * 0.28, 0.0, -tl * 0.5 + 0.1)))
			t.box(Vector3(0, 0, tl * 0.5 + 0.35), Vector3(tw2 * 0.85, tth * 0.75, 0.8), CAMO_DARK, 0.05)  # bustle rack
			t.box(Vector3(-tw2 * 0.25, tth, 0.3), Vector3(0.7, 0.32, 0.7), CAMO, 0.05, Vector2(0.8, 0.8))  # commander sight
			t.box(Vector3(-tw2 * 0.25, tth + 0.32, 0.3), Vector3(0.45, 0.1, 0.25), GLASS, 0.02)
			t.box(Vector3(tw2 * 0.25, tth, -0.5), Vector3(0.5, 0.25, 0.6), CAMO, 0.04)
			gun_z = -tl * 0.5 - 0.2
		"dome":
			t.blob(Vector3(0, 0, 0.1), Vector3(tw2 * 0.5, tth, tl * 0.5), 12, 6, CAMO, false, true)
			t.cyl(Vector3(-tw2 * 0.18, tth * 0.75, 0.3), Vector3(-tw2 * 0.18, tth + 0.22, 0.3), 0.38, 0.33, 8, CAMO_DARK, true)
			t.box(Vector3(tw2 * 0.22, tth * 0.82, 0.0), Vector3(0.5, 0.15, 0.55), CAMO_DARK, 0.04)
			t.box(Vector3(0.45, tth * 0.55, -tl * 0.42), Vector3(0.3, 0.25, 0.3), GLASS, 0.03)
			if p.get("era", false):
				for i: int in range(6):
					var a: float = -0.9 + i * 0.36
					var bb: Basis = Basis(Vector3.UP, -a)
					t.box(Vector3.ZERO, Vector3(0.55, 0.22, 0.35), CAMO_DARK, 0.02, Vector2(0.9, 0.7), Vector2.ZERO, Vector2.ONE, Vector2.ZERO,
						Transform3D(bb, Vector3(sin(a) * tw2 * 0.42, tth * 0.5, -cos(a) * tl * 0.42 + 0.1)))
			gun_y = tth * 0.45
			gun_z = -tl * 0.45
		"small_dome":
			t.blob(Vector3(0, 0, 0), Vector3(tw2 * 0.5, tth, tl * 0.5), 10, 6, CAMO, false, true)
			t.cyl(Vector3(0.35, tth * 0.8, 0.2), Vector3(0.35, tth + 0.12, 0.2), 0.25, 0.22, 7, CAMO_DARK, true)
			if p.get("atgm", false):
				t.cyl(Vector3(-0.2, tth + 0.2, 0.4), Vector3(-0.2, tth + 0.3, -0.9), 0.1, 0.1, 6, CAMO_DARK)
			gun_y = tth * 0.45
			gun_z = -tl * 0.45
		"box":
			t.box(Vector3(0.25, 0, 0.1), Vector3(tw2, tth, tl), CAMO, 0.07, Vector2(0.8, 0.85), Vector2(0, 0.1), Vector2(1.0, 0.9))
			t.box(Vector3(0.6, tth, 0.3), Vector3(0.55, 0.3, 0.5), CAMO_DARK, 0.04)
			t.box(Vector3(0.6, tth + 0.3, 0.2), Vector3(0.4, 0.1, 0.2), GLASS, 0.02)
			gun_z = -tl * 0.45
		"spg":
			t.box(Vector3(0, 0, 0), Vector3(tw2, tth, tl), CAMO, 0.1, Vector2(0.92, 0.9), Vector2(0, 0.1), Vector2(1.0, 1.0))
			t.box(Vector3(-tw2 * 0.25, tth, 0.6), Vector3(0.7, 0.25, 0.7), CAMO_DARK, 0.05)
			t.box(Vector3(tw2 * 0.3, tth, -0.2), Vector3(0.4, 0.15, 0.4), GLASS, 0.03)
			t.box(Vector3(0, tth * 0.1, tl * 0.5 + 0.1), Vector3(tw2 * 0.7, tth * 0.6, 0.3), GEAR, 0.04)
			gun_y = tth * 0.5
			gun_z = -tl * 0.5
		"aa":
			t.box(Vector3(0, 0, 0), Vector3(tw2, tth, tl), CAMO, 0.1, Vector2(0.88, 0.8), Vector2(0, 0.1))
			t.cyl(Vector3(0, tth, 0.7), Vector3(0, tth + 0.7, 0.7), 0.08, 0.08, 6, METAL)
			t.blob(Vector3(0, tth + 0.85, 0.75), Vector3(0.75, 0.45, 0.12), 10, 4, CAMO_DARK)
			gun_y = tth * 0.6
			gun_z = -tl * 0.5
	md.pivots["gun"] = Vector3(0, gun_y, gun_z)
	var gl: float = p["gun_l"]
	var gr: float = p["gun_r"]
	# mantlet
	if tt == "aa":
		for s2: float in [-1.0, 1.0]:
			for k: int in range(2):
				var xo: float = s2 * (0.35 + k * 0.2)
				gn.cyl(Vector3(xo, (k - 0.5) * 0.18, 0), Vector3(xo, (k - 0.5) * 0.18, -gl), gr, gr, 5, METAL)
		gn.box(Vector3(0, -0.25, 0.15), Vector3(1.4, 0.5, 0.4), CAMO_DARK, 0.05)
	else:
		gn.box(Vector3(0, -0.28, 0.15), Vector3(maxf(0.5, gr * 7.0), 0.56, 0.45), CAMO_DARK, 0.06, Vector2(0.85, 0.8))
		gn.cyl(Vector3(0, 0, 0), Vector3(0, 0, -gl), gr * 1.25, gr, 7, CAMO_DARK)
		if p.get("sleeve", false):
			gn.cyl(Vector3(0, 0, -gl * 0.15), Vector3(0, 0, -gl * 0.7), gr * 1.55, gr * 1.45, 7, CAMO)
		if p.get("evacuator", false):
			gn.cyl(Vector3(0, 0, -gl * 0.62), Vector3(0, 0, -gl * 0.78), gr * 1.6, gr * 1.6, 7, CAMO_DARK, true)
		if p.get("muzzle_brake", false):
			gn.box(Vector3(0, -gr * 1.5, -gl - 0.05), Vector3(gr * 4.0, gr * 3.0, gr * 5.0), METAL, 0.02)
		if p.get("smoke", false):
			for s3: float in [-1.0, 1.0]:
				for k2: int in range(3):
					t.cyl(Vector3(s3 * tw2 * 0.4, tth * 0.55, -tl * 0.15 + k2 * 0.18), Vector3(s3 * (tw2 * 0.4 + 0.3), tth * 0.8, -tl * 0.25 + k2 * 0.18), 0.06, 0.06, 5, CAMO_DARK)
	if tt == "box":
		gn.cyl(Vector3(0.0, 0.0, -gl * 0.55), Vector3(0, 0, -gl * 0.75), gr * 1.6, gr * 1.6, 6, CAMO_DARK)
	md.meta["muzzle"] = md.pivots["turret"] + md.pivots["gun"] + Vector3(0, 0, -gl)
	return md


# ---------------------------------------------------------------- wheeled

static func truck(id: String, row: int, p: Dictionary) -> Model:
	var md: Model = Model.new()
	md.id = id
	md.rust = p.get("rust", 0.0)
	md.dirt_height = 1.0
	var h: ForgeMesh = md.part("hull", row)
	var L: float = p["L"]
	var W: float = p["W"]
	var axles: int = p["axles"]
	var wr: float = 0.55 if W > 2.2 else 0.4
	var cab: String = p["cab"]
	# chassis
	h.box(Vector3(0, wr * 0.9, 0.1), Vector3(W * 0.55, 0.35, L * 0.9), METAL, 0.03)
	var front_axle: float = -L * 0.5 + (1.2 if cab != "hood" else 1.6)
	var rear: Array[float] = []
	if axles == 3:
		rear = [L * 0.5 - 2.0, L * 0.5 - 0.75]
	else:
		rear = [L * 0.5 - 1.0]
	var zs: Array[float] = [front_axle]
	zs.append_array(rear)
	for z: float in zs:
		for s: float in [-1.0, 1.0]:
			h.wheel(Vector3(s * (W * 0.5 - 0.25), wr, z), wr, 0.42, 10, RUBBER, CAMO_DARK)
	var bed_z0: float
	match cab:
		"flat":
			h.box(Vector3(0, wr * 1.1, -L * 0.5 + 1.0), Vector3(W, 2.0, 2.0), CAMO, 0.1, Vector2(1.0, 0.85), Vector2(0, 0.15))
			h.box(Vector3(0, wr * 1.1 + 1.25, -L * 0.5 + 0.03), Vector3(W * 0.85, 0.6, 0.06), GLASS, 0.01, Vector2(1.0, 1.0), Vector2(0, 0.1))
			h.box(Vector3(0, wr * 1.1 + 0.15, -L * 0.5 - 0.02), Vector3(W * 0.9, 0.35, 0.1), METAL, 0.02)
			bed_z0 = -L * 0.5 + 2.1
		"hood":
			h.box(Vector3(0, wr * 1.1, -L * 0.5 + 0.7), Vector3(W * 0.78, 0.95, 1.4), CAMO, 0.12, Vector2(0.85, 0.95), Vector2(0, 0.05))
			h.box(Vector3(0, wr * 1.1, -L * 0.5 + 2.0), Vector3(W, 1.85, 1.4), CAMO, 0.1, Vector2(1.0, 0.85), Vector2(0, 0.1))
			h.box(Vector3(0, wr * 1.1 + 1.15, -L * 0.5 + 1.34), Vector3(W * 0.85, 0.5, 0.06), GLASS, 0.01)
			for s2: float in [-1.0, 1.0]:
				h.box(Vector3(s2 * (W * 0.5 - 0.25), wr * 1.5, -L * 0.5 + 0.6), Vector3(0.5, 0.35, 1.3), CAMO_DARK, 0.1, Vector2(1.0, 0.7))
			bed_z0 = -L * 0.5 + 2.8
		_:
			# pickup
			h.box(Vector3(0, wr * 1.2, -L * 0.5 + 0.7), Vector3(W, 0.6, 1.4), CAMO, 0.1, Vector2(1.0, 0.95))
			h.box(Vector3(0, wr * 1.2 + 0.6, -L * 0.5 + 1.8), Vector3(W, 0.9, 1.3), CAMO, 0.1, Vector2(0.92, 0.75), Vector2(0, 0.1))
			h.box(Vector3(0, wr * 1.2 + 0.65, -L * 0.5 + 1.2), Vector3(W * 0.85, 0.7, 0.05), GLASS, 0.01, Vector2(1.0, 1.0), Vector2(0, 0.3))
			bed_z0 = -L * 0.5 + 2.5
	var bed_len: float = L * 0.5 - bed_z0 - 0.05
	var bed_c: float = bed_z0 + bed_len * 0.5
	var bed_y: float = wr * 1.15
	match p["body"]:
		"cargo":
			h.box(Vector3(0, bed_y, bed_c), Vector3(W, 0.5, bed_len), WOOD, 0.04)
			h.box(Vector3(0, bed_y + 0.5, bed_c), Vector3(W * 0.98, 1.6, bed_len * 0.98), CANVAS, 0.25, Vector2(0.92, 0.98))
			for i: int in range(3):
				h.box(Vector3(0, bed_y + 2.06, bed_c - bed_len * 0.3 + i * bed_len * 0.3), Vector3(W * 0.9, 0.06, 0.1), CANVAS, 0.02)
		"shelter":
			h.box(Vector3(0, bed_y, bed_c), Vector3(W, 2.1, bed_len), CAMO, 0.06)
			h.box(Vector3(W * 0.5 - 0.02, bed_y + 0.9, bed_c), Vector3(0.05, 0.7, 0.8), CAMO_DARK, 0.01)
			h.box(Vector3(0, bed_y + 2.1, bed_c + 0.6), Vector3(0.8, 0.3, 0.6), METAL, 0.03)
			for i2: int in range(3):
				var zz: float = bed_c - bed_len * 0.35 + i2 * bed_len * 0.35
				h.cyl(Vector3(-W * 0.3 + i2 * 0.3, bed_y + 2.1, zz), Vector3(-W * 0.3 + i2 * 0.3, bed_y + 4.2 + i2 * 0.6, zz), 0.03, 0.015, 4, METAL)
			if p.get("mast", false):
				h.cyl(Vector3(W * 0.3, bed_y + 2.1, bed_c - 0.6), Vector3(W * 0.3, bed_y + 7.5, bed_c - 0.6), 0.09, 0.05, 6, CAMO_DARK)
				h.blob(Vector3(W * 0.3, bed_y + 7.6, bed_c - 0.6), Vector3(0.45, 0.12, 0.45), 8, 4, CAMO_DARK)
				md.meta["antenna"] = Vector3(W * 0.3, bed_y + 7.7, bed_c - 0.6)
		"radar":
			h.box(Vector3(0, bed_y, bed_c), Vector3(W, 0.6, bed_len), CAMO, 0.06)
			h.cyl(Vector3(0, bed_y + 0.6, bed_c + 0.3), Vector3(0, bed_y + 1.1, bed_c + 0.3), 0.5, 0.45, 8, CAMO_DARK, true)
			var tilt: Basis = Basis(Vector3.RIGHT, 0.45)
			h.box(Vector3(0, -1.3, 0), Vector3(W * 1.05, 2.6, 0.35), CAMO, 0.05, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.ZERO,
				Transform3D(tilt, Vector3(0, bed_y + 2.45, bed_c + 0.3)))
			h.box(Vector3(0, -1.2, -0.19), Vector3(W * 0.9, 2.4, 0.03), CAMO_DARK, 0.0, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.ZERO,
				Transform3D(tilt, Vector3(0, bed_y + 2.45, bed_c + 0.3)))
			md.meta["antenna"] = Vector3(0, bed_y + 3.2, bed_c)
		"pickup":
			h.box(Vector3(0, bed_y, bed_c), Vector3(W, 0.55, bed_len), CAMO, 0.05)
			h.box(Vector3(0, bed_y + 0.55, bed_c + bed_len * 0.1), Vector3(0.6, 0.4, 0.6), RUST, 0.03)
			h.cyl(Vector3(0, bed_y + 0.9, bed_c), Vector3(0, bed_y + 1.6, bed_c), 0.05, 0.05, 5, METAL)
			h.box(Vector3(0, bed_y + 1.55, bed_c - 0.2), Vector3(0.22, 0.2, 0.8), METAL, 0.02)
			h.cyl(Vector3(0, bed_y + 1.65, bed_c - 0.5), Vector3(0, bed_y + 1.65, bed_c - 1.5), 0.04, 0.035, 5, METAL)
			h.box(Vector3(0, bed_y + 1.45, bed_c - 0.45), Vector3(0.5, 0.35, 0.04), METAL, 0.01)
			h.box(Vector3(-0.4, bed_y + 0.55, bed_c + 0.6), Vector3(0.6, 0.3, 0.5), WOOD, 0.03)
	md.meta["muzzle"] = Vector3(0, bed_y + 1.65, bed_c - 1.5)
	md.meta["exhaust"] = Vector3(W * 0.45, 2.4, -L * 0.5 + 2.1)
	md.meta["length"] = L
	return md


# ---------------------------------------------------------------- air

static func quad_drone(id: String, row: int) -> Model:
	var md: Model = Model.new()
	md.id = id
	var h: ForgeMesh = md.part("hull", row)
	h.box(Vector3(0, 0, 0), Vector3(0.35, 0.14, 0.45), CAMO_DARK, 0.04)
	h.box(Vector3(0, -0.08, -0.15), Vector3(0.12, 0.1, 0.12), GLASS, 0.02)
	for i: int in range(4):
		var a: float = PI * 0.25 + i * PI * 0.5
		var tip: Vector3 = Vector3(cos(a) * 0.55, 0.06, sin(a) * 0.55)
		h.cyl(Vector3(0, 0.06, 0), tip, 0.025, 0.025, 4, CAMO_DARK)
		h.cyl(tip, tip + Vector3(0, 0.08, 0), 0.05, 0.05, 6, METAL)
		h.cyl(tip + Vector3(0, 0.1, 0), tip + Vector3(0, 0.11, 0), 0.25, 0.25, 10, RUBBER)
	md.meta["length"] = 1.2
	return md


static func fixed_drone(id: String, row: int) -> Model:
	var md: Model = Model.new()
	md.id = id
	var h: ForgeMesh = md.part("hull", row)
	h.cyl(Vector3(0, 0.2, -1.1), Vector3(0, 0.2, 0.7), 0.16, 0.12, 8, CAMO)
	h.blob(Vector3(0, 0.2, -1.1), Vector3(0.16, 0.16, 0.3), 8, 4, CAMO)
	h.box(Vector3(0, 0.26, -0.3), Vector3(4.2, 0.05, 0.5), CAMO, 0.02, Vector2(1.0, 0.7))
	for s: float in [-1.0, 1.0]:
		h.cyl(Vector3(s * 0.55, 0.25, -0.2), Vector3(s * 0.55, 0.25, 1.4), 0.03, 0.03, 4, CAMO_DARK)
		h.box(Vector3(s * 0.55, 0.25, 1.35), Vector3(0.03, 0.35, 0.25), CAMO, 0.01)
	h.box(Vector3(0, 0.25, 1.4), Vector3(1.2, 0.03, 0.22), CAMO, 0.01)
	h.cyl(Vector3(0, 0.2, 0.7), Vector3(0, 0.2, 0.78), 0.4, 0.4, 8, RUBBER)
	h.blob(Vector3(0, 0.08, -0.6), Vector3(0.09, 0.09, 0.09), 6, 4, GLASS)
	md.meta["length"] = 2.6
	return md


# ---------------------------------------------------------------- infantry

## Squad member variants: "a" (rifleman), "b" (support weapon), optional "prop"
## (mortar / ATGM post placed beside the squad).
static func squad(id: String, row: int, role: String, faction: String) -> Model:
	var md: Model = Model.new()
	md.id = id
	md.dirt_height = 0.6
	var helmet: String = "modern" if faction == "nc" else ("steel" if faction == "ec" else "cap")
	var mask: bool = id in ["nc_decon_sqd", "ec_chem_sqd"]
	var a: ForgeMesh = md.part("soldier_a", row)
	soldier(a, helmet, "rifle", false, mask, id == "nc_recon_team" or id == "ec_recon_sqd")
	var b: ForgeMesh = md.part("soldier_b", row)
	match role:
		"at_infantry":
			soldier(b, helmet, "launcher", true, mask, false)
		"indirect":
			soldier(b, helmet, "rifle", true, mask, false)
		"support":
			soldier(b, helmet, "sprayer", false, true, false)
		_:
			soldier(b, helmet, "mg", true, mask, false)
	if role == "indirect":
		var pr: ForgeMesh = md.part("prop", row)
		pr.cyl(Vector3(0, 0.05, 0), Vector3(0, 0.15, 0), 0.4, 0.38, 8, METAL)
		pr.cyl(Vector3(0, 0.15, 0.0), Vector3(0, 1.35, -0.75), 0.07, 0.065, 7, CAMO_DARK)
		pr.cyl(Vector3(0, 0.95, -0.5), Vector3(-0.35, 0.0, -0.85), 0.025, 0.025, 4, METAL)
		pr.cyl(Vector3(0, 0.95, -0.5), Vector3(0.35, 0.0, -0.85), 0.025, 0.025, 4, METAL)
		for i: int in range(3):
			pr.box(Vector3(0.7, 0.0 + i * 0.16, 0.3), Vector3(0.45, 0.15, 0.3), WOOD, 0.02)
	elif id == "nc_atgm_team":
		var pr2: ForgeMesh = md.part("prop", row)
		for i2: int in range(3):
			var ang: float = TAU * i2 / 3.0
			pr2.cyl(Vector3(0, 0.8, 0), Vector3(cos(ang) * 0.55, 0.0, sin(ang) * 0.55), 0.025, 0.025, 4, METAL)
		pr2.cyl(Vector3(0, 0.95, 0.5), Vector3(0, 1.05, -0.9), 0.1, 0.1, 7, CAMO)
		pr2.box(Vector3(0.18, 0.8, 0.2), Vector3(0.3, 0.3, 0.4), CAMO_DARK, 0.03)
	return md


## A ~1.8 m soldier, ~250 tris. weapon: rifle | mg | launcher | sprayer.
static func soldier(m: ForgeMesh, helmet: String, weapon: String, kneel: bool, mask: bool, boonie: bool) -> void:
	var hip: float = 0.62 if kneel else 0.95
	# legs
	if kneel:
		m.box(Vector3(-0.13, 0.0, 0.25), Vector3(0.16, 0.18, 0.55), UNIFORM, 0.03)  # shin flat on ground
		m.cyl(Vector3(-0.13, 0.15, 0.0), Vector3(-0.13, hip, 0.05), 0.09, 0.1, 5, UNIFORM)
		m.cyl(Vector3(0.13, 0.05, -0.3), Vector3(0.13, 0.5, -0.28), 0.08, 0.09, 5, UNIFORM)
		m.cyl(Vector3(0.13, 0.5, -0.28), Vector3(0.13, hip, 0.05), 0.09, 0.1, 5, UNIFORM)
		m.box(Vector3(0.13, 0.0, -0.36), Vector3(0.13, 0.1, 0.26), RUBBER, 0.02)
	else:
		for s: float in [-1.0, 1.0]:
			m.cyl(Vector3(s * 0.12, 0.08, s * 0.08), Vector3(s * 0.12, hip, 0.0), 0.075, 0.1, 5, UNIFORM)
			m.box(Vector3(s * 0.12, 0.0, s * 0.08 - 0.04), Vector3(0.12, 0.1, 0.26), RUBBER, 0.02)
	# torso + vest
	m.box(Vector3(0, hip - 0.05, 0.02), Vector3(0.38, 0.62, 0.22), UNIFORM, 0.05, Vector2(1.1, 1.0))
	m.box(Vector3(0, hip + 0.08, 0.0), Vector3(0.42, 0.4, 0.28), GEAR, 0.05, Vector2(1.05, 1.0))
	if weapon == "sprayer":
		m.cyl(Vector3(0, hip + 0.05, 0.26), Vector3(0, hip + 0.6, 0.26), 0.15, 0.15, 7, CAMO_3)
	else:
		m.box(Vector3(0, hip + 0.1, 0.18), Vector3(0.32, 0.42, 0.18), GEAR, 0.05, Vector2(0.9, 0.9))
	var sh: float = hip + 0.52
	# head
	m.cyl(Vector3(0, sh, 0.0), Vector3(0, sh + 0.08, 0.0), 0.06, 0.06, 5, SKIN)
	m.blob(Vector3(0, sh + 0.2, 0.0), Vector3(0.1, 0.12, 0.11), 7, 4, SKIN if not mask else RUBBER)
	if mask:
		m.cyl(Vector3(0, sh + 0.14, -0.08), Vector3(0, sh + 0.12, -0.17), 0.05, 0.045, 5, RUBBER)
	match helmet:
		"modern":
			m.blob(Vector3(0, sh + 0.22, 0.01), Vector3(0.14, 0.13, 0.15), 8, 4, HELMET, false, true)
			m.box(Vector3(0, sh + 0.19, 0.0), Vector3(0.29, 0.04, 0.31), HELMET, 0.01)
		"steel":
			m.blob(Vector3(0, sh + 0.23, 0.0), Vector3(0.135, 0.12, 0.14), 8, 4, HELMET, false, true)
		_:
			if boonie:
				m.blob(Vector3(0, sh + 0.24, 0.0), Vector3(0.13, 0.1, 0.13), 7, 4, HELMET, false, true)
			else:
				m.blob(Vector3(0, sh + 0.24, 0.0), Vector3(0.12, 0.08, 0.12), 7, 4, CAMO_3, false, true)
				m.box(Vector3(0, sh + 0.22, -0.13), Vector3(0.18, 0.02, 0.1), CAMO_3, 0.0)
	# arms (aiming forward)
	var gun_y: float = sh - 0.05
	m.cyl(Vector3(0.21, sh - 0.02, 0.0), Vector3(0.2, gun_y - 0.12, -0.25), 0.06, 0.055, 5, UNIFORM)
	m.cyl(Vector3(0.2, gun_y - 0.12, -0.25), Vector3(0.06, gun_y - 0.02, -0.2), 0.05, 0.045, 5, UNIFORM)
	m.cyl(Vector3(-0.21, sh - 0.02, 0.0), Vector3(-0.18, gun_y - 0.15, -0.22), 0.06, 0.055, 5, UNIFORM)
	m.cyl(Vector3(-0.18, gun_y - 0.15, -0.22), Vector3(0.0, gun_y - 0.08, -0.48), 0.05, 0.045, 5, UNIFORM)
	match weapon:
		"rifle":
			m.box(Vector3(0.05, gun_y - 0.1, -0.35), Vector3(0.05, 0.12, 0.75), METAL, 0.01)
			m.box(Vector3(0.05, gun_y - 0.22, -0.3), Vector3(0.04, 0.14, 0.06), METAL, 0.0)
		"mg":
			m.box(Vector3(0.05, gun_y - 0.12, -0.4), Vector3(0.08, 0.15, 0.95), METAL, 0.01)
			m.box(Vector3(0.05, gun_y - 0.24, -0.2), Vector3(0.12, 0.12, 0.12), CAMO_DARK, 0.01)
		"launcher":
			m.cyl(Vector3(0.12, sh + 0.05, 0.45), Vector3(0.12, sh + 0.05, -0.75), 0.06, 0.06, 6, CAMO_DARK)
			m.cyl(Vector3(0.12, sh + 0.05, -0.7), Vector3(0.12, sh + 0.05, -0.95), 0.11, 0.06, 6, CAMO_DARK)
		"sprayer":
			m.cyl(Vector3(0.05, gun_y - 0.1, -0.2), Vector3(0.05, gun_y - 0.2, -0.75), 0.02, 0.02, 4, METAL)


# ---------------------------------------------------------------- structures

static func structure(id: String, w_m: float, d_m: float) -> Model:
	var md: Model = Model.new()
	md.id = id
	md.dirt_height = 0.8
	var row: int = ROW_NEUTRAL
	var m: ForgeMesh = md.part("hull", row)
	var hw: float = w_m * 0.5
	var hd: float = d_m * 0.5
	match id:
		"hq":
			m.box(Vector3(0, 0, 0), Vector3(w_m * 0.8, 1.6, d_m * 0.8), EARTH, 0.6, Vector2(0.8, 0.8))
			m.box(Vector3(-2, 1.5, 0), Vector3(9.0, 2.6, 6.0), CAMO, 0.1)
			_roof(m, Vector3(-2, 4.1, 0), 9.4, 6.4, 1.6, CANVAS)
			m.box(Vector3(5.0, 1.5, 3.0), Vector3(3.0, 2.2, 3.5), CAMO_DARK, 0.1)
			m.box(Vector3(5.0, 1.5, -3.5), Vector3(2.0, 1.4, 1.4), METAL, 0.06)
			_sandbags(m, Vector3(-hw * 0.75, 0, -hd * 0.75), Vector3(hw * 0.75, 0, -hd * 0.75), 1.2)
			_sandbags(m, Vector3(-hw * 0.75, 0, hd * 0.75), Vector3(-hw * 0.75, 0, -hd * 0.75), 1.2)
			m.cyl(Vector3(7, 1.5, -1), Vector3(7, 16, -1), 0.14, 0.06, 6, METAL)
			for i: int in range(3):
				var a: float = TAU * i / 3.0 + 0.4
				m.cyl(Vector3(7, 12, -1), Vector3(7 + cos(a) * 6.0, 0.2, -1 + sin(a) * 6.0), 0.015, 0.015, 3, METAL)
			m.cyl(Vector3(-6, 4.0, 2), Vector3(-6, 9, 2), 0.04, 0.02, 4, METAL)
			_net(m, Vector3(4, 0, 0), 9.0, 7.0, 3.6)
			md.meta["antenna"] = Vector3(7, 16, -1)
		"barracks":
			for i2: int in range(2):
				var z: float = -hd * 0.45 + i2 * hd * 0.9
				m.box(Vector3(0, 0, z), Vector3(w_m * 0.78, 2.0, 5.0), CANVAS, 0.08)
				_roof(m, Vector3(0, 2.0, z), w_m * 0.8, 5.4, 1.5, CANVAS)
				m.box(Vector3(-w_m * 0.39, 0, z), Vector3(0.1, 1.9, 1.2), CAMO_DARK, 0.01)
			m.cyl(Vector3(hw * 0.6, 3.0, 0), Vector3(hw * 0.6, 3.8, 0), 0.12, 0.12, 6, METAL)
			m.box(Vector3(-hw * 0.7, 0, 0), Vector3(1.2, 1.0, 2.5), WOOD, 0.05)
		"motor_pool":
			m.box(Vector3(0, 0, 0), Vector3(w_m * 0.9, 0.12, d_m * 0.9), CONCRETE, 0.04)
			m.box(Vector3(0, 0, hd * 0.55), Vector3(w_m * 0.85, 5.0, 0.4), CAMO, 0.06)
			for s: float in [-1.0, 1.0]:
				m.box(Vector3(s * w_m * 0.42, 0, 0), Vector3(0.4, 5.0, d_m * 0.5), CAMO, 0.06)
			m.box(Vector3(0, 5.0, hd * 0.05), Vector3(w_m * 0.88, 0.3, d_m * 0.6), CAMO_DARK, 0.06, Vector2(1.0, 1.0), Vector2(0, 0.0))
			for i3: int in range(3):
				m.box(Vector3(-w_m * 0.3 + i3 * w_m * 0.3, 0, hd * 0.3), Vector3(0.3, 5.0, 0.3), METAL, 0.03)
			_drums(m, Vector3(hw * 0.75, 0, -hd * 0.65), 5)
			m.box(Vector3(-hw * 0.7, 0, -hd * 0.6), Vector3(2.0, 1.2, 1.5), WOOD, 0.05)
		"artillery_park":
			for i4: int in range(2):
				var x: float = -hw * 0.45 + i4 * hw * 0.9
				m.box(Vector3(x, 0, hd * 0.35), Vector3(9.0, 1.5, 1.8), EARTH, 0.4, Vector2(0.85, 0.6))
				m.box(Vector3(x - 4.2, 0, -hd * 0.1), Vector3(1.8, 1.5, 9.0), EARTH, 0.4, Vector2(0.6, 0.85))
				m.box(Vector3(x + 4.2, 0, -hd * 0.1), Vector3(1.8, 1.5, 9.0), EARTH, 0.4, Vector2(0.6, 0.85))
				_crates(m, Vector3(x, 0, -hd * 0.1), 3, 2)
			_net(m, Vector3(0, 0, -hd * 0.65), 12.0, 4.0, 2.5)
		"repair_yard":
			m.box(Vector3(0, 0, 0), Vector3(w_m * 0.9, 0.12, d_m * 0.9), CONCRETE, 0.04)
			for s2: float in [-1.0, 1.0]:
				var x2: float = s2 * hw * 0.55
				m.cyl(Vector3(x2, 0, -4.5), Vector3(x2, 7.0, -0.2), 0.18, 0.18, 6, CAMO)
				m.cyl(Vector3(x2, 0, 4.5), Vector3(x2, 7.0, 0.2), 0.18, 0.18, 6, CAMO)
			m.box(Vector3(0, 6.8, 0), Vector3(w_m * 0.62, 0.5, 0.5), CAMO_DARK, 0.05)
			m.cyl(Vector3(-2, 6.8, 0), Vector3(-2, 3.6, 0), 0.03, 0.03, 4, METAL)
			m.box(Vector3(-2, 2.6, 0), Vector3(1.4, 1.0, 1.0), METAL, 0.08)
			m.box(Vector3(hw * 0.7, 0, -hd * 0.6), Vector3(2.4, 2.2, 2.0), CAMO, 0.08)
			_drums(m, Vector3(-hw * 0.7, 0, hd * 0.65), 4)
		"supply_depot":
			_crates(m, Vector3(-hw * 0.45, 0, -hd * 0.3), 4, 3)
			_crates(m, Vector3(-hw * 0.45, 0, hd * 0.4), 3, 2)
			_drums(m, Vector3(hw * 0.35, 0, hd * 0.45), 9)
			m.blob(Vector3(hw * 0.4, 0, -hd * 0.3), Vector3(4.0, 1.3, 2.4), 10, 6, RUBBER, false, true)
			m.box(Vector3(0, 0, 0), Vector3(3.0, 2.0, 2.4), CANVAS, 0.08)
			_roof(m, Vector3(0, 2.0, 0), 3.2, 2.6, 0.9, CANVAS)
		"trench":
			m.box(Vector3(0, 0.0, 0), Vector3(w_m * 0.85, 0.06, 1.6), EARTH, 0.0)
			for s3: float in [-1.0, 1.0]:
				_sandbags(m, Vector3(-hw * 0.85, 0, s3 * 1.3), Vector3(hw * 0.85, 0, s3 * 1.3), 0.7)
			m.box(Vector3(-hw * 0.3, 0, -2.6), Vector3(4.0, 0.5, 1.4), EARTH, 0.3, Vector2(0.8, 0.5))
		"vehicle_pit":
			m.box(Vector3(0, 0, -hd * 0.7), Vector3(w_m * 0.8, 1.7, 3.0), EARTH, 0.6, Vector2(0.8, 0.3))
			for s4: float in [-1.0, 1.0]:
				m.box(Vector3(s4 * hw * 0.72, 0, 0.5), Vector3(2.6, 1.5, d_m * 0.65), EARTH, 0.6, Vector2(0.3, 0.85))
			m.box(Vector3(0, 0.0, 0.5), Vector3(w_m * 0.55, 0.04, d_m * 0.6), EARTH, 0.0)
		"tank_trap":
			for i5: int in range(4):
				_hedgehog(m, Vector3(-hw * 0.75 + i5 * hw * 0.5, 0, (i5 % 2) * 1.5 - 0.75))
		"depot_objective":
			m.box(Vector3(0, 0, 1), Vector3(w_m * 0.7, 5.5, d_m * 0.5), CONCRETE, 0.1)
			_roof(m, Vector3(0, 5.5, 1), w_m * 0.72, d_m * 0.52, 1.2, RUST)
			for i6: int in range(3):
				m.box(Vector3(-w_m * 0.22 + i6 * w_m * 0.22, 0, 1 - d_m * 0.25 - 0.05), Vector3(2.6, 3.4, 0.12), RUST, 0.02)
			m.box(Vector3(0, 0, -d_m * 0.12), Vector3(w_m * 0.72, 1.1, 2.5), CONCRETE, 0.06)
			for c: Vector2 in [Vector2(-hw * 0.85, -hd * 0.85), Vector2(hw * 0.85, hd * 0.85)]:
				_tower(m, Vector3(c.x, 0, c.y))
			for i7: int in range(10):
				var xx: float = -hw * 0.9 + i7 * w_m * 0.1
				m.cyl(Vector3(xx, 0, -hd * 0.95), Vector3(xx, 2.2, -hd * 0.95), 0.06, 0.06, 4, WOOD)
			m.box(Vector3(0, 1.5, -hd * 0.95), Vector3(w_m * 0.9, 0.04, 0.04), METAL, 0.0)
			m.box(Vector3(0, 2.0, -hd * 0.95), Vector3(w_m * 0.9, 0.04, 0.04), METAL, 0.0)
			_crates(m, Vector3(hw * 0.6, 0, -hd * 0.55), 2, 2)
		"field_hospital":
			for i8: int in range(2):
				var x3: float = -hw * 0.42 + i8 * hw * 0.84
				m.box(Vector3(x3, 0, 0), Vector3(8.0, 2.2, d_m * 0.7), CANVAS, 0.08)
				_roof(m, Vector3(x3, 2.2, 0), 8.4, d_m * 0.72, 1.4, CANVAS)
				m.box(Vector3(x3, 3.62, 0), Vector3(2.6, 0.05, 2.6), MARK, 0.0, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.ZERO, Transform3D.IDENTITY, ROW_NEUTRAL)
			m.box(Vector3(0, 0, -hd * 0.7), Vector3(2.2, 1.0, 1.4), WOOD, 0.05)
		"decon_point":
			m.box(Vector3(0, 0, 0), Vector3(w_m * 0.85, 0.1, 6.0), CONCRETE, 0.03)
			for i9: int in range(3):
				var x4: float = -hw * 0.5 + i9 * hw * 0.5
				m.cyl(Vector3(x4, 0, -3.0), Vector3(x4, 4.2, -3.0), 0.08, 0.08, 5, METAL)
				m.cyl(Vector3(x4, 0, 3.0), Vector3(x4, 4.2, 3.0), 0.08, 0.08, 5, METAL)
				m.cyl(Vector3(x4, 4.2, -3.0), Vector3(x4, 4.2, 3.0), 0.07, 0.07, 5, METAL)
			m.cyl(Vector3(hw * 0.7, 0, -hd * 0.6), Vector3(hw * 0.7, 3.0, -hd * 0.6), 1.3, 1.3, 10, CAMO, true)
			m.box(Vector3(-hw * 0.7, 0, hd * 0.6), Vector3(2.5, 2.2, 2.0), CANVAS, 0.08)
			m.box(Vector3(-hw * 0.7, 0, -hd * 0.6), Vector3(1.5, 1.0, 1.0), METAL, 0.05)
	return md


static func _roof(m: ForgeMesh, base: Vector3, w: float, d: float, h: float, sw: int) -> void:
	m.box(base, Vector3(w, h, d), sw, 0.0, Vector2(1.0, 0.02))


static func _sandbags(m: ForgeMesh, a: Vector3, b: Vector3, height: float) -> void:
	var len: float = a.distance_to(b)
	var n: int = maxi(1, int(len / 0.95))
	var dir: Vector3 = (b - a) / maxf(0.01, len)
	var yaw: float = atan2(-dir.x, -dir.z)
	var layers: int = maxi(1, int(height / 0.3))
	for l: int in range(layers):
		for i: int in range(n):
			if (i + l) % 2 == 1 and i == n - 1:
				continue
			var p: Vector3 = a + dir * (len * (i + 0.5 + (l % 2) * 0.5) / n)
			m.box(Vector3.ZERO, Vector3(0.5, 0.3, 0.92), EARTH, 0.1, Vector2(0.85, 0.85), Vector2.ZERO, Vector2.ONE, Vector2.ZERO,
				Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, l * 0.3, 0)))


static func _crates(m: ForgeMesh, c: Vector3, nx: int, nz: int) -> void:
	for i: int in range(nx):
		for j: int in range(nz):
			var hgt: int = 1 + (i * 7 + j * 3) % 3
			for k: int in range(hgt):
				m.box(c + Vector3((i - nx * 0.5 + 0.5) * 1.35, k * 0.75, (j - nz * 0.5 + 0.5) * 1.0), Vector3(1.25, 0.72, 0.9), WOOD if (i + j + k) % 3 != 0 else CAMO_DARK, 0.04)


static func _drums(m: ForgeMesh, c: Vector3, n: int) -> void:
	for i: int in range(n):
		var p: Vector3 = c + Vector3((i % 3) * 0.65 - 0.65, 0, (i / 3) * 0.65)
		m.cyl(p, p + Vector3(0, 0.9, 0), 0.29, 0.29, 8, RUST if i % 4 == 0 else CAMO_DARK, true)


static func _net(m: ForgeMesh, c: Vector3, w: float, d: float, h: float) -> void:
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.cyl(c + Vector3(s.x * w * 0.42, 0, s.y * d * 0.42), c + Vector3(s.x * w * 0.42, h, s.y * d * 0.42), 0.05, 0.05, 4, WOOD)
	m.blob(c + Vector3(0, h - 0.4, 0), Vector3(w * 0.55, 0.55, d * 0.55), 10, 6, CAMO_3, false, true, 0.12, 3)


static func _hedgehog(m: ForgeMesh, c: Vector3) -> void:
	for k: int in range(3):
		var b: Basis = Basis(Vector3.UP, k * TAU / 3.0) * Basis(Vector3.RIGHT, 0.95)
		m.box(Vector3(0, -0.9, 0), Vector3(0.14, 1.8, 0.14), RUST, 0.02, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.ZERO, Transform3D(b, c + Vector3(0, 0.65, 0)))


static func _tower(m: ForgeMesh, c: Vector3) -> void:
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.cyl(c + Vector3(s.x * 1.1, 0, s.y * 1.1), c + Vector3(s.x * 0.8, 6.5, s.y * 0.8), 0.08, 0.08, 4, WOOD)
	m.box(c + Vector3(0, 6.5, 0), Vector3(2.2, 1.2, 2.2), WOOD, 0.04)
	m.box(c + Vector3(0, 7.7, 0), Vector3(2.6, 0.8, 2.6), RUST, 0.0, Vector2(0.05, 0.05))
