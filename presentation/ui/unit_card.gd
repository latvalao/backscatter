## Unit card (Phase 8). One unit: name, rank, health, armour diagram, crew,
## weapons with ammo, fuel, dose, cargo and status chips. Several units: one
## tile per type with count and health; click a tile to keep only that type.
class_name UnitCard
extends PanelContainer

var runner: SimRunner
var controller: SelectionController
var views: ViewSync

var _canvas: Control
var _tiles: Array[Dictionary] = []   # {rect, def_index}


func _ready() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 240
	offset_right = 760
	offset_top = -244
	offset_bottom = -10
	mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(500, 218)
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.draw.connect(_draw_card)
	_canvas.gui_input.connect(_on_input)
	add_child(_canvas)


func _process(_d: float) -> void:
	visible = not controller.selection.is_empty()
	if visible:
		_canvas.queue_redraw()


func _on_input(e: InputEvent) -> void:
	var mb: InputEventMouseButton = e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for t: Dictionary in _tiles:
		if (t["rect"] as Rect2).has_point(mb.position):
			var keep: PackedInt32Array = PackedInt32Array()
			for id: int in controller.selection:
				if runner.world.units.def_index[id] == int(t["def"]):
					keep.append(id)
			controller._set_selection(keep)
			return


func _draw_card() -> void:
	_tiles.clear()
	var w: SimWorld = runner.world
	var sel: PackedInt32Array = controller.selection
	if sel.is_empty() or not w.is_unit(sel[0]):
		return
	if sel.size() > 1:
		_draw_group(w, sel)
	else:
		_draw_single(w, sel[0])


func _draw_group(w: SimWorld, sel: PackedInt32Array) -> void:
	var by: Dictionary = {}
	for id: int in sel:
		if not w.is_unit(id):
			continue
		var k: int = w.units.def_index[id]
		if not by.has(k):
			by[k] = []
		(by[k] as Array).append(id)
	UiStyle.text(_canvas, Vector2(0, 14), "%d units   formation: %s" % [sel.size(), Formation.NAMES[controller.formation]], UiStyle.FONT_M, UiStyle.TEXT, false)
	var x: float = 0.0
	var y: float = 26.0
	var keys: Array = by.keys()
	keys.sort()
	for k2: Variant in keys:
		var ids: Array = by[k2]
		var d: UnitStats = w.defs.units[int(k2)]
		var r: Rect2 = Rect2(x, y, 120, 48)
		_canvas.draw_rect(r, Color(1, 1, 1, 0.05))
		_canvas.draw_rect(r, UiStyle.LINE, false, 1.0)
		UiStyle.text(_canvas, Vector2(x + 6, y + 16), _short(d.display_name, 17), UiStyle.FONT_S, UiStyle.TEXT, false)
		UiStyle.text(_canvas, Vector2(x + 6, y + 34), "x%d" % ids.size(), UiStyle.FONT_L, UiStyle.AMBER, false)
		var hp: float = 0.0
		for id2: Variant in ids:
			hp += _health(w, int(id2))
		UiStyle.bar(_canvas, Rect2(x + 46, y + 28, 66, 5), hp / ids.size(), UiStyle.health_color(hp / ids.size()))
		_tiles.append({"rect": r, "def": int(k2)})
		x += 126.0
		if x > 380.0:
			x = 0.0
			y += 54.0
		if y > 140.0:
			break


