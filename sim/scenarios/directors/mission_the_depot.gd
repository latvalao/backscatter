# SIM: deterministic — no floats, no Nodes
## Act I, mission 2: The Depot. Build a forward base, take two depots and hold
## them through three counterattacks while the plant leaks.
class_name MissionTheDepot
extends ScenarioDirector

const KIT: Dictionary = {"nc": ["nc_engineer_veh", "nc_supply_truck", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_ifv_90", "nc_mbt_2a"]}
const WAVE_TICKS: Array[int] = [6000, 8000, 10000]
const WAVES: Array = [
	["ec_motor_rifle", "ec_motor_rifle", "ec_ifv_2", "ec_ifv_2"],
	["ec_motor_rifle", "ec_rpg_team", "ec_ifv_2", "ec_mbt_72", "ec_motor_rifle"],
	["ec_mbt_72", "ec_mbt_72", "ec_ifv_2", "ec_motor_rifle", "ec_motor_rifle", "ec_rpg_team"],
]

var hq: int = 0
var depots: PackedInt32Array = PackedInt32Array()
var attackers: PackedInt32Array = PackedInt32Array()
var wave: int = 0
var _o_base: int = 0
var _o_depots: int = 0
var _o_hold: int = 0


func setup(world: SimWorld, _settings: MatchSettings) -> void:
	title = "Act I, 2: The Depot"
	briefing = "The corridor road is open. Set up a forward base, take the two depots on the road and hold them. Expect a counterattack, and watch the wind: the plant is not stable."
	world.hq_required = false
	enemy = world.add_player(1, "ec", true)
	player = enemy
	hq = base_for_humans(world, world.grid.width / 10, world.grid.height / 2, KIT, 1200)
	var dd: UnitStats = world.defs.unit("depot_objective")
	for fx: int in [45, 62]:
		var site: Vector2i = MatchSetup.find_site(world, dd, world.grid.width * fx / 100, world.grid.height * (40 + fx / 4) / 100, 30)
		if site.x >= 0:
			depots.append(world.spawn_structure(dd, SimWorld.NEUTRAL_TEAM, -1, site.x, site.y, true))
	world.radfield.add_source(7000, 8800, world.plant_x, world.plant_y, 1_100_000)
	var pts: Array = []
	for d: int in depots:
		pts.append(Vector2i(world.transform.x[d], world.transform.y[d]))
	mark(pts)
	_o_base = add_objective(world, "Build a barracks and a motor pool")
	_o_depots = add_objective(world, "Capture both depots")
	_o_hold = add_objective(world, "Hold at least one depot through three counterattacks")
	say(world, briefing)
	say(world, "Select the engineer vehicle: its build buttons are on the right (F1 to F8). Select a finished building to produce units; right-click the map to set its rally point.")


func step(world: SimWorld, tick: int) -> void:
	if world.winner_team >= 0 or tick % 10 != 0:
		return
	if not has_hq(world, 0):
		finish(world, 1)
		return
	if objective_state[_o_base] == OPEN and Economy.structures_of(world, 0, "barracks").size() > 0 and Economy.structures_of(world, 0, "motor_pool").size() > 0:
		complete(world, _o_base)
		say(world, "Supply trucks carry depot stock home along the roads. Keep one alive.")
	var held: int = 0
	for d: int in depots:
		if world.structures.holder_team[d] == 0:
			held += 1
	if objective_state[_o_depots] == OPEN and held == depots.size():
		complete(world, _o_depots)
	if wave < WAVE_TICKS.size() and tick >= WAVE_TICKS[wave]:
		var fresh: PackedInt32Array = spawn_group(world, enemy, WAVES[wave], world.map_width_mm() - 80000, world.map_height_mm() / 2, SimConst.ANGLE_HALF)
		attackers.append_array(fresh)
		wave += 1
		say(world, "Counterattack %d of 3 coming down the road from the east." % wave)
		if wave == 2:
			say(world, "Radiation release at the plant. Press D for the dosimetry map; Ctrl+right-click routes around hot ground.")
	if tick % 300 == 0 and not depots.is_empty():
		var tgt: int = depots[(tick / 300) % depots.size()]
		attack(world, alive(world, attackers), world.transform.x[tgt], world.transform.y[tgt])
	if wave >= WAVE_TICKS.size() and alive(world, attackers).is_empty() and tick % 50 == 0:
		if held >= 1:
			complete(world, _o_hold)
			finish(world, 0)
		else:
			fail(world, _o_hold)
			finish(world, 1)
