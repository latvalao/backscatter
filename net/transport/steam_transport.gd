## Steam transport via the GodotSteam GDExtension (§7.4): friends-only lobbies,
## invites through the Steam overlay, and Steam P2P packets. Written against
## GodotSteam's API through Engine.get_singleton("Steam") so the project still
## builds and runs without the addon (the menu hides Steam options then).
##
## Not exercised by automated tests: it needs the Steam client and the addon.
## Install: GodotSteam GDExtension (Godot Asset Library) into res://addons/godotsteam,
## and put steam_appid.txt (480 = Spacewar test app) next to the executable.
class_name SteamTransport
extends NetTransport

const LOBBY_FRIENDS_ONLY: int = 1
const P2P_RELIABLE: int = 2
const CHANNEL: int = 0

signal lobby_ready(lobby_id: int)
signal lobby_failed(reason: String)

var steam: Object
var lobby_id: int = 0
var my_id: int = 0
var owner_id: int = 0
var _events: Array[Dictionary] = []
var _members: Array = []


static func available() -> bool:
	return Engine.has_singleton("Steam")


func _init() -> void:
	if not available():
		return
	steam = Engine.get_singleton("Steam")
	var init: Variant = steam.call("steamInitEx", false, 480) if steam.has_method("steamInitEx") else steam.call("steamInit")
	my_id = steam.call("getSteamID")
	steam.connect("lobby_created", _on_lobby_created)
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.connect("lobby_chat_update", _on_lobby_chat_update)
	steam.connect("join_requested", _on_join_requested)
	steam.connect("p2p_session_request", _on_p2p_session_request)
	print("Steam init: %s" % str(init))


func host_lobby(max_members: int = 4) -> void:
	steam.call("createLobby", LOBBY_FRIENDS_ONLY, max_members)


func join_lobby(id: int) -> void:
	steam.call("joinLobby", id)


func invite_friends() -> void:
	if lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)


func is_host() -> bool:
	return owner_id != 0 and owner_id == my_id


func send(conn: int, data: PackedByteArray) -> void:
	if steam == null:
		return
	if conn == BROADCAST:
		if is_host():
			for m: Variant in _members:
				var mid: int = m
				if mid != my_id:
					steam.call("sendP2PPacket", mid, data, P2P_RELIABLE, CHANNEL)
		else:
			steam.call("sendP2PPacket", owner_id, data, P2P_RELIABLE, CHANNEL)
	else:
		steam.call("sendP2PPacket", conn, data, P2P_RELIABLE, CHANNEL)


func poll() -> Array[Dictionary]:
	if steam == null:
		return []
	steam.call("run_callbacks")
	var size: int = steam.call("getAvailableP2PPacketSize", CHANNEL)
	while size > 0:
		var packet: Dictionary = steam.call("readP2PPacket", size, CHANNEL)
		var from: int = packet.get("remote_steam_id", packet.get("steam_id_remote", 0))
		var data: PackedByteArray = packet.get("data", PackedByteArray())
		_events.append(data_event(from, data))
		if is_host() and NetProtocol.is_game(data):
			for m: Variant in _members:
				var mid: int = m
				if mid != my_id and mid != from:
					steam.call("sendP2PPacket", mid, data, P2P_RELIABLE, CHANNEL)
		size = steam.call("getAvailableP2PPacketSize", CHANNEL)
	var out: Array[Dictionary] = _events
	_events = []
	return out


func close() -> void:
	if steam != null and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
		lobby_id = 0


func describe() -> String:
	return "Steam lobby %d (%d members)" % [lobby_id, _members.size()]


func _refresh_members() -> void:
	var before: Array = _members.duplicate()
	_members = []
	var n: int = steam.call("getNumLobbyMembers", lobby_id)
	for i: int in range(n):
		_members.append(steam.call("getLobbyMemberByIndex", lobby_id, i))
	owner_id = steam.call("getLobbyOwner", lobby_id)
	for m: Variant in _members:
		if not before.has(m) and int(m) != my_id:
			_events.append(conn_event("connected", int(m)))
	for m: Variant in before:
		if not _members.has(m):
			_events.append(conn_event("disconnected", int(m)))


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		lobby_failed.emit("lobby creation failed (%d)" % result)
		return
	lobby_id = id
	steam.call("setLobbyJoinable", id, true)
	steam.call("setLobbyData", id, "game", "backscatter")


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		lobby_failed.emit("could not join lobby (%d)" % response)
		return
	lobby_id = id
	_refresh_members()
	if not is_host():
		# open the P2P session with the host by sending a no-op
		_events.append(conn_event("connected", owner_id))
	lobby_ready.emit(id)


func _on_lobby_chat_update(_lobby: int, _changed: int, _making_change: int, _state: int) -> void:
	_refresh_members()


func _on_join_requested(id: int, _friend: int) -> void:
	join_lobby(id)


func _on_p2p_session_request(remote_id: int) -> void:
	steam.call("acceptP2PSessionWithUser", remote_id)
