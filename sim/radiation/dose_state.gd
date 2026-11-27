# SIM: deterministic — no floats, no Nodes
## Dose thresholds and effects (§5.4 table). Doses in µSv.
class_name DoseState
extends RefCounted

const NORMAL: int = 0
const EXPOSED: int = 1
const MILD: int = 2
const SEVERE: int = 3
const CRITICAL: int = 4
const NAMES: Array[String] = ["Normal", "Exposed", "Mild ARS", "Severe ARS", "Critical"]
const THRESHOLDS_MSV: Array[int] = [0, 250, 1000, 2000, 4000]
## Accuracy multiplier permille per state.
const ACCURACY: Array[int] = [1000, 950, 850, 650, 400]
## Morale cap penalty per state (morale points, 0..1000 scale).
const MORALE_PENALTY: Array[int] = [0, 0, 100, 200, 400]


static func of(dose_usv: int) -> int:
	var msv: int = dose_usv / 1000
	for s: int in range(CRITICAL, 0, -1):
		if msv >= THRESHOLDS_MSV[s]:
			return s
	return NORMAL


static func accuracy(world: SimWorld, id: int) -> int:
	if not world.radiation.has(id):
		return 1000
	return ACCURACY[of(world.radiation.dose[id])]


## Infantry speed multiplier permille.
static func speed(world: SimWorld, id: int) -> int:
	if not world.radiation.has(id):
		return 1000
	return 900 if of(world.radiation.dose[id]) >= MILD else 1000


static func can_capture(world: SimWorld, id: int) -> bool:
	return not world.radiation.has(id) or of(world.radiation.dose[id]) < SEVERE
