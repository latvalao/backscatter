## Offline low-poly mesh builder used by tools/model_forge.gd (never at runtime).
## Triangle soup with flat (hard) normals for hard-surface parts and optional
## soft normals for foliage. Every part is convex, so each triangle is wound
## outward using the part's centroid.
##
## Vertex data written to the mesh (see docs/VISUALS.md §6.1):
##   UV    = palette swatch (u = column, v = faction/material row)
##   COLOR = R ambient occlusion, G curvature (bevel / edge), B dirt mask, A rust mask
class_name ForgeMesh
extends RefCounted

const COLUMNS: int = 16
const ROWS: int = 8

var verts: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var edges: PackedFloat32Array = PackedFloat32Array()
var row: int = 0
## Transform applied to every primitive added (stack-like helper for sub-assemblies).
var xf: Transform3D = Transform3D.IDENTITY

var _part_tris: Array[PackedVector3Array] = []


func swatch_uv(sw: int, r: int = -1) -> Vector2:
	return Vector2((sw + 0.5) / COLUMNS, ((row if r < 0 else r) + 0.5) / ROWS)


## Adds one convex part: a list of polygons (each a PackedVector3Array, any
## winding), with per-polygon edge flag and optional soft-normal ellipsoid.
func _emit_part(polys: Array[PackedVector3Array], edge_flags: PackedFloat32Array, sw: int, local_xf: Transform3D, soft: bool = false, soft_center: Vector3 = Vector3.ZERO, soft_radii: Vector3 = Vector3.ONE, r: int = -1) -> void:
	var t: Transform3D = xf * local_xf
	var centroid: Vector3 = Vector3.ZERO
	var n: int = 0
	for p: PackedVector3Array in polys:
		for v: Vector3 in p:
			centroid += t * v
			n += 1
	centroid /= maxf(1.0, n)
	var uv: Vector2 = swatch_uv(sw, r)
	for pi: int in range(polys.size()):
		var poly: PackedVector3Array = polys[pi]
		if poly.size() < 3:
			continue
		var pc: Vector3 = Vector3.ZERO
		for v: Vector3 in poly:
			pc += t * v
		pc /= poly.size()
		for k: int in range(1, poly.size() - 1):
			var la: Vector3 = poly[0]
			var lb: Vector3 = poly[k]
			var lc: Vector3 = poly[k + 1]
			var a: Vector3 = t * la
			var b: Vector3 = t * lb
			var c: Vector3 = t * lc
			var nrm: Vector3 = (b - a).cross(c - a)
			if nrm.length_squared() < 1e-12:
				continue
			if nrm.dot(pc - centroid) < 0.0:
				var tmp: Vector3 = b
				b = c
				c = tmp
				var tl: Vector3 = lb
				lb = lc
				lc = tl
				nrm = -nrm
			var wn: Vector3 = nrm.normalized()
			# Godot front faces are clockwise: emit a, c, b.
			var wv: Array[Vector3] = [a, c, b]
			var lv: Array[Vector3] = [la, lc, lb]
			for q: int in range(3):
				verts.append(wv[q])
				uvs.append(uv)
				edges.append(edge_flags[pi])
				if soft:
					var sn: Vector3 = ((lv[q] - soft_center) / (soft_radii * soft_radii)).normalized()
					normals.append((t.basis * sn).normalized().lerp(wn, 0.25).normalized())
				else:
					normals.append(wn)


