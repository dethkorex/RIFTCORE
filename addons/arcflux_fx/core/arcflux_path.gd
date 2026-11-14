class_name ArcfluxPath
extends RefCounted
## Procedural channel generation shared by the 3D and 2D effects.
## Paths are built with midpoint displacement; branches are grown recursively from the parent.


## One continuous polyline of a discharge.
class Strand:
	extends RefCounted
	var points: PackedVector3Array = PackedVector3Array()
	## Width multiplier per point (0..1).
	var widths: PackedFloat32Array = PackedFloat32Array()
	## Reveal parameter per point, 0 at the source and 1 at the far end of the main channel.
	var reveal: PackedFloat32Array = PackedFloat32Array()
	## 0 = main channel, 1+ = branch depth, 3 = spark.
	var level: int = 0
	var brightness: float = 1.0


## Settings for a branched discharge. Kept as a plain object so nodes can reuse one instance.
class Shape:
	extends RefCounted
	## Target length of the smallest segment, in local units.
	var segment_length: float = 0.25
	## Sideways displacement relative to segment length.
	var chaos: float = 0.32
	## Expected number of first-level branches.
	var branches: float = 4.0
	## Branch length as a fraction of the remaining main length.
	var branch_length: float = 0.45
	## Spread of branches away from the main direction, in radians.
	var branch_angle: float = 0.65
	## Maximum branch depth (0 disables branching).
	var branch_depth: int = 2
	## Width multiplier at the far end of the main channel.
	var end_width: float = 0.55
	## Constrain displacement to a plane with this normal (used by 2D). Zero means free 3D.
	var plane_normal: Vector3 = Vector3.ZERO
	## Optional sideways bow of the main channel, relative to its length.
	var bow: float = 0.0
	var bow_direction: Vector3 = Vector3.UP


const MAX_DETAIL: int = 9


static func random_unit_perpendicular(dir: Vector3, rng: RandomNumberGenerator, plane_normal: Vector3) -> Vector3:
	if plane_normal != Vector3.ZERO:
		var side: Vector3 = dir.cross(plane_normal)
		if side.length_squared() < 1e-8:
			return Vector3.RIGHT
		return side.normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
	var helper: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var u: Vector3 = dir.cross(helper).normalized()
	var v: Vector3 = dir.cross(u).normalized()
	var ang: float = rng.randf() * TAU
	return u * cos(ang) + v * sin(ang)


## Midpoint displacement between a and b. Returns the full point list including both ends.
static func displace(a: Vector3, b: Vector3, shape: Shape, rng: RandomNumberGenerator, chaos_scale: float = 1.0) -> PackedVector3Array:
	var length: float = a.distance_to(b)
	var pts: PackedVector3Array = PackedVector3Array([a, b])
	if length < 1e-5:
		return pts
	var detail: int = clampi(ceili(log(length / maxf(shape.segment_length, 0.01)) / log(2.0)), 1, MAX_DETAIL)
	var dir: Vector3 = (b - a) / length
	var basis_u: Vector3
	var basis_v: Vector3
	if shape.plane_normal != Vector3.ZERO:
		basis_u = dir.cross(shape.plane_normal).normalized()
		basis_v = Vector3.ZERO
	else:
		var helper: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		basis_u = dir.cross(helper).normalized()
		basis_v = dir.cross(basis_u).normalized()
	var amp: float = shape.chaos * chaos_scale
	for level in detail:
		# Coarse levels bend less than fine ones: long straight-ish runs with lots of small kinks.
		var level_amp: float = amp * lerpf(0.3, 1.0, clampf(float(level) / 4.0, 0.0, 1.0))
		var next: PackedVector3Array = PackedVector3Array()
		next.resize(pts.size() * 2 - 1)
		for j in pts.size() - 1:
			var p: Vector3 = pts[j]
			var q: Vector3 = pts[j + 1]
			var seg: float = p.distance_to(q)
			var off: Vector3 = basis_u * clampf(rng.randfn(0.0, 1.0), -2.2, 2.2) + basis_v * clampf(rng.randfn(0.0, 1.0), -2.2, 2.2)
			next[j * 2] = p
			next[j * 2 + 1] = (p + q) * 0.5 + off * seg * level_amp
		next[next.size() - 1] = pts[pts.size() - 1]
		pts = next
	if shape.bow != 0.0:
		var bow_dir: Vector3 = shape.bow_direction - dir * shape.bow_direction.dot(dir)
		if bow_dir.length_squared() > 1e-6:
			bow_dir = bow_dir.normalized() * shape.bow * length
			var n: int = pts.size()
			for j in range(1, n - 1):
				var s: float = float(j) / float(n - 1)
				pts[j] += bow_dir * 4.0 * s * (1.0 - s)
	return pts


