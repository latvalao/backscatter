## Game sound (Phase 7): positional weapon, impact and destruction sounds from
## sim events, engine and rotor loops on the nearest moving vehicles, wind and
## rain ambience from the sim weather, radio squelch on orders and contacts.
## Sounds are synthesised by tools/gen_sfx.py. Read-only w.r.t. the sim.
class_name AudioDirector
extends Node3D

const SFX: String = "res://presentation/audio/sfx/%s.wav"
const POOL: int = 20
const MAX_PER_FRAME: int = 6
const HEAR_M: float = 1800.0
const ENGINES: int = 5

var runner: SimRunner
var views: ViewSync
var controller: SelectionController

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _engines: Array[AudioStreamPlayer3D] = []
var _engine_ids: PackedInt32Array = PackedInt32Array()
var _wind: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _radio: AudioStreamPlayer
var _engine_timer: float = 0.0
var _known_enemies: Dictionary = {}
var _contact_cd: float = 0.0


func _ready() -> void:
	GraphicsSettings.load_settings()
	GraphicsSettings.apply_audio()
	for i: int in range(POOL):
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.bus = &"Effects"
		p.unit_size = 140.0
		p.max_distance = HEAR_M
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)
	for j: int in range(ENGINES):
		var e: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		e.bus = &"Effects"
		e.unit_size = 60.0
		e.max_distance = 700.0
		add_child(e)
		_engines.append(e)
		_engine_ids.append(0)
	_wind = _ambient("wind", -12.0)
	_rain = _ambient("rain", -80.0)
	_radio = AudioStreamPlayer.new()
	_radio.bus = &"Radio"
	_radio.stream = _stream("radio")
	add_child(_radio)
	if controller != null:
		controller.order_sent.connect(_on_order)


func _stream(name: String, looped: bool = false) -> AudioStream:
	if not _streams.has(name):
		var s: AudioStreamWAV = load(SFX % name) as AudioStreamWAV
		if s != null and looped and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			# loops are imported as forward loops (tools/gen_sfx.py); this is a
			# fallback. The end is in samples, not bytes: the data is compressed.
			s = s.duplicate() as AudioStreamWAV
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		_streams[name] = s
	return _streams[name]


func _ambient(name: String, db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = &"Ambient"
	p.stream = _stream(name, true)
	p.volume_db = db
	add_child(p)
	p.play()
	return p


func play_at(name: String, pos: Vector3, db: float = 0.0) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(pos) > HEAR_M * 1.2:
		return
	var p: AudioStreamPlayer3D = _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _stream(name)
	p.volume_db = db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.global_position = pos
	p.play()


func _process(delta: float) -> void:
	if runner == null or runner.world == null:
		return
	var w: SimWorld = runner.world
	var played: int = 0
	for e: SimEvent in views.last_events:
		if played >= MAX_PER_FRAME:
			break
		match e.kind:
			SimEvent.Type.SHOT:
				if not (views.reveal_all or views.is_shown(e.entity_id)):
					continue
				var wd: WeaponStats = w.defs.weapons[e.value]
				play_at(_weapon_sound(wd), runner.interpolated_position(e.entity_id), -4.0 if wd.burst > 1 else 0.0)
				played += 1
			SimEvent.Type.IMPACT, SimEvent.Type.MISSED:
				var wd2: WeaponStats = w.defs.weapons[e.value]
				if wd2.blast_radius_mm >= 8000 and not wd2.smoke:
					play_at("explosion_big" if wd2.blast_radius_mm >= 20000 else "explosion_small", SimRunner.sim_to_view(e.x, e.y, 0))
					played += 1
			SimEvent.Type.MINE:
				play_at("explosion_small", SimRunner.sim_to_view(e.x, e.y, 0))
				played += 1
	for id: int in views.lost.keys():
		var info: Array = views.lost[id]
		play_at("explosion_big", info[2] as Vector3, 2.0)
	_engine_timer -= delta
	if _engine_timer <= 0.0:
		_engine_timer = 0.5
		_pick_engines(w)
	for k: int in range(ENGINES):
		var id2: int = _engine_ids[k]
		if id2 != 0 and views.view_of(id2) != null:
			_engines[k].global_position = views.view_of(id2).global_position
	_weather(w, delta)
	_contacts(w, delta)


func _weapon_sound(wd: WeaponStats) -> String:
	if wd.is_indirect():
		return "artillery_fire"
	if wd.type == WeaponStats.ATGM:
		return "missile"
	if wd.penetration >= 300:
		return "cannon"
	if wd.burst > 1 and wd.penetration >= 40:
		return "autocannon"
	return "mg" if wd.burst > 1 else "rifle"


## Engine / rotor loops follow the nearest moving vehicles to the camera focus.
func _pick_engines(w: SimWorld) -> void:
	var focus: Vector3 = views.focus_point if views.focus_point != Vector3.INF else Vector3.ZERO
	var cands: Array = []
	for v: Variant in views.all_views():
		var uv: UnitView = v as UnitView
		if not uv.visible or uv.def.is_infantry or uv.def.is_structure:
			continue
		if not w.mobility.has(uv.entity_id) or (w.mobility.speed[uv.entity_id] == 0 and not uv.def.is_air):
			continue
		var d: float = uv.global_position.distance_to(focus)
		if d < 700.0:
			cands.append([d, uv.entity_id])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k: int in range(ENGINES):
		var want: int = int(cands[k][1]) if k < cands.size() else 0
		if want == _engine_ids[k]:
			continue
		_engine_ids[k] = want
		var p: AudioStreamPlayer3D = _engines[k]
		if want == 0:
			p.stop()
			continue
		var d2: UnitStats = w.def_of(want)
		p.stream = _stream("rotor" if d2.is_air else ("engine_tracked" if d2.mobility_class == TerrainTable.TRACKED else "engine_wheeled"), true)
		p.volume_db = -6.0
		p.play()


func _weather(w: SimWorld, delta: float) -> void:
	var wind_db: float = lerpf(-24.0, -8.0, clampf(w.weather.wind_speed / 12000.0, 0.0, 1.0))
	_wind.volume_db = move_toward(_wind.volume_db, wind_db, delta * 6.0)
	_rain.volume_db = move_toward(_rain.volume_db, -6.0 if w.weather.raining else -80.0, delta * 15.0)


func _on_order(ids: PackedInt32Array) -> void:
	var w: SimWorld = runner.world
	for id: int in ids:
		if w.is_unit(id) and w.is_on_net(id):
			_radio.play()
			return


## Radio contact call when the team spots a new enemy (on-net teams only).
func _contacts(w: SimWorld, delta: float) -> void:
	_contact_cd -= delta
	var team: int = views.local_team
	if team >= w.visible_enemies.size():
		return
	var fresh: bool = false
	for id: int in w.visible_enemies[team]:
		if not _known_enemies.has(id):
			_known_enemies[id] = true
			fresh = true
	if fresh and _contact_cd <= 0.0:
		_contact_cd = 12.0
		_radio.play()
