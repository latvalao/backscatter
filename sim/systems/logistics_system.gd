# SIM: deterministic — no floats, no Nodes
## Tick phase 9d: resupply (ammo + fuel) near friendly HQ / supply depots / loaded
## supply trucks, truck loading at depots and unloading at logistics nodes,
## repair at repair yards or by engineers, and manpower regeneration.
## (Fuel is consumed by MovementSystem as units drive.)
class_name LogisticsSystem
extends SimSystem

const MANPOWER_INTERVAL: int = 100


func step(world: SimWorld, tick: int) -> void:
	var interval: int = Economy.ticks(world, "resupply_interval_s")
	if tick % interval == 0:
		_trucks(world)
		_resupply(world)
		_repair(world)
	if tick > 0 and tick % MANPOWER_INTERVAL == 0:
		var regen: int = world.defs.rule("manpower_regen_per_min") * MANPOWER_INTERVAL / 600
		var cap: int = world.defs.rule("manpower_cap")
		for p: int in range(world.players.count()):
			world.players.manpower[p] = mini(cap, world.players.manpower[p] + regen)


## Trucks haul depot stock to the FOB, and top their resupply cargo up there
## (paid from the owner's SUPPLY).
func _trucks(world: SimWorld) -> void:
	var r: int = Economy.mm(world, "truck_transfer_radius_m")
	var rate: int = world.defs.rule("truck_transfer_per_interval")
	var depots: PackedInt32Array = ObjectiveSystem._depots(world)
	var lg: LogisticsStore = world.logistics
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		for id: int in world.team_units[team]:
			var def: UnitStats = world.def_of(id)
			if def.cargo_capacity <= 0 or not lg.has(id):
				continue
			var x: int = world.transform.x[id]
			var y: int = world.transform.y[id]
			var owner: int = world.units.owner[id]
			for d: int in depots:
				if world.structures.holder_team[d] != team or world.structures.stock[d] <= 0:
					continue
				if Economy.dist_to_structure(world, d, x, y) <= r:
					var take: int = mini(rate, mini(world.structures.stock[d], def.cargo_capacity - lg.haul[id]))
					world.structures.stock[d] -= take
					lg.haul[id] += take
			for node: int in world.team_units[team]:
				if not Economy.is_logistics_node(world, node, team) or Economy.dist_to_structure(world, node, x, y) > r:
					continue
				var give: int = mini(rate, lg.haul[id])
				lg.haul[id] -= give
				world.players.supply[owner] += give
				var top: int = mini(rate, mini(def.cargo_capacity - lg.cargo[id], world.players.supply[owner]))
				if top > 0:
					lg.cargo[id] += top
					world.players.supply[owner] -= top
				break


func _resupply(world: SimWorld) -> void:
	var r: int = Economy.mm(world, "resupply_radius_m")
	var pct: int = world.defs.rule("resupply_percent")
	var cost_pct: int = world.defs.rule("resupply_cost_percent")
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		var nodes: PackedInt32Array = PackedInt32Array()
		var trucks: PackedInt32Array = PackedInt32Array()
		for id: int in world.team_units[team]:
			if Economy.is_logistics_node(world, id, team):
				nodes.append(id)
			elif world.logistics.has(id) and world.def_of(id).has_ability("resupply"):
				trucks.append(id)
		if nodes.is_empty() and trucks.is_empty():
			continue
		for id: int in world.team_units[team]:
			if world.is_structure(id) or not world.logistics.has(id):
				continue
			var def: UnitStats = world.def_of(id)
			if not _needs_supply(world, id, def):
				continue
			var cost: int = maxi(1, def.cost_supply * cost_pct / 100)
			var x: int = world.transform.x[id]
			var y: int = world.transform.y[id]
			var owner: int = world.units.owner[id]
			var paid: bool = false
			for node: int in nodes:
				if Economy.dist_to_structure(world, node, x, y) <= r and world.players.supply[owner] >= cost:
					world.players.supply[owner] -= cost
					paid = true
					break
			if not paid:
				for tr: int in trucks:
					if tr == id or world.logistics.cargo[tr] < cost:
						continue
					var dx: int = world.transform.x[tr] - x
					var dy: int = world.transform.y[tr] - y
					if dx * dx + dy * dy <= r * r:
						world.logistics.cargo[tr] -= cost
						paid = true
						break
			if paid:
				_restore(world, id, def, pct)


