# SIM: deterministic — no floats, no Nodes
## Operations (design §4): replayable co-op missions picked from templates by
## the match seed. "secure": take and hold three depots against an Eastern
## commander; "raid": destroy an EW and artillery group near the plant.
## ("hold": a short Containment, built by MatchSetup.)
class_name OperationsDirector
extends ScenarioDirector

const KIT: Dictionary = {
	"nc": ["nc_engineer_veh", "nc_supply_truck", "nc_rifle_sqd", "nc_rifle_sqd", "nc_recon_team", "nc_ifv_90", "nc_ifv_90", "nc_mbt_2a"],
	"ec": ["ec_engineer_veh", "ec_supply_truck", "ec_motor_rifle", "ec_motor_rifle", "ec_recon_sqd", "ec_ifv_2", "ec_ifv_2", "ec_mbt_72"],
}
const HOLD_TICKS: int = 3000

var template: String = "secure"
var depots: PackedInt32Array = PackedInt32Array()
var targets: PackedInt32Array = PackedInt32Array()
var held_since: int = -1
var _o_main: int = 0


func setup(world: SimWorld, settings: MatchSettings) -> void:
	world.hq_required = false
	rng = SimRng.new(settings.match_seed ^ 0x0F)
	enemy = world.add_player(1, "ec", true)
	player = enemy
	base_for_humans(world, world.grid.width / 10, world.grid.height / 2, KIT, 1200)
	if template == "secure":
		title = "Operation: Secure the Road"
		briefing = "Three depots sit on the corridor road. Take all three and hold them together for five minutes. An Eastern commander will contest them."
		var dd: UnitStats = world.defs.unit("depot_objective")
		for k: int in range(3):
			var site: Vector2i = MatchSetup.find_site(world, dd, world.grid.width * (35 + k * 15) / 100, world.grid.height * (35 + rng.range_int(0, 30)) / 100, 30)
			if site.x >= 0:
				depots.append(world.spawn_structure(dd, SimWorld.NEUTRAL_TEAM, -1, site.x, site.y, true))
		var hq_def: UnitStats = world.defs.unit("hq")
		var es: Vector2i = MatchSetup.find_site(world, hq_def, world.grid.width * 9 / 10, world.grid.height / 2, 60)
		if es.x >= 0:
			world.spawn_structure(hq_def, 1, enemy, es.x, es.y, true)
			spawn_group(world, enemy, ["ec_engineer_veh", "ec_supply_truck", "ec_motor_rifle", "ec_motor_rifle", "ec_ifv_2", "ec_mbt_72"], es.x * SimGrid.CELL_MM - 60000, es.y * SimGrid.CELL_MM, SimConst.ANGLE_HALF)
			world.ai.append(CommanderAi.new(enemy, "ec", CommanderAi.NORMAL))
		_o_main = add_objective(world, "Hold all three depots at once for 5 minutes")
		var pts: Array = []
		for d: int in depots:
			pts.append(Vector2i(world.transform.x[d], world.transform.y[d]))
		mark(pts)
	else:
		title = "Operation: Raid on Kaarnavaara"
		briefing = "An Eastern EW and artillery group works from the edge of the plant zone. Get in, destroy it and get out before the dose gets you."
		var px: int = world.plant_x
		var py: int = world.plant_y
		targets = spawn_group(world, enemy, ["ec_ew_truck", "ec_spg_122", "ec_spg_122", "ec_spaa_23"], px + 200000, py - 250000, SimConst.ANGLE_HALF, 50000)
		spawn_group(world, enemy, ["ec_motor_rifle", "ec_motor_rifle", "ec_rpg_team", "ec_ifv_2", "ec_mbt_72"], px, py - 450000, 0 - SimConst.ANGLE_QUARTER, 60000)
		_o_main = add_objective(world, "Destroy the EW truck, both guns and the air defence vehicle")
		mark([Vector2i(px + 200000, py - 250000)])
	say(world, briefing)


func step(world: SimWorld, tick: int) -> void:
	if world.winner_team >= 0 or tick % 10 != 0:
		return
	if not has_hq(world, human_team):
		fail(world, _o_main)
		finish(world, 1)
		return
	if template == "secure":
		var all_held: bool = not depots.is_empty()
		for d: int in depots:
			all_held = all_held and world.structures.holder_team[d] == human_team
		if all_held and held_since < 0:
			held_since = tick
			say(world, "All three depots held. Five minutes to go.")
		elif not all_held and held_since >= 0:
			held_since = -1
			say(world, "A depot was lost. The clock resets.")
		if held_since >= 0 and tick - held_since >= HOLD_TICKS:
			complete(world, _o_main)
			finish(world, human_team)
	elif alive(world, targets).is_empty():
		complete(world, _o_main)
		finish(world, human_team)
