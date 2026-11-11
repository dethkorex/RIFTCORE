class_name WalkerBot
extends Combatant

const XP_REWARDS := [12, 16, 26, 18, 16]
const XP_ORB := preload("res://assets/pickups/xp_orb.tscn")
const SMALL_DROPS := [
	preload("res://assets/pickups/health_small.tscn"),
	preload("res://assets/pickups/energy_small.tscn"),
	preload("res://assets/pickups/credits_small.tscn"),
]
const LARGE_DROPS := [
	preload("res://assets/pickups/health_large.tscn"),
	preload("res://assets/pickups/energy_large.tscn"),
	preload("res://assets/pickups/credits_large.tscn"),
]
@export_range(0.0, 1.0) var drop_chance := 0.03
enum Variant { SCOUT, QUAD, HEAVY, TURRET, FLYER }
@export var variant: Variant
@export var patrol_right_limit := 100000.0
const MODELS := [
	preload("res://assets/enemies/factory_scout.tscn"),
	preload("res://assets/enemies/factory_quad.tscn"),
	preload("res://assets/enemies/factory_heavy.tscn"),
	preload("res://assets/enemies/factory_turret.tscn"),
	preload("res://assets/enemies/factory_flyer.tscn"),
]

var faction := "enemy"
var target: RiftPlayer
var patrol_center := 0.0
var direction := 1.0
var move_speed := 2.4
var contact_lock := 0.0
var shot_clock := 1.1
var home_height := 0.0
var hover_clock := 0.0
var robot: Node3D
var attack_time := 0.0
var stagger_left := 0.0
var recoil := 0.0
var gait_phase := 0.0
var gait_joints: Array[Node3D] = []

func _ready() -> void:
	max_health = [40.0, 55.0, 95.0, 60.0, 35.0][variant]
	move_speed = [2.4, 3.6, 1.35, 0.0, 2.5][variant]
	super._ready()
	patrol_center = global_position.x
	home_height = global_position.y
	build_visuals()
	install_model()
	install_health_bar()
	died.connect(_on_died)

func build_visuals() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.2, 0.8)
	collision.shape = box
	add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "BodyMesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.2, 0.8)
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e54152")
	mat.metallic = 0.7
	mat.emission_enabled = true
	mat.emission = Color("5a0713")
	mesh.material_override = mat
	add_child(mesh)

func install_model() -> void:
	robot = MODELS[variant].instantiate() as Node3D
	add_child(robot)
	robot.scale = Vector3.ONE * 1.16
	for index in range(4):
		var limb := robot.find_child("Gait_%d" % index, true, false) as Node3D
		if limb:
			gait_joints.append(limb)
	$BodyMesh.hide()
	var collider := $CollisionShape3D as CollisionShape3D
	var hitbox := BoxShape3D.new()
	hitbox.size = [
		Vector3(1.1, 1.2, 0.95), Vector3(1.2, 1.2, 1.0),
		Vector3(1.32, 1.2, 1.06), Vector3(1.0, 1.2, 1.16),
		Vector3(1.1, 0.78, 0.95),
	][variant] * 1.16
	collider.shape = hitbox

func install_health_bar() -> void:
	var bar := MeshInstance3D.new()
	bar.name = "HealthBar"
	var face := QuadMesh.new()
	face.size = Vector2(0.79, 0.086)
	bar.mesh = face
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/enemies/health_bar.gdshader")
	bar.material_override = material
	add_child(bar)
	bar.position = Vector3(0, 0.72 if variant == Variant.FLYER else 0.94, 0.27)
	health_changed.connect(func(current: float, maximum: float):
		material.set_shader_parameter("remaining", current / maximum)
	)

