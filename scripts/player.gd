class_name RiftPlayer
extends Combatant

const PACK_VFX := preload("res://scripts/pack_combat_vfx.gd")

signal energy_changed(current: float, maximum: float)
signal credits_changed(total: int)
signal experience_changed(total: int)
signal experience_earned(amount: int)
signal blueprint_found(id: String)
signal salvage_collected(drop: Dictionary)

const START_HEALTH := 80.0
const START_ENERGY := 75.0
const Catalog := preload("res://scripts/sector_catalog.gd")
signal fell_into_pit
signal shot_fired(projectile: RiftProjectile)
signal melee_performed
signal weapon_changed(title: String)
signal lives_changed(count: int)
signal life_picked_up

var lives := 3
var buster_damage_multiplier := 1.0
var armor_resistance := 0.0
var charge_cost_multiplier := 1.0
var salvage_multiplier := 1.0
var xp_pickup_multiplier := 1.0
var healing_pickup_multiplier := 1.0
var magma_unlocked := false
var thorn_unlocked := false
var thorn_active := false
var magma_active := false
var run_weapon_ids: Array = []
var special_weapon := ""
var original_armor: Dictionary = {}
var forge_armor: Dictionary = {}
var base_suit_meshes: Array[MeshInstance3D] = []
var fire_suit_mesh: MeshInstance3D
var nature_suit_mesh: MeshInstance3D

@export_group("Movement")
@export var move_speed := 9.0
@export var acceleration := 55.0
@export var air_acceleration := 63.0
@export var air_braking := 43.0
@export var air_reverse_acceleration := 105.0
@export var jump_velocity := 12.5
@export var gravity := 28.0
@export var fall_gravity_multiplier := 1.42
@export var max_fall_speed := 21.0
@export var coyote_duration := 0.12
@export var jump_buffer_duration := 0.14
@export_group("Dash")
@export var dash_speed := 20.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.35
@export var dash_energy_cost := 0.0
@export_group("Combat")
@export var fire_interval := 0.115
@export var charge_time := 0.7
@export var charge_energy_cost := 30.0
@export var base_buster_damage := 18.0
@export var melee_multiplier := 2.5
@export var damage_gain_per_level := 0.06
@export var melee_range := 2.2
@export var melee_cooldown := 0.42

var faction := "player"
var facing := 1.0
var energy := START_ENERGY
var max_energy := START_ENERGY
var credits := 0
var salvage: Dictionary = {}
var recovered_blueprints: Dictionary = {}
var experience := 0
var coyote := 0.0
var jump_buffer := 0.0
var dash_left := 0.0
var dash_elapsed := 0.0
var dash_facing := 1.0
var ground_dash := false
var dash_lock := 0.0
var fire_lock := 0.0
var shot_buffer_left := 0.0
var queued_charged := false
var queued_pose := false
var combo_hot := false
var melee_lock := 0.0
var combo_step := 0
var combo_queued := 0
var combo_grace := 0.0
var combo_time := 0.0
var combo_hit_at := 0.0
var combo_hit := false
var combo_facing := 1.0
var combo_duration := 0.0
const SWING_DURATIONS := [0.18, 0.18, 0.23]

var air_dash_available := true
var spawn_position := Vector3.ZERO
var model_root: Node3D
var animation_player: AnimationPlayer
var current_animation := ""
var landing_left := 0.0
var crouching := false
var low_profile := false
var contact_recoil := 0.0
var ladder: Node3D
var ladder_lock := 0.0
var ladder_exit := false
var drop_through: StaticBody3D
var wall_side := 0.0
var wall_grace := 0.0
var wall_launch_lock := 0.0
var wall_sliding := false
@export var wall_slide_speed := 2.4
@export var wall_kick_speed := 6.7
@export var wall_kick_height := 13.5
var climb_pose: SkeletonModifier3D
var standing_capsule := CapsuleShape3D.new()
var charge_held := false
var charge_elapsed := 0.0
var charge_orb: MeshInstance3D
var muzzle_skeleton: Skeleton3D
var muzzle_bone := -1
var muzzle_offset := Vector3.ZERO
var buster_pose: SkeletonModifier3D
var resume_input_guard := 0.0
var sword_follows_hand := false

func _ready() -> void:
	max_health = START_HEALTH
	super._ready()
	floor_snap_length = 0.24
	slide_on_ceiling = false
	floor_max_angle = deg_to_rad(52.0)
	spawn_position = global_position
	build_visuals()
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider and collider.shape is CapsuleShape3D:
		collider.shape = collider.shape.duplicate()
		standing_capsule.radius = collider.shape.radius
		standing_capsule.height = collider.shape.height
	model_root = get_node_or_null("ModelRoot") as Node3D
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	bind_sword_to_hand()
	bind_cannon_muzzle()
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		climb_pose = preload("res://scripts/climb_pose.gd").new()
		climb_pose.influence = 0.0
		skeleton.add_child(climb_pose)
		if buster_pose:
			skeleton.move_child(buster_pose, -1)
		install_fire_suit(skeleton)
	if animation_player:
		make_locomotion_in_place()
		build_finisher_clip()
		for clip in [&"idle", &"walk", &"run", &"fall"]:
			if animation_player.has_animation(clip):
				animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func install_fire_suit(skeleton: Skeleton3D) -> void:
	for object in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh := object as MeshInstance3D
		if mesh.skin:
			base_suit_meshes.append(mesh)
	fire_suit_mesh = attach_suit_mesh(skeleton, preload("res://assets/models/mecha_main/RiftcoreFireRigged.glb"))
	nature_suit_mesh = attach_suit_mesh(skeleton, preload("res://assets/models/mecha_main/RiftcoreNatureRigged.glb"))

