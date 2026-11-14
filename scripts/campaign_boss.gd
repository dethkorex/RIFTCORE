extends Combatant

const ATTACK_FX := preload("res://scripts/attack_fx.gd")

@export_range(3, 10) var sector_number := 3
@export var accent := Color.CYAN
@export var minion_scene: PackedScene
const ZONE := preload("res://scripts/biome_zone.gd")
const CARGO := preload("res://scripts/cargo_carrier.gd")
const XP := preload("res://assets/pickups/xp_orb.tscn")
const PATTERNS := {
	3: ["ice_wall", "shards", "charge", "ice_burst"],
	4: ["tentacles", "surge", "flood", "arc_fan"],
	5: ["burrow", "sandstorm", "decoy", "sweep"],
	6: ["dive", "gust", "missiles", "tornado"],
	7: ["mutate", "lunge", "hazard_rain", "clone"],
	8: ["gravity", "orbital_beam", "light_fan", "well"],
	9: ["debris", "magnet", "repair", "slam"],
	10: ["beam", "blink", "borrow", "fracture"]
}
var target: RiftPlayer
var faction := "enemy"
var active := false
var facing := -1.0
var attack := ""
var attack_index := 0
var cooldown := 0.94
var clock := 0.0
var strike_x := 0.0
var strike_dir := -1.0
var floor_y := 0.0
var left := 0.0
var right := 0.0
var sprint_left := 0.0
var rebuild_left := 0.0
var recovery := 0.0
var supply_index := 0
var contact_left := 0.0
var warning: Node3D
var hazards: Array[Dictionary] = []
var joints: Dictionary = {}
var lamp: OmniLight3D
@onready var armor: Node3D = $Armor

func _ready() -> void:
	max_health *= 1.24
	super._ready()
	floor_y = global_position.y - 1.55
	var level := get_parent().get_parent()
	left = level.get_node("Gate").global_position.x + 2.3
	right = level.get_node("ExitBarrier").global_position.x - 2.7
	for limb in ["ArmLeft", "ArmRight", "LegLeft", "LegRight", "Rotor"]:
		var part := armor.find_child(limb, true, false) as Node3D
		if part:
			joints[limb] = part
	for deck in get_tree().get_nodes_in_group("factory_one_way"):
		add_collision_exception_with(deck)
	lamp = OmniLight3D.new()
	lamp.light_color = accent
	lamp.omni_range = 3.1
	lamp.position = Vector3(0, 0.62, 0.65)
	add_child(lamp)
	died.connect(_explode)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if not active:
		return
	if rebuild_left > 0.0 and amount >= 55.0:
		rebuild_left = 0.0
		recovery = 1.0
	super.take_damage(amount * (1.24 if recovery > 0.0 else 1.0), source_position)

func damage_on_contact(player: RiftPlayer) -> void:
	if not active or contact_left > 0.0:
		return
	contact_left = 0.65
	player.take_damage(22.0 + sector_number * 1.9, global_position)

