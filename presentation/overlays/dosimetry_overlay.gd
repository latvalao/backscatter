## Dosimetry overlay (§5.4/§8): dose-rate heat map on the terrain + wind for the
## HUD. Coalition reads exact values; Eastern sees coarse bands unless one of
## its units with the "dosimetry" ability (chemical troops) is in the field.
class_name DosimetryOverlay
extends Node

const UPDATE_INTERVAL: float = 1.0

var runner: SimRunner
var terrain: TerrainView
var local_player: int = 0
var enabled: bool = false

var _img: Image
var _tex: ImageTexture
var _timer: float = 0.0


func setup() -> void:
	var f: RadiationField = runner.world.radfield
	_img = Image.create(f.w, f.h, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	terrain.set_rad_texture(_tex)
	_refresh()


func toggle() -> void:
	enabled = not enabled
	terrain.set_rad_enabled(enabled, banded())


func banded() -> bool:
	var w: SimWorld = runner.world
	if local_player >= w.players.count() or w.players.faction[local_player] == "nc":
		return false
	for id: int in w.entities.ids():
		if w.is_unit(id) and w.units.owner[id] == local_player and w.def_of(id).has_ability("dosimetry"):
			return false
	return true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		_refresh()
		if enabled:
			terrain.set_rad_enabled(true, banded())


func _refresh() -> void:
	var f: RadiationField = runner.world.radfield
	var data: PackedByteArray = PackedByteArray()
	data.resize(f.w * f.h)
	for i: int in range(f.w * f.h):
		var rate: float = float(f.ground[i] + f.air[i])
		data[i] = clampi(int(log(maxf(1.0, rate)) / log(10.0) / 7.5 * 255.0), 0, 255)
	_img.set_data(f.w, f.h, false, Image.FORMAT_L8, data)
	_tex.update(_img)


## Human-readable dose rate for the HUD, banded for Eastern players.
static func format_rate(rate_usv_h: int, banded: bool) -> String:
	if banded:
		if rate_usv_h < 1000:
			return "background"
		if rate_usv_h < 100_000:
			return "elevated"
		if rate_usv_h < 1_000_000:
			return "HIGH"
		return "DANGEROUS"
	if rate_usv_h < 1000:
		return "%d µSv/h" % rate_usv_h
	if rate_usv_h < 1_000_000:
		return "%.1f mSv/h" % (rate_usv_h / 1000.0)
	return "%.2f Sv/h" % (rate_usv_h / 1_000_000.0)
