# SIM: deterministic — no floats, no Nodes
## Everything needed to build the identical starting world on every peer and in
## replays. Serialised as a Dictionary of ints/strings.
class_name MatchSettings
extends RefCounted

const VERSION: int = 1

var mode: String = "skirmish"   # "sandbox" | "skirmish"
var match_seed: int = 1
var map_seed: int = 7
var map_cells: int = 500        # square map, 8 m cells
## Each: {"name": String, "team": int, "faction": "nc"|"ec", "ai": bool,
##        "difficulty": 0 easy | 1 normal | 2 hard | -1 passive dummy}
var players: Array[Dictionary] = []
## Add AI Marauders as a hostile third party (team 2).
var marauders: bool = false
## Point-symmetric map (fair versus / AI-vs-AI); skirmish default.
var symmetric: bool = true


func add_player(p_name: String, team: int, faction: String, ai: bool, difficulty: int = 1, battlegroup: int = 0) -> int:
	players.append({"name": p_name, "team": team, "faction": faction, "ai": ai, "difficulty": difficulty, "battlegroup": battlegroup})
	return players.size() - 1


func to_dict() -> Dictionary:
	return {"version": VERSION, "mode": mode, "match_seed": match_seed, "map_seed": map_seed,
		"map_cells": map_cells, "players": players.duplicate(true), "marauders": marauders, "symmetric": symmetric}


static func from_dict(d: Dictionary) -> MatchSettings:
	var s: MatchSettings = MatchSettings.new()
	s.mode = d.get("mode", "skirmish")
	s.match_seed = d.get("match_seed", 1)
	s.map_seed = d.get("map_seed", 7)
	s.map_cells = d.get("map_cells", 500)
	s.marauders = d.get("marauders", false)
	s.symmetric = d.get("symmetric", true)
	var ps: Array = d.get("players", [])
	for p: Variant in ps:
		var pd: Dictionary = p
		s.players.append({"name": String(pd.get("name", "")), "team": int(pd.get("team", 0)),
			"faction": String(pd.get("faction", "nc")), "ai": bool(pd.get("ai", false)),
			"difficulty": int(pd.get("difficulty", 1))})
	return s


## Default single-player skirmish: you (Coalition) vs a dummy Eastern AI.
static func default_skirmish(difficulty: int = 1, with_marauders: bool = true) -> MatchSettings:
	var s: MatchSettings = MatchSettings.new()
	s.mode = "skirmish"
	s.match_seed = 20261127
	s.marauders = with_marauders
	s.add_player("Player", 0, "nc", false)
	s.add_player("Eastern AI", 1, "ec", true, difficulty)
	return s