static func _needs_supply(world: SimWorld, id: int, def: UnitStats) -> bool:
	if def.fuel_capacity > 0 and world.logistics.fuel[id] < def.fuel_capacity:
		return true
	for s: int in range(def.weapons.size()):
		var w: WeaponStats = world.defs.weapons[def.weapons[s]]
		if world.weapons.ammo[id * WeaponStore.MAX_WEAPONS + s] < w.ammo_capacity:
			return true
	return false


static func _restore(world: SimWorld, id: int, def: UnitStats, pct: int) -> void:
	if def.fuel_capacity > 0:
		world.logistics.fuel[id] = mini(def.fuel_capacity, world.logistics.fuel[id] + maxi(1, def.fuel_capacity * pct / 100))
	for s: int in range(def.weapons.size()):
		var w: WeaponStats = world.defs.weapons[def.weapons[s]]
		var k: int = id * WeaponStore.MAX_WEAPONS + s
		world.weapons.ammo[k] = mini(w.ammo_capacity, world.weapons.ammo[k] + maxi(1, w.ammo_capacity * pct / 100))


func _repair(world: SimWorld) -> void:
	var yard_r: int = Economy.mm(world, "repair_radius_m")
	var eng_r: int = Economy.mm(world, "engineer_repair_radius_m")
	var pct: int = world.defs.rule("repair_percent")
	var cost_pct: int = world.defs.rule("repair_cost_percent")
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		var yards: PackedInt32Array = Economy.structures_of(world, team, "repair_yard")
		var engineers: PackedInt32Array = PackedInt32Array()
		for id: int in world.team_units[team]:
			if not world.is_structure(id) and world.def_of(id).has_ability("repair") and world.orders.kind[id] == OrderStore.NONE:
				engineers.append(id)
		if yards.is_empty() and engineers.is_empty():
			continue
		for id: int in world.team_units[team]:
			var def: UnitStats = world.def_of(id)
			if def.is_infantry:
				continue
			if world.is_structure(id) and not world.structures.is_complete(id):
				continue
			var damaged: bool = world.units.hp[id] < def.hp or world.units.damage[id] != 0
			if not damaged:
				continue
			if world.radiation.has(id) and world.radiation.contamination[id] > RadiationSystem.REPAIR_BLOCK_CONTAMINATION:
				continue  # §5.1: decontaminate before repair
			var x: int = world.transform.x[id]
			var y: int = world.transform.y[id]
			var near: bool = false
			if not world.is_structure(id):
				for yard: int in yards:
					if Economy.dist_to_structure(world, yard, x, y) <= yard_r:
						near = true
						break
			if not near:
				for e: int in engineers:
					if e == id:
						continue
					var d: int = Economy.dist_to_structure(world, id, world.transform.x[e], world.transform.y[e]) if world.is_structure(id) \
						else FixedMath.length2(world.transform.x[e] - x, world.transform.y[e] - y)
					if d <= eng_r:
						near = true
						break
			if not near:
				continue
			var owner: int = world.units.owner[id]
			var cost: int = maxi(1, def.cost_supply * cost_pct / 100)
			if world.players.supply[owner] < cost:
				continue
			world.players.supply[owner] -= cost
			world.units.hp[id] = mini(def.hp, world.units.hp[id] + maxi(1, def.hp * pct / 100))
			# components come back once the hull is above half
			var dmg: int = world.units.damage[id]
			if dmg != 0 and world.units.hp[id] * 2 >= def.hp:
				world.units.damage[id] = dmg & (dmg - 1)  # clear lowest damaged component
