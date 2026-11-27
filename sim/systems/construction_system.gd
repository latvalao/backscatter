# SIM: deterministic — no floats, no Nodes
## Tick phase 9a: construction sites advance while builders (units with a BUILD
## order on the site, within build range) work on them. Engineers build at full
## rate; infantry (trenches) at infantry_build_rate_percent.
class_name ConstructionSystem
extends SimSystem


func step(world: SimWorld, tick: int) -> void:
	var o: OrderStore = world.orders
	var s: StructureStore = world.structures
	var range_mm: int = Economy.mm(world, "build_range_m")
	var inf_rate: int = world.defs.rule("infantry_build_rate_percent")
	# accumulate work per site in builder-id order (deterministic)
	var work: Dictionary = {}  # site id -> percent-ticks of work this tick
	for id: int in world.entities.ids():
		if not o.has(id) or o.kind[id] != OrderStore.BUILD or not world.is_unit(id):
			continue
		var site: int = o.target[id]
		if not world.is_unit(site) or not s.has(site) or s.build_left[site] <= 0:
			Orders.finish(world, id)
			continue
		if Economy.dist_to_structure(world, site, world.transform.x[id], world.transform.y[id]) > range_mm:
			continue
		var rate: int = inf_rate if world.def_of(id).is_infantry else 100
		work[site] = int(work.get(site, 0)) + rate
	var sites: Array = work.keys()
	sites.sort()
	for site: int in sites:
		var def: UnitStats = world.def_of(site)
		var w: int = work[site]
		# build_left counts in 1/100 builder-ticks
		s.build_left[site] = maxi(0, s.build_left[site] - w)
		var total: int = maxi(1, def.build_time_ticks * 100)
		var done: int = total - s.build_left[site]
		world.units.hp[site] = maxi(world.units.hp[site], def.hp / 10 + (def.hp * 9 / 10) * done / total)
		if s.build_left[site] == 0:
			world.units.hp[site] = def.hp
			world.emit(SimEvent.Type.BUILT, site, 0, def.index)
			for id: int in world.entities.ids():
				if o.has(id) and o.kind[id] == OrderStore.BUILD and o.target[id] == site:
					Orders.finish(world, id)


## Placement check (§5.2): footprint on buildable ground (field/road/urban for
## buildings; trenches and obstacles also on bog), no other structure, no units.
static func can_place(world: SimWorld, def: UnitStats, cx: int, cy: int) -> bool:
	if not def.is_structure:
		return false
	var g: SimGrid = world.grid
	if cx < 0 or cy < 0 or cx + def.footprint_w > g.width or cy + def.footprint_h > g.height:
		return false
	for c: int in world.footprint_cells(def, cx, cy):
		if world.occupancy[c] != 0:
			return false
		var t: int = g.terrain[c]
		var ok: bool = t == TerrainTable.FIELD or t == TerrainTable.ROAD or t == TerrainTable.URBAN
		if not ok and def.blocks_mask == 0 and t == TerrainTable.BOG:
			ok = true
		if not ok:
			return false
	# no units standing in a blocking footprint
	if def.blocks_mask != 0:
		var x0: int = cx * SimGrid.CELL_MM - 2000
		var y0: int = cy * SimGrid.CELL_MM - 2000
		var x1: int = (cx + def.footprint_w) * SimGrid.CELL_MM + 2000
		var y1: int = (cy + def.footprint_h) * SimGrid.CELL_MM + 2000
		for id: int in world.entities.ids():
			if not world.mobility.has(id) or not world.is_unit(id) or world.is_air(id):
				continue
			var x: int = world.transform.x[id]
			var y: int = world.transform.y[id]
			if x >= x0 and x <= x1 and y >= y0 and y <= y1:
				return false
	return true