## Lofts convex rings (all same point count) bottom->top and caps both ends.
## edge_rows[i] marks strip i (between ring i and i+1) as bevel; edge_seg_even
## marks even segments of non-bevel strips as bevel (chamfered vertical edges).
func loft(rings: Array[PackedVector3Array], sw: int, edge_rows: PackedInt32Array = PackedInt32Array(), edge_seg_even: bool = false, local_xf: Transform3D = Transform3D.IDENTITY, cap_bottom: bool = true, cap_top: bool = true, r: int = -1) -> void:
	var polys: Array[PackedVector3Array] = []
	var flags: PackedFloat32Array = PackedFloat32Array()
	var cnt: int = rings[0].size()
	for i: int in range(rings.size() - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		for j: int in range(cnt):
			var j2: int = (j + 1) % cnt
			var q: PackedVector3Array = PackedVector3Array([r0[j], r0[j2], r1[j2], r1[j]])
			# drop degenerate edges (rings collapsing to a point)
			if r1[j].distance_squared_to(r1[j2]) < 1e-10:
				q = PackedVector3Array([r0[j], r0[j2], r1[j]])
			elif r0[j].distance_squared_to(r0[j2]) < 1e-10:
				q = PackedVector3Array([r0[j], r1[j2], r1[j]])
			polys.append(q)
			var e: float = 1.0 if edge_rows.has(i) else (1.0 if edge_seg_even and j % 2 == 0 else 0.0)
			flags.append(e)
	if cap_bottom:
		polys.append(rings[0])
		flags.append(0.0)
	if cap_top:
		polys.append(rings[rings.size() - 1])
		flags.append(0.0)
	_emit_part(polys, flags, sw, local_xf, false, Vector3.ZERO, Vector3.ONE, r)


static func rect(hx: float, hz: float, y: float, sx: float = 0.0, sz: float = 0.0) -> PackedVector3Array:
	return PackedVector3Array([Vector3(sx + hx, y, sz - hz), Vector3(sx + hx, y, sz + hz), Vector3(sx - hx, y, sz + hz), Vector3(sx - hx, y, sz - hz)])


static func octagon(hx: float, hz: float, c: float, y: float, sx: float = 0.0, sz: float = 0.0) -> PackedVector3Array:
	c = minf(c, minf(hx, hz) * 0.95)
	return PackedVector3Array([
		Vector3(sx + hx - c, y, sz - hz), Vector3(sx + hx, y, sz - hz + c),
		Vector3(sx + hx, y, sz + hz - c), Vector3(sx + hx - c, y, sz + hz),
		Vector3(sx - hx + c, y, sz + hz), Vector3(sx - hx, y, sz + hz - c),
		Vector3(sx - hx, y, sz - hz + c), Vector3(sx - hx + c, y, sz - hz)])


## Chamfered box standing on `base` (bottom centre). top/bot scale & shift
## (x, z) taper the top and bottom faces (glacis plates, sloped turret sides).
func box(base: Vector3, size: Vector3, sw: int, bevel: float = 0.08, top_scale: Vector2 = Vector2.ONE, top_shift: Vector2 = Vector2.ZERO, bot_scale: Vector2 = Vector2.ONE, bot_shift: Vector2 = Vector2.ZERO, local_xf: Transform3D = Transform3D.IDENTITY, r: int = -1) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var b: float = minf(bevel, minf(size.y * 0.3, minf(hx, hz) * 0.5))
	var y0: float = base.y
	var y1: float = base.y + size.y
	var rings: Array[PackedVector3Array] = []
	if b > 0.001:
		rings.append(octagon(hx * bot_scale.x - b, hz * bot_scale.y - b, b, y0, base.x + bot_shift.x, base.z + bot_shift.y))
		rings.append(octagon(hx * bot_scale.x, hz * bot_scale.y, b, y0 + b, base.x + bot_shift.x, base.z + bot_shift.y))
		rings.append(octagon(hx * top_scale.x, hz * top_scale.y, b, y1 - b, base.x + top_shift.x, base.z + top_shift.y))
		rings.append(octagon(hx * top_scale.x - b, hz * top_scale.y - b, b, y1, base.x + top_shift.x, base.z + top_shift.y))
		loft(rings, sw, PackedInt32Array([0, 2]), true, local_xf, true, true, r)
	else:
		rings.append(rect(hx * bot_scale.x, hz * bot_scale.y, y0, base.x + bot_shift.x, base.z + bot_shift.y))
		rings.append(rect(hx * top_scale.x, hz * top_scale.y, y1, base.x + top_shift.x, base.z + top_shift.y))
		loft(rings, sw, PackedInt32Array(), false, local_xf, true, true, r)


static func circle(radius_x: float, radius_z: float, segs: int, y: float, off: Vector3 = Vector3.ZERO, phase: float = 0.0) -> PackedVector3Array:
	var p: PackedVector3Array = PackedVector3Array()
	for i: int in range(segs):
		var a: float = TAU * i / segs + phase
		p.append(Vector3(off.x + cos(a) * radius_x, y, off.z + sin(a) * radius_z))
	return p


## Frustum / cylinder / cone between two points.
func cyl(a: Vector3, b: Vector3, r0: float, r1: float, segs: int, sw: int, bevel_edges: bool = false, r: int = -1) -> void:
	var axis: Vector3 = b - a
	var h: float = axis.length()
	if h < 1e-5:
		return
	var y: Vector3 = axis / h
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y).normalized()
	var t: Transform3D = Transform3D(Basis(x, y, z), a)
	var rings: Array[PackedVector3Array] = []
	rings.append(circle(r0, r0, segs, 0.0, Vector3.ZERO, PI / segs))
	rings.append(circle(maxf(r1, 0.0001), maxf(r1, 0.0001), segs, h, Vector3.ZERO, PI / segs))
	loft(rings, sw, PackedInt32Array([0]) if bevel_edges else PackedInt32Array(), false, t, true, r1 > 0.0002, r)


