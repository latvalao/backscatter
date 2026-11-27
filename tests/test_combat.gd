## M2 combat tests: armour facing, penetration, accuracy, suppression,
## spotting, wire guidance, indirect fire, smoke.
extends TestCase

var w: SimWorld


func before_each() -> void:
	w = SimFixture.world(SimFixture.flat_grid(128, 128))


func test_facing_front_side_rear() -> void:
	# target at origin facing east (heading 0)
	assert_eq(Combat.facing(0, 0, 0, 1000, 0), Combat.FACE_FRONT)
	assert_eq(Combat.facing(0, 0, 0, 1000, 900), Combat.FACE_FRONT, "within 45°")
	assert_eq(Combat.facing(0, 0, 0, 0, 1000), Combat.FACE_SIDE)
	assert_eq(Combat.facing(0, 0, 0, 0, -1000), Combat.FACE_SIDE)
	assert_eq(Combat.facing(0, 0, 0, -1000, 0), Combat.FACE_REAR)
	assert_eq(Combat.facing(0, 0, 0, -1000, 900), Combat.FACE_REAR, "within 45° of rear")
	# target facing north: shooter to the north hits the front
	assert_eq(Combat.facing(16384, 0, 0, 0, 5000), Combat.FACE_FRONT)
	assert_eq(Combat.facing(16384, 0, 0, 5000, 0), Combat.FACE_SIDE)


func test_penetration_by_face() -> void:
	var mbt: UnitStats = w.defs.unit("ec_mbt_72")
	var atgm: WeaponStats = w.defs.weapon("nc_atgm_ff")
	var ac: WeaponStats = w.defs.weapon("nc_ac_40")
	assert_true(Combat.penetrates(atgm.penetration, Combat.armour_for(mbt, Combat.FACE_FRONT)), "ATGM defeats MBT front")
	assert_false(Combat.penetrates(ac.penetration, Combat.armour_for(mbt, Combat.FACE_FRONT)), "40 mm bounces off MBT front")
	assert_false(Combat.penetrates(ac.penetration, Combat.armour_for(mbt, Combat.FACE_SIDE)), "40 mm vs MBT side (110)")
	assert_true(Combat.penetrates(ac.penetration, Combat.armour_for(mbt, Combat.FACE_REAR)), "40 mm defeats MBT rear")
	var ifv: UnitStats = w.defs.unit("ec_ifv_2")
	assert_true(Combat.penetrates(ac.penetration, Combat.armour_for(ifv, Combat.FACE_FRONT)), "40 mm defeats IFV front")


func test_apply_hit_front_vs_rear_on_tank() -> void:
	var gun: WeaponStats = w.defs.weapon("nc_ac_40")
	var tank: int = SimFixture.spawn(w, "ec_mbt_72", 1, 500, 500, 0)  # facing east
	var hp0: int = w.units.hp[tank]
	# from the front (east): non-penetrating, chip damage
	Combat.apply_hit(w, tank, gun, 900000, 500000, 0)
	assert_eq(w.units.hp[tank], hp0 - gun.damage / 20)
	# from the rear (west): penetrates
	var hp1: int = w.units.hp[tank]
	Combat.apply_hit(w, tank, gun, 100000, 500000, 0)
	assert_true(w.units.hp[tank] <= hp1 - gun.damage * 800 / 1000)


func test_infantry_hit_kills_soldiers_and_suppresses() -> void:
	var sq: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 500, 500)
	var mg: WeaponStats = w.defs.weapon("ec_pkm")
	for i: int in range(4):
		Combat.apply_hit(w, sq, mg, 100000, 500000, 0)
	assert_true(w.units.members_alive[sq] < 9)
	assert_true(w.units.suppression[sq] >= 4 * mg.suppression - 1)
	assert_true(w.units.morale[sq] < w.defs.unit("ec_motor_rifle").morale)


func test_squad_destroyed_when_all_members_die() -> void:
	var sq: int = SimFixture.spawn(w, "nc_atgm_team", 0, 500, 500)
	var gun: WeaponStats = w.defs.weapon("ec_gun_125")
	for i: int in range(20):
		Combat.apply_hit(w, sq, gun, 100000, 500000, 0)
	assert_false(w.is_unit(sq))
	w.step()
	assert_false(w.entities.is_alive(sq))


func test_hit_chance_modifiers() -> void:
	var shooter: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 100, 500)
	var tank: int = SimFixture.spawn(w, "ec_mbt_72", 1, 1100, 500)
	var sq: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 1100, 520)
	var gun: WeaponStats = w.defs.weapon("nc_gun_120")
	var vs_tank: int = Combat.hit_chance(w, shooter, tank, gun, 1_000_000)
	var vs_inf: int = Combat.hit_chance(w, shooter, sq, gun, 1_000_000)
	assert_true(vs_inf < vs_tank, "infantry is a smaller target")
	w.units.suppression[shooter] = 800
	assert_true(Combat.hit_chance(w, shooter, tank, gun, 1_000_000) < vs_tank, "suppression hurts accuracy")


