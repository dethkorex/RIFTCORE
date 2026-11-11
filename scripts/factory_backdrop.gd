@tool
extends Node3D

const INK := Color("#101a31")
const STEEL := Color("#1b2e4a")
const EDGE := Color("#2c4563")
const PIPE := Color("#233855")
const BLUE := Color("#187ba5")
const PINK := Color("#782d76")
const GOLD := Color("#ae582a")

var batches := {}
var panorama: MeshInstance3D

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71309
	# Continuous distant shell, then equipment and gantries on separate depth planes.
	add_panorama()
	for x in range(-40, 550, 20):
		var h := rng.randf_range(13.0, 34.0)
		part(Vector3(x, h * 0.5 - 34, -29), Vector3(rng.randf_range(3.2, 5.7), h + 48.0, 2.3), STEEL.darkened(0.38))
		for j in range(3):
			part(Vector3(x - 0.75 + j * 0.75, h - 10.7, -27.8), Vector3(0.29, 1.45, 0.1), BLUE.darkened(0.36), true)
	for x in range(-34, 546, 26):
		var height := rng.randf_range(10.0, 22.0)
		var z := rng.randf_range(-20.5, -15.0)
		part(Vector3(x, height / 2 - 30.0, z), Vector3(3.4, height + 48.0, 3.0), STEEL)
		part(Vector3(x, height - 5.8, z), Vector3(3.8, 0.66, 3.4), EDGE)
		for j in range(5):
			part(Vector3(x, j * 1.46 + height - 13.0, z + 1.52), Vector3(2.95, 0.43, 0.18), INK)
			for k in range(3):
				part(Vector3(x - 0.95 + k * 0.94, j * 1.46 + height - 13.0, z + 1.64), Vector3(0.59, 0.21, 0.08), GOLD if x % 2 == 0 else PINK, true)
		part(Vector3(x - 3.3, height / 2 - 6.0, z + 1.3), Vector3(0.85, height, 0.85), PIPE)
		for j in range(4):
			part(Vector3(x - 3.3, j * 3.7 - 3.0, z + 1.3), Vector3(1.06, 0.27, 1.06), EDGE)
	for x in range(-28, 540, 8):
		if posmod((x + 28) / 8, 5) >= 3:
			continue
		var deck := 7.6 + sin(x * 0.059) * 2.0
		part(Vector3(x, deck, -8.6), Vector3(8.05, 0.53, 1.25), STEEL)
		part(Vector3(x - 3.45, deck - 5.2, -9.2), Vector3(0.53, 10.5, 0.85), PIPE)
		brace(Vector3(x - 3.4, deck - 3.55, -9.0), Vector3(x + 0.1, deck - 0.2, -9.0))
		brace(Vector3(x + 3.4, deck - 3.55, -9.0), Vector3(x + 0.1, deck - 0.2, -9.0))
		part(Vector3(x, deck + 0.78, -8.4), Vector3(8.0, 0.065, 0.08), EDGE)
		for j in range(4):
			part(Vector3(x - 3.5 + j * 2.0, deck + 0.4, -8.4), Vector3(0.075, 0.79, 0.08), EDGE)
		part(Vector3(x, deck - 0.07, -7.94), Vector3(1.5, 0.085, 0.075), BLUE, true)
	for x in range(-27, 543, 19):
		part(Vector3(x, 2.0, -11.0), Vector3(18.95, 0.47, 0.65), PIPE)
		part(Vector3(x, 2.0, -11.0), Vector3(0.26, 0.61, 0.82), EDGE)
		part(Vector3(x + 3.2, 11.0, -10.8), Vector3(0.38, 18.0, 0.52), PIPE)
		part(Vector3(x + 3.2, 12.0, -10.49), Vector3(0.11, 1.45, 0.08), PINK, true)
	for key in batches:
		emit_batch(batches[key])
	batches.clear()

func _process(_delta: float) -> void:
	if is_instance_valid(panorama):
		var camera := get_viewport().get_camera_3d()
		if camera:
			panorama.global_position.x = camera.global_position.x

func add_panorama() -> void:
	var atlas := load("res://assets/neon_factory/factory_panorama.png") as Texture2D
	if atlas == null:
		part(Vector3(249, 11, -36), Vector3(570, 63, 1), INK)
		return
	var item := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(240.0, 180.0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/neon_factory/factory_panorama.gdshader")
	material.set_shader_parameter("skyline", atlas)
	item.mesh = quad
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.position = Vector3(0, 15, -36)
	add_child(item)
	panorama = item

func brace(a: Vector3, b: Vector3) -> void:
	var v := b - a
	part((a + b) * 0.5, Vector3(0.18, v.length(), 0.30), EDGE, false, -atan2(v.x, v.y))

func part(at: Vector3, size: Vector3, tint: Color, glow := false, tilt := 0.0) -> void:
	var key := tint.to_html() + str(glow)
	if not batches.has(key):
		batches[key] = [tint, glow, []]
	batches[key][2].append(Transform3D(Basis(Vector3.FORWARD, -tilt).scaled_local(size), at))

func emit_batch(batch: Array) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	if not batch[1] and batch[0] != INK:
		var facade := ShaderMaterial.new()
		facade.shader = preload("res://assets/neon_factory/factory_facade.gdshader")
		facade.set_shader_parameter("trim", preload("res://assets/neon_factory/factory_trim.png"))
		facade.set_shader_parameter("tint", batch[0])
		box.material = facade
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = batch[0]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = material
	instances.mesh = box
	var transforms: Array = batch[2]
	instances.instance_count = transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i, transforms[i])
	var item := MultiMeshInstance3D.new()
	item.multimesh = instances
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
