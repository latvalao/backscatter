# SIM: deterministic — no floats, no Nodes
## Builds the starting world for a match from MatchSettings. Runs identically on
## every peer, so nothing here may depend on local state.
class_name MatchSetup
extends RefCounted

const NC_SANDBOX: Array[String] = ["nc_mbt_2a", "nc_mbt_2a", "nc_mbt_2a", "nc_mbt_2a", "nc_ifv_90", "nc_ifv_90",
	"nc_ifv_90", "nc_ifv_90", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd",
	"nc_rifle_sqd", "nc_atgm_team", "nc_atgm_team", "nc_recon_team", "nc_recon_team", "nc_mortar_team",
	"nc_mortar_team", "nc_spg_155", "nc_spg_155", "nc_supply_truck", "nc_supply_truck"]
const EC_SANDBOX: Array[String] = ["ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72",
	"ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_motor_rifle", "ec_motor_rifle",
	"ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle",
	"ec_rpg_team", "ec_rpg_team", "ec_rpg_team", "ec_recon_sqd", "ec_recon_sqd", "ec_mortar_team", "ec_mortar_team",
	"ec_spg_122", "ec_spg_122"]
const START_KIT: Dictionary = {
	"nc": ["nc_engineer_veh", "nc_supply_truck", "nc_rifle_sqd", "nc_rifle_sqd", "nc_recon_team", "nc_ifv_90"],
	"ec": ["ec_engineer_veh", "ec_supply_truck", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_recon_sqd", "ec_ifv_2"],
}


static func create(settings: MatchSettings, defs: DefDb, grid: SimGrid = null) -> SimWorld:
	if grid == null:
		grid = MapGen.generate(settings.map_seed, settings.map_cells, settings.map_cells, settings.symmetric and settings.mode == "skirmish")
	var w: SimWorld = SimWorld.new(settings.match_seed, defs, grid)
	for p: Dictionary in settings.players:
		w.add_player(p["team"], p["faction"], p["ai"], int(p.get("battlegroup", 0)))
	if settings.mode == "skirmish" and settings.marauders:
		w.add_player(2, "mr", true)
	_fallout(w, settings)
	if settings.mode == "sandbox":
		_sandbox(w, settings)
	else:
		_skirmish(w, settings)
	w.drain_events()
	# re-emit spawns so presentation that attaches later sees every entity
	for id: int in w.entities.ids():
		w.emit(SimEvent.Type.SPAWNED, id, 0, w.units.def_index[id], w.transform.x[id], w.transform.y[id])
	return w


static func _sandbox(w: SimWorld, settings: MatchSettings) -> void:
	for p: int in range(w.players.count()):
		var team: int = w.players.team[p]
		var list: Array[String] = NC_SANDBOX if w.players.faction[p] == "nc" else EC_SANDBOX
		for i: int in range(list.size()):
			var x: int
			var heading: int = 0
			if team == 0:
				x = (500 + (i / 6) * 60) * 1000
			else:
				x = (3500 - (i / 7) * 60) * 1000
				heading = SimConst.ANGLE_HALF
			var y: int = (1850 + (i % 6) * 60) * 1000 if team == 0 else (1800 + (i % 7) * 60) * 1000
			w.spawn_unit(w.defs.unit(list[i]), team, p, x * w.grid.width / 500, y * w.grid.height / 500, heading)
		if w.players.is_ai[p] == 1:
			var ai: SandboxOpponent = SandboxOpponent.new()
			ai.player = p
			w.ai.append(ai)


static func _skirmish(w: SimWorld, settings: MatchSettings) -> void:
	w.hq_required = true
	var g: SimGrid = w.grid
	# per-team slot counters so teammates spread north/south
	var slot: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for p: int in range(w.players.count()):
		if w.players.faction[p] == "mr":
			continue
		var team: int = w.players.team[p]
		var cx: int = g.width / 10 if team == 0 else g.width - g.width / 10
		var off: int = [0, 1, -1, 2][slot[team]] * g.height / 5
		slot[team] += 1
		var cy: int = g.height / 2 + off
		var hq_def: UnitStats = w.defs.unit("hq")
		var site: Vector2i = find_site(w, hq_def, cx, cy, 60)
		if team == 1:
			# mirror of the matching team-0 slot when the map is symmetric
			var west: Vector2i = find_site(w, hq_def, g.width / 10, g.height - cy, 60)
			var mirrored: Vector2i = Vector2i(g.width - west.x - hq_def.footprint_w, g.height - west.y - hq_def.footprint_h)
			if west.x >= 0 and ConstructionSystem.can_place(w, hq_def, mirrored.x, mirrored.y):
				site = mirrored
		if site.x < 0:
			continue
		var hq: int = w.spawn_structure(hq_def, team, p, site.x, site.y, true)
		var kit: Array = START_KIT[w.players.faction[p]]
		var hx: int = w.transform.x[hq]
		var hy: int = w.transform.y[hq]
		var face: int = 0 if team == 0 else SimConst.ANGLE_HALF
		var dir: int = 1 if team == 0 else -1
		for i: int in range(kit.size()):
			var ux: int = hx + dir * (50_000 + (i / 3) * 30_000)
			var uy: int = hy + ((i % 3) - 1) * 30_000
			w.spawn_unit(w.defs.unit(String(kit[i])), team, p, ux, uy, face)
		if w.players.is_ai[p] == 1:
			var diff: int = int(settings.players[p].get("difficulty", 1))
			if diff < 0:
				var dummy: SkirmishAi = SkirmishAi.new()
				dummy.player = p
				dummy.aggressive = false
				w.ai.append(dummy)
			else:
				w.ai.append(CommanderAi.new(p, w.players.faction[p], diff))
	# neutral depots along the roads: mirrored pairs (west / rotated east) + one central
	var depot: UnitStats = w.defs.unit("depot_objective")
	var fx: Array[int] = [25, 37]
	var fy: Array[int] = [50, 28]
	for k: int in range(fx.size()):
		var tx: int = g.width * fx[k] / 100
		var ty: int = g.height * fy[k] / 100
		var road: int = _nearest_road(g, tx, ty, 60)
		var bx: int = g.cell_x(road) if road >= 0 else tx
		var by: int = g.cell_y(road) if road >= 0 else ty
		# beside the road, not on it, so the route stays open
		var s: Vector2i = find_site(w, depot, bx + 2, by + 2, 30)
		if s.x < 0:
			continue
		w.spawn_structure(depot, SimWorld.NEUTRAL_TEAM, -1, s.x, s.y, true)
		var mx: int = g.width - s.x - depot.footprint_w
		var my: int = g.height - s.y - depot.footprint_h
		if ConstructionSystem.can_place(w, depot, mx, my):
			w.spawn_structure(depot, SimWorld.NEUTRAL_TEAM, -1, mx, my, true)
	var cs: Vector2i = find_site(w, depot, g.width / 2 - 1, g.height / 2 - 1, 30)
	if cs.x >= 0:
		w.spawn_structure(depot, SimWorld.NEUTRAL_TEAM, -1, cs.x, cs.y, true)
	# Marauders: hostile to everyone, camps in the woods
	for p: int in range(w.players.count()):
		if w.players.faction[p] == "mr":
			var m: MarauderAi = MarauderAi.new()
			m.player = p
			m.setup(w, 3, SimRng.new(settings.match_seed ^ 0x3A7))
			w.ai.append(m)


## Nearest valid placement origin to (cx, cy), scanning square rings outward.
static func find_site(w: SimWorld, def: UnitStats, cx: int, cy: int, max_r: int) -> Vector2i:
	for r: int in range(0, max_r + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				if ConstructionSystem.can_place(w, def, cx + dx, cy + dy):
					return Vector2i(cx + dx, cy + dy)
	return Vector2i(-1, -1)


static func _nearest_road(g: SimGrid, cx: int, cy: int, max_r: int) -> int:
	for r: int in range(0, max_r + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				if g.in_grid(cx + dx, cy + dy) and g.terrain[g.index(cx + dx, cy + dy)] == TerrainTable.ROAD:
					return g.index(cx + dx, cy + dy)
	return -1


## Baked contamination (§5.4): the plant's hot zone north of the map centre,
## forest/bog pockets, plus a scripted sarcophagus breach plume mid-match.
static func _fallout(w: SimWorld, settings: MatchSettings) -> void:
	var g: SimGrid = w.grid
	var rng: SimRng = SimRng.new(settings.map_seed * 7919 + 13)
	var wmm: int = g.width_mm()
	var hmm: int = g.height_mm()
	# plant hot zone
	var px: int = wmm / 2 + rng.range_int(-wmm / 10, wmm / 10)
	var py: int = hmm * 4 / 5
	w.radfield.add_hotspot(px, py, wmm / 8, 9_000_000)
	w.radfield.add_hotspot(px, py, wmm / 30, 30_000_000)
	# pockets: prefer forest / bog cells
	var placed: int = 0
	var tries: int = 0
	while placed < 6 and tries < 400:
		tries += 1
		var cx: int = rng.range_int(g.width / 6, g.width * 5 / 6)
		var cy: int = rng.range_int(g.height / 8, g.height * 7 / 8)
		var t: int = g.terrain[g.index(cx, cy)]
		if t != TerrainTable.FOREST and t != TerrainTable.BOG:
			continue
		w.radfield.add_hotspot(cx * SimGrid.CELL_MM, cy * SimGrid.CELL_MM, rng.range_int(80_000, 220_000), rng.range_int(2_000_000, 7_000_000))
		placed += 1
	# sarcophagus breach: a 3-minute release starting 8–14 minutes in
	var start: int = rng.range_int(4800, 8400)
	w.radfield.add_source(start, start + 1800, px, py, 900_000)
	w.plant_x = px
	w.plant_y = py
