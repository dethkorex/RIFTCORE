class_name WalkerBot
extends Combatant

signal shot_fired(shot: RiftProjectile)

const XP_REWARDS := [12, 16, 26, 18, 16]
const ATTACK_FX := preload("res://scripts/attack_fx.gd")
const Guard := preload("res://scripts/enemy_guard.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const PATROL_SPEEDS := [2.4, 3.6, 1.35, 0.0, 2.5]
const ARMOR := preload("res://assets/enemies/security_finish.gdshader")
const HEIGHT_ATLAS := preload("res://assets/enemies/security_height.png")
const ALBEDO_ATLAS := preload("res://assets/enemies/security_trim.png")
const CERAMIC_TONES := ["5e7898", "66784c", "7299b2", "648892", "a08059", "8399b1", "9ca39c", "837b9e", "ab8553", "8e6089"]
static var armor_finishes: Dictionary = {}
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
@export_range(0.0, 1.0) var drop_chance := 0.018
enum Variant { SCOUT, QUAD, HEAVY, TURRET, FLYER }
@export var variant: Variant
@export_range(0, 10) var detachment_sector := 0
@export_range(-1, 5) var patrol_model := -1
const STANDARD_ROLES := [Variant.SCOUT, Variant.QUAD, Variant.HEAVY, Variant.TURRET, Variant.FLYER, Variant.FLYER]
const STANCE_COLORS := [Color("ffc278"), Color("8deeee"), Color("eadb68"), Color("9bb7ff"), Color("d99bff"), Color("f5e9a6")]
var defense_marker: Guard
var guard_hit_count := 0
var last_guard_state := -1
var maneuver_time := 0.0
var attacks_launched := 0
var has_defense := false
@export var model_override: PackedScene
@export var patrol_left_limit := -100000.0
@export var patrol_right_limit := 100000.0
@export var planted_override := false
var mission_enemy := false
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
var last_support: StaticBody3D
var last_ground_local := Vector3.ZERO
var gait_joints: Array[Node3D] = []
var sector_damage_scale := 1.0
var sector_experience_scale := 1.0
var operator_at_deploy: RiftPlayer
var sector_number := 1
var enemy_level := 1
var level_tag: Label3D
var second_act := false
var difficulty_mode := 0
var shot_windup := 0.0
var locked_aim := Vector3.ZERO
var ledge_probe := PhysicsRayQueryParameters3D.new()
var ledge_target := RID()

func scale_for_sector(sector: int, act: int, health_scale: float, mode: int) -> void:
	sector_number = sector
	difficulty_mode = mode
	enemy_level = Difficulty.recommended_level(sector, mode)
	level_tag.text = "LV. %d" % enemy_level
	second_act = act == 2
	var steps := maxi(0, sector - 1)
	max_health = [40.0, 55.0, 95.0, 60.0, 35.0][variant] * (1.0 + 0.30 * steps) * (1.32 if second_act else 1.0) * health_scale
	if is_in_group(&"spillway_patrol"):
		max_health *= .66
	move_speed = PATROL_SPEEDS[variant] * Difficulty.enemy_speed_scale(sector, mode)
	health = max_health
	var extra_levels := enemy_level - Difficulty.recommended_level(sector, Difficulty.NORMAL)
	sector_damage_scale = (1.0 + 0.20 * steps) * (1.20 if second_act else 1.0) * (1.0 + 0.02 * extra_levels)
	sector_experience_scale = 1.0 + 0.10 * steps
	health_changed.emit(health, max_health)

func damage_model() -> Node3D:
	return robot

func _ready() -> void:
	if patrol_model >= 0:
		variant = STANDARD_ROLES[patrol_model]
	has_defense = variant == Variant.HEAVY or patrol_model == 3
	max_health = [40.0, 55.0, 95.0, 60.0, 35.0][variant]
	move_speed = PATROL_SPEEDS[variant]
	super._ready()
	ledge_probe.exclude = [get_rid()]
	ledge_probe.collision_mask = 1
	patrol_center = global_position.x
	home_height = global_position.y
	build_visuals()
	install_model()
	install_health_bar()
	if has_defense:
		defense_marker = Guard.new()
		add_child(defense_marker)
		defense_marker.install($CollisionShape3D.shape as BoxShape3D)
		refresh_defense()
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

const FOUNDRY_MODELS := [
	preload("res://assets/neon_factory/foundry/scorch_scout.glb"),
	preload("res://assets/neon_factory/foundry/slag_crawler.glb"),
	preload("res://assets/neon_factory/foundry/crucible_guard.glb"),
	preload("res://assets/neon_factory/foundry/flue_sentry.glb"),
	preload("res://assets/neon_factory/foundry/ember_drone.glb"),
]

func install_model() -> void:
	var visual := model_override if model_override else MODELS[variant] as PackedScene
	if detachment_sector == 1:
		visual = FOUNDRY_MODELS[variant]
	elif detachment_sector > 0:
		var model_name := "sector_%02d_%d" % [detachment_sector, variant] if patrol_model < 0 else "patrol_%d" % patrol_model
		var polished := load("res://assets/enemies/detachments/%s.glb" % model_name) as PackedScene
		if polished:
			visual = polished
	robot = visual.instantiate() as Node3D
	add_child(robot)
	robot.scale = Vector3.ONE * 1.16
	if detachment_sector > 1:
		finish_armor()
	var gait_prefix := visual.resource_path.get_file().get_basename() + "_Gait_" if detachment_sector == 1 else "Gait_"
	for index in range(4):
		var limb := robot.find_child(gait_prefix + str(index), true, false) as Node3D
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

func finish_armor() -> void:
	const SECTOR_TRIM := preload("res://assets/enemies/sector_armor_trim.png")
	const TRIM_ROWS := [0, 102, 196, 295, 390, 475, 558, 636, 718, 802, 887]
	var kit := detachment_sector if patrol_model < 0 else 0
	var tone := Color(CERAMIC_TONES[kit - 1]) if kit > 0 else Color("8798ad")
	var atlas := ALBEDO_ATLAS
	if kit > 2:
		var path := "res://assets/campaign/%s/trim.png" % Catalog.info(kit).id
		if ResourceLoader.exists(path):
			atlas = load(path)
	for piece in robot.find_children("*", "MeshInstance3D", true, false):
		for surface in piece.mesh.get_surface_count():
			var material := piece.get_active_material(surface) as StandardMaterial3D
			if not material or material.resource_name not in ["Ceramic", "Cobalt", "Brushed steel", "Service caution"]:
				continue
			var slot := material.resource_name
			var key := "%d:%s" % [kit, slot]
			if not armor_finishes.has(key):
				var finish := ShaderMaterial.new()
				finish.shader = ARMOR
				finish.set_shader_parameter("armor_albedo", atlas)
				finish.set_shader_parameter("trim_height", HEIGHT_ATLAS)
				var coating := tone if slot.contains("Ceramic") else tone.darkened(.27) if slot.contains("Cobalt") else Color("8394aa")
				finish.set_shader_parameter("chassis_coat", coating)
				finish.set_shader_parameter("alloy", .46 if slot.contains("Ceramic") else .62)
				finish.set_shader_parameter("roughness_bias", .43)
				if kit > 0:
					var strip := Vector2(TRIM_ROWS[kit - 1] + 3, TRIM_ROWS[kit] - 3) / 887.0
					finish.set_shader_parameter("sector_trim", SECTOR_TRIM)
					finish.set_shader_parameter("sector_strip", strip)
					finish.set_shader_parameter("sector_mix", .37)
				armor_finishes[key] = finish
			piece.set_surface_override_material(surface, armor_finishes[key])

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
	level_tag = Label3D.new()
	level_tag.name = "EnemyLevel"
	level_tag.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	level_tag.font_size = 38
	level_tag.outline_size = 9
	level_tag.pixel_size = .0036
	level_tag.modulate = Color("e7f7ff")
	level_tag.position = Vector3(0, .13, 0)
	level_tag.text = "LV. %d" % enemy_level
	bar.add_child(level_tag)
	health_changed.connect(func(current: float, maximum: float):
		material.set_shader_parameter("remaining", current / maximum)
	)

func _physics_process(delta: float) -> void:
	contact_lock = maxf(0.0, contact_lock - delta)
	shot_clock -= delta
	attack_time = maxf(0.0, attack_time - delta)
	maneuver_time = maxf(0.0, maneuver_time - delta)
	var tracking := false
	if is_instance_valid(target) and target.health > 0.0:
		var distance := target.global_position.x - global_position.x
		tracking = absf(distance) < (12.0 if second_act else 8.6) and absf(target.global_position.y - global_position.y) < (5.0 if variant == Variant.FLYER else 2.2)
		if tracking and shot_windup <= 0.0 and absf(distance) > 0.05:
			direction = signf(distance)
		if shot_windup > 0.0:
			shot_windup = maxf(shot_windup - delta, 0.0)
			if shot_windup == 0.0 and stagger_left <= 0.0:
				fire_at_player()
		elif stagger_left <= 0.0 and tracking and shot_clock <= 0.0 and absf(distance) > 1.45:
			prepare_shot()
	if not is_instance_valid(target) or target.health <= 0.0:
		shot_windup = 0.0
	if not tracking:
		var left_edge := maxf(patrol_center - 4.0, patrol_left_limit)
		var right_edge := minf(patrol_center + 4.0, patrol_right_limit)
		if direction > 0.0 and global_position.x >= right_edge - .02:
			direction = -1.0
		elif direction < 0.0 and global_position.x <= left_edge + .02:
			direction = 1.0
	var move_factor := 1.0
	if maneuver_time > 0.0:
		move_factor = -0.68 if patrol_model in [0, 5] else 1.78 if variant == Variant.QUAD else 1.0
	velocity.x = 0.0 if planted_override or shot_windup > 0.0 else direction * move_speed * move_factor
	var travel := signf(velocity.x)
	if is_on_floor() and not is_zero_approx(travel) and variant != Variant.FLYER:
		var ledge := global_position + Vector3(travel * 0.75, 0.0, 0.0)
		var target_rid := target.get_rid() if is_instance_valid(target) else RID()
		if target_rid != ledge_target:
			ledge_probe.exclude = [get_rid(), target_rid] if target_rid.is_valid() else [get_rid()]
			ledge_target = target_rid
		ledge_probe.from = ledge
		ledge_probe.to = ledge + Vector3.DOWN * 1.1
		if get_world_3d().direct_space_state.intersect_ray(ledge_probe).is_empty():
			if not tracking:
				direction = -direction
			velocity.x = 0.0
	if stagger_left > 0.0:
		stagger_left = maxf(0.0, stagger_left - delta)
		velocity.x = recoil
		recoil = move_toward(recoil, 0.0, 25.0 * delta)
	if variant == Variant.FLYER:
		hover_clock += delta
		var hover_height := .70 if tracking and patrol_model == 4 else .32
		var evasion := .7 if maneuver_time > 0.0 and (patrol_model == 5 or detachment_sector == 6) else 0.0
		velocity.y = (home_height + sin(hover_clock * 2.6) * hover_height + evasion - global_position.y) * 4.0
	elif not is_on_floor():
		velocity.y -= 28.0 * delta
	velocity.z = -global_position.z * 12.0
	velocity.x = clampf(velocity.x, (patrol_left_limit - global_position.x) / delta, (patrol_right_limit - global_position.x) / delta)
	move_and_slide()
	if robot and not is_zero_approx(direction):
		refresh_defense()
		robot.rotation.y = lerp_angle(robot.rotation.y, direction * PI * 0.5, 1.0 - exp(-14.0 * delta))
		robot.rotation.z = direction * (attack_time * 0.32 if attack_time > 0.0 else clampf(velocity.x * -0.025, -0.09, 0.09))
		present_patrol_motion(get_real_velocity().x if is_on_floor() and stagger_left <= 0.0 else 0.0, delta)
	if global_position.y < lower_death_limit():
		take_damage(max_health)
		return
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		var collider := contact.get_collider()
		var body := collider as RiftPlayer
		if body:
			damage_on_contact(body)
		var support := collider as StaticBody3D
		if support and contact.get_normal().y > 0.62:
			last_support = support
			last_ground_local = support.to_local(contact.get_position() + Vector3.UP * 0.42)

func present_patrol_motion(speed: float, delta: float) -> void:
	if not robot or variant in [Variant.TURRET, Variant.FLYER]:
		return
	var striding := absf(speed) > 0.28
	if striding:
		gait_phase = fposmod(gait_phase + absf(speed) * 4.8 * delta, TAU)
	var blend := 1.0 - exp(-27.0 * delta)
	for i in gait_joints.size():
		var diagonal := (i in [0, 3]) if gait_joints.size() == 4 else i == 0
		var flex := sin(gait_phase + (0.0 if diagonal else PI)) * 0.34 if striding else 0.0
		gait_joints[i].rotation.x = lerpf(gait_joints[i].rotation.x, flex, blend)
	robot.position.y = lerpf(robot.position.y, absf(sin(gait_phase)) * 0.04 if striding else 0.0, blend)

func refresh_defense() -> void:
	if defense_marker:
		defense_marker.update_pose(direction, guard_active())

func guard_active() -> bool:
	return health > 0.0 and has_defense and attack_time <= 0.0 and shot_windup <= 0.0 and stagger_left <= 0.0

func guard_snapshot() -> int:
	var stance := (1 if direction < 0.0 else 2) if guard_active() else 0
	return posmod(guard_hit_count, 64) * 3 + stance

func apply_guard_snapshot(state: int) -> void:
	if not defense_marker:
		return
	var stance := posmod(state, 3)
	var side := -1.0 if stance == 1 else 1.0
	defense_marker.update_pose(side, stance > 0)
	if stance > 0 and last_guard_state >= 0 and state - stance != last_guard_state - posmod(last_guard_state, 3):
		defense_marker.flash_at(defense_marker.global_position)
	last_guard_state = state

func hit_by_projectile(shot: RiftProjectile) -> bool:
	if shot.owner_faction != "player" or not guard_active():
		return false
	if shot.direction.x * direction >= 0.0:
		return false
	if shot.is_charged:
		# Keep the plate down long enough for the player to see the break and follow up.
		shot_windup = 0.0
		stagger_left = 0.8
		refresh_defense()
		return false
	if shot.weapon_id == "data_lance":
		return false
	# A closed front plate blocks basic buster fire. Charged fire, melee,
	# attacking from behind or shooting while the enemy fires defeat it.
	shot_clock = minf(shot_clock, .45)
	guard_hit_count += 1
	defense_marker.update_pose(direction, true)
	defense_marker.flash_at(shot.global_position)
	RiftAudio.play_effect(&"armor_hit")
	return true

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	var previous := health
	super.take_damage(amount, source_position)
	if health > 0.0 and health < previous:
		var side := signf(global_position.x - source_position.x)
		if is_zero_approx(side):
			side = -direction
		stagger_left = maxf(stagger_left, 0.18)
		recoil = 0.0 if variant == Variant.TURRET or planted_override else side * (3.2 if variant == Variant.HEAVY else 5.0)
		refresh_defense()

func damage_on_contact(body: RiftPlayer) -> void:
	if contact_lock > 0.0 or health <= 0.0:
		return
	contact_lock = 0.8
	var contact_damage := 7.0 if is_in_group(&"spillway_patrol") else 14.0
	body.take_damage(contact_damage * sector_damage_scale, global_position)

func prepare_shot() -> void:
	var origin := global_position + Vector3(direction * 0.66, 0.13, 0.0)
	var sight := PhysicsRayQueryParameters3D.create(origin, target.global_position)
	sight.exclude = [get_rid(), target.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
		shot_clock = 0.23
		return
	locked_aim = (target.global_position - origin).normalized()
	shot_windup = Difficulty.windup_time(0.46 if variant in [Variant.HEAVY, Variant.TURRET] else 0.30, difficulty_mode, 0.26)
	refresh_defense()
	shot_clock = (randf_range(1.2, 1.65) if variant == Variant.TURRET else randf_range(1.75, 2.6)) * (0.81 if second_act else 1.0) * Difficulty.boss_recovery_scale(difficulty_mode)
	ATTACK_FX.charge(get_parent(), origin, ATTACK_FX.tint_for(sector_number), shot_windup)

func fire_at_player() -> void:
	attack_time = 0.4
	var origin := global_position + Vector3(direction * 0.76, 0.13, 0.0)
	var tint: Color = ATTACK_FX.tint_for(sector_number) if patrol_model < 0 else STANCE_COLORS[patrol_model]
	ATTACK_FX.muzzle(get_parent(), origin, tint)
	var spread := attack_spread()
	maneuver_time = .42
	attacks_launched += 1
	for angle in spread:
		var shot := RiftProjectile.new()
		get_parent().add_child(shot)
		shot.global_position = origin
		shot.speed = (17.0 if variant == Variant.TURRET else 13.2) * (1.10 if second_act else 1.0)
		if patrol_model == 2 or detachment_sector == 1:
			shot.speed *= 1.14
		elif detachment_sector == 3 or patrol_model == 5:
			shot.speed *= .82
		shot.damage = (15.0 if variant == Variant.HEAVY else 9.0) * sector_damage_scale
		if is_in_group(&"spillway_patrol"):
			shot.damage *= .55
		var role: int = variant if patrol_model < 0 else mini(patrol_model+1, 7)
		var style := sector_number if patrol_model < 0 else 0
		shot.setup(locked_aim.rotated(Vector3.BACK, float(angle)), faction, tint, false, variant == Variant.HEAVY, false, style, role)
		shot_fired.emit(shot)

func attack_spread() -> Array:
	if patrol_model >= 0:
		match patrol_model:
			0: return [0.0]
			1: return [-.12, .12]
			2: return [0.0, .32] if second_act else [0.0]
			3: return [-.19, 0.0, .19]
			4: return [-.20, -.06]
			5: return [-.27, .27, 0.0]
	match detachment_sector:
		1: return [0.0] if attacks_launched % 2 == 0 else [-.18, .18]
		2: return [.16, .30] if variant == Variant.FLYER else [0.0, .30]
		3: return [-.22, .22] if variant == Variant.TURRET else [.06]
		4: return [0.15, .37]
		5: return [0.24 if attacks_launched % 2 == 0 else -.24, 0.0]
		6: return [-.25, -.10] if variant == Variant.FLYER else [0.0, .23]
		7: return [-.25, 0.0, .25]
		8: return [.12, -.12]
		9: return [0.0, .14, -.14] if variant == Variant.HEAVY else [0.0]
		10: return [-.32, 0.0, .32]
	if second_act and variant in [Variant.TURRET, Variant.FLYER]:
		return [-.16, .16] if variant == Variant.FLYER else [-.21, 0.0, .21]
	return [0.0]

func spawn_pickup(scene: PackedScene, at: Vector3, temporary: bool, anchor: StaticBody3D = null) -> void:
	var pickup := scene.instantiate() as Area3D
	pickup.expires = temporary
	var host := anchor if is_instance_valid(anchor) else get_parent_node_3d()
	pickup.position = host.to_local(at)
	host.add_child.call_deferred(pickup)

func lower_death_limit() -> float:
	if has_meta("pit_floor_y"):
		return float(get_meta("pit_floor_y"))
	var stage := get_parent_node_3d().get_parent_node_3d()
	return float(stage.get_meta("pit_floor_y", -3.4)) - 0.6 if stage else -4.0

func find_drop_anchor() -> Dictionary:
	if global_position.y < lower_death_limit() + 1.2 and is_instance_valid(last_support):
		return {"position": last_support.to_global(last_ground_local), "body": last_support}
	var origin := global_position
	var casts: Array[Vector3] = []
	for distance in [0.0, -1.15, 1.15, -2.30, 2.30, -3.45, 3.45]:
		casts.append(Vector3(origin.x + distance, origin.y + 0.30, 0.0))
	casts.append(Vector3(patrol_center, home_height + 0.85, 0.0))
	var exclusions: Array[RID] = [get_rid()]
	if is_instance_valid(target):
		exclusions.append(target.get_rid())
	for at in casts:
		var ray := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 13.0)
		ray.exclude = exclusions
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is StaticBody3D and hit.normal.y >= 0.55:
			return {"position": hit.position + Vector3.UP * 0.42, "body": hit.collider}
	if is_instance_valid(last_support):
		return {"position": last_support.to_global(last_ground_local), "body": last_support}
	if is_instance_valid(target):
		var fallback := PhysicsRayQueryParameters3D.create(target.global_position, target.global_position + Vector3.DOWN * 15.0)
		fallback.exclude = exclusions
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(fallback)
		if not floor_hit.is_empty() and floor_hit.collider is StaticBody3D:
			return {"position": floor_hit.position + Vector3.UP * 0.42, "body": floor_hit.collider}
	return {"position": Vector3(patrol_center, home_height - 0.18, 0), "body": null}

func experience_reward() -> int:
	return roundi(XP_REWARDS[variant] * sector_experience_scale)

func roll_field_drop() -> PackedScene:
	if global_position.y <= lower_death_limit() + 1.0 or randf() >= drop_chance:
		return null
	var pool := LARGE_DROPS if randf() < 0.16 else SMALL_DROPS
	return pool.pick_random()

func _on_died() -> void:
	if not mission_enemy:
		var recipient := operator_at_deploy if is_instance_valid(operator_at_deploy) else target
		if is_instance_valid(recipient) and recipient.health > 0.0:
			recipient.gain_experience(roundi(experience_reward() * recipient.xp_gain_multiplier))
		var reward := roll_field_drop()
		if reward:
			var anchor := find_drop_anchor()
			spawn_pickup(reward, anchor.position + Vector3.FORWARD * 0.25, true, anchor.body)
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	if global_position.y <= lower_death_limit() + 1.0:
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
