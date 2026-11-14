class_name BlastluxMeshes
extends RefCounted
## Mesh generators for BLASTLUX layers. Everything is built once and cached; the shaders move
## the elements, so the CPU does no per-particle work.
##
## Lite version: quads() and the disc (the shockwave's ring, dust and ripple layers).
## Free elements (quads): VERTEX.x = element index, UV = corner.

static var _cache: Dictionary = {}


# ---------------------------------------------------------------- free elements

static func quads(count: int) -> ArrayMesh:
	return _strip_mesh("q_%d" % count, count, 1)


## A disc of `rings` x `segments` with UV = (radius 0..1, angle 0..1): the crater bowl and
## the ground scorch. The vertex shader sinks and lifts it.
static func disc(rings: int, segments: int) -> ArrayMesh:
	var key: String = "disc_%d_%d" % [rings, segments]
	var hit: ArrayMesh = _cached(key)
	if hit:
		return hit
	rings = maxi(rings, 2)
	segments = maxi(segments, 6)
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	v.append(Vector3.ZERO)
	n.append(Vector3.UP)
	uv.append(Vector2(0.0, 0.0))
	for r: int in rings:
		var rr: float = float(r + 1) / float(rings)
		for s: int in segments:
			var a: float = TAU * float(s) / float(segments)
			v.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
			n.append(Vector3.UP)
			uv.append(Vector2(rr, float(s) / float(segments)))
	for s: int in segments:
		var s2: int = (s + 1) % segments
		idx.append_array([0, 1 + s2, 1 + s])
	for r: int in rings - 1:
		var b0: int = 1 + r * segments
		var b1: int = b0 + segments
		for s: int in segments:
			var s2: int = (s + 1) % segments
			idx.append_array([b0 + s, b1 + s2, b1 + s, b0 + s, b0 + s2, b1 + s2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = [null, mesh]
	return mesh


static func clear_cache() -> void:
	_cache.clear()


# ---------------------------------------------------------------- internals

static func _cached(key: String) -> ArrayMesh:
	if not _cache.has(key):
		return null
	var entry: Array = _cache[key]
	return entry[1]


static func _strip_mesh(key: String, count: int, segments: int) -> ArrayMesh:
	var hit: ArrayMesh = _cached(key)
	if hit:
		return hit
	count = maxi(count, 1)
	segments = maxi(segments, 1)
	var per: int = (segments + 1) * 2
	var n: int = count * per
	var v3: PackedVector3Array = PackedVector3Array()
	v3.resize(n)
	var uvs: PackedVector2Array = PackedVector2Array()
	uvs.resize(n)
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(count * segments * 6)
	var k: int = 0
	for i: int in count:
		var b: int = i * per
		for s: int in segments + 1:
			var along: float = float(s) / float(segments)
			var j: int = b + s * 2
			uvs[j] = Vector2(0.0, along)
			uvs[j + 1] = Vector2(1.0, along)
			v3[j] = Vector3(float(i), 0.0, 0.0)
			v3[j + 1] = Vector3(float(i), 1.0, 0.0)
		for s: int in segments:
			var j: int = b + s * 2
			idx[k] = j
			idx[k + 1] = j + 1
			idx[k + 2] = j + 3
			idx[k + 3] = j
			idx[k + 4] = j + 3
			idx[k + 5] = j + 2
			k += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v3
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = [null, mesh]
	return mesh


