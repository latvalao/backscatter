# SIM: deterministic — no floats, no Nodes
## Per-unit radiation state (§5.4): accumulated crew dose (µSv; one value per
## unit for the whole crew/squad), sub-µSv remainder, and vehicle/kit
## contamination (adds its own dose rate, µSv/h, until decontaminated).
class_name RadiationStore
extends ComponentStore

var dose: PackedInt32Array = PackedInt32Array()
var remainder: PackedInt32Array = PackedInt32Array()
var contamination: PackedInt32Array = PackedInt32Array()
## Tick of the next radiation casualty while Critical (0 = none scheduled).
var next_casualty: PackedInt32Array = PackedInt32Array()


func add(id: int) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	dose[id] = 0
	remainder[id] = 0
	contamination[id] = 0
	next_casualty[id] = 0


func _resize_columns(n: int) -> void:
	dose.resize(n)
	remainder.resize(n)
	contamination.resize(n)
	next_casualty.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(dose[id])
	h.add_int(remainder[id])
	h.add_int(contamination[id])
	h.add_int(next_casualty[id])