func phase() -> int:
	return 2 if health < max_health * 0.30 else (1 if health < max_health * 0.66 else 0)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or target.health <= 0.0 or health <= 0.0:
		return
	clock += delta
	cooldown -= delta
	sprint_left = maxf(0.0, sprint_left - delta)
	contact_left = maxf(0.0, contact_left - delta)
	recovery = maxf(0.0, recovery - delta)
	var stage := phase()
	var dx := target.global_position.x - global_position.x
	if attack.is_empty() and sprint_left <= 0.0:
		if absf(dx) > 0.25:
			facing = signf(dx)
	var speed := (2.6 + stage * 0.75) * (0.7 if sector_number == 4 else 1.0)
	var walk := facing * speed if attack.is_empty() and absf(dx) > 4.3 else 0.0
	velocity.x = strike_dir * (18.0 + stage * 3.4) if sprint_left > 0.0 else move_toward(velocity.x, walk, delta * 22.0)
	velocity.y -= 29.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, left, right)
	armor.rotation.y = lerp_angle(armor.rotation.y, facing * 1.03, 1.0 - exp(-12.0 * delta))
	var stepping := sin(clock * 9.5) * minf(absf(velocity.x) * 0.11, 0.39)
	for label in joints:
		var limb: Node3D = joints[label]
		match label:
			"LegLeft": limb.rotation.x = stepping
			"LegRight": limb.rotation.x = -stepping
			"Rotor": limb.rotate_z(delta * (1.0 + stage * 0.64))
			_: limb.rotation.x = lerpf(limb.rotation.x, -0.86 if not attack.is_empty() else 0.0, delta * 8.0)
	if sector_number in [5, 6, 8, 10]:
		armor.position.y = -1.55 + sin(clock * 3.3) * 0.13
	lamp.light_energy = 2.4 if recovery > 0.0 else (1.55 if not attack.is_empty() else 0.54)
	if rebuild_left > 0.0:
		rebuild_left -= delta
		health = minf(max_health, health + delta * 84.0)
		health_changed.emit(health, max_health)
	update_fields(delta)
	check_supply()
	if cooldown > 0.0 or sprint_left > 0.0:
		return
	if attack.is_empty():
		windup()
	else:
		if is_instance_valid(warning):
			warning.queue_free()
		execute(attack)
		attack = ""
		cooldown = (0.82 if stage == 0 else (0.61 if stage == 1 else 0.44)) + recovery

func windup() -> void:
	var pattern: Array = PATTERNS[sector_number]
	attack = pattern[attack_index % pattern.size()]
	if phase() > 0 and attack_index % (4 if phase() == 1 else 3) == 2:
		attack = "crossfire"
	attack_index += 1
	strike_x = clampf(target.global_position.x, left - 0.8, right + 0.8)
	strike_dir = signf(strike_x - global_position.x) if absf(strike_x - global_position.x) > 0.25 else facing
	facing = strike_dir
	cooldown = maxf(0.49, 0.84 - phase() * 0.11)
	warning = Node3D.new()
	add_child(warning)
	warning.top_level = true
	var broad := attack in ["flood", "gravity", "sweep", "beam", "fracture", "gust", "crossfire"]
	var dash := attack in ["charge", "lunge", "dive", "tentacles"]
	var width := (right - left) * 0.51 if broad else (6.0 if dash else 1.7)
	var x := (left + right) * 0.5 if broad else (global_position.x + strike_dir * 5.5 if dash else strike_x)
	warning.global_position = Vector3(x, floor_y + 0.075, 0)
	ATTACK_FX.telegraph(warning, width * 2.0, accent, cooldown)
	if attack == "crossfire":
		var signal_light := Label3D.new()
		signal_light.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
		signal_light.text = "CROSSFIRE"
		signal_light.pixel_size = 0.0054
		signal_light.modulate = accent.lerp(Color.WHITE, 0.35)
		signal_light.position = Vector3(0.0, 2.1, 0.22)
		warning.add_child(signal_light)
	RiftAudio.play_effect(&"titan_windup")

