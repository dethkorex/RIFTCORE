@tool
extends RefCounted

static var cache: Dictionary = {}

static func from_box(box: BoxMesh, width: float) -> ArrayMesh:
	var key := str(box.size) + ":" + str(width)
	if not cache.has(key):
		cache[key] = build(box.size, width)
	return cache[key]

static func face(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	for i in range(1, points.size() - 1):
		var order := [0, i, i + 1]
		if (points[i] - points[0]).cross(points[i + 1] - points[0]).dot(normal) > 0.0:
			order = [0, i + 1, i]
		for j in order:
			surface.set_normal(normal)
			surface.add_vertex(points[j])

static func build(size: Vector3, width: float) -> ArrayMesh:
	var outer := size * 0.5
	var bevel := minf(width, minf(outer.x, minf(outer.y, outer.z)) * 0.72)
	var inner := outer - Vector3.ONE * bevel
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in range(3):
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for side in [-1, 1]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var points: Array[Vector3] = []
			for sign_pair in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = side * outer[axis]
				point[a] = sign_pair.x * inner[a]
				point[b] = sign_pair.y * inner[b]
				points.append(point)
			face(surface, points, normal)
		for a_side in [-1, 1]:
			for b_side in [-1, 1]:
				var normal := Vector3.ZERO
				normal[a] = a_side
				normal[b] = b_side
				var p := Vector3.ZERO
				p[a] = a_side * outer[a]
				p[b] = b_side * inner[b]
				var q := Vector3.ZERO
				q[a] = a_side * inner[a]
				q[b] = b_side * outer[b]
				p[axis] = -inner[axis]
				q[axis] = -inner[axis]
				var r := q
				var t := p
				r[axis] = inner[axis]
				t[axis] = inner[axis]
				face(surface, [p, q, r, t], normal.normalized())
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				var signs := Vector3(x, y, z)
				var corner := inner * signs
				var points: Array[Vector3] = []
				for axis in range(3):
					var point := corner
					point[axis] = signs[axis] * outer[axis]
					points.append(point)
				face(surface, points, signs.normalized())
	return surface.commit()
