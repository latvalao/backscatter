## Match statistics for the end-of-match summary (Phase 4.3), collected from sim
## events and state as the match plays (live or replay). Read-only.
class_name MatchStats
extends Node

const SAMPLE_TICKS: int = 300

var runner: SimRunner
var views: ViewSync
## Per team: produced, lost, kills, supply_spent, dose_msv
var produced: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var lost: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var kills: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var salvage: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var support_calls: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Army value (sum of unit supply cost) per team, sampled over time.
var strength: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
var _last_sample: int = -SAMPLE_TICKS


func _process(_delta: float) -> void:
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	for e: SimEvent in views.last_events:
		match e.kind:
			SimEvent.Type.PRODUCED:
				if w.units.has(e.entity_id):
					produced[w.units.team[e.entity_id] % 4] += 1
			SimEvent.Type.DESTROYED:
				var team: int = e.value % 4
				if views.lost.has(e.entity_id):
					lost[team] += 1
					for t: int in range(3):
						if t != team and w.is_enemy_team(t, team):
							kills[t] += 1
			SimEvent.Type.SALVAGED:
				if w.units.has(e.other_id):
					salvage[w.units.team[e.other_id] % 4] += e.value
			SimEvent.Type.SUPPORT_CALLED:
				support_calls[w.team_of_player(e.other_id) % 4] += 1
	if w.tick - _last_sample >= SAMPLE_TICKS:
		_last_sample = w.tick
		var sums: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
		for t2: int in range(SimWorld.MAX_TEAMS):
			for id: int in w.team_units[t2] if t2 < w.team_units.size() else PackedInt32Array():
				if not w.is_structure(id):
					sums[t2] += w.def_of(id).cost_supply
		for t3: int in range(4):
			strength[t3].append(sums[t3])


func dose_msv(team: int) -> int:
	var w: SimWorld = runner.world
	var total: int = 0
	for id: int in w.team_units[team]:
		if w.radiation.has(id):
			total += w.radiation.dose[id]
	return total / 1000