func attach_suit_mesh(skeleton: Skeleton3D, suit: PackedScene) -> MeshInstance3D:
	var imported := suit.instantiate() as Node3D
	model_root.add_child(imported)
	var skin: MeshInstance3D
	for object in imported.find_children("*", "MeshInstance3D", true, false):
		var mesh := object as MeshInstance3D
		if not mesh.skin:
			continue
		skin = mesh
		# Both meshes use the exact same RX-07 bind matrices and named bones.
		# Reuse the live skeleton, so swapping never restarts clips or modifiers.
		mesh.reparent(skeleton, true)
		mesh.skeleton = mesh.get_path_to(skeleton)
		mesh.visible = false
		break
	imported.queue_free()
	return skin

func bind_cannon_muzzle() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var bone := skeleton.find_bone("mixamorig_RightForeArm")
	if bone < 0:
		return
	muzzle_skeleton = skeleton
	muzzle_bone = bone
	# Barrel rim center measured in the imported mesh's rest coordinates.
	muzzle_offset = skeleton.get_bone_global_rest(bone).affine_inverse() * Vector3(-0.5, 0.65, -0.042)
	if animation_player:
		buster_pose = preload("res://scripts/buster_pose.gd").new()
		buster_pose.muzzle_bone = bone
		buster_pose.muzzle_offset = muzzle_offset
		buster_pose.influence = 0.0
		skeleton.add_child(buster_pose)
		buster_pose.load_poses(animation_player)
		buster_pose.modification_processed.connect(buster_pose.cache_muzzle)

func bind_sword_to_hand() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	var sword := get_node_or_null("SwordPivot") as Node3D
	if skeleton == null or sword == null or skeleton.find_bone("mixamorig_LeftHand") < 0:
		return
	var hand := BoneAttachment3D.new()
	hand.bone_name = "mixamorig_LeftHand"
	skeleton.add_child(hand)
	sword.reparent(hand, false)
	sword.position = Vector3.ZERO
	sword.rotation.z = PI * 0.5
	sword.scale = Vector3.ONE * 0.39
	sword_follows_hand = true

func make_locomotion_in_place() -> void:
	var rest := animation_player.get_animation(&"idle")
	for clip in [&"walk", &"run", &"jump"]:
		if rest == null or not animation_player.has_animation(clip):
			continue
		var animation := animation_player.get_animation(clip)
		for track in range(animation.get_track_count()):
			var path := animation.track_get_path(track)
			if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or not String(path).ends_with(":mixamorig_Hips"):
				continue
			var rest_track := rest.find_track(path, Animation.TYPE_POSITION_3D)
			if rest_track < 0:
				continue
			var neutral: Vector3 = rest.track_get_key_value(rest_track, 0)
			for key in range(animation.track_get_key_count(track)):
				var pose: Vector3 = animation.track_get_key_value(track, key)
				pose.x = neutral.x
				pose.z = neutral.z
				if clip == &"jump":
					pose.y = neutral.y
				animation.track_set_key_value(track, key, pose)

func build_visuals() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	collision.shape = capsule
	add_child(collision)
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.42
	capsule_mesh.height = 1.7
	body_mesh.mesh = capsule_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1678ff")
	mat.metallic = 0.65
	mat.roughness = 0.22
	body_mesh.material_override = mat
	add_child(body_mesh)
	var core := OmniLight3D.new()
	core.name = "CoreLight"
	core.light_color = Color("3ddcff")
	core.light_energy = 2.2
	core.omni_range = 3.5
	add_child(core)

