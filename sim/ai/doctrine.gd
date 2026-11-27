# SIM: deterministic — no floats, no Nodes
## AI doctrine profiles (§6): Coalition = recon-first, standoff, precision,
## safe routing; Eastern = mass, barrage, EW; Marauders = ambush and raid.
class_name Doctrine
extends RefCounted

var faction: String = "nc"
var build_order: Array[String] = []
## Production weights by unit role (higher = more of it).
var weights: Dictionary = {}
var recon_first: bool = false
var barrage: bool = false
var use_ew: bool = false
var use_drones: bool = false
var safe_routing: bool = false
var shoot_and_scoot: bool = false
## Attack once own strength / known enemy strength exceeds this (permille).
var attack_ratio: int = 1200
var min_attack_size: int = 8


static func for_faction(f: String) -> Doctrine:
	var d: Doctrine = Doctrine.new()
	d.faction = f
	match f:
		"nc":
			d.build_order = ["barracks", "motor_pool", "supply_depot", "repair_yard", "artillery_park", "field_hospital"]
			d.weights = {"mbt": 2, "ifv": 3, "infantry": 4, "at_infantry": 3, "scout": 1, "artillery": 1, "indirect": 1}
			d.recon_first = true
			d.use_drones = true
			d.safe_routing = true
			d.shoot_and_scoot = true
			d.attack_ratio = 1300
			d.min_attack_size = 8
		"ec":
			d.build_order = ["barracks", "motor_pool", "artillery_park", "supply_depot", "decon_point", "repair_yard"]
			d.weights = {"mbt": 4, "ifv": 3, "infantry": 4, "at_infantry": 2, "scout": 1, "artillery": 2, "indirect": 2, "ew": 1, "air_defence": 1, "support": 1}
			d.barrage = true
			d.use_ew = true
			d.attack_ratio = 1000
			d.min_attack_size = 12
		_:
			d.attack_ratio = 700
			d.min_attack_size = 4
	return d
