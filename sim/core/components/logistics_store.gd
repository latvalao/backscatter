# SIM: deterministic — no floats, no Nodes
## Fuel and carried supply per mobile unit (§5.1).
class_name LogisticsStore
extends ComponentStore

var fuel: PackedInt32Array = PackedInt32Array()       # mL
## Distance moved not yet charged as fuel (mm), keeps integer fuel use exact.
var odometer: PackedInt32Array = PackedInt32Array()
## Resupply stock carried for units in the field (trucks), topped up at the FOB.
var cargo: PackedInt32Array = PackedInt32Array()
## Depot stock being hauled to the FOB (delivered as player SUPPLY).
var haul: PackedInt32Array = PackedInt32Array()


func add(id: int, def: UnitStats) -> void:
	ensure_capacity(id + 1)
	present[id] = 1
	fuel[id] = def.fuel_capacity
	odometer[id] = 0
	cargo[id] = def.cargo_capacity
	haul[id] = 0


func _resize_columns(n: int) -> void:
	fuel.resize(n)
	odometer.resize(n)
	cargo.resize(n)
	haul.resize(n)


func hash_entity(id: int, h: Checksum) -> void:
	h.add_int(fuel[id])
	h.add_int(odometer[id])
	h.add_int(cargo[id])
	h.add_int(haul[id])
