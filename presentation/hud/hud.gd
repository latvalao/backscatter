## Text HUD: resources, match status, current mode, selected unit card, key
## help, banners (victory/defeat/desync) and the Esc menu.
class_name Hud
extends CanvasLayer

var runner: SimRunner
var controller: SelectionController
var views: ViewSync
var scene: GameScene

var _status: Label
var _card: Label
var _help: Label
var _banner: Label
var _menu: PanelContainer
var _msg_timer: float = 0.0
var _last_msg: String = ""
var _ended: bool = false

const HELP: String = "LMB select/box, double-click selects type  |  RMB move/attack/board, drag to set facing  |  Shift queue  |  Alt+RMB reverse\n" \
	+ "A attack-move  R reverse  F fire mission  G smoke mission  X smoke  S stop  H hold fire  Y engage range (Shift+Y clear)\n" \
	+ "U unload  T unload at point  N formation  Tab subgroup  . idle unit  Home HQ  Space last alert  L line of sight\n" \
	+ "M lay mines (engineer)  RMB wreck: salvage (engineer)  I illumination flare (mortar/artillery)\n" \
	+ "K seize  O overwatch  B auto counter-battery  J crew rotation\n" \
	+ "F1-F8 build/produce  Ctrl+1-9 group  Z EMCON  Ctrl+RMB safe route  D dosimetry  V signals  P pause  +/- speed  Esc menu"


func _ready() -> void:
	_status = _label(Vector2(12, 8), 15)
	_card = _label(Vector2(12, 0), 15)
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_top = -230
	_card.offset_left = 245
	_help = _label(Vector2(0, 0), 13)
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.offset_left = -760
	_help.offset_top = 8
	_help.offset_right = -12
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.text = HELP
	_banner = _label(Vector2.ZERO, 34)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	_build_menu()