func _physics_process(delta: float) -> void:
	resume_input_guard = maxf(0.0, resume_input_guard - delta)
	if health <= 0.0:
		cancel_charge()
		return
	var terrain := environment_control()
	landing_left = maxf(0.0, landing_left - delta)
	fire_lock = maxf(0.0, fire_lock - delta)
	dash_lock = maxf(0.0, dash_lock - delta)
	var axis := Input.get_axis("move_left", "move_right")
	ladder_lock = maxf(0.0, ladder_lock - delta)
	update_wall_contact(delta, axis)
	var dropping := false
	var down := Input.is_action_pressed("crouch") or Input.is_action_pressed("crouch_stick")
	if is_on_floor() and down and Input.is_action_just_pressed("dash") and not is_instance_valid(ladder):
		dropping = start_platform_drop()
	if not dropping and update_ladder(delta, axis):
		return
	if climb_pose:
		climb_pose.influence = move_toward(climb_pose.influence, 0.0, 0.28)
	if contact_recoil > 0.0:
		contact_recoil = maxf(0.0, contact_recoil - delta)
		axis = 0.0
	if dash_left <= 0.0 and absf(axis) > 0.1:
		var next_facing := signf(axis)
		facing = next_facing
	if dropping:
		coyote = 0.0
	elif is_on_floor():
		coyote = coyote_duration
		air_dash_available = true
	else:
		coyote = maxf(0.0, coyote - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = jump_buffer_duration
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	if not dropping and resume_input_guard <= 0.0 and contact_recoil <= 0.0 and Input.is_action_just_pressed("dash") and dash_lock <= 0.0 and (is_on_floor() or air_dash_available):
		dash_left = dash_duration
		dash_elapsed = 0.0
		dash_facing = facing
		ground_dash = is_on_floor()
		dash_lock = dash_cooldown
		RiftAudio.play_effect(&"dash")
		var flash := preload("res://scripts/dash_flash.gd").new()
		get_parent().add_child(flash)
		flash.global_position = global_position
		flash.ignite(facing)
		if not is_on_floor(): air_dash_available = false
	var stick_crouch := Input.is_action_pressed("crouch_stick") and absf(axis) < 0.35
	var wants_crouch := Input.is_action_pressed("crouch") or stick_crouch
	set_crouch(not dropping and wants_crouch and is_on_floor() and dash_left <= 0.0 and jump_buffer <= 0.0)
	if melee_lock <= 0.0:
		if Input.is_action_just_pressed("swap_weapon"):
			cycle_weapon()
		elif Input.is_action_just_pressed("previous_suit"):
			cycle_weapon(-1)
	update_charge(delta)
	update_melee(delta)
	if dash_left > 0.0:
		update_dash(delta, axis)
	if dash_left <= 0.0:
		var accel := acceleration * terrain.x if is_on_floor() else air_acceleration
		if axis * velocity.x < 0.0:
			accel = acceleration * 1.8 * terrain.x if is_on_floor() else air_reverse_acceleration
		elif is_on_floor() and absf(axis) < 0.08:
			accel *= 1.20
		elif not is_on_floor() and absf(axis) < 0.08:
			accel = air_braking
		if contact_recoil <= 0.0 and wall_launch_lock <= 0.0:
			velocity.x = move_toward(velocity.x, 0.0 if crouching else axis * move_speed, accel * delta)
		if not is_on_floor():
			var gravity_scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
			velocity.y = maxf(-max_fall_speed * clampf(terrain.y * 1.4, 0.36, 1.0), velocity.y - gravity * gravity_scale * terrain.y * delta)
		velocity.x += terrain.z * delta
		if wall_sliding:
			velocity.y = maxf(velocity.y, -wall_slide_speed)
		if jump_buffer > 0.0 and wall_grace > 0.0 and coyote <= 0.0 and contact_recoil <= 0.0:
			velocity = Vector3(-wall_side * wall_kick_speed, wall_kick_height, 0.0)
			facing = -wall_side
			wall_launch_lock = 0.095
			wall_sliding = false
			wall_grace = 0.0
			jump_buffer = 0.0
		if jump_buffer > 0.0 and coyote > 0.0 and not low_profile and contact_recoil <= 0.0:
			velocity.y = jump_velocity
			jump_buffer = 0.0
			coyote = 0.0
		elif jump_buffer > 0.0 and terrain.w > 0.0 and contact_recoil <= 0.0:
			velocity.y = 8.4
			jump_buffer = 0.0
		if Input.is_action_just_released("jump") and not Input.is_action_pressed("jump") and velocity.y > 0.0:
			velocity.y *= 0.45
	velocity.z = -global_position.z * 18.0
	for deck in get_tree().get_nodes_in_group(&"factory_one_way"):
		var platform := deck as StaticBody3D
		if platform == null:
			continue
		var surface_y := platform.global_position.y
		var side_contact := false
		var platform_shape := platform.get_node_or_null("Collider") as CollisionShape3D
		if platform_shape and platform_shape.shape:
			var half_size := one_way_half_size(platform_shape)
			if half_size != Vector3.ZERO:
				var basis := platform_shape.global_basis
				var top := platform_shape.to_global(Vector3(0, half_size.y, 0))
				var normal := basis.z.cross(basis.x).normalized()
				if normal.y < cos(floor_max_angle):
					remove_collision_exception_with(platform)
					continue
				var relative := global_position - top
				surface_y = top.y - (normal.x * relative.x + normal.z * relative.z) / normal.y
				side_contact = not platform.has_meta("hatch_walk_support") and outside_one_way_edge(platform_shape, half_size)
		var soles := global_position.y - standing_capsule.height * 0.5
		if platform == drop_through and soles < surface_y - 0.22:
			drop_through = null
		if platform == drop_through or (not side_contact and (velocity.y > 0.0 or soles < surface_y - 0.115)):
			add_collision_exception_with(platform)
		else:
			remove_collision_exception_with(platform)
	var was_airborne := not is_on_floor()
	var incoming_velocity := velocity
	move_and_slide()
	apply_ceiling_rebound(incoming_velocity)
	var landing_speed := incoming_velocity.y
	if was_airborne and is_on_floor() and landing_speed < -4.0:
		landing_left = 0.16 if absf(velocity.x) < 3.0 else 0.09
	for index in range(get_slide_collision_count()):
		var collider := get_slide_collision(index).get_collider()
		if is_instance_valid(collider) and collider.has_method("damage_on_contact"):
			collider.damage_on_contact(self)
	update_character_visuals()
	if global_position.y < -3.4:
		health = 0.0
		cancel_charge()
		health_changed.emit(health, max_health)
		set_physics_process(false)
		collision_layer = 0
		hide()
		fell_into_pit.emit()

func apply_ceiling_rebound(incoming: Vector3) -> void:
	if incoming.y <= 0.0:
		return
	if not is_on_ceiling():
		var hit_underside := false
		for index in range(get_slide_collision_count()):
			var normal := get_slide_collision(index).get_normal()
			if normal.y < -0.25 and incoming.dot(normal) < 0.0:
				hit_underside = true
				break
		if not hit_underside:
			return
	velocity.y = minf(velocity.y, -2.8)
	jump_buffer = 0.0
	coyote = 0.0

func update_dash(delta: float, axis: float) -> void:
	dash_elapsed += delta
	var reversing := axis * dash_facing < -0.27
	var released := not Input.is_action_pressed("dash") and dash_elapsed >= 0.065
	var at_edge := ground_dash and is_on_floor() and absf(axis) < 0.17 and not has_dash_floor(delta)
	if reversing or released or at_edge:
		dash_left = 0.0
		velocity.x = 0.0 if at_edge or reversing else clampf(velocity.x * 0.45, -move_speed, move_speed)
		if reversing:
			facing = signf(axis)
		return
	var steering := lerpf(0.78, 1.0, absf(axis)) if absf(axis) >= 0.17 else 1.0
	var speed := lerpf(move_speed, dash_speed, clampf(dash_left / 0.045, 0.0, 1.0))
	velocity = Vector3(dash_facing * speed * steering, 0.0, 0.0)
	dash_left = maxf(0.0, dash_left - delta)
	if dash_left == 0.0:
		velocity.x = clampf(velocity.x, -move_speed, move_speed)

func has_dash_floor(delta: float) -> bool:
	var ahead := global_position + Vector3(dash_facing * (standing_capsule.radius * 0.50 + dash_speed * delta), -standing_capsule.height * 0.5 + 0.30, 0)
	var ray := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 0.74, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y > 0.5

func environment_control() -> Vector4:
	# Ground grip, gravity, lateral flow, and buoyant jump.
	var result := Vector4(1, 1, 0, 0)
	for zone in get_tree().get_nodes_in_group("terrain_modifier"):
		if not zone.get_overlapping_bodies().has(self):
			continue
		match int(zone.kind):
			0: result.x = 0.24
			1:
				result.y = 0.46
				result.w = 1.0
				result.z += zone.direction * 13.0
			2: result.z += zone.direction * 27.0
			3: result.y = 0.47
	return result

func one_way_half_size(collider: CollisionShape3D) -> Vector3:
	var box := collider.shape as BoxShape3D
	if box:
		return box.size * 0.5
	var perch := collider.shape as CylinderShape3D
	if perch:
		var local_z := collider.to_local(global_position).z
		var edge_x := sqrt(maxf(0.0, perch.radius * perch.radius - local_z * local_z))
		return Vector3(edge_x, perch.height * 0.5, perch.radius)
	return Vector3.ZERO

func outside_one_way_edge(collider: CollisionShape3D, half_size: Vector3) -> bool:
	# Keep the end face solid while the capsule is next to it. The underside
	# still lets the player jump through the middle or climb through a ladder.
	var local := collider.to_local(global_position)
	var box_scale := collider.global_basis.get_scale().abs()
	var radius := standing_capsule.radius
	var side_reach := (radius + 0.25) / box_scale.x
	var body_side := (standing_capsule.height * 0.5 - radius) / box_scale.y
	return (
		absf(local.x) >= half_size.x and absf(local.x) <= half_size.x + side_reach
		and absf(local.y) < half_size.y + body_side and absf(local.z) < half_size.z
	)

func update_wall_contact(delta: float, axis: float) -> void:
	wall_launch_lock = maxf(0.0, wall_launch_lock - delta)
	wall_grace = maxf(0.0, wall_grace - delta)
	wall_sliding = false
	if is_on_floor() or dash_left > 0.0 or wall_launch_lock > 0.0 or contact_recoil > 0.0:
		wall_grace = 0.0
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var barrier := collision.get_collider() as StaticBody3D
		var normal := collision.get_normal()
		if not barrier or absf(normal.x) < 0.77 or absf(normal.y) > 0.53:
			continue
		if barrier.name in ["Blocker", "ExitBarrier"]:
			continue
		var side := -signf(normal.x)
		if absf(axis) > 0.14 and axis * side < 0.0:
			continue
		wall_side = side
		wall_grace = 0.11
		wall_sliding = velocity.y <= 0.0
		return

func start_platform_drop() -> bool:
	for index in range(get_slide_collision_count()):
		var hit := get_slide_collision(index)
		var deck := hit.get_collider() as StaticBody3D
		if not deck or not deck.is_in_group(&"factory_one_way") or hit.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
			continue
		drop_through = deck
		add_collision_exception_with(deck)
		velocity.y = -4.5
		jump_buffer = 0.0
		ladder_lock = 0.25
		return true
	return false

func climb_rise(climb: Node3D) -> float:
	return (climb.global_basis.y * float(climb.rise)).y

func update_ladder(delta: float, axis: float) -> bool:
	var vertical := Input.get_axis("climb_down", "climb_up")
	if not is_instance_valid(ladder):
		var dash_grab := dash_left > 0.0
		var wall_intent := wall_grace > 0.0 and (axis * wall_side > 0.14 or Input.is_action_just_pressed("jump"))
		var diagonal_air_input := not is_on_floor() and absf(axis) >= 0.50
		if not dash_grab and (wall_intent or diagonal_air_input or wall_launch_lock > 0.0):
			return false
		if absf(vertical) < 0.35 or ladder_lock > 0.0 or contact_recoil > 0.0:
			return false
		for candidate in get_tree().get_nodes_in_group(&"factory_ladder"):
			if not candidate.is_visible_in_tree():
				continue
			var offset: Vector3 = global_position - candidate.global_position
			var minimum := 0.32 if vertical > 0.0 else 0.96
			var rise: float = climb_rise(candidate)
			var has_hatch: bool = candidate.has_meta("hatch_support")
			var hatch_descent := has_hatch and vertical < 0.0
			if hatch_descent:
				var near_top := absf(offset.y - rise - standing_capsule.height * 0.5) < 0.16
				if not near_top or not Input.is_action_just_pressed("climb_down") or absf(axis) > 0.35:
					continue
			var reach := float(candidate.get_meta("hatch_landing_distance")) + 0.13 if hatch_descent else 0.63
			var next_offset_x := offset.x + velocity.x * delta
			var crosses_ladder := dash_grab and minf(offset.x, next_offset_x) < reach and maxf(offset.x, next_offset_x) > -reach
			if (absf(offset.x) < reach or crosses_ladder) and offset.y > minimum and offset.y < rise + (1.05 if hatch_descent else (0.93 if vertical < 0.0 else 0.82)):
				ladder = candidate
				ladder_exit = false
				dash_left = 0.0
				wall_grace = 0.0
				wall_launch_lock = 0.0
				wall_sliding = false
				jump_buffer = 0.0
				cancel_charge()
				break
		if not is_instance_valid(ladder):
			return false
	if Input.is_action_just_pressed("jump"):
		ladder = null
		ladder_exit = false
		ladder_lock = 0.24
		velocity = Vector3(axis * move_speed * 0.52, jump_velocity * 0.78, 0.0)
		return false
	var bottom: float = ladder.global_position.y + standing_capsule.height * 0.5
	var top := bottom + climb_rise(ladder)
	var climb_speed := vertical * 2.85
	var target_x := ladder.global_position.x
	var proposed := global_position.y + climb_speed * delta
	var finished := (vertical > 0.0 and proposed >= top) or (vertical < 0.0 and proposed <= bottom)
	if ladder.has_meta("hatch_support"):
		for deck in get_tree().get_nodes_in_group(&"factory_one_way"):
			remove_collision_exception_with(deck)
		add_collision_exception_with(ladder.get_meta("hatch_support"))
		var top_clearance := top + 0.055
		if ladder_exit or (vertical > 0.0 and proposed >= top):
			# Step onto the solid half only after the capsule has cleared the hatch.
			if global_position.y < top_clearance - 0.005:
				climb_speed = minf(climb_speed, (top_clearance - global_position.y) / delta)
				finished = false
			else:
				ladder_exit = true
				var exit_direction: float = ladder.get_meta("hatch_exit")
				var side_distance: float = ladder.get_meta("hatch_landing_distance")
				target_x = ladder.to_global(Vector3(exit_direction * side_distance, 0, 0)).x
				climb_speed = 0.0
				finished = absf(target_x - global_position.x) < 0.045
		elif vertical < 0.0 and global_position.y >= top - 0.14 and absf(target_x - global_position.x) > 0.10:
			climb_speed = 0.0
	else:
		for deck in get_tree().get_nodes_in_group(&"factory_one_way"):
			add_collision_exception_with(deck)
		if finished:
			var endpoint := top + 0.025 if vertical > 0.0 else bottom + 0.02
			climb_speed = (endpoint - global_position.y) / delta
	set_crouch(false)
	velocity = Vector3(clampf((target_x - global_position.x) * (18.0 if ladder_exit else 14.0), -4.4, 4.4), climb_speed, -global_position.z * 18.0)
	var incoming := velocity
	move_and_slide()
	apply_ceiling_rebound(incoming)
	var hit_ceiling := incoming.y > 0.0 and velocity.y < 0.0
	if finished or hit_ceiling:
		if ladder.has_meta("hatch_support"):
			remove_collision_exception_with(ladder.get_meta("hatch_support"))
		if ladder_exit and not hit_ceiling:
			facing = float(ladder.get_meta("hatch_exit"))
		ladder = null
		ladder_exit = false
		ladder_lock = 0.23
		if not hit_ceiling:
			velocity = Vector3.ZERO
		return true
	play_character_animation("idle")
	if model_root:
		# The rungs sit along the ladder's local -Z; RX-07's front is local +Z.
		var toward_rungs := -ladder.global_basis.z
		var local_forward := global_basis.inverse() * toward_rungs
		var climb_yaw := atan2(local_forward.x, local_forward.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, climb_yaw, 1.0 - exp(-27.0 * delta))
		model_root.rotation.x = lerpf(model_root.rotation.x, 0.0, 0.4)
	if absf(axis) > 0.30:
		facing = signf(axis)
	if buster_pose:
		buster_pose.ladder_direction = facing
		buster_pose.crouched = false
		var aiming := absf(axis) > 0.30 or charge_held or fire_lock > 0.0
		buster_pose.influence = move_toward(buster_pose.influence, 1.0 if aiming else 0.0, 0.30)
	update_charge(delta)
	if is_instance_valid(charge_orb):
		charge_orb.global_position = cannon_muzzle(facing)
	if climb_pose:
		climb_pose.influence = move_toward(climb_pose.influence, 0.0 if ladder_exit else 1.0, delta * 13.0)
		if not ladder_exit:
			climb_pose.cycle = fposmod(climb_pose.cycle + vertical * delta * 16.4, TAU)
		else:
			play_character_animation("walk")
	return true

static func experience_threshold(level: int) -> int:
	var steps := maxi(level - 1, 0)
	return 60 * steps + 20 * steps * steps

static func level_for_experience(total: float) -> int:
	return 1 + floori((sqrt(3600.0 + 80.0 * maxf(total, 0.0)) - 60.0) / 40.0)

func gain_experience(amount: int, earned := true) -> void:
	var previous_level := level_for_experience(experience)
	experience += amount
	var gained_levels := level_for_experience(experience) - previous_level
	if gained_levels > 0:
		max_health += gained_levels * 8.0
		max_energy += gained_levels * 6.0
		health = minf(max_health, health + gained_levels * 20.0)
		health_changed.emit(health, max_health)
		energy_changed.emit(energy, max_energy)
	experience_changed.emit(experience)
	if earned and amount > 0:
		experience_earned.emit(amount)

func collect_salvage(drop: Dictionary) -> void:
	for id in drop:
		salvage[id] = int(salvage.get(id, 0)) + int(drop[id])
	salvage_collected.emit(drop)

func add_life() -> void:
	if lives >= 5:
		return
	lives += 1
	lives_changed.emit(lives)
	life_picked_up.emit()

func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)

