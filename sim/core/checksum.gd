# SIM: deterministic — no floats, no Nodes
## FNV-1a (32-bit, word-wise) state hash for desync detection.
## Every step is masked to 32 bits so nothing overflows signed 64-bit int.
class_name Checksum
extends RefCounted

const OFFSET: int = 0x811C9DC5
const PRIME: int = 0x01000193
const MASK: int = 0xFFFFFFFF

var value: int = OFFSET


func add_u32(v: int) -> void:
	value = ((value ^ (v & MASK)) * PRIME) & MASK


func add_int(v: int) -> void:
	add_u32(v & MASK)
	add_u32((v >> 32) & MASK)


## Hash the whole world. Order: tick, rng, entity count, then per entity in
## ascending id: id, then each component store (fixed order) presence + data;
## then team vision, projectiles, smoke and the path request queue.
static func compute(world: SimWorld) -> int:
	var h: Checksum = Checksum.new()
	h.add_int(world.tick)
	for s: int in world.rng.get_state():
		h.add_int(s)
	var ids: PackedInt32Array = world.entities.ids()
	h.add_int(ids.size())
	var stores: Array[ComponentStore] = world.component_stores()
	for id: int in ids:
		h.add_int(id)
		for i: int in range(stores.size()):
			var store: ComponentStore = stores[i]
			if store.has(id):
				h.add_u32(i + 1)
				store.hash_entity(id, h)
	for v: TeamVision in world.vision:
		v.hash_into(h, ids)
	world.projectiles.hash_into(h)
	world.players.hash_into(h)
	h.add_int(world.winner_team)
	world.smoke.hash_into(h)
	h.add_int(world.path_requests.size())
	for pid: int in world.path_requests:
		h.add_int(pid)
	return h.value
