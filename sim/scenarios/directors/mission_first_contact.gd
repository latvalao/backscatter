# SIM: deterministic — no floats, no Nodes
## Act I, mission 1: First Contact. Doubles as the tutorial: each objective
## comes with the controls it needs.
class_name MissionFirstContact
extends ScenarioDirector

var force: PackedInt32Array = PackedInt32Array()
var outpost: PackedInt32Array = PackedInt32Array()
var depot: int = 0
var ifv: int = 0
var stage: int = 0
var jx: int = 0
var jy: int = 0


func setup(world: SimWorld, settings: MatchSettings) -> void:
	title = "Act I, 1: First Contact"
	briefing = "Coalition recon platoon, border corridor. Intelligence reports an Eastern outpost on the road ahead, guarding a supply depot we need."
	world.hq_required = false
	rng = SimRng.new(settings.match_seed)
	enemy = world.add_player(1, "ec", true)
	player = enemy
	var w_mm: int = world.map_width_mm()
	var h_mm: int = world.map_height_mm()
	force = spawn_group(world, 0, ["nc_recon_team", "nc_rifle_sqd", "nc_rifle_sqd", "nc_ifv_90"], w_mm / 8, h_mm / 2, 0)
	ifv = force[3]
	jx = w_mm * 3 / 10
	jy = h_mm / 2
	var dd: UnitStats = world.defs.unit("depot_objective")
	var site: Vector2i = MatchSetup.find_site(world, dd, w_mm * 7 / 10 / SimGrid.CELL_MM, h_mm / 2 / SimGrid.CELL_MM, 30)
	if site.x >= 0:
		depot = world.spawn_structure(dd, SimWorld.NEUTRAL_TEAM, -1, site.x, site.y, true)
	outpost = spawn_group(world, enemy, ["ec_motor_rifle", "ec_motor_rifle", "ec_ifv_2"], w_mm * 7 / 10 - 60000, h_mm / 2 + 40000, SimConst.ANGLE_HALF)
	say(world, briefing)
	_next(world)


func _next(world: SimWorld) -> void:
	stage += 1
	match stage:
		1:
			add_objective(world, "Move your platoon to the road junction (marked on the minimap)")
			mark([Vector2i(jx, jy)])
			say(world, "Left-click or drag a box to select. Right-click the ground to move. Drag with the right button to set the direction they face on arrival.")
		2:
			add_objective(world, "Put a rifle squad in the IFV")
			mark([])
			say(world, "Select a rifle squad and right-click the IFV to board. U unloads on the spot, T drives to a point and unloads there.")
		3:
			add_objective(world, "Find the enemy outpost")
			mark([Vector2i(world.map_width_mm() * 6 / 10, world.map_height_mm() / 2)])
			say(world, "Recon teams see furthest. Hold L to check what a unit would see from the cursor. Far contacts show as '?' until you get closer.")
		4:
			add_objective(world, "Destroy the outpost")
			say(world, "A then left-click: attack-move. Y sets the range to open fire at, so your anti-tank team waits for a sure shot. H holds fire.")
		5:
			add_objective(world, "Capture the depot with infantry")
			if depot != 0:
				mark([Vector2i(world.transform.x[depot], world.transform.y[depot])])
			say(world, "Infantry captures depots by standing next to them. A held depot earns supply.")


func step(world: SimWorld, tick: int) -> void:
	if world.winner_team >= 0 or tick % 10 != 0:
		return
	if alive(world, force).is_empty() and stage < 6:
		finish(world, 1)
		return
	match stage:
		1:
			if count_near(world, 0, jx, jy, 150000) >= 2:
				complete(world, 0)
				_next(world)
		2:
			for id: int in force:
				if world.is_unit(id) and world.units.carrier[id] != 0:
					complete(world, 1)
					_next(world)
					break
		3:
			for e: int in outpost:
				if world.is_unit(e) and world.vision[0].is_visible(e, tick):
					complete(world, 2)
					_next(world)
					break
		4:
			if alive(world, outpost).is_empty():
				complete(world, 3)
				_next(world)
		5:
			if depot != 0 and world.structures.holder_team[depot] == 0:
				complete(world, 4)
				stage = 6
				say(world, "Depot secured. Well done.")
				finish(world, 0)
	# the outpost reacts once it is found
	if stage >= 4 and tick % 200 == 0:
		attack(world, alive(world, outpost), world.transform.x[force[0]] if world.is_unit(force[0]) else jx, jy)
