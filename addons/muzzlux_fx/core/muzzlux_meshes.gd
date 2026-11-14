class_name MuzzluxMeshes
extends RefCounted
## Every piece of geometry MUZZLUX draws, built in code and cached. No OBJ, no glTF, no
## texture: a chip of concrete, a metal flake, a wood splinter, a puff of powder and a spark
## are all static index meshes that the vertex shader puts in place.
##
## Lite version: the four kinds a material impact needs. The full pack adds the crossed quads
## a flash is built from, the bullet-hole slot grid, five kinds of shell case and the 2D
## meshes that carry their element index in COLOR instead of UV2.
##
## Attribute layout, the same for every mesh here:
##   VERTEX  the element's own shape, in its local space, unit sized
##   UV      the surface coordinate of the vertex: (corner.x, corner.y) for a quad,
##           (side, along) for a strip, (around, along) for a casing
##   UV2     (element index, sub index). The sub index is the arm of a crossed quad, the
##           face of a solid, 0 otherwise.
##   NORMAL  the element's flat face normal, in the element's local space
##
## Nothing here reads or writes a shared resource at draw time, and nothing is rebuilt per
## shot: one mesh per (kind, count) is shared by every instance in the project.

## Cache of built meshes, keyed by kind and size.
static var _cache: Dictionary = {}


# ---------------------------------------------------------------- flat elements

## `count` unit quads in the XY plane, facing +Z. The impact bloom, the surface ring and the
## puffs of dust are all placed from these.
static func quads(count: int) -> ArrayMesh:
	var key: String = "quad_%d" % count
	var hit: ArrayMesh = _cached(key)
	if hit != null:
		return hit
	var b: _Builder = _Builder.new()
	for i in maxi(count, 1):
		_quad(b, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK, float(i), 0.0)
	return _store(key, b)


## `count` ribbons of `segments` segments, UV = (side 0..1, along 0..1). The white-hot sparks
## a round strikes off steel are drawn with these.
static func strips(count: int, segments: int) -> ArrayMesh:
	var seg: int = maxi(segments, 1)
	var key: String = "strip_%d_%d" % [count, seg]
	var hit: ArrayMesh = _cached(key)
	if hit != null:
		return hit
	var b: _Builder = _Builder.new()
	for i in maxi(count, 1):
		for s in seg:
			var a0: float = float(s) / float(seg)
			var a1: float = float(s + 1) / float(seg)
			var v0: int = b.add(Vector3(-0.5, a0, 0.0), Vector2(0.0, a0), Vector2(float(i), 0.0), Vector3.BACK)
			var v1: int = b.add(Vector3(0.5, a0, 0.0), Vector2(1.0, a0), Vector2(float(i), 0.0), Vector3.BACK)
			var v2: int = b.add(Vector3(0.5, a1, 0.0), Vector2(1.0, a1), Vector2(float(i), 0.0), Vector3.BACK)
			var v3: int = b.add(Vector3(-0.5, a1, 0.0), Vector2(0.0, a1), Vector2(float(i), 0.0), Vector3.BACK)
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
	return _store(key, b)


# ---------------------------------------------------------------- solid debris

## `count` irregular chips: a four-faced solid inside a unit box, flat shaded, a different
## shape per element. Concrete spall and metal flakes.
static func chips(count: int, seed_value: int) -> ArrayMesh:
	var key: String = "chip_%d_%d" % [count, seed_value]
	var hit: ArrayMesh = _cached(key)
	if hit != null:
		return hit
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var b: _Builder = _Builder.new()
	for i in maxi(count, 1):
		var p: Array[Vector3] = []
		for k in 4:
			p.append(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5),
				rng.randf_range(-0.5, 0.5)))
		# a tetrahedron, every face its own flat normal
		var faces: Array = [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]]
		for f: int in faces.size():
			var face: Array = faces[f]
			_flat_tri(b, p[face[0]], p[face[1]], p[face[2]], float(i), float(f))
	return _store(key, b)


