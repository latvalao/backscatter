## Invite-only lobby protocol (§4: friends only, no matchmaking) over any
## NetTransport. The host owns the roster, assigns player ids and starts the
## match by broadcasting MatchSettings; every peer then builds the same world.
class_name Lobby
extends RefCounted

signal roster_changed(roster: Array)
signal match_started(settings: MatchSettings, local_player: int)
signal message(text: String)

var transport: NetTransport
var local_name: String = "Player"
var local_player: int = -1
## Each: {"name", "team", "faction", "ai", "conn"} — index = player id.
var roster: Array[Dictionary] = []
var map_seed: int = 7
var mode: String = "skirmish"


func _init(p_transport: NetTransport, p_name: String) -> void:
	transport = p_transport
	local_name = p_name
	if transport.is_host():
		local_player = 0
		roster.append(_slot(local_name, 0, 0))


func _slot(n: String, team: int, conn: int, ai: bool = false) -> Dictionary:
	return {"name": n, "team": team, "faction": "nc" if team == 0 else "ec", "ai": ai, "conn": conn, "difficulty": 1}


func add_ai(team: int) -> void:
	if transport.is_host() and roster.size() < 4:
		roster.append(_slot("AI %d" % roster.size(), team, -1, true))
		_broadcast_roster()


func set_team(player: int, team: int) -> void:
	if transport.is_host() and player < roster.size():
		roster[player]["team"] = team
		roster[player]["faction"] = "nc" if team == 0 else "ec"
		_broadcast_roster()


## Processes lobby traffic. Returns game messages (turns etc.) that arrived
## early so the caller can hand them to the lockstep.
func poll() -> Array[PackedByteArray]:
	var game: Array[PackedByteArray] = []
	for e: Dictionary in transport.poll():
		var conn: int = e["conn"]
		match String(e["kind"]):
			"connected":
				if not transport.is_host():
					transport.send(NetTransport.BROADCAST, NetProtocol.with_var(NetProtocol.HELLO, local_name))
			"disconnected":
				_on_disconnect(conn)
			"data":
				var data: PackedByteArray = e["data"]
				if NetProtocol.is_game(data):
					game.append(data)
				else:
					_on_lobby_message(conn, data)
	return game


func _on_lobby_message(conn: int, data: PackedByteArray) -> void:
	var v: Variant = NetProtocol.read_var(data)
	match int(data[0]):
		NetProtocol.HELLO:
			if not transport.is_host() or roster.size() >= 4:
				return
			var team: int = roster.size() % 2
			roster.append(_slot(String(v), team, conn))
			transport.send(conn, NetProtocol.with_var(NetProtocol.WELCOME, roster.size() - 1))
			message.emit("%s joined" % String(v))
			_broadcast_roster()
		NetProtocol.WELCOME:
			local_player = int(v)
		NetProtocol.ROSTER:
			var arr: Array = v
			roster.clear()
			for item: Variant in arr:
				roster.append(item as Dictionary)
			roster_changed.emit(roster)
		NetProtocol.START:
			var settings: MatchSettings = MatchSettings.from_dict(v as Dictionary)
			match_started.emit(settings, local_player)


func _on_disconnect(conn: int) -> void:
	if transport.is_host():
		for i: int in range(roster.size()):
			if int(roster[i].get("conn", -9)) == conn and i > 0:
				message.emit("%s left" % roster[i]["name"])
				roster.remove_at(i)
				_broadcast_roster()
				return
	else:
		message.emit("Disconnected from host")


func _broadcast_roster() -> void:
	transport.send(NetTransport.BROADCAST, NetProtocol.with_var(NetProtocol.ROSTER, roster))
	roster_changed.emit(roster)


## Host only: freeze the roster into MatchSettings and start everywhere.
func start(match_seed: int) -> MatchSettings:
	var s: MatchSettings = MatchSettings.new()
	s.mode = mode
	s.match_seed = match_seed
	s.map_seed = map_seed
	for p: Dictionary in roster:
		s.add_player(p["name"], p["team"], p["faction"], p["ai"], int(p.get("difficulty", 1)))
	transport.send(NetTransport.BROADCAST, NetProtocol.with_var(NetProtocol.START, s.to_dict()))
	match_started.emit(s, local_player)
	return s


## Human player ids (they send turns); AI players run inside the sim.
static func human_players(s: MatchSettings) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(s.players.size()):
		if not bool(s.players[i]["ai"]):
			out.append(i)
	return out
