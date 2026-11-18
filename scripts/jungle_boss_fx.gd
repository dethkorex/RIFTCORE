extends RefCounted

const GROUND_WARNING := preload("res://assets/machine_jungle/terrain/boss_telegraph.gdshader")
const SPORE_MIST := preload("res://assets/machine_jungle/terrain/canopy_spore_mist.gdshader")
const ROOTS := preload("res://assets/machine_jungle/tread.tres")
const ACID := Color("e45cff")
const DANGER := Color("ff942f")
const OPEN := Color("ccf8ff")

static var root_mesh: ArrayMesh
static var chip_mesh := PrismMesh.new()

static func at_world(parent: Node3D, at: Vector3) -> Node3D:
	var effect := Node3D.new()
	effect.top_level = true
	parent.add_child(effect)
	effect.global_position = at
	return effect

static func warning_field(parent: Node3D, at: Vector3, width: float, length: float, tint: Color, duration: float, direction := 0.0) -> Node3D:
	var effect := at_world(parent, at)
	var surface := PlaneMesh.new()
	surface.size = Vector2(width, length)
	var material := ShaderMaterial.new()
	material.shader = GROUND_WARNING
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("direction", direction)
	material.set_shader_parameter("stripe_count", maxf(3.0, width * 1.35))
	RiftProjectile.part(effect, surface, material, Vector3.ZERO, Vector3.ONE)
	material.set_shader_parameter("progress", 0.0)
	effect.create_tween().tween_method(func(value: float): material.set_shader_parameter("progress", value), 0.0, 1.0, maxf(duration, 0.04))
	return effect

static func roots(parent: Node3D, at: Vector3, width: float, height: float, count: int, direction := 0.0) -> void:
	var effect := at_world(parent, at)
	var bloom := RiftProjectile.light_paint(Color("a8ef5c"), 0.65)
	var motion := effect.create_tween().set_parallel()
	for index in count:
		var t := (index + 0.5) / count
		var side := 1.0 if index % 2 == 0 else -1.0
		var piece := RiftProjectile.part(effect, thorn_mesh(), ROOTS,
			Vector3((t - 0.5) * width, 0.0, side * 0.25), Vector3(0.28, height * (0.64 + 0.36 * sin(t * PI)), 0.30))
		piece.rotation.y = direction * 1.1 if direction != 0.0 else side * 0.82
		RiftProjectile.part(piece, chip_mesh, bloom, Vector3(.28, .66, .05), Vector3(.64, .16, .55))
		var final_height := piece.scale.y
		var delay := (t if direction >= 0.0 else 1.0 - t) * .075
		motion.tween_property(piece, "scale:y", final_height, .14).from(.025).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		motion.tween_property(piece, "scale:y", .015, .20).set_delay(.38 + delay)
	motion.chain().tween_callback(effect.queue_free)
	burst(parent, at, Color("abd56e"), width * .43, 11)

static func thorn_mesh() -> ArrayMesh:
	if root_mesh:
		return root_mesh
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 5:
		for side in 8:
			for offset in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
				var t := float(row + offset.y) / 5.0
				var angle := TAU * float(side + offset.x) / 8.0
				var r := maxf(.018, pow(1.0 - t, 0.82) * .74)
				builder.set_uv(Vector2((side + offset.x) / 8.0, t))
				builder.add_vertex(Vector3(cos(angle) * r + t * t * 1.3, t, sin(angle) * r))
	builder.generate_normals()
	root_mesh = builder.commit()
	return root_mesh

static func core_halo(parent: Node3D, at: Vector3, radius: float) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - .025
	ring.outer_radius = radius
	var halo := RiftProjectile.part(parent, ring, RiftProjectile.light_paint(OPEN, 1.6), at, Vector3.ONE)
	halo.rotation.x = PI * .5
	halo.hide()
	return halo

static func burst(parent: Node3D, at: Vector3, tint: Color, radius: float, count: int, inward := false) -> void:
	var effect := at_world(parent, at)
	var particles := effect.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var material := RiftProjectile.light_paint(tint, .75)
	for i in count:
		var phase := float(i) * 2.39996
		var edge := Vector3(cos(phase) * radius, .18 + float(i % 5) * .23, sin(phase) * minf(radius * .70, .92))
		var chip := RiftProjectile.part(effect, chip_mesh, material, edge if inward else Vector3.ZERO,
			Vector3(.055, .15 + float(i % 3) * .063, .063))
		chip.rotation = Vector3(phase, phase * .4, phase * .7)
		var duration := .32 + float(i % 4) * .067
		particles.tween_property(chip, "position", Vector3.ZERO if inward else edge, duration)
		particles.tween_property(chip, "scale", Vector3.ZERO, duration)
		particles.tween_property(chip, "rotation:z", phase + 1.8, duration)
	particles.chain().tween_callback(effect.queue_free)

static func mist(parent: Node3D, width: float, height: float, tint: Color, layers: int) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	for layer in layers:
		var material := ShaderMaterial.new()
		material.shader = SPORE_MIST
		material.set_shader_parameter("spores", tint.lerp(Color("632981"), float(layer) / layers * .48))
		material.set_shader_parameter("drift", float(layer) * 4.71)
		material.set_shader_parameter("density", .84)
		RiftProjectile.part(parent, quad, material, Vector3(0, layer * .14, .66 - .55 * layer), Vector3.ONE)