func _draw_single(w: SimWorld, id: int) -> void:
	var d: UnitStats = w.def_of(id)
	var u: UnitStore = w.units
	UiStyle.text(_canvas, Vector2(0, 16), d.display_name, UiStyle.FONT_L, UiStyle.TEXT, false)
	var sub: String = d.role.capitalize()
	if not d.is_structure:
		sub += "   " + Veterancy.NAMES[u.rank[id]] + ("  (%d xp)" % u.xp[id])
		sub += "   " + OrderStore.NAMES[w.orders.kind[id]].capitalize()
	UiStyle.text(_canvas, Vector2(0, 34), sub, UiStyle.FONT_S, UiStyle.DIM, false)
	var f: float = _health(w, id)
	var hp_txt: String = "%d / %d soldiers" % [u.members_alive[id], d.members] if d.is_infantry else "%d / %d" % [maxi(0, u.hp[id]), d.hp]
	UiStyle.text(_canvas, Vector2(0, 54), "Health", UiStyle.FONT_S, UiStyle.DIM, false)
	UiStyle.bar(_canvas, Rect2(60, 46, 150, 8), f, UiStyle.health_color(f))
	UiStyle.text(_canvas, Vector2(216, 54), hp_txt, UiStyle.FONT_S, UiStyle.TEXT, false)
	var y: float = 72.0
	if not d.is_structure:
		UiStyle.text(_canvas, Vector2(0, y), "Suppression", UiStyle.FONT_S, UiStyle.DIM, false)
		UiStyle.bar(_canvas, Rect2(80, y - 8, 130, 6), u.suppression[id] / 1000.0, UiStyle.AMBER)
		y += 16.0
	if w.radiation.has(id) and not d.is_structure:
		var dose: int = w.radiation.dose[id]
		var st: int = DoseState.of(dose)
		UiStyle.text(_canvas, Vector2(0, y), "Dose", UiStyle.FONT_S, UiStyle.DIM, false)
		UiStyle.bar(_canvas, Rect2(80, y - 8, 130, 6), minf(1.0, dose / 4000000.0), [UiStyle.GOOD, UiStyle.AMBER, UiStyle.AMBER, UiStyle.BAD, UiStyle.BAD][st])
		UiStyle.text(_canvas, Vector2(216, y), "%d mSv  %s" % [dose / 1000, DoseState.NAMES[st]], UiStyle.FONT_S, UiStyle.TEXT, false)
		y += 16.0
	if d.fuel_capacity > 0:
		var ff: float = float(w.logistics.fuel[id]) / maxi(1, d.fuel_capacity)
		UiStyle.text(_canvas, Vector2(0, y), "Fuel", UiStyle.FONT_S, UiStyle.DIM, false)
		UiStyle.bar(_canvas, Rect2(80, y - 8, 130, 6), ff, UiStyle.health_color(ff))
		y += 16.0
	if d.cargo_capacity > 0:
		UiStyle.text(_canvas, Vector2(0, y), "Cargo %d / %d" % [w.logistics.cargo[id], d.cargo_capacity], UiStyle.FONT_S, UiStyle.TEXT, false)
		y += 16.0
	if Transport.capacity(d) > 0:
		var pax: PackedInt32Array = Transport.passengers(w, id)
		var names: PackedStringArray = PackedStringArray()
		for p: int in pax:
			names.append(w.def_of(p).display_name)
		UiStyle.text(_canvas, Vector2(0, y), "Carrying: " + (", ".join(names) if not names.is_empty() else "empty"), UiStyle.FONT_S, UiStyle.CYAN, false)
		y += 16.0
	# status chips
	var chips: Array = []
	if u.rout_until[id] > w.tick:
		chips.append(["ROUTING", UiStyle.BAD])
	elif u.suppression[id] >= MoraleSystem.PIN_THRESHOLD:
		chips.append(["PINNED", UiStyle.AMBER])
	if u.stance[id] == UnitStore.STANCE_HOLD_FIRE:
		chips.append(["HOLD FIRE", UiStyle.AMBER])
	if u.engage_range[id] > 0:
		chips.append(["FIRE INSIDE %d m" % (u.engage_range[id] / 1000), UiStyle.TEXT])
	if u.overwatch_dir[id] >= 0:
		chips.append(["OVERWATCH", UiStyle.TEXT])
	if (u.smart[id] & UnitStore.SMART_AUTO_CB) != 0:
		chips.append(["AUTO CB", UiStyle.CYAN])
	if (u.smart[id] & UnitStore.SMART_ROTATE) != 0:
		chips.append(["ROTATION", UiStyle.CYAN])
	if d.emitter_kind != UnitStats.EMIT_NONE and not d.is_structure:
		chips.append(["EMCON " + UnitStore.EMCON_NAMES[u.emcon[id]], UiStyle.CYAN if u.emcon[id] != UnitStore.EMCON_EMIT else UiStyle.DIM])
	if not d.is_structure and not w.is_on_net(id):
		chips.append(["OFF NET", UiStyle.AMBER])
	if w.jammed[id] == 1:
		chips.append(["JAMMED", UiStyle.BAD])
	if d.is_infantry and FieldSystem.dug_in_bonus(w, id) > 0:
		chips.append(["DUG IN", UiStyle.GOOD])
	if w.radiation.has(id) and w.radiation.contamination[id] > 0:
		chips.append(["CONTAMINATED", UiStyle.AMBER])
	var cx: float = 0.0
	var cy: float = maxf(y + 4.0, 150.0)
	for ch: Array in chips:
		var t: String = str(ch[0])
		var cw: float = UiStyle.text_width(t, UiStyle.FONT_S - 1) + 10.0
		if cx + cw > 290.0:
			cx = 0.0
			cy += 18.0
		_canvas.draw_rect(Rect2(cx, cy - 12, cw, 16), Color(0, 0, 0, 0.4))
		_canvas.draw_rect(Rect2(cx, cy - 12, cw, 16), (ch[1] as Color) * Color(1, 1, 1, 0.6), false, 1.0)
		UiStyle.text(_canvas, Vector2(cx + 5, cy), t, UiStyle.FONT_S - 1, ch[1] as Color, false)
		cx += cw + 4.0
	# right column: armour diagram, crew, weapons
	var rx: float = 310.0
	if not d.is_infantry and not d.is_structure:
		_armour(Vector2(rx + 30, 40), d, u.damage[id])
		_crew(Vector2(rx + 80, 20), d, u.crew[id])
	var wy: float = 100.0 if not d.is_infantry else 20.0
	for s: int in range(d.weapons.size()):
		var wd: WeaponStats = w.defs.weapons[d.weapons[s]]
		var k: int = id * WeaponStore.MAX_WEAPONS + s
		var af: float = float(w.weapons.ammo[k]) / maxi(1, wd.ammo_capacity)
		UiStyle.text(_canvas, Vector2(rx, wy), weapon_name(wd.id), UiStyle.FONT_S, UiStyle.TEXT, false)
		UiStyle.text(_canvas, Vector2(rx + 128, wy), "%d m" % (wd.range_max_mm / 1000), UiStyle.FONT_S - 1, UiStyle.DIM, false)
		UiStyle.bar(_canvas, Rect2(rx, wy + 3, 180, 3), af, UiStyle.health_color(af))
		wy += 22.0


