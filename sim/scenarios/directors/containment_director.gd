# SIM: deterministic — no floats, no Nodes
## Containment (design §4): co-op defence of a position beside the plant
## against escalating assaults while the fallout gets worse. Survive the last
## wave to win; lose the command post and it is over.
class_name ContainmentDirector
extends ScenarioDirector

var waves: int = 10
const FIRST_WAVE: int = 1200
const WAVE_GAP: int = 1500
const KIT: Dictionary = {
	"nc": ["nc_engineer_veh", "nc_supply_truck", "nc_rifle_sqd", "nc_rifle_sqd", "nc_atgm_team", "nc_ifv_90", "nc_mbt_2a", "nc_mortar_team"],
	"ec": ["ec_engineer_veh", "ec_supply_truck", "ec_motor_rifle", "ec_motor_rifle", "ec_rpg_team", "ec_ifv_2", "ec_mbt_72", "ec_mortar_team"],
}
## Unit pool per wave stage (index grows with the wave number).
const POOL: Array = [
	["ec_motor_rifle", "ec_motor_rifle", "ec_recon_sqd"],
	["ec_motor_rifle", "ec_rpg_team", "ec_ifv_2"],
	["ec_ifv_2", "ec_motor_rifle", "ec_mbt_72", "ec_rpg_team"],
	["ec_mbt_72", "ec_ifv_2", "ec_motor_rifle", "ec_mortar_team", "ec_mbt_72"],
]

var wave: int = 0
var hq: int = 0
var hq_x: int = 0
var hq_y: int = 0
var attackers: PackedInt32Array = PackedInt32Array()
var _obj_waves: int = 0
var _obj_hq: int = 0


func setup(world: SimWorld, settings: MatchSettings) -> void:
	title = "Containment"
	briefing = "Hold the line at Kaarnavaara. Assaults come every few minutes and grow heavier, and every one of them stirs up the plant. Dig in, keep the command post alive, rotate irradiated crews."
	rng = SimRng.new(settings.match_seed ^ 0xC0FFEE)
	world.hq_required = false
	human_team = 0
	enemy = world.add_player(1, "ec", true)
	player = enemy
	var px: int = world.plant_x
	var py: int = world.plant_y
	hq = base_for_humans(world, (px - 500000) / SimGrid.CELL_MM, (py - 700000) / SimGrid.CELL_MM, KIT, 1500)
	if hq != 0:
		hq_x = world.transform.x[hq]
		hq_y = world.transform.y[hq]
	_obj_waves = add_objective(world, "Survive %d assaults" % waves)
	_obj_hq = add_objective(world, "Keep the command post standing")
	say(world, briefing)


func step(world: SimWorld, tick: int) -> void:
	if world.winner_team >= 0:
		return
	if tick % 10 == 0 and not has_hq(world, human_team):
		fail(world, _obj_hq)
		finish(world, 1)
		return
	if wave < waves and tick >= FIRST_WAVE + wave * WAVE_GAP:
		_launch(world)
	if tick % 300 == 150 and not attackers.is_empty():
		attackers = alive(world, attackers)
		attack(world, attackers, hq_x, hq_y)
	if wave >= waves and tick % 50 == 0 and alive(world, attackers).is_empty():
		complete(world, _obj_waves)
		complete(world, _obj_hq)
		finish(world, human_team)


func _launch(world: SimWorld) -> void:
	wave += 1
	var stage: Array = POOL[mini(POOL.size() - 1, (wave - 1) / 3)]
	var count: int = 3 + wave * 2
	var ids: Array = []
	for i: int in range(count):
		ids.append(stage[(i + wave) % stage.size()])
	# from a random edge away from the defenders
	var side: int = rng.range_int(0, 2)
	var w_mm: int = world.map_width_mm()
	var h_mm: int = world.map_height_mm()
	var sx: int = [w_mm - 60000, 60000, w_mm / 2 + rng.range_int(-w_mm / 4, w_mm / 4)][side]
	var sy: int = [h_mm / 2 + rng.range_int(-h_mm / 4, h_mm / 4), h_mm / 2 + rng.range_int(-h_mm / 4, h_mm / 4), h_mm - 60000][side]
	var fresh: PackedInt32Array = spawn_group(world, enemy, ids, sx, sy, FixedMath.atan2_b(hq_y - sy, hq_x - sx))
	attackers.append_array(fresh)
	attack(world, fresh, hq_x, hq_y)
	# the plant stirs: a fresh release with every assault
	world.radfield.add_source(world.tick, world.tick + 900, world.plant_x, world.plant_y, 300_000 + wave * 60_000)
	say(world, "Assault %d of %d inbound: %d units from the %s." % [wave, waves, fresh.size(), ["east", "west", "north"][side]])