## Builds a main channel plus recursive branches. The returned array starts with the main strand.
static func build(a: Vector3, b: Vector3, shape: Shape, rng: RandomNumberGenerator) -> Array[Strand]:
	var out: Array[Strand] = []
	var main: Strand = Strand.new()
	main.points = displace(a, b, shape, rng)
	var n: int = main.points.size()
	main.widths.resize(n)
	main.reveal.resize(n)
	var total: float = 0.0
	var cum: PackedFloat32Array = PackedFloat32Array()
	cum.resize(n)
	for i in n:
		if i > 0:
			total += main.points[i].distance_to(main.points[i - 1])
		cum[i] = total
	for i in n:
		var s: float = cum[i] / maxf(total, 1e-5)
		main.reveal[i] = s
		main.widths[i] = lerpf(1.0, shape.end_width, s) * rng.randf_range(0.85, 1.0)
	main.widths[0] = main.widths[0] * 0.7
	out.append(main)
	if shape.branch_depth > 0 and shape.branches > 0.0:
		_grow_branches(main, total, 1, shape.branches, shape, rng, out)
	return out


static func _grow_branches(parent: Strand, parent_length: float, depth: int, count: float, shape: Shape, rng: RandomNumberGenerator, out: Array[Strand]) -> void:
	var n: int = parent.points.size()
	if n < 4:
		return
	var k: int = int(floor(count + rng.randf()))
	var overall: Vector3 = (parent.points[n - 1] - parent.points[0]).normalized()
	for _b in k:
		var idx: int = int(clampf(pow(rng.randf(), 1.3) * 0.85 + 0.05, 0.0, 0.95) * float(n - 1))
		idx = clampi(idx, 1, n - 3)
		var origin: Vector3 = parent.points[idx]
		var remaining: float = parent_length * (1.0 - float(idx) / float(n - 1))
		var length: float = remaining * shape.branch_length * rng.randf_range(0.45, 1.0)
		if length < shape.segment_length * 2.0:
			continue
		var local_dir: Vector3 = (parent.points[idx + 1] - parent.points[idx - 1]).normalized()
		var fwd: Vector3 = (overall * 0.8 + local_dir * 0.2).normalized()
		var perp: Vector3 = random_unit_perpendicular(fwd, rng, shape.plane_normal)
		var ang: float = shape.branch_angle * rng.randf_range(0.5, 1.25)
		var dir: Vector3 = (fwd * cos(ang) + perp * sin(ang)).normalized()
		var strand: Strand = Strand.new()
		strand.level = depth
		strand.brightness = pow(0.55, float(depth))
		strand.points = displace(origin, origin + dir * length, shape, rng, 1.15)
		var m: int = strand.points.size()
		strand.widths.resize(m)
		strand.reveal.resize(m)
		var r0: float = parent.reveal[idx]
		var r1: float = r0 + (parent.reveal[n - 1] - r0) * (length / maxf(remaining, 1e-5))
		var w0: float = parent.widths[idx] * 0.62
		for i in m:
			var s: float = float(i) / float(m - 1)
			strand.widths[i] = w0 * (1.0 - s * s * 0.95)
			strand.reveal[i] = lerpf(r0, r1, s)
		out.append(strand)
		if depth < shape.branch_depth:
			_grow_branches(strand, length, depth + 1, count * 0.45, shape, rng, out)


## Box-filtered copy of a polyline, resampled every step points. Ends stay pinned.
## Used for wide glow layers, which would show fins on sharp corners otherwise.
static func smoothed(points: PackedVector3Array, radius: int, step: int) -> PackedVector3Array:
	var n: int = points.size()
	var out: PackedVector3Array = PackedVector3Array()
	if n < 3 or radius < 1:
		return points
	var i: int = 0
	while i < n:
		var acc: Vector3 = Vector3.ZERO
		var wsum: float = 0.0
		for k in range(-radius, radius + 1):
			var j: int = clampi(i + k, 0, n - 1)
			var w: float = 1.0 - absf(float(k)) / float(radius + 1)
			acc += points[j] * w
			wsum += w
		var p: Vector3 = acc / wsum
		var edge: float = minf(float(i), float(n - 1 - i)) / float(radius)
		out.append(points[i].lerp(p, clampf(edge * 2.0, 0.0, 1.0)))
		if i == n - 1:
			break
		i = mini(i + step, n - 1)
	return out


## Straight polyline with evenly spaced points, used by beams.
static func straight(a: Vector3, b: Vector3, segments: int) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(segments + 1)
	for i in segments + 1:
		pts[i] = a.lerp(b, float(i) / float(segments))
	return pts
