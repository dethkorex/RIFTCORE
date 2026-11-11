extends StaticBody3D

signal burned

const SMOKE := preload("res://assets/vfx/kenney/smoke_05.png")
const GREEN := Color("94f551")
const ROOT := Color("29402d")

var faction := "scenery"
var health := 1.0
var sacs: Node3D
var throat: StandardMaterial3D
var cloud: CPUParticles3D

func build(tint: Color) -> void:
	collision_layer = 8
	collision_mask = 0
	var target := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.51
	target.shape = shape
	target.position.y = 0.55
	add_child(target)
	sacs = Node3D.new()
	add_child(sacs)
	var orb := RiftProjectile.cached_mesh("Orb")
	for i in range(6):
		var angle := i * TAU / 6.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var leaf := RiftProjectile.part(sacs, orb, RiftProjectile.light_paint(ROOT.lightened(i * 0.045), 0.0),
			radial * 0.25 + Vector3.UP * 0.26, Vector3(0.60, 0.11, 0.20))
		leaf.rotation = Vector3(0, -angle, 0.25)
	var shell := RiftProjectile.light_paint(Color("365139"), 0.0)
	RiftProjectile.part(sacs, orb, shell, Vector3(0, 0.40, 0), Vector3(0.54, 0.56, 0.50))
	throat = RiftProjectile.light_paint(tint, 0.70).duplicate() as StandardMaterial3D
	for i in range(5):
		var angle := i * TAU / 5.0
		var rim := RiftProjectile.part(sacs, orb, shell, Vector3(cos(angle) * 0.27, 0.68, sin(angle) * 0.27), Vector3(0.20, 0.25, 0.14))
		rim.rotation = Vector3(0, -angle, -0.47)
	RiftProjectile.part(sacs, orb, throat, Vector3(0, 0.67, 0.09), Vector3(0.28, 0.17, 0.25))
	build_cloud(tint)

func build_cloud(tint: Color) -> void:
	cloud = CPUParticles3D.new()
	cloud.position.y = 0.68
	cloud.amount = 30
	cloud.lifetime = 0.84
	cloud.emitting = false
	cloud.direction = Vector3.UP
	cloud.spread = 52.0
	cloud.gravity = Vector3(0, -0.23, 0)
	cloud.initial_velocity_min = 0.81
	cloud.initial_velocity_max = 1.9
	cloud.scale_amount_min = 0.70
	cloud.scale_amount_max = 1.58
	cloud.visibility_range_end = 35.0
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var puff := QuadMesh.new()
	puff.size = Vector2(0.98, 0.82)
	var material := StandardMaterial3D.new()
	material.albedo_texture = SMOKE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	puff.material = material
	cloud.mesh = puff
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0, 0.12, 0.55, 1])
	fade.colors = PackedColorArray([Color(tint, 0), Color(tint.lightened(0.25), 0.93), Color(tint, 0.72), Color(tint, 0)])
	cloud.color_ramp = fade
	add_child(cloud)

func update_pressure(charge: float, active: bool) -> void:
	throat.emission_energy_multiplier = 0.5 + charge * 2.5
	sacs.scale = Vector3.ONE * (1.0 + charge * 0.10)
	cloud.emitting = active

func take_damage(_amount: float, _source := Vector3.ZERO) -> void:
	pass

func take_fire_damage(amount: float, _source := Vector3.ZERO) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = 0.0
	burned.emit()
	finish_burn.call_deferred()

func finish_burn() -> void:
	collision_layer = 0
	cloud.hide()
	var flash := preload("res://scripts/pit_burst.gd").new()
	add_child(flash)
	flash.position.y = 0.55
	flash.ignite(Color("ff963c"))
	RiftAudio.play_effect(&"enemy_break")
	var collapse := create_tween()
	collapse.tween_property(sacs, "scale", Vector3(0.25, 0.04, 0.25), 0.43)
	collapse.tween_callback(hide)