func test_spotting_range_and_forest_concealment() -> void:
	var g: SimGrid = SimGrid.new(400, 40)
	for y: int in range(40):
		for x: int in range(300, 320):
			g.terrain[g.index(x, y)] = TerrainTable.FOREST
	g.rebuild_sectors()
	var w2: SimWorld = SimFixture.world(g)
	var obs: int = SimFixture.spawn(w2, "ec_motor_rifle", 1, 1500, 160)  # 1.3 km day optics
	var near: int = SimFixture.spawn(w2, "nc_mbt_2a", 0, 600, 160)       # 900 m, open field
	var far: int = SimFixture.spawn(w2, "nc_mbt_2a", 0, 40, 160)         # 1.46 km: out of range
	var hidden: int = SimFixture.spawn(w2, "nc_rifle_sqd", 0, 2490, 200) # 1 km, 10 m inside forest edge
	SimFixture.run(w2, 6)
	var v: TeamVision = w2.vision[1]
	assert_true(v.is_visible(near, w2.tick), "tank in the open at 900 m")
	assert_false(v.is_visible(far, w2.tick), "beyond optics")
	assert_false(v.is_visible(hidden, w2.tick), "infantry in forest at 1 km")
	assert_true(w2.vision[0].is_visible(obs, w2.tick), "thermal MBT sees the squad")


func test_firing_reveals_shooter() -> void:
	var obs: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 100, 500)
	var hidden: int = SimFixture.spawn(w, "nc_recon_team", 0, 900, 500)
	SimFixture.run(w, 6)
	assert_false(w.vision[1].is_visible(hidden, w.tick), "recon concealed at 800 m")
	w.units.last_fired_tick[hidden] = w.tick
	SimFixture.run(w, 6)
	assert_true(w.vision[1].is_visible(hidden, w.tick), "muzzle flash gives it away")


func test_tank_duel_resolves() -> void:
	var a: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 100, 500, 0)
	var b: int = SimFixture.spawn(w, "ec_mbt_72", 1, 900, 500, 32768)
	for i: int in range(1200):
		w.step()
		if not w.is_unit(a) or not w.is_unit(b):
			break
	assert_true(not w.is_unit(a) or not w.is_unit(b) or w.units.hp[a] < 1200 or w.units.hp[b] < 1100, "someone got hurt")


func test_wire_guided_missile_fails_when_operator_suppressed() -> void:
	var at: int = SimFixture.spawn(w, "ec_rpg_team", 1, 100, 500)
	var tank: int = SimFixture.spawn(w, "nc_mbt_2a", 0, 1500, 500, 32768)
	w.units.stance[tank] = UnitStore.STANCE_HOLD_FIRE
	var launched: bool = false
	for i: int in range(400):
		w.step()
		if w.projectiles.count() > 0:
			launched = true
			break
	assert_true(launched, "ATGM launched")
	w.units.suppression[at] = 1000
	w.units.last_hit_tick[at] = w.tick  # keep it suppressed
	var hp0: int = w.units.hp[tank]
	for i: int in range(120):
		w.units.suppression[at] = 1000
		w.units.last_hit_tick[at] = w.tick
		w.step()
		if w.projectiles.count() == 0:
			break
	assert_eq(w.projectiles.count(), 0)
	assert_eq(w.units.hp[tank], hp0, "guidance lost: no damage")


func test_fire_mission_requires_spotter_and_hits_area() -> void:
	w = SimFixture.world(SimFixture.flat_grid(600, 128))
	var spg: int = SimFixture.spawn(w, "nc_spg_155", 0, 50, 50)
	var spotter: int = SimFixture.spawn(w, "nc_recon_team", 0, 600, 900)
	var victims: PackedInt32Array = PackedInt32Array()
	for i: int in range(4):
		victims.append(SimFixture.spawn(w, "ec_motor_rifle", 1, 900 + i * 12, 900))
	for v: int in victims:
		w.units.stance[v] = UnitStore.STANCE_HOLD_FIRE
	w.units.stance[spotter] = UnitStore.STANCE_HOLD_FIRE
	# unobserved point: rejected
	SimFixture.cmd(FireMissionCommand.new(PackedInt32Array([spg]), 4_500_000, 900_000, 6), w, 0, 0)
	w.step()
	assert_eq(w.orders.kind[spg], OrderStore.NONE, "point 3.9 km from the spotter is unobserved")
	SimFixture.cmd(StopCommand.new(PackedInt32Array([spg])), w, 0, 1)
	w.step()
	SimFixture.cmd(FireMissionCommand.new(PackedInt32Array([spg]), 918000, 900000, 6), w, 0, 2)
	w.step()
	assert_eq(w.orders.kind[spg], OrderStore.FIRE_MISSION)
	var men0: int = 0
	for v: int in victims:
		men0 += w.units.members_alive[v]
	SimFixture.run(w, 900)
	assert_eq(w.weapons.ammo[spg * WeaponStore.MAX_WEAPONS], 36 - 6)
	var men1: int = 0
	for v: int in victims:
		if w.is_unit(v):
			men1 += w.units.members_alive[v]
	assert_true(men1 < men0, "artillery caused casualties (%d -> %d)" % [men0, men1])


func test_smoke_screen_breaks_spotting_for_optics_only() -> void:
	var tank: int = SimFixture.spawn(w, "nc_ifv_90", 0, 500, 500, 0)
	var ec_obs: int = SimFixture.spawn(w, "ec_motor_rifle", 1, 1100, 500)  # no thermal
	SimFixture.run(w, 6)
	assert_true(w.vision[1].is_visible(tank, w.tick))
	SimFixture.cmd(SmokeCommand.new(PackedInt32Array([tank])), w, 0)
	SimFixture.run(w, 12)
	assert_false(w.vision[1].is_visible(tank, w.tick), "smoke hides IFV from optics")
	assert_true(w.vision[0].is_visible(ec_obs, w.tick), "IFV thermal sees through its own smoke at 600 m")
	assert_eq(w.units.smoke_charges[tank], 1)