func _label(pos: Vector2, size: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var box: VBoxContainer = VBoxContainer.new()
	_menu.add_child(box)
	for pair: Array in [["Resume", func() -> void: toggle_menu()],
			["Save replay", func() -> void: banner("Replay saved: " + ProjectSettings.globalize_path(scene.save_replay()))],
			["Leave match", func() -> void: scene.leave()]]:
		var b: Button = Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(240, 36)
		b.pressed.connect(pair[1] as Callable)
		box.add_child(b)
	_menu.visible = false
	add_child(_menu)


func toggle_menu() -> void:
	_menu.visible = not _menu.visible


func banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func _process(delta: float) -> void:
	var w: SimWorld = runner.world
	var me: int = controller.local_player()
	var team: int = views.local_team
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for id: int in w.entities.ids():
		if w.units.has(id) and not w.is_structure(id):
			counts[w.units.team[id]] += 1
	var depots: int = 0
	var routed: int = 0
	for d: int in ObjectiveSystem._depots(w):
		if w.structures.holder_team[d] == team:
			depots += 1
			routed += w.structures.connected[d]
	var speed_txt: String = "PAUSED" if runner.speed == 0 else "%dx" % runner.speed
	var res: String = ""
	if me < w.players.count():
		res = "SUPPLY %d   MANPOWER %d   depots %d (%d on route)" % [w.players.supply[me], w.players.manpower[me], depots, routed]
	var mode_name: String = "REPLAY" if scene.replay_mode else settings_mode()
	_status.text = "%s   t=%d:%02d  [%s]   units %d vs %d   sim %.1f ms   %d FPS%s%s\n%s\n%s" % [
		mode_name, w.tick / 600, (w.tick / 10) % 60, speed_txt, counts[team], counts[1 - mini(team, 1)],
		runner.last_tick_ms, Engine.get_frames_per_second(), "   (REVEAL)" if views.reveal_all else "",
		"   WAITING FOR PLAYERS…" if runner.waiting and not scene.replay_mode else "", res, controller.mode_text()]
	if controller.message != _last_msg:
		_last_msg = controller.message
		_msg_timer = 3.0
	_msg_timer -= delta
	if _msg_timer > 0.0:
		_status.text += "\n" + controller.message
	_status.text += "\n" + _env_line(w, me)
	_card.text = _card_text(w)
	if w.winner_team >= 0 and not _ended:
		_ended = true
		if scene.stats != null:
			var ms: MatchSummary = MatchSummary.new()
			ms.stats = scene.stats
			ms.local_team = team
			ms.on_leave = func() -> void: scene.leave()
			add_child(ms)
			ms.build(w.winner_team)
		else:
			banner("VICTORY" if w.winner_team == team else "DEFEAT")


func _env_line(w: SimWorld, me: int) -> String:
	var wx: Weather = w.weather
	var compass: Array[String] = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
	var dir: String = compass[((wx.wind_dir + 4096) & 0xFFFF) / 8192]
	var wtxt: String = "wind → %s %d m/s%s%s%s" % [dir, wx.wind_speed / 1000, "  RAIN" if wx.raining else "",
		"  FOG" if wx.fog else "", "  NIGHT" if wx.night or w.is_night else ""]
	var gp: Variant = controller.cam.ground_point(controller.get_viewport().get_mouse_position())
	if gp != null:
		var s: Vector2i = SimRunner.view_to_sim(gp as Vector3)
		var banded: bool = scene.dosimetry != null and scene.dosimetry.banded()
		wtxt += "   cursor: " + DosimetryOverlay.format_rate(w.radfield.rate_at(s.x, s.y), banded)
	return wtxt


func settings_mode() -> String:
	return "Skirmish" if scene.settings.mode == "skirmish" else "Sandbox"


func _card_text(w: SimWorld) -> String:
	var sel: PackedInt32Array = controller.selection
	if sel.is_empty() or not w.is_unit(sel[0]):
		return ""
	if sel.size() > 1:
		var names: Dictionary = {}
		for id: int in sel:
			if w.is_unit(id):
				var n: String = w.def_of(id).display_name
				names[n] = int(names.get(n, 0)) + 1
		var parts: PackedStringArray = PackedStringArray()
		for n: String in names.keys():
			parts.append("%d× %s" % [names[n], n])
		return "%d selected: %s\nformation: %s" % [sel.size(), ", ".join(parts), Formation.NAMES[controller.formation]]
	var id: int = sel[0]
	var d: UnitStats = w.def_of(id)
	var u: UnitStore = w.units
	var lines: PackedStringArray = PackedStringArray()
	if d.is_structure:
		lines.append("%s   hp %d/%d%s" % [d.display_name, u.hp[id], d.hp,
			"" if w.structures.is_complete(id) else "   UNDER CONSTRUCTION"])
		return "\n".join(lines)
	lines.append("%s   [%s]   %s (%d xp)   order: %s%s%s" % [d.display_name, d.role, Veterancy.NAMES[u.rank[id]], u.xp[id],
		OrderStore.NAMES[w.orders.kind[id]], "   HOLD FIRE" if u.stance[id] == UnitStore.STANCE_HOLD_FIRE else "",
		"   ROUTING" if u.rout_until[id] > w.tick else ("   DUG IN" if FieldSystem.dug_in_bonus(w, id) > 0 and d.is_infantry else "")])
	if d.is_infantry:
		var hp: PackedStringArray = PackedStringArray()
		for m: int in range(d.members):
			hp.append(str(w.squads.member_hp[id * SquadStore.MAX_MEMBERS + m]))
		lines.append("soldiers %d/%d   hp [%s]" % [u.members_alive[id], d.members, " ".join(hp)])
	else:
		lines.append("hp %d/%d   armour F%d S%d R%d T%d   crew %s   damage %s" % [u.hp[id], d.hp,
			d.armour_front, d.armour_side, d.armour_rear, d.armour_top, _crew(d, u.crew[id]), _damage(u.damage[id])])
	var extra: String = ""
	if Transport.capacity(d) > 0:
		var pax: PackedInt32Array = Transport.passengers(w, id)
		var pn: PackedStringArray = PackedStringArray()
		for pid: int in pax:
			pn.append(w.def_of(pid).display_name)
		extra += "   carrying %s" % (", ".join(pn) if not pn.is_empty() else "nobody")
	if u.engage_range[id] > 0:
		extra += "   opens fire inside %d m" % (u.engage_range[id] / 1000)
	if d.fuel_capacity > 0:
		extra += "   fuel %d/%d L" % [w.logistics.fuel[id] / 1000, d.fuel_capacity / 1000]
	if d.cargo_capacity > 0:
		extra += "   cargo %d/%d" % [w.logistics.cargo[id], d.cargo_capacity]
	lines.append("suppression %d%%   morale %d   kills %d   smoke %d   speed %d km/h%s" % [u.suppression[id] / 10, u.morale[id],
		u.kills[id], u.smoke_charges[id], absi(w.mobility.speed[id]) * 36 / 1000, extra])
	if w.radiation.has(id):
		var dose: int = w.radiation.dose[id]
		lines.append("dose %d mSv (%s)   contamination %s   EMCON %s%s%s" % [dose / 1000, DoseState.NAMES[DoseState.of(dose)],
			"%d µSv/h" % w.radiation.contamination[id] if w.radiation.contamination[id] > 0 else "none",
			UnitStore.EMCON_NAMES[u.emcon[id]], "   OFF NET" if not w.is_on_net(id) else "", "   JAMMED" if w.jammed[id] == 1 else ""])
	if d.is_air:
		lines.append("battery %ds   link %s" % [maxi(0, d.battery_ticks - w.logistics.odometer[id]) / 10, "LOST" if u.link_lost[id] > 0 else "ok"])
	for s: int in range(d.weapons.size()):
		var wd: WeaponStats = w.defs.weapons[d.weapons[s]]
		var k: int = id * WeaponStore.MAX_WEAPONS + s
		var tgt: int = w.weapons.target[k]
		lines.append("  %-20s ammo %4d/%d   %s" % [wd.id, w.weapons.ammo[k], wd.ammo_capacity, ("→ #%d" % tgt) if tgt > 0 else ""])
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