func _physics_process(delta: float) -> void:
	contact_lock = maxf(0.0, contact_lock - delta)
	shot_clock -= delta
	attack_time = maxf(0.0, attack_time - delta)
	var tracking := false
	if is_instance_valid(target) and target.health > 0.0:
		var distance := target.global_position.x - global_position.x
		tracking = absf(distance) < 8.0 and absf(target.global_position.y - global_position.y) < (4.0 if variant == Variant.FLYER else 1.8)
		if tracking and absf(distance) > 0.05:
			direction = signf(distance)
		if stagger_left <= 0.0 and tracking and shot_clock <= 0.0 and absf(distance) > 1.5:
			fire_at_player()
	if not tracking and absf(global_position.x - patrol_center) > 4.0:
		direction = -signf(global_position.x - patrol_center)
	velocity.x = direction * move_speed
	if is_on_floor() and variant != Variant.TURRET:
		var ledge := global_position + Vector3(direction * 0.75, 0.0, 0.0)
		var probe := PhysicsRayQueryParameters3D.create(ledge, ledge + Vector3.DOWN * 1.1)
		probe.exclude = [get_rid()]
		if is_instance_valid(target):
			probe.exclude = [get_rid(), target.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(probe).is_empty():
			if not tracking:
				direction = -direction
			velocity.x = 0.0
	if stagger_left > 0.0:
		stagger_left = maxf(0.0, stagger_left - delta)
		velocity.x = recoil
		recoil = move_toward(recoil, 0.0, 25.0 * delta)
	if variant == Variant.FLYER:
		hover_clock += delta
		velocity.y = (home_height + sin(hover_clock * 2.6) * 0.17 - global_position.y) * 4.0
	elif not is_on_floor():
		velocity.y -= 28.0 * delta
	velocity.z = -global_position.z * 12.0
	velocity.x = minf(velocity.x, (patrol_right_limit - global_position.x) / delta)
	move_and_slide()
	if robot and not is_zero_approx(direction):
		robot.rotation.y = lerp_angle(robot.rotation.y, direction * PI * 0.5, 1.0 - exp(-14.0 * delta))
		robot.rotation.z = direction * (attack_time * 0.32 if attack_time > 0.0 else clampf(velocity.x * -0.025, -0.09, 0.09))
		var striding := is_on_floor() and stagger_left <= 0.0 and absf(velocity.x) > 0.28
		gait_phase = fposmod(gait_phase + (absf(velocity.x) * 4.8 * delta if striding else 0.0), TAU)
		for i in range(gait_joints.size()):
			var diagonal := (i in [0, 3]) if gait_joints.size() == 4 else i == 0
			var flex := sin(gait_phase + (0.0 if diagonal else PI)) * 0.34 if striding else 0.0
			gait_joints[i].rotation.x = lerpf(gait_joints[i].rotation.x, flex, 0.47)
		robot.position.y = lerpf(robot.position.y, absf(sin(gait_phase)) * 0.04 if striding else 0.0, 0.34)
	if global_position.y < -4.0:
		take_damage(max_health)
		return
	for index in range(get_slide_collision_count()):
		var body := get_slide_collision(index).get_collider() as RiftPlayer
		if body:
			damage_on_contact(body)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	var previous := health
	super.take_damage(amount, source_position)
	if health > 0.0 and health < previous:
		var side := signf(global_position.x - source_position.x)
		if is_zero_approx(side):
			side = -direction
		stagger_left = 0.18
		recoil = side * (3.2 if variant == Variant.HEAVY or variant == Variant.TURRET else 5.0)

func damage_on_contact(body: RiftPlayer) -> void:
	if contact_lock > 0.0 or health <= 0.0:
		return
	contact_lock = 0.8
	body.take_damage(14.0, global_position)

func fire_at_player() -> void:
	var side := signf(target.global_position.x - global_position.x)
	if side != 0.0:
		direction = side
	if robot:
		robot.rotation.y = direction * PI * 0.5
	var origin := global_position + Vector3(direction * 0.66, 0.13, 0.0)
	var aim := target.global_position - origin
	var sight := PhysicsRayQueryParameters3D.create(origin, target.global_position)
	sight.exclude = [get_rid(), target.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
		shot_clock = 0.23
		return
	shot_clock = randf_range(0.85, 1.35) if variant == Variant.TURRET else randf_range(1.7, 2.6)
	attack_time = 0.4
	var shot := RiftProjectile.new()
	get_parent().add_child(shot)
	shot.global_position = origin
	shot.speed = 15.0 if variant == Variant.TURRET else 11.5
	shot.damage = 15.0 if variant == Variant.HEAVY else 9.0
	shot.setup(aim, faction, Color("ff5d71"))

func spawn_pickup(scene: PackedScene, at: Vector3, temporary: bool, experience := 0) -> void:
	var pickup := scene.instantiate() as Area3D
	pickup.expires = temporary
	pickup.xp_amount = experience
	pickup.position = get_parent_node_3d().to_local(at)
	get_parent().add_child.call_deferred(pickup)

func find_drop_anchor() -> Vector3:
	var origin := global_position
	var casts: Array[Vector3] = []
	for distance in [0.0, -1.15, 1.15, -2.30, 2.30, -3.45, 3.45]:
		casts.append(Vector3(origin.x + distance, maxf(origin.y + 0.30, 0.95), 0.0))
	casts.append(Vector3(patrol_center, maxf(home_height + 0.85, 1.25), 0.0))
	var exclusions: Array[RID] = [get_rid()]
	if is_instance_valid(target):
		exclusions.append(target.get_rid())
	for at in casts:
		var ray := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 13.0)
		ray.exclude = exclusions
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is StaticBody3D and hit.normal.y >= 0.55:
			return hit.position + Vector3.UP * 0.42
	if is_instance_valid(target):
		return target.global_position
	return Vector3(patrol_center, home_height - 0.18, 0)

func _on_died() -> void:
	var drop_position := find_drop_anchor()
	spawn_pickup(XP_ORB, drop_position, false, XP_REWARDS[variant])
	if global_position.y > -3.0 and randf() < drop_chance:
		var pool := LARGE_DROPS if randf() < 0.2 else SMALL_DROPS
		spawn_pickup(pool.pick_random(), drop_position + Vector3.FORWARD * 0.25, true)
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	if global_position.y <= -3.0:
		queue_free()
		return
	RiftAudio.play_effect(&"enemy_break")
	hide()
	var burst := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.ignite()
	get_tree().create_timer(0.45, false).timeout.connect(burst.queue_free)
	queue_free()
