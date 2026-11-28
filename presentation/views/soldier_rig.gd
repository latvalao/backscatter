## One animated soldier: a small skeleton of Node3D joints carrying the forged
## limb meshes (Rig* parts of the squad model). Poses are procedural and blend
## smoothly: walk / run cycle, kneel, prone with crawl, aiming, recoil, lying
## wounded, dragging a casualty, treating one, and a dead pose for corpses.
## Driven by UnitView from the soldier's sim state; purely presentation.
class_name SoldierRig
extends Node3D

const STAND: int = 0
const CROUCH: int = 1
const PRONE: int = 2

const HIP_H: float = 0.93
const DRAW_SCALE: float = 1.2

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _sh: Array[Node3D] = []     # shoulders L, R
var _el: Array[Node3D] = []     # elbows L, R
var _hp: Array[Node3D] = []     # hip joints L, R
var _kn: Array[Node3D] = []     # knees L, R
var _weapon: Node3D
var _meshes: Dictionary = {}
var _mat: Material
var _alt: bool = false

var phase: float = 0.0
## Lying already (prone or wounded): his body doesn't need to fall.
var lying: bool = false
var _recoil: float = 0.0
var _anim_t: float = 0.0


## meshes: part name -> Mesh (RigTorso, RigHead, RigUpperArm, RigForearm,
## RigThigh, RigShin, RigRifle, RigWeaponB). alt = carries the support weapon.
func build(meshes: Dictionary, mat: Material, alt: bool) -> void:
	_meshes = meshes
	_mat = mat
	_alt = alt
	scale = Vector3.ONE * DRAW_SCALE
	_hips = _joint(self, Vector3(0, HIP_H, 0))
	_torso = _joint(_hips, Vector3.ZERO, "RigTorso")
	_head = _joint(_torso, Vector3(0, 0.5, 0.0), "RigHead")
	for s: float in [-1.0, 1.0]:
		var sh: Node3D = _joint(_torso, Vector3(s * 0.25, 0.44, 0.0), "RigUpperArm")
		_sh.append(sh)
		_el.append(_joint(sh, Vector3(0, -0.3, 0), "RigForearm"))
		var hp: Node3D = _joint(_hips, Vector3(s * 0.11, -0.02, 0.0), "RigThigh")
		_hp.append(hp)
		_kn.append(_joint(hp, Vector3(0, -0.45, 0), "RigShin"))
	_weapon = _joint(_torso, Vector3(0.06, 0.3, -0.3), "RigWeaponB" if alt and meshes.has("RigWeaponB") else "RigRifle")


func _joint(parent: Node3D, pos: Vector3, mesh_name: String = "") -> Node3D:
	var j: Node3D = Node3D.new()
	j.position = pos
	parent.add_child(j)
	if mesh_name != "" and _meshes.has(mesh_name):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _meshes[mesh_name]
		mi.material_override = _mat
		j.add_child(mi)
	return j


## A fresh rig in the dead pose with a plain material (for Effects bodies).
func corpse(plain: Material) -> SoldierRig:
	var c: SoldierRig = SoldierRig.new()
	c.build(_meshes, plain, _alt)
	c._pose_dead(get_instance_id())
	return c


func fire() -> void:
	_recoil = 1.0


## World position of the weapon muzzle (for flashes).
func muzzle() -> Vector3:
	return _weapon.global_transform * Vector3(0, -0.04, -0.6 if not _alt else -0.75)


## speed in m/s over the ground. posture 0/1/2. aiming: engaged at a target.
## wounded: lying hurt. dragging / treating: helping a casualty.
func animate(delta: float, speed: float, posture: int, aiming: bool, wounded: bool, dragging: bool, treating: bool) -> void:
	_anim_t += delta
	lying = wounded or posture == PRONE
	_recoil = maxf(0.0, _recoil - delta * 7.0)
	var running: bool = speed > 3.2
	if speed > 0.15:
		phase += delta * speed * (2.6 if posture != PRONE else 4.0) / maxf(0.8, 1.0 + speed * 0.08)
	var moving: bool = speed > 0.15
	var p: Dictionary = {}
	if wounded:
		_pose_wounded(p)
	elif treating:
		_pose_kneel(p)
		p["torso"] = Vector3(-0.65, 0, 0)
		p["head"] = Vector3(0.35, 0, 0)
		var w: float = sin(_anim_t * 3.0) * 0.25
		p["sh0"] = Vector3(1.1 + w, 0, 0.1)
		p["sh1"] = Vector3(1.1 - w, 0, -0.1)
		p["el0"] = Vector3(0.6, 0, 0)
		p["el1"] = Vector3(0.6, 0, 0)
		p["wpn_slung"] = 1.0
	elif dragging:
		# walking backwards, bent over, both hands on the casualty's harness
		_pose_walk(p, phase, 0.35, false)
		p["torso"] = Vector3(-0.75, 0, 0)
		p["hips_y"] = HIP_H - 0.12
		p["sh0"] = Vector3(0.6, 0, 0.15)
		p["sh1"] = Vector3(0.6, 0, -0.15)
		p["el0"] = Vector3(0.2, 0, 0)
		p["el1"] = Vector3(0.2, 0, 0)
		p["wpn_slung"] = 1.0
	elif posture == PRONE:
		_pose_prone(p, moving)
	elif posture == CROUCH and not moving:
		_pose_kneel(p)
		_arms_aim(p, aiming, false)
	else:
		_pose_walk(p, phase, 0.75 if running else 0.45, running)
		if posture == CROUCH:
			p["hips_y"] = HIP_H - 0.18
			p["torso"] = Vector3(-0.35, 0, 0)
		_arms_aim(p, aiming and not running, moving)
	_apply(p, delta)