## Wheel: cylinder along X centred at c, with a bevelled rim and hub.
func wheel(c: Vector3, radius: float, width: float, segs: int, sw: int, hub_sw: int = -1) -> void:
	var hw: float = width * 0.5
	var b: float = minf(radius * 0.15, hw * 0.6)
	var t: Transform3D = Transform3D(Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), c)
	var rings: Array[PackedVector3Array] = [
		circle(radius - b, radius - b, segs, -hw, Vector3.ZERO, PI / segs),
		circle(radius, radius, segs, -hw + b, Vector3.ZERO, PI / segs),
		circle(radius, radius, segs, hw - b, Vector3.ZERO, PI / segs),
		circle(radius - b, radius - b, segs, hw, Vector3.ZERO, PI / segs)]
	loft(rings, sw, PackedInt32Array([0, 2]), false, t)
	if hub_sw >= 0:
		cyl(c + Vector3(-hw - 0.02, 0, 0), c + Vector3(hw + 0.02, 0, 0), radius * 0.45, radius * 0.45, maxi(5, segs / 2), hub_sw)


## Convex 2D profile in the (z, y) plane extruded along X from x0 to x1.
func extrude_x(profile: PackedVector2Array, x0: float, x1: float, sw: int, edge: bool = true, r: int = -1) -> void:
	var r0: PackedVector3Array = PackedVector3Array()
	var r1: PackedVector3Array = PackedVector3Array()
	for p: Vector2 in profile:
		r0.append(Vector3(p.y, x0, p.x))
		r1.append(Vector3(p.y, x1, p.x))
	# loft along local Y then rotate so local Y -> world X
	var t: Transform3D = Transform3D(Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), Vector3.ZERO)
	var rings: Array[PackedVector3Array] = [r0, r1]
	loft(rings, sw, PackedInt32Array(), false, t, true, true, r)
	if edge:
		pass


## Ellipsoid (or upper half if `half`), optionally with soft normals.
func blob(c: Vector3, radii: Vector3, segs: int, rings_n: int, sw: int, soft: bool = false, half: bool = false, jitter: float = 0.0, seed_v: int = 0, r: int = -1) -> void:
	var rings: Array[PackedVector3Array] = []
	var start: int = rings_n / 2 if half else 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for i: int in range(start, rings_n + 1):
		var phi: float = PI * float(i) / rings_n - PI * 0.5
		var rr: float = cos(phi)
		var yy: float = sin(phi) * radii.y
		if i == rings_n or (i == 0):
			rr = 0.0005
		var ring: PackedVector3Array = PackedVector3Array()
		for j: int in range(segs):
			var a: float = TAU * j / segs + (PI / segs) * (i % 2)
			var jj: float = 1.0 + (rng.randf_range(-jitter, jitter) if i > start and i < rings_n else 0.0)
			ring.append(Vector3(cos(a) * rr * radii.x * jj, yy, sin(a) * rr * radii.z * jj))
		rings.append(ring)
	var polys: Array[PackedVector3Array] = []
	var flags: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(rings.size() - 1):
		for j: int in range(segs):
			var j2: int = (j + 1) % segs
			var a0: Vector3 = rings[i][j]
			var b0: Vector3 = rings[i][j2]
			var a1: Vector3 = rings[i + 1][j]
			var b1: Vector3 = rings[i + 1][j2]
			polys.append(PackedVector3Array([a0, b0, b1]))
			polys.append(PackedVector3Array([a0, b1, a1]))
			flags.append(0.0)
			flags.append(0.0)
	if half:
		polys.append(rings[0])
		flags.append(0.0)
	_emit_part(polys, flags, sw, Transform3D(Basis.IDENTITY, c), soft, Vector3.ZERO, radii, r)