func set_crouch(enabled: bool) -> void:
	crouching = enabled
	var slide := dash_left > 0.0
	var should_lower := enabled or slide
	var collider := $CollisionShape3D as CollisionShape3D
	if not should_lower and low_profile:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = standing_capsule
		query.transform = global_transform.translated(Vector3.UP * 0.04)
		query.collision_mask = collision_mask
		query.exclude = [get_rid()] + get_collision_exceptions().map(func(body): return body.get_rid())
		should_lower = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	if should_lower == low_profile:
		return
	low_profile = should_lower
	var capsule := collider.shape as CapsuleShape3D
	capsule.height = 1.05 if low_profile else standing_capsule.height
	collider.position.y = -(standing_capsule.height - capsule.height) * 0.5

func cancel_charge() -> void:
	if not charge_held and not is_instance_valid(charge_orb):
		return
	charge_held = false
	charge_elapsed = 0.0
	RiftAudio.stop_effect(&"buster_charge")
	if is_instance_valid(charge_orb):
		charge_orb.queue_free()
		charge_orb = null

func update_charge(delta: float) -> void:
	if shot_buffer_left > 0.0:
		shot_buffer_left = maxf(0.0, shot_buffer_left - delta)
		if fire_lock <= 0.0 and melee_lock <= 0.0:
			shot_buffer_left = 0.0
			shoot(queued_charged, queued_pose)
	if Input.is_action_just_pressed("shoot"):
		charge_held = true
		charge_elapsed = 0.0
	if not charge_held:
		return
	if not Input.is_action_pressed("shoot"):
		var full := charge_elapsed >= charge_time and energy >= charged_shot_cost()
		var pose_held := is_instance_valid(charge_orb)
		cancel_charge()
		if melee_lock <= 0.0:
			if fire_lock <= 0.0:
				shoot(full, pose_held)
			else:
				shot_buffer_left = 0.12
				queued_charged = full
				queued_pose = pose_held
		return
	charge_elapsed += delta
	if charge_elapsed < 0.18:
		return
	if not is_instance_valid(charge_orb):
		charge_orb = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("ff7a25") if magma_active else (Color(Catalog.weapon(special_weapon).color) if not special_weapon.is_empty() else (Color("a8ff64") if thorn_active else Color("49dfff")))
		sphere.material = glow
		charge_orb.mesh = sphere
		add_child(charge_orb)
		RiftAudio.play_effect(&"buster_charge")
	var progress := clampf(charge_elapsed / charge_time, 0.0, 1.0)
	charge_orb.scale = Vector3.ONE * lerpf(0.10, 0.56, progress)