func _armour(c: Vector2, d: UnitStats, dmg: int) -> void:
	var r: Rect2 = Rect2(c - Vector2(14, 24), Vector2(28, 48))
	_canvas.draw_rect(r, Color(1, 1, 1, 0.06))
	_canvas.draw_rect(r, UiStyle.DIM, false, 1.0)
	UiStyle.text(_canvas, c + Vector2(-10, -30), str(d.armour_front), UiStyle.FONT_S - 1, UiStyle.TEXT, false)
	UiStyle.text(_canvas, c + Vector2(-10, 42), str(d.armour_rear), UiStyle.FONT_S - 1, UiStyle.TEXT, false)
	UiStyle.text(_canvas, c + Vector2(18, 4), str(d.armour_side), UiStyle.FONT_S - 1, UiStyle.TEXT, false)
	UiStyle.text(_canvas, c + Vector2(-8, 4), str(d.armour_top), UiStyle.FONT_S - 2, UiStyle.DIM, false)
	var parts: PackedStringArray = PackedStringArray()
	for pair: Array in [[UnitStore.DMG_ENGINE, "engine"], [UnitStore.DMG_TRACKS, "tracks"], [UnitStore.DMG_TURRET, "turret"], [UnitStore.DMG_OPTICS, "optics"]]:
		if (dmg & int(pair[0])) != 0:
			parts.append(str(pair[1]))
	if not parts.is_empty():
		UiStyle.text(_canvas, c + Vector2(-30, 62), "Damaged: " + ", ".join(parts), UiStyle.FONT_S - 1, UiStyle.BAD, false)


func _crew(p: Vector2, d: UnitStats, mask: int) -> void:
	var names: Array[String] = ["Driver", "Gunner", "Commander", "Loader"]
	var y: float = p.y
	for b: int in range(4):
		if not d.has_crew(1 << b):
			continue
		var alive: bool = (mask & (1 << b)) != 0
		_canvas.draw_circle(Vector2(p.x, y - 4), 4.0, UiStyle.GOOD if alive else UiStyle.BAD)
		UiStyle.text(_canvas, Vector2(p.x + 8, y), names[b], UiStyle.FONT_S - 1, UiStyle.TEXT if alive else UiStyle.BAD, false)
		y += 15.0


func _health(w: SimWorld, id: int) -> float:
	var d: UnitStats = w.def_of(id)
	if d.is_infantry:
		return float(w.units.members_alive[id]) / maxi(1, d.members)
	return float(maxi(0, w.units.hp[id])) / maxi(1, d.hp)


const WEAPON_NAMES: Dictionary = {
	"nc_rifle": "Assault rifles", "ec_rifle": "Assault rifles", "mr_rifle": "Rifles", "nc_lmg": "Light machine gun",
	"ec_pkm": "Machine gun", "nc_law": "Light anti-tank rocket", "ec_rpg": "RPG", "mr_rpg7": "RPG",
	"nc_atgm_ff": "Fire-and-forget ATGM", "ec_atgm_wire": "Wire-guided ATGM", "nc_mortar_81": "81 mm mortar",
	"nc_mortar_81_smoke": "81 mm mortar, smoke", "ec_mortar_120": "120 mm mortar", "ec_mortar_120_smoke": "120 mm mortar, smoke",
	"mr_mortar_82": "82 mm mortar", "coax_mg": "Coaxial machine gun", "nc_ac_40": "40 mm autocannon",
	"ec_ac_30": "30 mm autocannon", "nc_gun_120": "120 mm gun", "ec_gun_125": "125 mm gun", "nc_how_155": "155 mm howitzer",
	"ec_how_122": "122 mm howitzer", "ec_aa_23": "23 mm AA guns", "mr_hmg": "Heavy machine gun", "mr_gun_100": "100 mm gun",
	"nc_heli_atgm": "Air-launched ATGM", "nc_heli_30": "30 mm chain gun", "ec_heli_atgm": "Air-launched ATGM",
	"ec_heli_rockets": "Rocket pods", "door_gun": "Door gun",
}


static func weapon_name(id: String) -> String:
	return str(WEAPON_NAMES.get(id, id.replace("_", " ").capitalize()))


func _short(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "."
