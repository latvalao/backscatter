## Text HUD: match status, current mode, selected unit card and key help.
class_name Hud
extends CanvasLayer

var runner: SimRunner
var controller: SelectionController
var views: ViewSync

var _status: Label
var _card: Label
var _help: Label
var _msg_timer: float = 0.0
var _last_msg: String = ""

const HELP: String = "LMB select/box · RMB move / attack (on enemy) · Shift queue · Alt+RMB reverse\n" \
	+ "A attack-move · R reverse · F fire mission · G smoke mission · X smoke launchers · S stop · H hold fire\n" \
	+ "Ctrl+1-9 set group · 1-9 recall · arrows/edge/MMB pan · wheel zoom · Q/E rotate · PgUp/PgDn pitch\n" \
	+ "P pause · +/- speed · F9 reveal map · F10 toggle labels"


func _ready() -> void:
	_status = _label(Vector2(12, 8), 15)
	_card = _label(Vector2(12, 0), 15)
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_top = -230
	_help = _label(Vector2(0, 0), 13)
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.offset_left = -640
	_help.offset_top = 8
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.offset_right = -12
	_help.text = HELP


func _label(pos: Vector2, size: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


func _process(delta: float) -> void:
	var w: SimWorld = runner.world
	var counts: PackedInt32Array = PackedInt32Array([0, 0])
	for id: int in w.entities.ids():
		if w.units.has(id) and w.units.team[id] < 2:
			counts[w.units.team[id]] += 1
	var speed_txt: String = "PAUSED" if runner.speed == 0 else "%dx" % runner.speed
	_status.text = "Backscatter — sandbox   t=%d:%02d  [%s]   NC %d  vs  EC %d   sim %.1f ms   %d FPS%s\n%s" % [
		w.tick / 600, (w.tick / 10) % 60, speed_txt, counts[0], counts[1], runner.last_tick_ms,
		Engine.get_frames_per_second(), "   (REVEAL)" if views.reveal_all else "", controller.mode_text()]
	if controller.message != _last_msg:
		_last_msg = controller.message
		_msg_timer = 3.0
	_msg_timer -= delta
	if _msg_timer > 0.0:
		_status.text += "\n" + controller.message
	_card.text = _card_text(w)


func _card_text(w: SimWorld) -> String:
	var sel: PackedInt32Array = controller.selection
	if sel.is_empty():
		return ""
	if sel.size() > 1:
		var names: Dictionary = {}
		for id: int in sel:
			var n: String = w.def_of(id).display_name
			names[n] = int(names.get(n, 0)) + 1
		var parts: PackedStringArray = PackedStringArray()
		for n: String in names.keys():
			parts.append("%d× %s" % [names[n], n])
		return "%d selected: %s" % [sel.size(), ", ".join(parts)]
	var id: int = sel[0]
	var d: UnitStats = w.def_of(id)
	var u: UnitStore = w.units
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s   [%s]   order: %s%s" % [d.display_name, d.role, OrderStore.NAMES[w.orders.kind[id]],
		"   HOLD FIRE" if u.stance[id] == UnitStore.STANCE_HOLD_FIRE else ""])
	if d.is_infantry:
		var hp: PackedStringArray = PackedStringArray()
		for m: int in range(d.members):
			hp.append(str(w.squads.member_hp[id * SquadStore.MAX_MEMBERS + m]))
		lines.append("soldiers %d/%d   hp [%s]" % [u.members_alive[id], d.members, " ".join(hp)])
	else:
		lines.append("hp %d/%d   armour F%d S%d R%d T%d   crew %s   damage %s" % [u.hp[id], d.hp,
			d.armour_front, d.armour_side, d.armour_rear, d.armour_top, _crew(d, u.crew[id]), _damage(u.damage[id])])
	lines.append("suppression %d%%   morale %d   kills %d   smoke %d   speed %d km/h" % [u.suppression[id] / 10, u.morale[id],
		u.kills[id], u.smoke_charges[id], absi(w.mobility.speed[id]) * 36 / 1000])
	for s: int in range(d.weapons.size()):
		var wd: WeaponStats = w.defs.weapons[d.weapons[s]]
		var k: int = id * WeaponStore.MAX_WEAPONS + s
		var tgt: int = w.weapons.target[k]
		lines.append("  %-20s ammo %4d   %s" % [wd.id, w.weapons.ammo[k], ("→ #%d" % tgt) if tgt > 0 else ""])
	return "\n".join(lines)


func _crew(d: UnitStats, mask: int) -> String:
	var out: String = ""
	var names: Array[String] = ["D", "G", "C", "L"]
	for b: int in range(4):
		if d.has_crew(1 << b):
			out += names[b] if (mask & (1 << b)) != 0 else "x"
	return out


func _damage(mask: int) -> String:
	if mask == 0:
		return "none"
	var parts: PackedStringArray = PackedStringArray()
	for pair: Array in [[UnitStore.DMG_ENGINE, "engine"], [UnitStore.DMG_TRACKS, "tracks"], [UnitStore.DMG_TURRET, "turret"], [UnitStore.DMG_OPTICS, "optics"]]:
		var bit: int = pair[0]
		if (mask & bit) != 0:
			parts.append(str(pair[1]))
	return ",".join(parts)