## Pushes a sub-assembly transform; returns the previous one for restore.
func push(t: Transform3D) -> Transform3D:
	var prev: Transform3D = xf
	xf = xf * t
	return prev


func tri_count() -> int:
	return verts.size() / 3


## Bakes vertex colours (voxel AO, edges, dirt, rust) and returns an ArrayMesh.
func commit(dirt_height: float = 1.0, rust: float = 0.0, ao_strength: float = 1.0) -> ArrayMesh:
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(verts.size())
	var ao: PackedFloat32Array = _voxel_ao(ao_strength)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 0.9
	noise.seed = 7
	for i: int in range(verts.size()):
		var v: Vector3 = verts[i]
		var dirt: float = clampf(1.0 - v.y / maxf(0.01, dirt_height), 0.0, 1.0)
		dirt = clampf(dirt * (0.75 + 0.5 * noise.get_noise_3dv(v * 0.7)), 0.0, 1.0)
		var rmask: float = clampf((noise.get_noise_3dv(v * 1.7 + Vector3(9, 3, 1)) + 0.15) * 2.5, 0.0, 1.0) * rust
		colors[i] = Color(ao[i], edges[i], dirt, rmask)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var m: ArrayMesh = ArrayMesh.new()
	if verts.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Coarse voxel ambient occlusion: occupancy sampled over the triangles, then a
## short hemisphere march from each vertex (plus the ground plane at y = 0).
func _voxel_ao(strength: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(verts.size())
	if verts.is_empty():
		return out
	var aabb: AABB = AABB(verts[0], Vector3.ZERO)
	for v: Vector3 in verts:
		aabb = aabb.expand(v)
	var vox: float = clampf(aabb.get_longest_axis_size() / 40.0, 0.04, 0.35)
	var occ: Dictionary = {}
	for i: int in range(0, verts.size(), 3):
		var a: Vector3 = verts[i]
		var b: Vector3 = verts[i + 1]
		var c: Vector3 = verts[i + 2]
		var steps: int = clampi(int(maxf(a.distance_to(b), maxf(b.distance_to(c), a.distance_to(c))) / vox) + 1, 1, 40)
		for u: int in range(steps + 1):
			for w: int in range(steps + 1 - u):
				var p: Vector3 = a + (b - a) * (float(u) / steps) + (c - a) * (float(w) / steps)
				occ[Vector3i(floori(p.x / vox), floori(p.y / vox), floori(p.z / vox))] = true
	var dirs: Array[Vector3] = []
	for k: int in range(14):
		var phi: float = acos(1.0 - (k + 0.5) / 14.0)  # hemisphere
		var th: float = k * 2.39996
		dirs.append(Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)))
	var reach: float = clampf(aabb.get_longest_axis_size() * 0.12, 0.3, 2.5)
	for i: int in range(verts.size()):
		var n: Vector3 = normals[i]
		var basis: Basis = _basis_from(n)
		var p0: Vector3 = verts[i] + n * vox * 1.1
		var hits: float = 0.0
		for d: Vector3 in dirs:
			var dir: Vector3 = basis * d
			for s: int in range(1, 5):
				var p: Vector3 = p0 + dir * (reach * s / 4.0)
				if p.y < 0.0 or occ.has(Vector3i(floori(p.x / vox), floori(p.y / vox), floori(p.z / vox))):
					hits += 1.0 - (s - 1) * 0.2
					break
		out[i] = clampf(1.0 - hits / dirs.size() * 1.1 * strength, 0.15, 1.0)
	return out


static func _basis_from(n: Vector3) -> Basis:
	var up: Vector3 = n
	var x: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(up).normalized()
	return Basis(x, up, z)
