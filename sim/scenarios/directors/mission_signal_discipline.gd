# SIM: deterministic — no floats, no Nodes
## Act I, mission 3: Signal Discipline. Hidden Eastern guns shell the base.
## Find them by direction finding and counter-battery radar, then kill them.
class_name MissionSignalDiscipline
extends ScenarioDirector

const KIT: Dictionary = {"nc": ["nc_recon_team", "nc_recon_team", "nc_rifle_sqd", "nc_rifle_sqd", "nc_mbt_2a", "nc_mbt_2a", "nc_spg_155", "nc_spg_155", "nc_cbr_radar"]}
const SHELL_INTERVAL: int = 600

var hq: int = 0
var guns: PackedInt32Array = PackedInt32Array()
var screen: PackedInt32Array = PackedInt32Array()
var _o_find: int = 0
var _o_kill: int = 0
var _o_hq: int = 0


func setup(world: SimWorld, settings: MatchSettings) -> void:
	title = "Act I, 3: Signal Discipline"
	briefing = "Eastern guns are shelling the corridor from somewhere in the eastern woods. They are well hidden. Every time they fire, they transmit. Find them and silence them."
	world.hq_required = false
	rng = SimRng.new(settings.match_seed ^ 0x51)
	enemy = world.add_player(1, "ec", true)
	player = enemy
	hq = base_for_humans(world, world.grid.width / 10, world.grid.height / 2, KIT, 600)
	var w_mm: int = world.map_width_mm()
	var h_mm: int = world.map_height_mm()
	for k: int in range(3):
		var g: PackedInt32Array = spawn_group(world, enemy, ["ec_spg_122"], w_mm * 8 / 10, h_mm * (25 + k * 25) / 100, SimConst.ANGLE_HALF)
		guns.append_array(g)
	screen = spawn_group(world, enemy, ["ec_motor_rifle", "ec_motor_rifle", "ec_rpg_team", "ec_ew_truck", "ec_ifv_2"], w_mm * 6 / 10, h_mm / 2, SimConst.ANGLE_HALF, 60000)
	for id: int in guns:
		world.units.emcon[id] = UnitStore.EMCON_SILENT
	_o_find = add_objective(world, "Fix the position of an enemy gun")
	_o_kill = add_objective(world, "Destroy all three guns")
	_o_hq = add_objective(world, "Keep the command post standing")
	say(world, briefing)
	say(world, "Press V for the signal overlay: bearings and fixes from your HQ and recon teams. The radar truck fixes guns the moment they fire. Select your SPGs and press B for automatic counter-battery fire.")


func step(world: SimWorld, tick: int) -> void:
	if world.winner_team >= 0 or tick % 10 != 0:
		return
	if not has_hq(world, 0):
		fail(world, _o_hq)
		finish(world, 1)
		return
	var live: PackedInt32Array = alive(world, guns)
	if objective_state[_o_find] == OPEN:
		var intel: SignalIntel = world.signals[0]
		for em: int in intel.fixes():
			if guns.has(em) and int(intel.fix_r[em]) <= FireMissionCommand.MAX_FIX_RADIUS_MM:
				complete(world, _o_find)
				say(world, "Gun located. Fire on the fix, or call an airstrike if someone can see it.")
				break
	if live.is_empty():
		complete(world, _o_find)
		complete(world, _o_kill)
		complete(world, _o_hq)
		finish(world, 0)
		return
	# the battery fires on the base every so often, one gun at a time
	if tick % SHELL_INTERVAL == 0 and tick > 300 and hq != 0 and world.is_unit(hq):
		var g: int = live[(tick / SHELL_INTERVAL) % live.size()]
		var cmd: FireMissionCommand = FireMissionCommand.new(PackedInt32Array([g]), world.transform.x[hq] + rng.range_int(-60000, 60000), world.transform.y[hq] + rng.range_int(-60000, 60000), 3)
		cmd.player_id = enemy
		cmd.tick = tick
		if cmd.validate(world):
			cmd.apply(world)
