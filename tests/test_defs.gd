extends TestCase


func test_rosters_load_with_integer_stats() -> void:
	var db: DefDb = DefLoader.load_default()
	for id: String in ["nc_rifle_sqd", "nc_atgm_team", "nc_recon_team", "nc_mortar_team", "nc_ifv_90", "nc_mbt_2a", "nc_spg_155",
			"ec_motor_rifle", "ec_rpg_team", "ec_recon_sqd", "ec_mortar_team", "ec_ifv_2", "ec_mbt_72", "ec_spg_122"]:
		assert_true(db.unit_index(id) >= 0, "missing " + id)
	var mbt: UnitStats = db.unit("nc_mbt_2a")
	assert_eq(typeof(mbt.max_speed), TYPE_INT)
	assert_eq(mbt.max_speed, 1806, "65 km/h -> mm/tick")
	assert_eq(mbt.armour_front, 650)
	assert_eq(mbt.crew_count(), 4)
	assert_eq(mbt.radius_mm, 3400)
	assert_eq(mbt.vision_thermal_mm, 3_500_000)
	assert_eq(db.unit("ec_mbt_72").crew_count(), 3, "autoloader: no loader")
	var gun: WeaponStats = db.weapon("nc_gun_120")
	assert_eq(gun.reload_ticks, 60)
	assert_eq(gun.aim_ticks, 15)
	assert_eq(gun.projectile_speed, 160000)
	assert_eq(db.weapon("ec_atgm_wire").guidance, WeaponStats.GUIDE_WIRE)


func test_accuracy_falloff() -> void:
	var gun: WeaponStats = DefLoader.load_default().weapon("nc_gun_120")
	assert_eq(gun.accuracy_at(0), 920)
	assert_eq(gun.accuracy_at(gun.range_max_mm), 560)
	assert_eq(gun.accuracy_at(gun.range_max_mm / 2), 740)