func _pose_walk(p: Dictionary, ph: float, amp: float, running: bool) -> void:
	var s: float = sin(ph)
	p["hips_y"] = HIP_H - absf(cos(ph)) * (0.06 if running else 0.03)
	p["hips_rot"] = Vector3(0, 0, 0)
	p["torso"] = Vector3(-0.28 if running else -0.06, s * 0.08, 0)
	p["head"] = Vector3(0.1 if running else 0.0, 0, 0)
	p["hp0"] = Vector3(s * amp, 0, 0)
	p["hp1"] = Vector3(-s * amp, 0, 0)
	p["kn0"] = Vector3(-maxf(0.0, -cos(ph)) * amp * 1.4 - 0.05, 0, 0)
	p["kn1"] = Vector3(-maxf(0.0, cos(ph)) * amp * 1.4 - 0.05, 0, 0)


func _pose_kneel(p: Dictionary) -> void:
	p["hips_y"] = 0.56
	p["hips_rot"] = Vector3.ZERO
	p["torso"] = Vector3(-0.12, 0, 0)
	p["head"] = Vector3(0.05, 0, 0)
	p["hp0"] = Vector3(1.45, 0, 0.05)
	p["kn0"] = Vector3(-1.45, 0, 0)
	p["hp1"] = Vector3(0.25, 0, -0.08)
	p["kn1"] = Vector3(-1.75, 0, 0)


func _pose_prone(p: Dictionary, crawling: bool) -> void:
	var c: float = sin(phase) if crawling else 0.0
	p["hips_y"] = 0.17
	p["hips_rot"] = Vector3(-1.47, 0, 0)
	p["torso"] = Vector3(0.08, 0, 0)
	p["head"] = Vector3(1.0, 0, 0)
	p["hp0"] = Vector3(c * 0.35, 0, 0.18 + absf(c) * 0.25)
	p["hp1"] = Vector3(-c * 0.35, 0, -0.18 - absf(c) * 0.25)
	p["kn0"] = Vector3(-0.15 - maxf(0.0, c) * 0.9, 0, 0)
	p["kn1"] = Vector3(-0.15 - maxf(0.0, -c) * 0.9, 0, 0)
	# elbows on the ground, weapon forward
	p["sh0"] = Vector3(2.55 + c * 0.25, 0, 0.25)
	p["sh1"] = Vector3(2.55 - c * 0.25, 0, -0.25)
	p["el0"] = Vector3(0.9, 0, 0)
	p["el1"] = Vector3(1.2, 0, 0)
	p["wpn_pos"] = Vector3(0.05, 0.66, -0.16)
	p["wpn_rot"] = Vector3(PI * 0.5, 0, 0)


func _arms_aim(p: Dictionary, aiming: bool, moving: bool) -> void:
	if aiming:
		# weapon shouldered and level
		p["sh0"] = Vector3(1.35, 0, 0.35)
		p["sh1"] = Vector3(1.05, 0, -0.2)
		p["el0"] = Vector3(0.35, 0, 0)
		p["el1"] = Vector3(0.95, 0, 0)
		p["wpn_pos"] = Vector3(0.07, 0.43, -0.28)
		p["wpn_rot"] = Vector3(0.0, 0, 0)
	else:
		# low ready across the chest
		var bob: float = sin(phase * 2.0) * 0.05 if moving else 0.0
		p["sh0"] = Vector3(0.75 + bob, 0, 0.3)
		p["sh1"] = Vector3(0.45 - bob, 0, -0.15)
		p["el0"] = Vector3(0.9, 0, 0)
		p["el1"] = Vector3(1.25, 0, 0)
		p["wpn_pos"] = Vector3(0.05, 0.27, -0.3)
		p["wpn_rot"] = Vector3(-0.55, 0.35, 0.25)


