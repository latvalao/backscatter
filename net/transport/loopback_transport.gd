## In-process transport for tests and offline play. Endpoints registered with a
## LoopbackHub exchange messages with a configurable delay (in polls) and
## optional jitter — deterministic for a given hub seed.
class_name LoopbackTransport
extends NetTransport

var hub: LoopbackHub
var conn_id: int = 0


func _init(p_hub: LoopbackHub, p_conn: int) -> void:
	hub = p_hub
	conn_id = p_conn
	hub.register(self)


func is_host() -> bool:
	return conn_id == HOST_CONN


func send(conn: int, data: PackedByteArray) -> void:
	if conn == BROADCAST:
		if is_host():
			for c: int in hub.endpoints():
				if c != conn_id:
					hub.deliver(conn_id, c, data)
		else:
			hub.deliver(conn_id, HOST_CONN, data)
	else:
		hub.deliver(conn_id, conn, data)


func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = hub.collect(conn_id)
	if is_host():
		# relay game messages from clients to the other clients
		for e: Dictionary in out:
			var data: PackedByteArray = e["data"]
			if e["kind"] == "data" and NetProtocol.is_game(data):
				for c: int in hub.endpoints():
					if c != conn_id and c != int(e["conn"]):
						hub.deliver(int(e["conn"]), c, data)
	return out


func describe() -> String:
	return "loopback #%d" % conn_id
