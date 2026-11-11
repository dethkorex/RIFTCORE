@tool
extends Area3D

enum Kind { ICE, WATER, WIND, LOW_GRAVITY, VENT, ELECTRIC, UPDRAFT, MUTATION, SOLAR, PRESS, CORRUPTION }
@export var kind: Kind
@export var dimensions := Vector3(3, 2, 2)
@export var tint := Color("54dfff")
@export var direction := 1.0
@export var period := 4.2
@export var offset := 0.0
@export var power := 20.0
var clock := 0.0
var damage_timer := 0.0
var signal_mesh: MeshInstance3D
var effect: Node3D
var paint: StandardMaterial3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	clock = offset
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var plate := BoxMesh.new()
	plate.size = Vector3(dimensions.x, 0.035, minf(dimensions.z, 2.15))
	paint = StandardMaterial3D.new()
	paint.albedo_color = tint.darkened(0.38)
	paint.emission_enabled = true
	paint.emission = tint
	paint.emission_energy_multiplier = 0.6
	paint.metallic = 0.43
	signal_mesh = MeshInstance3D.new()
	signal_mesh.mesh = plate
	signal_mesh.material_override = paint
	signal_mesh.position.y = -dimensions.y * 0.5 + 0.035
	add_child(signal_mesh)
	effect = Node3D.new()
	add_child(effect)
	if kind <= Kind.LOW_GRAVITY:
		add_to_group("terrain_modifier")
	if kind == Kind.WATER:
		var volume := BoxMesh.new()
		volume.size = Vector3(dimensions.x, dimensions.y, dimensions.z)
		var water := StandardMaterial3D.new()
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		water.albedo_color = Color(tint, 0.13)
		RiftProjectile.part(effect, volume, water, Vector3.ZERO, Vector3.ONE)
	elif kind in [Kind.WIND, Kind.LOW_GRAVITY, Kind.UPDRAFT]:
		for i in range(6):
			var at := Vector3((i - 2.5) * dimensions.x / 6.5, 0.20 * cos(i), -0.53)
			var marker := RiftProjectile.part(effect, RiftProjectile.cached_mesh("Ring"), RiftProjectile.light_paint(tint, 0.8), at, Vector3.ONE * 0.53)
			marker.rotation.z = direction * 0.48
	elif kind >= Kind.VENT:
		var count := clampi(roundi(dimensions.x / 0.7), 3, 12)
		for i in count:
			var x := ((i + 0.5) / count - 0.5) * dimensions.x
			var pulse := RiftProjectile.add_glow(effect, tint, 0.95 + 0.25 * (i % 3))
			pulse.position = Vector3(x, -dimensions.y * 0.21, 0.03)
		if kind == Kind.PRESS:
			var head := BoxMesh.new()
			head.size = Vector3(dimensions.x * 0.85, 0.42, 1.72)
			RiftProjectile.part(effect, head, RiftProjectile.light_paint(tint.darkened(0.38), 0.6), Vector3.ZERO, Vector3.ONE)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or kind <= Kind.LOW_GRAVITY:
		return
	clock = fposmod(clock + delta, maxf(period, 2.4))
	var phase := clock / maxf(period, 2.4)
	var live := phase >= 0.65 and phase <= 0.90
	paint.emission_energy_multiplier = 2.0 + sin(clock * 29.0) if phase > 0.45 and phase < 0.90 else 0.45
	effect.visible = live
	if kind == Kind.PRESS:
		effect.visible = true
		effect.position.y = lerpf(dimensions.y * 0.67, -dimensions.y * 0.22, smoothstep(0.51, 0.67, phase) * (1.0 - smoothstep(0.90, 1.0, phase)))
	damage_timer = maxf(0.0, damage_timer - delta)
	if not live or damage_timer > 0.0:
		return
	for body in get_overlapping_bodies():
		if not body is RiftPlayer:
			continue
		if kind == Kind.UPDRAFT:
			body.velocity.y = maxf(body.velocity.y, 11.3)
			body.air_dash_available = true
			damage_timer = 0.42
		else:
			body.take_projectile_damage(power)
			damage_timer = 0.62
