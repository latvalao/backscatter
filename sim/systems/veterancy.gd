# SIM: deterministic — no floats, no Nodes
## Veterancy (§5.7): Trained -> Veteran -> Elite from spotting, hits that count
## (penetrations, soldiers killed) and kills.
## Better aim, faster reloads, steadier morale.
class_name Veterancy
extends RefCounted

const NAMES: Array[String] = ["Trained", "Veteran", "Elite"]
const THRESHOLDS: Array[int] = [0, 250, 700]
const XP_KILL: int = 60
const XP_PENETRATION: int = 15
const XP_CASUALTY: int = 10
const XP_SPOT: int = 3
const ACCURACY: Array[int] = [1000, 1100, 1200]
const RELOAD: Array[int] = [1000, 900, 800]
const MORALE_BONUS: Array[int] = [0, 80, 160]


static func award(world: SimWorld, id: int, amount: int) -> void:
	if not world.units.has(id) or world.is_structure(id):
		return
	var u: UnitStore = world.units
	u.xp[id] += amount
	var r: int = u.rank[id]
	while r < 2 and u.xp[id] >= THRESHOLDS[r + 1]:
		r += 1
	if r != u.rank[id]:
		u.rank[id] = r
		u.morale[id] += MORALE_BONUS[r] - MORALE_BONUS[r - 1]
		world.emit(SimEvent.Type.PROMOTED, id, 0, r)


static func accuracy(world: SimWorld, id: int) -> int:
	return ACCURACY[world.units.rank[id]]


static func reload_ticks(world: SimWorld, id: int, ticks: int) -> int:
	return maxi(1, ticks * RELOAD[world.units.rank[id]] / 1000)


static func morale_cap(world: SimWorld, id: int, base: int) -> int:
	return base + MORALE_BONUS[world.units.rank[id]]
