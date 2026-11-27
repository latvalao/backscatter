## Geiger counter (§8): click rate follows the dose rate at the selected units.
## Procedurally generated clicks (no audio assets yet).
class_name Geiger
extends AudioStreamPlayer

const MIX_RATE: float = 22050.0

var runner: SimRunner
var controller: SelectionController
var _playback: AudioStreamGeneratorPlayback
var _rate_hz: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	stream = gen
	volume_db = -10.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null or runner == null:
		return
	var w: SimWorld = runner.world
	var rate: int = 0
	for id: int in controller.selection:
		if w.is_unit(id):
			rate = maxi(rate, w.radfield.rate_at(w.transform.x[id], w.transform.y[id]))
	# ~1 click/s at background, saturating around 60/s in a hot zone
	_rate_hz = clampf(log(maxf(1.0, float(rate))) / log(10.0) * 8.0 - 6.0, 0.0, 60.0) if not controller.selection.is_empty() else 0.0
	var frames: int = _playback.get_frames_available()
	var p_click: float = _rate_hz / MIX_RATE
	var click_left: int = 0
	for i: int in range(frames):
		if click_left <= 0 and _rng.randf() < p_click:
			click_left = 40
		var v: float = 0.0
		if click_left > 0:
			v = (0.6 if click_left > 35 else -0.3) * (click_left / 40.0)
			click_left -= 1
		_playback.push_frame(Vector2(v, v))
