## Fog-of-war texture for the terrain shader: cells within vision range of any
## local-team unit are lit. Approximation (range circles, no LOS) — unit
## visibility itself comes from the sim's per-team spotting.
class_name FogOverlay
extends Node

const RES_CELLS: int = 4          # one texel per 4×4 sim cells (32 m)
const UPDATE_INTERVAL: float = 0.5

var runner: SimRunner
var terrain: TerrainView
var local_team: int = 0

var _img: Image
var _tex: ImageTexture
var _timer: float = 0.0
var _w: int = 1
var _h: int = 1


func setup() -> void:
	var g: SimGrid = runner.world.grid
	_w = (g.width + RES_CELLS - 1) / RES_CELLS
	_h = (g.height + RES_CELLS - 1) / RES_CELLS
	_img = Image.create(_w, _h, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	terrain.set_fog_texture(_tex)
	_refresh()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and runner != null and runner.world != null:
		_timer = UPDATE_INTERVAL
		_refresh()


func _refresh() -> void:
	var w: SimWorld = runner.world
	var data: PackedByteArray = PackedByteArray()
	data.resize(_w * _h)
	var texel_m: float = RES_CELLS * SimGrid.CELL_MM * 0.001
	var t: TransformStore = w.transform
	for id: int in w.entities.ids():
		if not w.units.has(id) or w.units.team[id] != local_team:
			continue
		var ranges: Vector2i = VisionSystem.observer_ranges(w, id)
		var r_m: float = maxi(ranges.x, ranges.y) * 0.001 * 0.75
		var cx: float = t.x[id] * 0.001 / texel_m
		var cy: float = t.y[id] * 0.001 / texel_m
		var rr: float = r_m / texel_m
		var x0: int = maxi(0, floori(cx - rr))
		var x1: int = mini(_w - 1, ceili(cx + rr))
		var y0: int = maxi(0, floori(cy - rr))
		var y1: int = mini(_h - 1, ceili(cy + rr))
		var rr2: float = rr * rr
		for y: int in range(y0, y1 + 1):
			var dy: float = y + 0.5 - cy
			for x: int in range(x0, x1 + 1):
				var dx: float = x + 0.5 - cx
				if dx * dx + dy * dy <= rr2:
					data[y * _w + x] = 255
	_img.set_data(_w, _h, false, Image.FORMAT_L8, data)
	_tex.update(_img)
