## Transport interface (§7.4). Star topology: clients talk to the host only;
## the host relays game messages. Connection ids are transport-specific ints
## (ENet peer ids, Steam ids, loopback endpoints); the host is HOST_CONN.
class_name NetTransport
extends RefCounted

const HOST_CONN: int = 1
const BROADCAST: int = -1

## Events returned by poll(): {"kind": "data"|"connected"|"disconnected", "conn": int, "data": PackedByteArray}


func is_host() -> bool:
	return false


## Sends to one connection, or BROADCAST (host: every client; client: the host,
## which relays game messages to everyone else).
func send(_conn: int, _data: PackedByteArray) -> void:
	pass


func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


func close() -> void:
	pass


## Human-readable status for menus.
func describe() -> String:
	return "offline"


static func data_event(conn: int, data: PackedByteArray) -> Dictionary:
	return {"kind": "data", "conn": conn, "data": data}


static func conn_event(kind: String, conn: int) -> Dictionary:
	return {"kind": kind, "conn": conn, "data": PackedByteArray()}