func cannon_muzzle(aim: float) -> Vector3:
	if is_instance_valid(buster_pose) and buster_pose.influence > 0.0 and buster_pose.muzzle_local != Vector3.ZERO:
		return muzzle_skeleton.to_global(buster_pose.muzzle_local)
	if is_instance_valid(muzzle_skeleton):
		return muzzle_skeleton.to_global(muzzle_skeleton.get_bone_global_pose(muzzle_bone) * muzzle_offset)
	return global_position + Vector3(aim * 0.85, 0.08 if low_profile else 0.42, 0.0)

func level_damage_scale() -> float:
	return 1.0 + (level_for_experience(experience) - 1) * damage_gain_per_level

func buster_power() -> float:
	return base_buster_damage * level_damage_scale() * buster_damage_multiplier

func charged_shot_cost() -> float:
	var base := 36.0 if magma_active else (30.0 if thorn_active or not special_weapon.is_empty() else charge_energy_cost)
	return base * charge_cost_multiplier

func shoot(charged := false, pose_held := false) -> void:
	var magma := magma_active
	var thorn := thorn_active
	var special := special_weapon
	var cost := charged_shot_cost() if charged else (8.0 if magma else (7.0 if thorn or not special.is_empty() else 0.0))
	if energy < cost:
		return
	fire_lock = fire_interval
	if cost > 0.0:
		restore_energy(-cost)
	var aim := facing
	if buster_pose:
		buster_pose.ladder_direction = aim if is_instance_valid(ladder) else 0.0
		buster_pose.crouched = low_profile and is_zero_approx(buster_pose.ladder_direction)
		buster_pose.influence = 1.0 if pose_held else 0.7
	if health <= 0.0:
		return
	if buster_pose:
		buster_pose.influence = 1.0
		await buster_pose.modification_processed
		if health <= 0.0:
			return
	var muzzle := cannon_muzzle(aim)
	if not special.is_empty():
		launch_reward_weapon(muzzle, aim, charged, special)
	elif thorn:
		var count := 5 if charged else 2
		for i in range(count):
			var angle := (i - (count - 1) * 0.5) * (0.18 if charged else 0.14)
			launch_buster(muzzle, Vector3(aim * cos(angle), sin(angle), 0), charged, false, (30.0 if charged else 16.0) * level_damage_scale(), Color("a8ff64"), "thorn_swarm")
	elif magma and charged:
		for spread in [-0.51, 0.0, 0.51]:
			var direction := Vector3(aim * cos(spread), sin(spread), 0.0)
			launch_buster(muzzle, direction, true, true, (62.0 if is_zero_approx(spread) else 45.0) * level_damage_scale())
	else:
		var power := (34.0 * level_damage_scale()) if magma else (buster_power() * (4.0 if charged else 1.0))
		launch_buster(muzzle, Vector3(aim, 0, 0), charged, magma, power)
	RiftAudio.play_effect(&"buster_charged" if charged else &"buster")

