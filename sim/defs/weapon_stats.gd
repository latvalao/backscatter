# SIM: deterministic — no floats, no Nodes
## Immutable integer weapon stats (converted from data/weapons/*.json at load).
class_name WeaponStats
extends RefCounted

const DIRECT: int = 0
const INDIRECT: int = 1
const ATGM: int = 2

const GUIDE_NONE: int = 0
const GUIDE_FIRE_FORGET: int = 1
const GUIDE_WIRE: int = 2

var index: int = 0
var id: String = ""
var type: int = DIRECT
var guidance: int = GUIDE_NONE
var range_min_mm: int = 0
var range_max_mm: int = 0
## Armour penetration (mm RHA equivalent).
var penetration: int = 0
## Damage to vehicle HP on a penetrating hit.
var damage: int = 0
## Damage to one soldier's HP per hit.
var inf_damage: int = 0
var blast_radius_mm: int = 0
## Suppression added on hit (0..1000 scale). Near misses add a quarter.
var suppression: int = 0
var reload_ticks: int = 1
var aim_ticks: int = 0
var ammo_capacity: int = 0
var ammo_per_shot: int = 1
## Hit rolls per trigger pull (squads scale by surviving members).
var burst: int = 1
## Hit chance permille at point blank and at max range.
var accuracy_near: int = 500
var accuracy_far: int = 100
## Projectile speed mm/tick; 0 = resolves instantly.
var projectile_speed: int = 0
## Indirect fire dispersion radius per km of range (mm).
var dispersion_per_km_mm: int = 0
var smoke: bool = false


func is_indirect() -> bool:
	return type == INDIRECT


## Hit chance permille at range r_mm, linear falloff between near and far.
func accuracy_at(r_mm: int) -> int:
	if range_max_mm <= 0:
		return accuracy_near
	var r: int = clampi(r_mm, 0, range_max_mm)
	return accuracy_near + ((accuracy_far - accuracy_near) * r) / range_max_mm