func execute(move: String) -> void:
	var power := 19.0 + sector_number * 2.05 + phase() * 5.0
	match move:
		"crossfire":
			fan(4 + phase(), 0.22, power * 0.84, 18.5)
			var wall := right if strike_dir > 0.0 else left
			fire(Vector3(wall, floor_y + 0.57, 0), Vector3(-strike_dir, 0, 0), power * 0.86, 21.0, true)
		"ice_wall":
			ice_wall(clampf(strike_x - strike_dir * 2.3, left, right))
			fan(3, 0.18, power, 14.0)
		"shards", "hazard_rain", "debris":
			for i in range(5 + phase()):
				var x := clampf(strike_x + (i - 2) * 1.65, left - 0.6, right + 0.6)
				fire(Vector3(x, floor_y + 7.1 + i * 0.27, 0), Vector3.DOWN, power, 12.0 + i, i % 3 == 0)
		"charge", "lunge", "dive":
			sprint_left = 0.62 if move == "dive" else 0.52
			if move != "charge":
				fan(3, 0.22, power * 0.78, 15.0)
		"ice_burst", "slam":
			field(strike_x, floor_y + 0.64, 2.05 + phase() * 0.6, 1.0, 0.7, power * 1.28)
			ground_wave(power)
			recovery = 0.72
		"tentacles":
			field(global_position.x + strike_dir * 4.1, floor_y + 0.75, 4.6, 1.01, 0.49, power * 1.16)
		"surge":
			ground_wave(power * 0.9)
			fan(2 + phase(), 0.15, power * 0.75, 19.0)
		"flood":
			var center := (left + right) * 0.5
			field(center, floor_y + 0.96, (right - left) * 0.58, 1.15, 3.0, power * 0.68)
			recovery = 0.85
		"arc_fan", "light_fan", "missiles":
			fan(4 + phase(), 0.17 if move == "missiles" else 0.25, power, 13.5 + phase() * 2.8)
		"burrow", "blink":
			global_position.x = clampf(strike_x + strike_dir * 3.1, left, right)
			facing = -strike_dir
			strike_dir = facing
			field(strike_x, floor_y + 0.9, 1.85, 1.20, 0.58, power)
			fan(3 + phase(), 0.21, power, 17.0)
		"sandstorm", "tornado":
			field(strike_x - strike_dir * 2.3, floor_y + 1.33, 1.35 + phase() * 0.22, 2.2, 2.8, power * 0.69, strike_dir * 3.1)
		"decoy":
			make_decoy(clampf(strike_x - 5.8, left, right))
			make_decoy(clampf(strike_x + 5.8, left, right))
			fan(3, 0.28, power, 17.0)
		"sweep", "beam":
			field((left + right) * 0.5, floor_y + 1.26, (right - left) * 0.61, 0.23, 0.55, power * 1.10, 0.0, true)
			if phase() >= 1:
				field((left + right) * 0.5, floor_y + 3.55, (right - left) * 0.59, 0.26, 0.54, power)
		"gust", "magnet", "gravity", "well":
			field(strike_x, floor_y + 1.0, 4.1 + phase() * 0.6, 2.7, 2.4, power * 0.45, 0.0, false, -1.0 if move in ["magnet", "gravity", "well"] else 1.0)
			fan(3, 0.28, power, 17.0)
		"mutate", "clone":
			summon()
			fan(5, 0.19, power * 0.92, 16.0)
		"orbital_beam":
			field(strike_x, floor_y + 3.0, 1.38, 4.3, 0.70, power * 1.18)
			if phase() >= 1:
				field(clampf(strike_x + 4.6, left, right), floor_y + 3.0, 1.23, 4.3, 0.75, power)
		"repair":
			rebuild_left = 1.75
			recovery = 1.6
			summon()
		"borrow":
			execute(["ice_wall", "arc_fan", "well"][phase()])
		"fracture":
			for i in range(3 + phase()):
				field(clampf(strike_x + (i - 1.6) * 4.4, left, right), floor_y + 1.2, 1.30, 2.6, 1.7, power * 0.75)
			recovery = 0.85

func fire(at: Vector3, aim: Vector3, power: float, speed: float, heavy := false) -> void:
	var shot := RiftProjectile.new()
	shot.collision_layer = 0
	shot.collision_mask = 1
	shot.damage = power
	shot.speed = speed
	shot.lifetime = 3.2
	shot.setup(aim, faction, ATTACK_FX.tint_for(sector_number), false, heavy, false, sector_number, 4)
	get_parent().add_child(shot)
	shot.global_position = at
	if heavy:
		ATTACK_FX.muzzle(get_parent(), at, accent, 0.78)

func fan(count: int, spread: float, power: float, speed: float) -> void:
	for i in count:
		var y := (i - (count - 1) * 0.5) * spread
		fire(global_position + Vector3(strike_dir * 1.24, 0.49, 0), Vector3(strike_dir, y, 0), power, speed, i == floori(count * 0.5))

func ground_wave(power: float) -> void:
	for side in [-1.0, 1.0]:
		fire(Vector3(global_position.x + side * 1.35, floor_y + 0.57, 0), Vector3(side, 0, 0), power, 17.0, true)