func launch_buster(muzzle: Vector3, direction: Vector3, charged: bool, magma: bool, power: float, tint := Color.TRANSPARENT, weapon_id := "") -> void:
	var projectile := RiftProjectile.new()
	projectile.collision_mask = 3 | 8 if magma else 3
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle
	projectile.damage = power * (buster_damage_multiplier if magma or not weapon_id.is_empty() else 1.0)
	projectile.weapon_id = weapon_id
	if charged:
		projectile.speed = 29.0
	if magma:
		projectile.speed = 24.0 if charged else 25.0
		projectile.lifetime = 2.35
		projectile.burn_power = (8.0 if charged else 4.5) * level_damage_scale()
	match weapon_id:
		"frost_lance":
			projectile.speed = 36.0
			projectile.pierces = 2 if charged else 1
		"data_lance":
			projectile.speed = 42.0
			projectile.pierces = 4 if charged else 1
		"gale_edge":
			projectile.speed = 32.0
		"singularity_shot":
			projectile.speed = 17.0
		"scrap_reaver":
			projectile.speed = 20.0
		"core_override":
			projectile.pierces = 2 if charged else 1
	var shot_color := (Color("ffae35") if charged else Color("ff681c")) if magma else (Color("73f4ff") if charged else Color.CYAN)
	if tint.a > 0.0:
		shot_color = tint
	projectile.setup(direction, faction, shot_color, false, charged, magma)
	shot_fired.emit(projectile)

func launch_reward_weapon(muzzle: Vector3, aim: float, charged: bool, id: String) -> void:
	var info := Catalog.weapon(id)
	var count := 1
	var power := 35.0 if not charged else 111.0
	match id:
		"gale_edge":
			count = 5 if charged else 3
			power = 38.0 if charged else 15.0
		"chimera_burst":
			count = 5 if charged else 3
			power = 46.0 if charged else 19.0
		"scrap_reaver":
			power = 136.0 if charged else 47.0
		"core_override":
			count = 5 if charged else 3
			power = 55.0 if charged else 23.0
	for i in count:
		var spread := (i - (count - 1) * 0.5) * (0.18 if charged else 0.13)
		launch_buster(muzzle, Vector3(aim * cos(spread), sin(spread), 0), charged, false, power * level_damage_scale(), Color(info.color), id)

