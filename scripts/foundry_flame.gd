extends Node3D

const HOT := Color("ff742b")
var height := 2.4
var width := 1.2
var warning_time := 0.65
var burst_time := 0.66
var clock := -1.0
var warning_ring: MeshInstance3D
var column: Node3D
var lamp: OmniLight3D
var sparks: CPUParticles3D

func _ready() -> void:
	warning_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = width * 0.48
	ring.outer_radius = width * 0.61
	ring.rings = 20
	ring.ring_segments = 8
	warning_ring.mesh = ring
	warning_ring.position.y = 0.041
	warning_ring.scale.y = 0.17
	warning_ring.material_override = RiftProjectile.light_paint(Color("ffae37"), 1.9)
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warning_ring)
	column = Node3D.new()
	add_child(column)
	for angle in [0.0, PI * 0.38, PI * 0.71]:
		var flare := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(width * 1.35, height * 1.12)
		flare.mesh = quad
		flare.position.y = quad.size.y * 0.5 + 0.05
		flare.rotation.y = angle
		var fire := ShaderMaterial.new()
		fire.shader = preload("res://assets/neon_factory/foundry/fire_column.gdshader")
		fire.set_shader_parameter("seed", angle * 4.7)
		flare.material_override = fire
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		column.add_child(flare)
	lamp = OmniLight3D.new()
	lamp.light_color = HOT
	lamp.omni_range = 3.4
	lamp.position.y = 0.45
	add_child(lamp)
	sparks = CPUParticles3D.new()
	sparks.emitting = false
	sparks.amount = 15
	sparks.lifetime = 0.45
	sparks.direction = Vector3.UP
	sparks.spread = 21.0
	sparks.gravity = Vector3(0.0, -2.2, 0.0)
	sparks.initial_velocity_min = height * 1.8
	sparks.initial_velocity_max = height * 3.2
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.5
	var ember := SphereMesh.new()
	ember.radius = 0.031
	ember.height = 0.062
	ember.radial_segments = 5
	ember.rings = 3
	ember.material = RiftProjectile.light_paint(Color("ffb32b"), 1.85)
	sparks.mesh = ember
	sparks.position.y = 0.2
	add_child(sparks)
	show_phase(-1.0)

func show_phase(at: float) -> void:
	var warning := at >= 0.0 and at < warning_time
	var burning := at >= warning_time and at < warning_time + burst_time
	var heat := clampf((at - warning_time) / 0.14, 0.0, 1.0)
	var settle := clampf((warning_time + burst_time - at) / 0.16, 0.0, 1.0)
	var pulse := (1.0 + sin(at * 28.0)) * 0.5
	warning_ring.visible = warning
	warning_ring.scale.x = 0.86 + pulse * 0.14
	warning_ring.scale.z = warning_ring.scale.x
	column.visible = burning
	column.scale.y = maxf(0.03, minf(heat, settle))
	lamp.light_energy = 2.25 * column.scale.y if burning else (0.35 + pulse * 0.6 if warning else 0.0)
	sparks.emitting = burning
