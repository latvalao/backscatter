# SIM: deterministic — no floats, no Nodes
## Tick phase 8 (§5.4): weather + plume update (every 10 ticks), dose accrual
## (every tick), contamination pickup/decay, decontamination, field hospital
## treatment, NBC overpressure, and radiation casualties at Critical.
class_name RadiationSystem
extends SimSystem

const FIELD_INTERVAL: int = 10
const CARE_INTERVAL: int = 20
const NBC_THRESHOLD: int = 1000          # µSv/h at which overpressure switches on
const NBC_FUEL_PER_TICK: int = 15        # mL
const CONTAM_THRESHOLD: int = 500        # ground µSv/h that starts contaminating units
const CASUALTY_INTERVAL: int = 600       # ticks between losses while Critical
const DECON_POINT_RADIUS_MM: int = 40000
const DECON_SQUAD_RADIUS_MM: int = 30000
const HOSPITAL_RADIUS_MM: int = 60000
const REPAIR_BLOCK_CONTAMINATION: int = 200


func step(world: SimWorld, tick: int) -> void:
	var field: RadiationField = world.radfield
	if tick % FIELD_INTERVAL == 0:
		world.weather.step(tick)
		field.step(tick, world.weather.wind_x(), world.weather.wind_y(), world.weather.raining)
	var r: RadiationStore = world.radiation
	var t: TransformStore = world.transform
	var pickup: bool = tick % FIELD_INTERVAL == 0
	for id: int in world.entities.ids():
		if not r.has(id) or not world.is_unit(id):
			continue
		var def: UnitStats = world.def_of(id)
		var rate: int = field.rate_at(t.x[id], t.y[id])
		var pf: int = protection_factor(world, id, def, rate)
		var rem: int = r.remainder[id] + (rate + r.contamination[id]) / pf
		r.dose[id] += rem / 36000
		r.remainder[id] = rem % 36000
		if pickup:
			_contaminate(world, id, rate)
		if DoseState.of(r.dose[id]) == DoseState.CRITICAL:
			_critical(world, id, def, tick)
	if tick % CARE_INTERVAL == 0:
		_decontaminate(world)
		_hospital(world)


## Protection factor (§5.4): unit PF × fortification × NBC overpressure.
static func protection_factor(world: SimWorld, id: int, def: UnitStats, rate: int) -> int:
	var pf: int = def.protection_factor
	var car: int = world.units.carrier[id]
	if car != 0 and world.units.has(car):
		pf = maxi(pf, world.def_of(car).protection_factor)
	var t: TransformStore = world.transform
	var cover: int = world.fortification_cover(t.x[id], t.y[id], def.is_infantry)
	if cover > 0:
		pf *= 3 if def.is_infantry else 2
	if def.nbc and rate >= NBC_THRESHOLD and world.logistics.has(id) and world.logistics.fuel[id] > 0:
		pf *= 2
		world.logistics.fuel[id] = maxi(0, world.logistics.fuel[id] - NBC_FUEL_PER_TICK)
	return maxi(1, pf)


func _contaminate(world: SimWorld, id: int, rate: int) -> void:
	var r: RadiationStore = world.radiation
	var ground: int = world.radfield.ground[world.radfield.index_at(world.transform.x[id], world.transform.y[id])]
	var c: int = r.contamination[id]
	if ground >= CONTAM_THRESHOLD and world.mobility.has(id) and world.mobility.speed[id] != 0:
		# driving through hot ground picks up dust: up to 5% of the cell's rate
		c = mini(maxi(c, ground / 20), c + ground / 200)
	else:
		c -= c / 500 + (1 if c > 0 else 0)  # slow natural weathering
	r.contamination[id] = maxi(0, c)


func _critical(world: SimWorld, id: int, def: UnitStats, tick: int) -> void:
	var r: RadiationStore = world.radiation
	if r.next_casualty[id] == 0:
		r.next_casualty[id] = tick + CASUALTY_INTERVAL
		return
	if tick < r.next_casualty[id]:
		return
	r.next_casualty[id] = tick + CASUALTY_INTERVAL
	if def.is_infantry:
		Combat._wound_random_member(world, id, 100000, 0)
	elif def.crew_slots != 0:
		Combat._kill_random_crew(world, id)
		if world.units.crew[id] == 0:
			world.destroy_entity(id)
	world.emit(SimEvent.Type.RADIATION_CASUALTY, id)


## Decon points and CBRN/chemical troops strip contamination (costs supply at points).
func _decontaminate(world: SimWorld) -> void:
	var r: RadiationStore = world.radiation
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		var points: PackedInt32Array = Economy.structures_of(world, team, "decon_point")
		var squads: PackedInt32Array = PackedInt32Array()
		for id: int in world.team_units[team]:
			if not world.is_structure(id) and world.def_of(id).has_ability("decon"):
				squads.append(id)
		if points.is_empty() and squads.is_empty():
			continue
		for id: int in world.team_units[team]:
			if not r.has(id) or r.contamination[id] <= 0:
				continue
			var x: int = world.transform.x[id]
			var y: int = world.transform.y[id]
			var done: bool = false
			for p: int in points:
				var owner: int = world.units.owner[p]
				if Economy.dist_to_structure(world, p, x, y) <= DECON_POINT_RADIUS_MM and world.players.supply[owner] >= 2:
					world.players.supply[owner] -= 2
					r.contamination[id] = r.contamination[id] * 3 / 4
					done = true
					break
			if done:
				continue
			for s: int in squads:
				if s != id and FixedMath.dist2_sq(x, y, world.transform.x[s], world.transform.y[s]) <= DECON_SQUAD_RADIUS_MM * DECON_SQUAD_RADIUS_MM:
					r.contamination[id] = r.contamination[id] * 85 / 100
					break


## Field hospitals recover Exposed / Mild crews over time (§5.4).
func _hospital(world: SimWorld) -> void:
	var r: RadiationStore = world.radiation
	for team: int in range(SimWorld.MAX_TEAMS):
		if team == SimWorld.NEUTRAL_TEAM:
			continue
		var hospitals: PackedInt32Array = Economy.structures_of(world, team, "field_hospital")
		if hospitals.is_empty():
			continue
		for id: int in world.team_units[team]:
			if not r.has(id) or r.dose[id] <= 0:
				continue
			var state: int = DoseState.of(r.dose[id])
			if state > DoseState.MILD:
				continue
			for hsp: int in hospitals:
				var owner: int = world.units.owner[hsp]
				if Economy.dist_to_structure(world, hsp, world.transform.x[id], world.transform.y[id]) <= HOSPITAL_RADIUS_MM \
						and world.players.supply[owner] >= 1:
					world.players.supply[owner] -= 1
					r.dose[id] = maxi(0, r.dose[id] - maxi(2000, r.dose[id] / 50))
					break