func field(x: float, y: float, radius: float, height: float, lifetime: float, power: float, drift := 0.0, crouchable := false, pull := 0.0) -> void:
	var fx := Node3D.new()
	add_child(fx)
	fx.top_level = true
	fx.global_position = Vector3(x, y, 0)
	ATTACK_FX.field(fx, sector_number, radius, height, lifetime, attack)
	hazards.append({"fx": fx, "left": lifetime, "tick": 0.14, "radius": radius, "height": height, "damage": power, "drift": drift, "crouchable": crouchable, "pull": pull})

func update_fields(delta: float) -> void:
	for data in hazards.duplicate():
		data.left -= delta
		data.tick -= delta
		var fx: Node3D = data.fx
		if data.left <= 0.0:
			fx.queue_free()
			hazards.erase(data)
			continue
		fx.global_position.x += float(data.drift) * delta
		var diff := target.global_position - fx.global_position
		if absf(diff.x) > data.radius or absf(diff.y) > data.height:
			continue
		if data.pull != 0.0:
			target.velocity.x += signf(diff.x) * float(data.pull) * 25.0 * delta
		if data.tick <= 0.0 and (not data.crouchable or not target.low_profile):
			target.take_projectile_damage(data.damage)
			data.tick = 0.66

func ice_wall(x: float) -> void:
	var obstacle := StaticBody3D.new()
	add_child(obstacle)
	obstacle.top_level = true
	obstacle.global_position = Vector3(x, floor_y + 1.32, 0)
	obstacle.add_to_group("boss_hazard")
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.44, 2.64, 1.91)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	obstacle.add_child(collision)
	var armor_mesh := BoxMesh.new()
	armor_mesh.size = shape.size
	RiftProjectile.part(obstacle, armor_mesh, RiftProjectile.light_paint(accent.darkened(0.2), 0.76), Vector3.ZERO, Vector3.ONE)
	add_collision_exception_with(obstacle)
	obstacle.create_tween().tween_interval(3.1).finished.connect(obstacle.queue_free)

func make_decoy(x: float) -> void:
	var ghost := armor.duplicate() as Node3D
	add_child(ghost)
	ghost.top_level = true
	ghost.global_position = Vector3(x, floor_y, -0.11)
	for piece in ghost.find_children("*", "MeshInstance3D", true, false):
		piece.transparency = 0.46
	ghost.create_tween().tween_interval(1.9).finished.connect(ghost.queue_free)
	fire(Vector3(x, floor_y + 1.52, 0), Vector3(signf(strike_x - x), 0, 0), 17.0 + sector_number, 14.5)

func summon() -> void:
	if minion_scene == null or get_tree().get_nodes_in_group("arena_minions").size() >= 2:
		return
	var add := minion_scene.instantiate()
	add.target = target
	add.position = Vector3(clampf(global_position.x - facing * 5.2, left, right), floor_y + 2.5, 0)
	add.add_to_group("arena_minions")
	get_parent().add_child(add)
	add.scale_for_sector(sector_number)

func check_supply() -> void:
	if supply_index >= 2 or health / max_health > [0.66, 0.32][supply_index]:
		return
	var platform := get_parent().get_parent().get_node("TERRAIN/ArenaPerch%d" % supply_index) as Node3D
	var cargo := CARGO.new()
	cargo.adaptive_supply = true
	cargo.supply_target = target
	cargo.add_to_group("boss_supply")
	var landing: Vector3 = platform.supply_landing_point() if platform.has_method("supply_landing_point") else platform.global_position
	cargo.position = get_parent_node_3d().to_local(landing + Vector3.UP * 2.3)
	get_parent().add_child.call_deferred(cargo)
	supply_index += 1

func _explode() -> void:
	active = false
	var orb := XP.instantiate()
	orb.xp_amount = 68 + sector_number * 12
	orb.large = true
	orb.position = Vector3(global_position.x, floor_y + 0.42, 0)
	get_parent().add_child.call_deferred(orb)
	var blast := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child.call_deferred(blast)
	blast.set_deferred("global_position", global_position)
	blast.ignite.call_deferred(accent)
	get_tree().create_timer(0.48, false).timeout.connect(blast.queue_free)
	set_deferred("collision_layer", 0)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	queue_free()