func equipped_suit() -> String:
	return "magma_breaker" if magma_active else ("thorn_swarm" if thorn_active else special_weapon)

func cycle_weapon(step := 1) -> void:
	var equipped := equipped_suit()
	var choices: Array[String] = [""]
	for entry in Catalog.SECTORS:
		var id: String = entry.reward
		if id in run_weapon_ids or (id == "magma_breaker" and magma_unlocked) or (id == "thorn_swarm" and thorn_unlocked):
			choices.append(id)
	if choices.size() > 1:
		equip_sector_weapon(choices[posmod(choices.find(equipped) + step, choices.size())])

func unlock_sector_weapon(id: String) -> void:
	if id not in run_weapon_ids:
		run_weapon_ids.append(id)
	if id == "magma_breaker":
		magma_unlocked = true
	elif id == "thorn_swarm":
		thorn_unlocked = true
	equip_sector_weapon(id)

func equip_sector_weapon(id: String) -> void:
	match id:
		"magma_breaker":
			set_magma_active(true)
		"thorn_swarm":
			set_thorn_active()
		_:
			set_magma_active(false)
			if not id.is_empty() and id in run_weapon_ids:
				var info := Catalog.weapon(id)
				special_weapon = id
				var armor := ShaderMaterial.new()
				armor.shader = preload("res://assets/ui/reward_armor.gdshader")
				armor.set_shader_parameter("suit_color", Color(info.color))
				for mesh in base_suit_meshes:
					mesh.material_overlay = armor
				var light := get_node_or_null("CoreLight") as OmniLight3D
				if light:
					light.light_color = Color(info.color)
				weapon_changed.emit(String(info.reward_name).to_upper())

func unlock_magma() -> void:
	magma_unlocked = true
	set_magma_active(true)

func set_thorn_active() -> void:
	if not thorn_unlocked:
		return
	set_magma_active(false)
	thorn_active = true
	for mesh in base_suit_meshes:
		mesh.hide()
	if is_instance_valid(nature_suit_mesh):
		nature_suit_mesh.show()
	var light := get_node_or_null("CoreLight") as OmniLight3D
	if light:
		light.light_color = Color("a8ff64")
	weapon_changed.emit("THORN SWARM")

func set_magma_active(enabled: bool) -> void:
	if enabled and not magma_unlocked:
		return
	cancel_charge()
	special_weapon = ""
	thorn_active = false
	magma_active = enabled
	for mesh in base_suit_meshes:
		mesh.visible = not enabled
		mesh.material_overlay = null
	if is_instance_valid(fire_suit_mesh):
		fire_suit_mesh.visible = enabled
	if is_instance_valid(nature_suit_mesh):
		nature_suit_mesh.hide()
	var blade_mesh := find_child("EnergyBlade", true, false) as MeshInstance3D
	if blade_mesh:
		blade_mesh.material_override = RiftProjectile.light_paint(Color("ff4e19"), 2.4) if enabled else null
	var light := get_node_or_null("CoreLight") as OmniLight3D
	if light:
		light.light_color = Color("ff8e42") if enabled else Color("3ddcff")
	weapon_changed.emit("MAGMA BREAKER" if enabled else "BUSTER CANNON")

func build_finisher_clip() -> void:
	if not animation_player.has_animation(&"slash") or not animation_player.has_animation_library(&""):
		return
	var library := animation_player.get_animation_library(&"")
	if library.has_animation(&"slash_finisher"):
		return
	var finisher := animation_player.get_animation(&"slash").duplicate() as Animation
	for track in range(finisher.get_track_count()):
		if finisher.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := String(finisher.track_get_path(track))
		if not path.ends_with(":mixamorig_LeftArm") and not path.ends_with(":mixamorig_Spine2"):
			continue
		var accent := 0.28 if path.ends_with(":mixamorig_LeftArm") else 0.12
		for key in range(finisher.track_get_key_count(track)):
			var t := finisher.track_get_key_time(track, key) / finisher.length
			var pose: Quaternion = finisher.track_get_key_value(track, key)
			var offset := sin(t * TAU) * accent
			finisher.track_set_key_value(track, key, (pose * Quaternion(Vector3.BACK, offset)).normalized())
	library.add_animation(&"slash_finisher", finisher)

func update_melee(delta: float) -> void:
	var pressed := Input.is_action_just_pressed("melee") and contact_recoil <= 0.0 and dash_left <= 0.0
	if melee_lock > 0.0:
		if pressed and combo_step + combo_queued < 3:
			combo_queued += 1
		combo_time += delta
		if not combo_hit and combo_time >= combo_hit_at:
			combo_hit = true
			strike_melee()
		melee_lock = maxf(0.0, combo_duration - combo_time)
		if melee_lock <= 0.0:
			if combo_queued > 0 and combo_step < 3:
				combo_queued -= 1
				perform_melee(combo_step + 1)
			else:
				var blade := find_child("SwordPivot", true, false) as Node3D
				if blade:
					blade.hide()
				combo_grace = 0.19 if combo_step < 3 else 0.0
	elif pressed:
		perform_melee(combo_step + 1 if combo_grace > 0.0 and combo_step < 3 else 1)
	else:
		combo_grace = maxf(0.0, combo_grace - delta)

