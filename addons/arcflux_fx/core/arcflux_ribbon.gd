class_name ArcfluxRibbon
extends RefCounted
## Accumulates polylines into a single camera-facing ribbon surface.
## Each point is emitted twice; the vertex shader pushes the pair apart perpendicular to the
## view ray, so the ribbon always faces the camera without any per-frame CPU work.
##
## Vertex layout consumed by the ARCFLUX ribbon/beam shaders:
##   VERTEX  point position
##   NORMAL  path tangent
##   UV      x = distance along the strand (local units), y = side (-1 / +1)
##   UV2     x = full width (local units), y = level
##   COLOR   r = brightness, g = reveal parameter, b = normalised position along the strand, a = 1 for halo layers

var _verts: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _uv2s: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()
var max_width: float = 0.0


func clear() -> void:
	_verts.clear()
	_normals.clear()
	_uvs.clear()
	_uv2s.clear()
	_colors.clear()
	_indices.clear()
	max_width = 0.0


func is_empty() -> bool:
	return _indices.is_empty()


## halo = true emits the strand as a wide soft glow layer (COLOR.a = 1).
func add_strand(strand: ArcfluxPath.Strand, width: float, brightness_scale: float = 1.0, halo: bool = false) -> void:
	add_polyline(strand.points, strand.widths, strand.reveal, width, strand.level, strand.brightness * brightness_scale, 1.0 if halo else 0.0)


## widths and reveal may be empty; they default to 1.0 and the normalised position.
## taper fades brightness and narrows the strip over this distance at both ends, which
## hides the square ends of wide glow strips.
## dists optionally overrides the distance written to UV.x (used by helices so their
## texture and end fades follow the beam axis instead of the curve length).
func add_polyline(points: PackedVector3Array, widths: PackedFloat32Array, reveal: PackedFloat32Array, width: float, level: int, brightness: float, spare: float = 0.0, dists: PackedFloat32Array = PackedFloat32Array(), taper: float = 0.0) -> void:
	var n: int = points.size()
	if n < 2:
		return
	var base: int = _verts.size()
	var has_w: bool = widths.size() == n
	var has_r: bool = reveal.size() == n
	var has_d: bool = dists.size() == n
	var total: float = 0.0
	for i in range(1, n):
		total += points[i].distance_to(points[i - 1])
	var dist: float = 0.0
	var last_t: Vector3 = (points[1] - points[0]).normalized()
	for i in n:
		if i > 0:
			dist += points[i].distance_to(points[i - 1])
		var t: Vector3
		if i == 0:
			t = points[1] - points[0]
		elif i == n - 1:
			t = points[i] - points[i - 1]
		else:
			t = (points[i + 1] - points[i]).normalized() + (points[i] - points[i - 1]).normalized()
		if t.length_squared() < 1e-10:
			t = last_t
		else:
			t = t.normalized()
			last_t = t
		var w: float = width * (widths[i] if has_w else 1.0)
		var s: float = dist / maxf(total, 1e-6)
		var r: float = reveal[i] if has_r else s
		var b: float = brightness
		if taper > 0.0:
			var f: float = smoothstep(0.0, taper, minf(dist, total - dist))
			w *= lerpf(0.4, 1.0, f)
			b *= f
		var c: Color = Color(b, r, s, spare)
		var uv2: Vector2 = Vector2(w, float(level))
		var ux: float = dists[i] if has_d else dist
		_verts.append(points[i])
		_verts.append(points[i])
		_normals.append(t)
		_normals.append(t)
		_uvs.append(Vector2(ux, -1.0))
		_uvs.append(Vector2(ux, 1.0))
		_uv2s.append(uv2)
		_uv2s.append(uv2)
		_colors.append(c)
		_colors.append(c)
		max_width = maxf(max_width, w)
	for i in n - 1:
		var v: int = base + i * 2
		_indices.append_array(PackedInt32Array([v, v + 1, v + 2, v + 1, v + 3, v + 2]))


## Replaces the mesh contents. An empty builder leaves the mesh without surfaces.
func commit(mesh: ArrayMesh) -> void:
	mesh.clear_surfaces()
	if _indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
