## Palette atlas texture (16 swatches × 8 rows) built from palette.json.
## Shared by the scale-model, foliage and terrain shaders (docs/VISUALS.md §6.1).
class_name LookPalette
extends RefCounted

const PATH: String = "res://presentation/look/palette.json"
const COLUMNS: int = 16
const ROWS: int = 8

static var _texture: ImageTexture
static var _colors: Array[PackedColorArray] = []


static func colors() -> Array[PackedColorArray]:
	if _colors.is_empty():
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		var data: Dictionary = JSON.parse_string(f.get_as_text())
		var rows: Dictionary = data["rows"]
		var keys: Array = rows.keys()
		keys.sort()
		for k: Variant in keys:
			var hexes: Array = rows[k]
			var pc: PackedColorArray = PackedColorArray()
			for h: Variant in hexes:
				pc.append(Color(str(h)))
			_colors.append(pc)
	return _colors


static func swatch(row: int, col: int) -> Color:
	var c: Array[PackedColorArray] = colors()
	return c[row][col] if row < c.size() else Color.MAGENTA


static func texture() -> ImageTexture:
	if _texture == null:
		var img: Image = Image.create(COLUMNS, ROWS, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 0.5))
		var c: Array[PackedColorArray] = colors()
		for r: int in range(mini(ROWS, c.size())):
			for x: int in range(COLUMNS):
				img.set_pixel(x, r, c[r][x])
		_texture = ImageTexture.create_from_image(img)
	return _texture