## `count` splinters: a long thin wedge standing along +Y, for wood. Six faces, flat shaded.
static func splinters(count: int, seed_value: int) -> ArrayMesh:
	var key: String = "splint_%d_%d" % [count, seed_value]
	var hit: ArrayMesh = _cached(key)
	if hit != null:
		return hit
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var b: _Builder = _Builder.new()
	for i in maxi(count, 1):
		var w: float = rng.randf_range(0.05, 0.14)
		var d: float = rng.randf_range(0.04, 0.10)
		var bend: float = rng.randf_range(-0.12, 0.12)
		var base: Array[Vector3] = [
			Vector3(-w, 0.0, -d), Vector3(w, 0.0, -d), Vector3(w, 0.0, d), Vector3(-w, 0.0, d)]
		var tip: Vector3 = Vector3(bend, 1.0, bend * 0.5)
		for k in 4:
			_flat_tri(b, base[k], base[(k + 1) % 4], tip, float(i), float(k))
		_flat_tri(b, base[0], base[2], base[1], float(i), 4.0)
		_flat_tri(b, base[0], base[3], base[2], float(i), 5.0)
	return _store(key, b)



## Drops every cached mesh. Only needed in tests.
static func clear_cache() -> void:
	_cache.clear()


## How many meshes are cached. The tests use it to prove nothing is rebuilt per shot.
static func cache_size() -> int:
	return _cache.size()


# ---------------------------------------------------------------- internals

## The mesh cached under `key`, or null. Written without `as` on purpose: casting a Variant
## is flagged by the strict typed-warning check.
static func _cached(key: String) -> ArrayMesh:
	if not _cache.has(key):
		return null
	return _cache[key]


static func _store(key: String, b: _Builder) -> ArrayMesh:
	var mesh: ArrayMesh = b.build()
	_cache[key] = mesh
	return mesh


static func _quad(b: _Builder, centre: Vector3, right: Vector3, up: Vector3, nrm: Vector3,
		index: float, sub: float) -> void:
	var uv2: Vector2 = Vector2(index, sub)
	var v0: int = b.add(centre - right * 0.5 - up * 0.5, Vector2(0.0, 0.0), uv2, nrm)
	var v1: int = b.add(centre + right * 0.5 - up * 0.5, Vector2(1.0, 0.0), uv2, nrm)
	var v2: int = b.add(centre + right * 0.5 + up * 0.5, Vector2(1.0, 1.0), uv2, nrm)
	var v3: int = b.add(centre - right * 0.5 + up * 0.5, Vector2(0.0, 1.0), uv2, nrm)
	b.tri(v0, v1, v2)
	b.tri(v0, v2, v3)


static func _flat_tri(b: _Builder, p0: Vector3, p1: Vector3, p2: Vector3, index: float,
		sub: float) -> void:
	var nrm: Vector3 = (p1 - p0).cross(p2 - p0)
	nrm = nrm.normalized() if nrm.length() > 0.00001 else Vector3.UP
	var uv2: Vector2 = Vector2(index, sub)
	var v0: int = b.add(p0, Vector2(0.0, 0.0), uv2, nrm)
	var v1: int = b.add(p1, Vector2(1.0, 0.0), uv2, nrm)
	var v2: int = b.add(p2, Vector2(0.5, 1.0), uv2, nrm)
	b.tri(v0, v1, v2)


## Collects vertices and indices for one surface.
class _Builder extends RefCounted:
	var v3: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()

	func add(p: Vector3, p_uv: Vector2, p_uv2: Vector2, p_n: Vector3) -> int:
		v3.append(p)
		uv.append(p_uv)
		uv2.append(p_uv2)
		nrm.append(p_n)
		return v3.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		idx.append(a)
		idx.append(b)
		idx.append(c)

	func build() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v3
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