func perform_melee(step := 1) -> void:
	combo_step = step
	combo_duration = SWING_DURATIONS[step - 1]
	combo_time = 0.0
	combo_hit_at = [0.075, 0.077, 0.115][step - 1]
	combo_hit = false
	combo_facing = facing
	combo_hot = magma_active
	melee_lock = combo_duration
	cancel_charge()
	if animation_player and animation_player.has_animation(&"slash"):
		var clip := &"slash_finisher" if step == 3 and animation_player.has_animation(&"slash_finisher") else &"slash"
		var reverse := step == 2
		var speed_scale := animation_player.get_animation(clip).length / combo_duration
		current_animation = String(clip)
		animation_player.speed_scale = 1.0
		animation_player.play(clip, 0.018, -speed_scale if reverse else speed_scale, reverse)
	var sword := find_child("SwordPivot", true, false) as Node3D
	if sword:
		sword.show()
		if not sword_follows_hand:
			sword.rotation_degrees.z = -72.0 * facing if step != 2 else 65.0 * facing
			var slash := create_tween()
			slash.tween_property(sword, "rotation_degrees:z", 62.0 * facing if step != 2 else -71.0 * facing, combo_duration)
		PACK_VFX.blade_trail(sword, combo_duration, saber_tint(), step == 3)
	RiftAudio.play_effect(&"saber_swing")

func saber_tint() -> Color:
	return Color("ff6525") if combo_hot else Color("35beff")

func strike_melee() -> void:
	var reach := melee_range + (0.25 if combo_step == 3 else 0.0)
	var power := buster_power() * melee_multiplier * (1.22 if combo_step == 3 else 1.0)
	for candidate in get_tree().get_nodes_in_group("damageable_enemies"):
		if not is_instance_valid(candidate):
			continue
		var offset: Vector3 = candidate.global_position - global_position
		if absf(offset.z) < 1.4 and absf(offset.y) < 1.7 and absf(offset.x) <= reach and offset.x * combo_facing > -0.05:
			var before: float = candidate.health
			if combo_hot and candidate.has_method("take_fire_damage"):
				candidate.take_fire_damage(power, global_position)
			else:
				candidate.take_damage(power, global_position)
			if candidate.health < before:
				PACK_VFX.saber_hit.call_deferred(get_parent(), candidate.global_position + Vector3(0, 0.34, 0.3), combo_facing, saber_tint())
				if combo_hot and candidate.has_method("ignite"):
					candidate.ignite(3.8 * level_damage_scale(), 2.5)
	melee_performed.emit()

func update_character_visuals() -> void:
	if model_root:
		var visual_facing := signf(velocity.x) if absf(velocity.x) > 0.65 and fire_lock <= 0.0 and melee_lock <= 0.0 else facing
		if is_instance_valid(charge_orb):
			visual_facing = facing
		model_root.rotation.y = PI * 0.5 * (combo_facing if melee_lock > 0.0 else visual_facing)
		model_root.rotation.x = lerpf(model_root.rotation.x, 0.46 if dash_left > 0.0 else (0.13 if wall_sliding else 0.0), 0.48)
	var swinging := melee_lock > 0.0
	if buster_pose:
		buster_pose.ladder_direction = 0.0
		buster_pose.crouched = low_profile
		var aiming := not swinging and (charge_held or is_instance_valid(charge_orb) or fire_lock > 0.0)
		buster_pose.influence = move_toward(buster_pose.influence, 1.0 if aiming else 0.0, 0.30)
	if is_instance_valid(charge_orb):
		charge_orb.global_position = cannon_muzzle(facing)
	if swinging:
		return
	if dash_left > 0.0:
		play_character_animation("dash")
	elif wall_sliding:
		play_character_animation("fall")
		if animation_player:
			animation_player.speed_scale = 0.36
	elif not is_on_floor():
		if current_animation == "fall" and animation_player:
			animation_player.speed_scale = 1.0
		play_character_animation("fall" if velocity.y < -0.6 else "jump")
	elif low_profile:
		play_character_animation("crouch")
	elif landing_left > 0.0:
		play_character_animation("land")
	elif absf(velocity.x) > move_speed * 0.50:
		play_character_animation("run")
	elif absf(velocity.x) > 0.6:
		play_character_animation("walk")
	else:
		play_character_animation("idle")
	if animation_player:
		match current_animation:
			"walk": animation_player.speed_scale = clampf(absf(velocity.x) / 2.0, 0.5, 1.75)
			"run": animation_player.speed_scale = clampf(absf(velocity.x) / 6.4, 0.8, 1.45)

func play_character_animation(animation_name: String, force := false) -> void:
	if not animation_player or not animation_player.has_animation(animation_name):
		return
	if not force and current_animation == animation_name:
		return
	current_animation = animation_name
	animation_player.speed_scale = 1.0
	var speed_scale := 1.0
	var duration := animation_player.get_animation(animation_name).length
	match animation_name:
		"jump": speed_scale = duration / (jump_velocity / gravity)
		"land": speed_scale = duration / 0.21
		"dash": speed_scale = duration / dash_duration
		"shoot": speed_scale = duration / 0.15
		"crouch_shoot": speed_scale = duration / 0.15
		"slash": speed_scale = duration / 0.30
	animation_player.play(animation_name, 0.035 if force or animation_name == "dash" else 0.10, speed_scale)

static func defense_for_experience(total: int) -> float:
	return minf(0.25, (level_for_experience(total) - 1) * 0.02)

func mitigate_damage(amount: float) -> float:
	return amount * (1.0 - defense_for_experience(experience)) * (1.0 - armor_resistance)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	var before := health
	super.take_damage(mitigate_damage(amount), source_position)
	if health < before:
		RiftAudio.play_effect(&"armor_hit")
	if health < before and health > 0.0:
		invulnerable_time = 0.65
		var away := signf(global_position.x - source_position.x)
		velocity.x = (away if away != 0.0 else -facing) * 5.4
		velocity.y = 2.9
		contact_recoil = 0.115
		dash_left = 0.0
		ladder = null
		ladder_lock = 0.24

func take_projectile_damage(amount: float) -> void:
	var before := health
	super.take_damage(mitigate_damage(amount))
	if health < before:
		RiftAudio.play_effect(&"armor_hit")
	if health < before and health > 0.0:
		invulnerable_time = 0.65

