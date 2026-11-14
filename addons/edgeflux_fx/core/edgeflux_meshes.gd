class_name EdgefluxMeshes
extends RefCounted
## Procedural meshes shared by EDGEFLUX effects. Nothing here is saved into scenes.

static var _quads: Dictionary = {}


## n empty quads for the particle shaders: UV = corner (x 0..1 along, y -1..1 across),
## UV2.x = particle index. Positions are solved in the vertex shader.
static func particle_quads(n: int) -> ArrayMesh:
	if _quads.has(n):
		var cached: ArrayMesh = _quads[n]
		return cached
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uv2s: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var corners: Array[Vector2] = [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for i in n:
		var b: int = i * 4
		for c in corners:
			verts.append(Vector3.ZERO)
			uvs.append(c)
			uv2s.append(Vector2(float(i), 0.0))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_quads[n] = mesh
	return mesh


## Arc strips on the local XZ plane, centred on -Z (forward). Each strand is a Dictionary with
## optional keys: roll (degrees around the forward axis), radius (multiplier), delay (0..1),
## offset (Vector3, local units), arc (degrees, overrides arc_deg), yaw (degrees).
## UV.x runs along the arc, UV.y from the outer cutting edge (0) to the inner side (1).
static func arc_strands(strands: Array[Dictionary], arc_deg: float, radius: float, band: float, segments: int = 48) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uv2s: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	for si in strands.size():
		var st: Dictionary = strands[si]
		var roll_deg: float = st.get("roll", 0.0)
		var yaw_deg: float = st.get("yaw", 0.0)
		var rad_mult: float = st.get("radius", 1.0)
		var arc_d: float = st.get("arc", arc_deg)
		var delay: float = st.get("delay", 0.0)
		var off: Vector3 = st.get("offset", Vector3.ZERO)
		var roll: float = deg_to_rad(roll_deg)
		var yaw: float = deg_to_rad(yaw_deg)
		var rad: float = radius * rad_mult
		var arc: float = deg_to_rad(arc_d)
		var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll)
		var b0: int = verts.size()
		for i in segments + 1:
			var u: float = float(i) / float(segments)
			var ang: float = -arc * 0.5 + arc * u
			var dir: Vector3 = Vector3(sin(ang), 0.0, -cos(ang))
			verts.append(basis * (dir * rad) + off)
			verts.append(basis * (dir * maxf(rad - band, 0.0)) + off)
			uvs.append(Vector2(u, 0.0))
			uvs.append(Vector2(u, 1.0))
			uv2s.append(Vector2(delay, float(si)))
			uv2s.append(Vector2(delay, float(si)))
		for i in segments:
			var a: int = b0 + i * 2
			idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 2x2 quad on the local XY plane (VERTEX.xy in -1..1).
static func quad() -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	return q


## 2x2 plane on the local XZ plane.
static func ground_plane() -> PlaneMesh:
	var p: PlaneMesh = PlaneMesh.new()
	p.size = Vector2(2.0, 2.0)
	return p


## Open cylinder, radius 1, height 1 (y from -0.5 to 0.5).
static func open_cylinder(segments: int = 48) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = segments
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	return c


static var _quads_2d: Dictionary = {}


## 2D version of particle_quads(): VERTEX.x carries the particle index (canvas shaders have no UV2).
static func particle_quads_2d(n: int) -> ArrayMesh:
	if _quads_2d.has(n):
		var cached: ArrayMesh = _quads_2d[n]
		return cached
	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var corners: Array[Vector2] = [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for i in n:
		var b: int = i * 4
		for c in corners:
			verts.append(Vector2(float(i), 0.0))
			uvs.append(c)
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var mesh: ArrayMesh = _mesh_2d(verts, uvs, idx)
	_quads_2d[n] = mesh
	return mesh


## Square of half size `extent` for the 2D shape shader (VERTEX in local pixels).
static func quad_2d(extent: float) -> ArrayMesh:
	var e: float = maxf(extent, 1.0)
	var verts: PackedVector2Array = PackedVector2Array([Vector2(-e, -e), Vector2(e, -e), Vector2(e, e), Vector2(-e, e)])
	var uvs: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	return _mesh_2d(verts, uvs, PackedInt32Array([0, 1, 2, 0, 2, 3]))


static func _mesh_2d(verts: PackedVector2Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh
