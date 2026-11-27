## LAN / direct-IP transport over Godot's built-in ENet. Reliable ordered
## channel; the host relays game messages between clients (star topology).
class_name ENetTransport
extends NetTransport

const DEFAULT_PORT: int = 27960

var peer: ENetMultiplayerPeer
var _host: bool = false
var _clients: PackedInt32Array = PackedInt32Array()
var _events: Array[Dictionary] = []


func host(port: int = DEFAULT_PORT, max_clients: int = 3) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_clients)
	if err != OK:
		return err
	_host = true
	_hook()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	_host = false
	_hook()
	return OK


func _hook() -> void:
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.peer_connected.connect(_on_connected)
	peer.peer_disconnected.connect(_on_disconnected)


func _on_connected(id: int) -> void:
	if _host:
		_clients.append(id)
	_events.append(conn_event("connected", id))


func _on_disconnected(id: int) -> void:
	var i: int = _clients.find(id)
	if i >= 0:
		_clients.remove_at(i)
	_events.append(conn_event("disconnected", id))


func is_host() -> bool:
	return _host


func send(conn: int, data: PackedByteArray) -> void:
	if peer == null:
		return
	if conn == BROADCAST:
		peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST if _host else MultiplayerPeer.TARGET_PEER_SERVER)
	else:
		peer.set_target_peer(conn)
	peer.put_packet(data)


func poll() -> Array[Dictionary]:
	if peer == null:
		return []
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var from: int = peer.get_packet_peer()
		var data: PackedByteArray = peer.get_packet()
		_events.append(data_event(from, data))
		if _host and NetProtocol.is_game(data):
			for c: int in _clients:
				if c != from:
					peer.set_target_peer(c)
					peer.put_packet(data)
	var out: Array[Dictionary] = _events
	_events = []
	return out


func close() -> void:
	if peer != null:
		peer.close()
		peer = null


func describe() -> String:
	if peer == null:
		return "ENet (closed)"
	return "ENet host (%d clients)" % _clients.size() if _host else "ENet client"
