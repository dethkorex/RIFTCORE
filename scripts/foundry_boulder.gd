extends AnimatableBody3D

const VFX := preload("res://scripts/factory_trap_vfx.gd")
# Ten standard hits or four charged hits. Mixed hits share the same fracture meter.
const TO_BREAK := 30
const WARNING := 1.8
const ROLL_SPEED := 3.6
@export var radius := 1.4
@export var runway_length := 10.0
@export var direction := -1.0
var authority := true
var hit_count := 0
var elapsed := 0.0
var status := 0
var start: Vector3
var material := ShaderMaterial.new()
var body_mesh: MeshInstance3D
var body_shape: CollisionShape3D
var warning: Node3D

func _ready() -> void:
	start = position
	sync_to_physics = false
	collision_layer = 2
	collision_mask = 0
	body_shape = CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = radius
	body_shape.shape = ball
	add_child(body_shape)
	body_mesh = MeshInstance3D.new()
	var stone := SphereMesh.new()
	stone.radius = radius
	stone.height = radius * 2.0
	stone.radial_segments = 48
	stone.rings = 24
	body_mesh.mesh = stone
	material.shader = preload("res://assets/neon_factory/foundry/slag_fracture.gdshader")
	body_mesh.material_override = material
	add_child(body_mesh)
	warning = Node3D.new()
	add_child(warning)
	warning.position = Vector3(direction * runway_length * 0.52, -radius + 0.035, 0)
	preload("res://scripts/attack_fx.gd").telegraph(warning, runway_length, Color("ff6d3c"), WARNING)
	present()

func _physics_process(delta: float) -> void:
	if not authority or status == 3:
		return
	match status:
		0:
			if operators().any(threatens):
				status = 1
		1:
			elapsed += delta
			if elapsed >= WARNING:
				status = 2
				elapsed = 0.0
				RiftAudio.foundry_sound(&"boulder_roll", global_position)
		2:
			elapsed += delta
			var distance := minf(elapsed * ROLL_SPEED, runway_length)
			var prior_x := global_position.x
			position.x = start.x + direction * distance
			for body in operators():
				var from := Vector2(prior_x, global_position.y)
				var to := Vector2(global_position.x, global_position.y)
				var center := Vector2(body.global_position.x, body.global_position.y)
				if body.health > 0.0 and center.distance_to(Geometry2D.get_closest_point_to_segment(center, from, to)) < radius + 0.32:
					body.die_in_pit()
			if distance >= runway_length:
				status = 4
	present()

func threatens(body: RiftPlayer) -> bool:
	var origin := get_parent_node_3d().to_global(start)
	var ahead := (body.global_position.x - origin.x) * direction
	return body.health > 0.0 and absf(body.global_position.y - origin.y) < 2.1 and ahead >= -0.75 and ahead < runway_length + 4.3

func is_near_room(body: RiftPlayer) -> bool:
	var origin := get_parent_node_3d().to_global(start)
	var along := (body.global_position.x - origin.x) * direction
	return body.health > 0.0 and absf(body.global_position.y - origin.y) < 4.3 and along >= -5.0 and along <= runway_length + 7.0

func operators() -> Array[Node]:
	var stage := get_parent().get_parent()
	var actors := stage.get_node_or_null("Actors")
	return actors.get_children().filter(func(actor): return actor is RiftPlayer) if actors else []

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if shot.owner_faction != "player" or not authority or status == 3:
		return false
	hit_count = mini(TO_BREAK, hit_count + (8 if shot.is_charged else 3))
	if hit_count >= TO_BREAK:
		status = 3
		break_rock()
	else:
		VFX.throw_sparks(self, Color("ff7e40"), 0.56)
	present()
	return true

func break_rock() -> void:
	RiftAudio.foundry_sound(&"barricade_crack", global_position)
	var debris := CPUParticles3D.new()
	debris.emitting = false
	debris.one_shot = true
	debris.explosiveness = 0.92
	debris.amount = 28
	debris.lifetime = 0.8
	debris.direction = Vector3.UP
	debris.spread = 145.0
	debris.gravity = Vector3.DOWN * 11.0
	debris.initial_velocity_min = 2.7
	debris.initial_velocity_max = 6.0
	debris.angular_velocity_min = -250.0
	debris.angular_velocity_max = 250.0
	debris.scale_amount_min = 0.4
	debris.scale_amount_max = 1.4
	var shard := PrismMesh.new()
	shard.size = Vector3(0.27, 0.21, 0.16)
	shard.material = material
	debris.mesh = shard
	add_child(debris)
	debris.emitting = true
	get_tree().create_timer(debris.lifetime + 0.14, false).timeout.connect(debris.queue_free)

func present() -> void:
	body_mesh.visible = status != 3
	body_shape.set_deferred("disabled", status == 3)
	var body_layer := 3 if status in [0, 1, 4] else 2
	if collision_layer != body_layer:
		set_deferred("collision_layer", body_layer)
	body_mesh.rotation.z = -direction * absf(position.x - start.x) / radius
	material.set_shader_parameter("damage", float(hit_count) / TO_BREAK)
	warning.visible = status == 1

func reset_runway() -> void:
	if hit_count >= TO_BREAK:
		return
	status = 0
	elapsed = 0.0
	hit_count = 0
	position = start
	present()

func snapshot() -> Array:
	return [status, hit_count, position.x, elapsed]

func apply_snapshot(state: Array) -> void:
	var starts_rolling := status == 1 and int(state[0]) == 2
	var breaks := hit_count < TO_BREAK and int(state[1]) >= TO_BREAK
	status = int(state[0])
	hit_count = int(state[1])
	position.x = float(state[2])
	elapsed = float(state[3])
	if starts_rolling:
		RiftAudio.foundry_sound(&"boulder_roll", global_position)
	if breaks:
		break_rock()
	present()
