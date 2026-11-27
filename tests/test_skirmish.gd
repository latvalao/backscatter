## M2 ACCEPTANCE: scripted 20v20 combined-arms skirmish resolves plausibly and
## deterministically.
extends TestCase

const NC: Array[String] = ["nc_mbt_2a", "nc_mbt_2a", "nc_mbt_2a", "nc_ifv_90", "nc_ifv_90", "nc_ifv_90", "nc_ifv_90",
	"nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd", "nc_rifle_sqd",
	"nc_atgm_team", "nc_atgm_team", "nc_atgm_team", "nc_recon_team", "nc_recon_team", "nc_mortar_team", "nc_mortar_team"]
const EC: Array[String] = ["ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_mbt_72", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2", "ec_ifv_2",
	"ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle", "ec_motor_rifle",
	"ec_rpg_team", "ec_rpg_team", "ec_rpg_team", "ec_recon_sqd", "ec_mortar_team", "ec_mortar_team"]
const MAX_TICKS: int = 6000


static func run_battle(seed_value: int) -> Dictionary:
	var w: SimWorld = SimFixture.world(SimFixture.flat_grid(300, 120), seed_value)
	var side: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for i: int in range(20):
		side[0].append(SimFixture.spawn(w, NC[i], 0, 600 + (i / 5) * 40, 300 + (i % 5) * 80, 0))
		side[1].append(SimFixture.spawn(w, EC[i], 1, 1800 - (i / 5) * 40, 300 + (i % 5) * 80, 32768))
	SimFixture.cmd(MoveCommand.new(side[0], 1200_000, 480_000, MoveCommand.MODE_ATTACK_MOVE), w, 0, 0)
	SimFixture.cmd(MoveCommand.new(side[1], 1200_000, 480_000, MoveCommand.MODE_ATTACK_MOVE), w, 1, 0)
	var shots: int = 0
	var ticks: int = 0
	var alive: Array[int] = [20, 20]
	while ticks < MAX_TICKS:
		w.step()
		ticks += 1
		for e: SimEvent in w.drain_events():
			if e.kind == SimEvent.Type.SHOT:
				shots += 1
		if ticks % 50 == 0:
			for s: int in range(2):
				alive[s] = 0
				for id: int in side[s]:
					if w.is_unit(id):
						alive[s] += 1
			if alive[0] <= 4 or alive[1] <= 4:
				break
	return {"ticks": ticks, "alive_nc": alive[0], "alive_ec": alive[1], "shots": shots, "checksum": Checksum.compute(w)}


func test_m2_acceptance_20v20_resolves() -> void:
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = run_battle(1234)
	var ms: int = Time.get_ticks_msec() - t0
	print("    20v20: %s (%d ms)" % [str(r), ms])
	var nc: int = r["alive_nc"]
	var ec: int = r["alive_ec"]
	var ticks: int = r["ticks"]
	assert_true(r["shots"] > 100, "lots of shooting")
	assert_true(nc < 20 and ec < 20, "both sides took losses")
	assert_true(nc <= 4 or ec <= 4, "one side was destroyed/broken within %d ticks" % MAX_TICKS)
	assert_true(ticks > 300, "not instantaneous")


func test_m2_battle_is_deterministic() -> void:
	var a: Dictionary = run_battle(77)
	var b: Dictionary = run_battle(77)
	assert_eq(a["checksum"], b["checksum"])
	assert_eq(a["ticks"], b["ticks"])
