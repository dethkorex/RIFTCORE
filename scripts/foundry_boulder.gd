extends AnimatableBody3D

const VFX := preload("res://scripts/factory_trap_vfx.gd")
# Ten standard hits or four charged hits. Mixed hits share the same fracture meter.
const TO_BREAK := 30
const FLOOR_MARK := preload("res://scripts/foundry_flame.gd")
const WARNING := 0.62
const START_SPEED := 5.5
const ACCELERATION := 8.4
@export var radius := 1.4
@export var runway_length := 10.0
@export var direction := -1.0
@export var slope_drop := 0.0
var authority := true
var hit_count := 0
var elapsed := 0.0
var roll_speed := START_SPEED
var vertical_speed := 0.0
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
	collision_mask = 1
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
	var track := FLOOR_MARK.floor_mark(Vector2(runway_length, slope_drop).length(), 1.76, FLOOR_MARK.Style.DRILL, Color("ff783b"))
	warning = Node3D.new()
	warning.position = Vector3(direction * runway_length * 0.5, -radius - slope_drop * 0.5, 0)
	warning.rotation.z = atan2(-direction * slope_drop, runway_length)
	add_child(warning)
	warning.add_child(track)
	track.material_override.set_shader_parameter("direction", direction)
	track.material_override.set_shader_parameter("progress", 0.75)
	present()

func _physics_process(delta: float) -> void:
	if not authority or status in [3, 4]:
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
				# Actors take swept contact damage; only the terrain arrests the roll.
				for actor in get_parent().get_parent().get_node("Actors").get_children():
					if actor is CharacterBody3D:
						add_collision_exception_with(actor)
				RiftAudio.foundry_sound(&"boulder_roll", global_position)
		2:
			elapsed += delta
			var prior := global_position
			roll(delta)
			for body in operators():
				var from := Vector2(prior.x, prior.y)
				var to := Vector2(global_position.x, global_position.y)
				var center := Vector2(body.global_position.x, body.global_position.y)
				var closest := from if from.is_equal_approx(to) else Geometry2D.get_closest_point_to_segment(center, from, to)
				if body.health > 0.0 and center.distance_to(closest) < radius + 0.32:
					body.die_in_pit()
			# An unsupported boulder keeps falling until it leaves the playable sector.
			if global_position.y < float(get_parent().get_parent().get_meta("pit_floor_y", -3.4)) - 24.0:
				status = 3
	present()

func roll(delta: float) -> void:
	roll_speed = minf(roll_speed + ACCELERATION * delta, 22.0)
	vertical_speed -= 28.0 * delta
	var travel := Vector3(direction * roll_speed, vertical_speed, 0.0) * delta
	var ground := move_and_collide(Vector3.DOWN * 0.12, true)
	if ground and ground.get_normal().y > 0.65:
		var normal := ground.get_normal()
		vertical_speed = -normal.x * direction * roll_speed / normal.y
		travel.y = vertical_speed * delta - 0.012
	for contact in 4:
		var hit := move_and_collide(travel)
		if not hit:
			break
		var normal := hit.get_normal()
		if normal.y < 0.65 and normal.x * direction < -0.45:
			status = 4
			return
		travel = hit.get_remainder().slide(normal)
		if travel.length_squared() < 0.000001:
			break

func move_along_slope(distance: float) -> void:
	var progress := clampf(distance / runway_length, 0.0, 1.0)
	position = start + Vector3(direction * distance, -slope_drop * progress, 0.0)

func threatens(body: RiftPlayer) -> bool:
	var origin := get_parent_node_3d().to_global(start)
	var ahead := (body.global_position.x - origin.x) * direction
	var floor_y := origin.y - radius - slope_drop * clampf(ahead / runway_length, 0.0, 1.0)
	return body.health > 0.0 and body.global_position.y >= floor_y - 0.7 and body.global_position.y < floor_y + 3.0 \
		and ahead >= -0.75 and ahead < runway_length + 4.5

func is_near_room(body: RiftPlayer) -> bool:
	var origin := get_parent_node_3d().to_global(start)
	var along := (body.global_position.x - origin.x) * direction
	return body.health > 0.0 and absf(body.global_position.y - origin.y + slope_drop * 0.5) < 4.3 and along >= -5.0 and along <= runway_length + 7.0

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
		VFX.impact(self, 0.56, &"concrete")
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
	body_mesh.rotation.z = -Vector2(position.x - start.x, position.y - start.y).length() * direction / radius
	material.set_shader_parameter("damage", float(hit_count) / TO_BREAK)
	warning.visible = status == 1

func reset_runway() -> void:
	if status == 2 or hit_count >= TO_BREAK:
		return
	status = 0
	elapsed = 0.0
	roll_speed = START_SPEED
	vertical_speed = 0.0
	hit_count = 0
	position = start
	present()

func snapshot() -> Array:
	return [status, hit_count, position.x, elapsed, position.y]

func apply_snapshot(state: Array) -> void:
	var starts_rolling := status < 2 and int(state[0]) == 2
	var breaks := hit_count < TO_BREAK and int(state[1]) >= TO_BREAK
	status = int(state[0])
	hit_count = int(state[1])
	if state.size() > 4:
		position = Vector3(float(state[2]), float(state[4]), start.z)
	else:
		move_along_slope(absf(float(state[2]) - start.x))
	elapsed = float(state[3])
	if starts_rolling:
		RiftAudio.foundry_sound(&"boulder_roll", global_position)
	if breaks:
		break_rock()
	present()