func _pose_wounded(p: Dictionary) -> void:
	# on his back, one knee up, an arm moving now and then
	var lift: float = maxf(0.0, sin(_anim_t * 0.9 + float(get_instance_id() % 7))) * 0.7
	p["hips_y"] = 0.14
	p["hips_rot"] = Vector3(1.5, 0, 0)
	p["torso"] = Vector3(0.0, 0, 0.1)
	p["head"] = Vector3(-0.4, 0.3, 0)
	p["hp0"] = Vector3(0.7, 0, 0.1)
	p["kn0"] = Vector3(-1.2, 0, 0)
	p["hp1"] = Vector3(0.05, 0, -0.15)
	p["kn1"] = Vector3(-0.1, 0, 0)
	p["sh0"] = Vector3(0.2 + lift, 0, 0.5)
	p["sh1"] = Vector3(0.6, 0, -0.9)
	p["el0"] = Vector3(0.8, 0, 0)
	p["el1"] = Vector3(0.3, 0, 0)
	p["wpn_slung"] = 2.0


func _pose_dead(seed_v: int) -> void:
	var r: float = float(seed_v % 97) / 97.0
	_hips.position.y = HIP_H
	_torso.rotation = Vector3(0.1, 0, (r - 0.5) * 0.4)
	_head.rotation = Vector3(0.4, (r - 0.5) * 1.2, 0)
	_sh[0].rotation = Vector3(0.3 + r, 0, 0.9)
	_sh[1].rotation = Vector3(1.6 - r, 0, -1.1)
	_el[0].rotation = Vector3(0.4, 0, 0)
	_el[1].rotation = Vector3(0.9, 0, 0)
	_hp[0].rotation = Vector3(0.3 * r, 0, 0.2)
	_hp[1].rotation = Vector3(0.5 - 0.3 * r, 0, -0.25)
	_kn[0].rotation = Vector3(-0.5 * r, 0, 0)
	_kn[1].rotation = Vector3(-0.7, 0, 0)
	_weapon.visible = r > 0.5
	_weapon.position = Vector3(0.4, 0.1, -0.5)
	_weapon.rotation = Vector3(0, 1.2, 1.4)


func _apply(p: Dictionary, delta: float) -> void:
	var k: float = clampf(delta * 12.0, 0.0, 1.0)
	_hips.position.y = lerpf(_hips.position.y, float(p.get("hips_y", HIP_H)), k)
	_blend(_hips, p.get("hips_rot", Vector3.ZERO), k)
	var torso: Vector3 = p.get("torso", Vector3.ZERO)
	_blend(_torso, torso + Vector3(_recoil * 0.06, 0, 0), k)
	_blend(_head, p.get("head", Vector3.ZERO), k)
	for i: int in range(2):
		_blend(_sh[i], p.get("sh%d" % i, Vector3(0.05, 0, 0.08 * (1 - 2 * i))), k)
		_blend(_el[i], p.get("el%d" % i, Vector3(0.15, 0, 0)), k)
		_blend(_hp[i], p.get("hp%d" % i, Vector3.ZERO), k)
		_blend(_kn[i], p.get("kn%d" % i, Vector3(-0.05, 0, 0)), k)
	var slung: float = float(p.get("wpn_slung", 0.0))
	var wpos: Vector3 = p.get("wpn_pos", Vector3(0.05, 0.27, -0.3))
	var wrot: Vector3 = p.get("wpn_rot", Vector3(-0.55, 0.35, 0.25))
	if slung == 1.0:
		wpos = Vector3(0.0, 0.32, 0.2)
		wrot = Vector3(0.0, 0.0, 1.0)
	elif slung == 2.0:
		wpos = Vector3(0.45, 0.2, -0.2)
		wrot = Vector3(0.3, 0.8, 1.4)
	_weapon.position = _weapon.position.lerp(wpos + Vector3(0, 0, _recoil * 0.07), k)
	_blend(_weapon, wrot + Vector3(_recoil * 0.12, 0, 0), k)


func _blend(n: Node3D, target: Vector3, k: float) -> void:
	n.rotation = Vector3(lerp_angle(n.rotation.x, target.x, k), lerp_angle(n.rotation.y, target.y, k), lerp_angle(n.rotation.z, target.z, k))
