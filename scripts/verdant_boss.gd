extends Combatant

const WASP := preload("res://assets/machine_jungle/enemies/canopy_wasp.tscn")
const XP := preload("res://assets/pickups/xp_orb.tscn")
const TOXIN := Color("d45aff")
const THORN := Color("a4ff5a")
var faction := "enemy"
var active := false
var target: RiftPlayer
var facing := -1.0
var clock := 0.0
var phase_time := 0.8
var attack := -1
var pattern := 0
var summons := 0
var strike_x := 0.0
var strike_dir := -1.0
var warning: Node3D
var hazards: Array[Dictionary] = []
var body_floor := 0.0
var arena_left := 174.2
var arena_right := 203.7
var exposed_left := 0.0
var supply_threshold := 0
var reactor_light: OmniLight3D
@onready var armor: Node3D = $Armor
@onready var vine := armor.find_child("VineArm", true, false) as Node3D
@onready var spore := armor.find_child("SporeBank", true, false) as Node3D
@onready var left := armor.find_child("LegLeft", true, false) as Node3D
@onready var right := armor.find_child("LegRight", true, false) as Node3D

func _ready() -> void:
	max_health *= 1.22
	super._ready()
	body_floor = global_position.y - 1.55
	var level := get_parent().get_parent()
	var gate := level.get_node_or_null("Gate") as Node3D
	var exit := level.get_node_or_null("ExitBarrier") as Node3D
	if gate and exit:
		arena_left = gate.global_position.x + 2.4
		arena_right = exit.global_position.x - 3.9
	died.connect(_break_apart)
	reactor_light = OmniLight3D.new()
	reactor_light.position = Vector3(0, 0.45, 0.5)
	reactor_light.omni_range = 2.6
	reactor_light.light_color = TOXIN
	reactor_light.light_energy = 0.65
	add_child(reactor_light)
	for platform in get_tree().get_nodes_in_group(&"factory_one_way"):
		add_collision_exception_with(platform as PhysicsBody3D)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if active:
		super.take_damage(amount * (1.30 if exposed_left > 0.0 else 1.0), source_position)

func dispatch_canopy_supply() -> void:
	if supply_threshold >= 2 or health / max_health > [0.65, 0.35][supply_threshold]:
		return
	var terrain := get_parent().get_parent().get_node("TERRAIN")
	var perch := terrain.get_node("Canopy6" if supply_threshold == 0 else "RootPerchWestUpper") as Node3D
	var drone := preload("res://scripts/cargo_carrier.gd").new()
	drone.adaptive_supply = true
	drone.supply_target = target
	drone.add_to_group(&"boss_supply")
	drone.position = get_parent_node_3d().to_local(perch.global_position + Vector3.UP * 2.3)
	get_parent().add_child.call_deferred(drone)
	supply_threshold += 1

func _physics_process(delta: float) -> void:
	if not active or health <= 0.0 or not is_instance_valid(target):
		return
	clock += delta
	exposed_left = maxf(0.0, exposed_left - delta)
	reactor_light.light_color = Color("e8ffae") if exposed_left > 0.0 else TOXIN
	reactor_light.light_energy = 2.3 if exposed_left > 0.0 else 0.65
	dispatch_canopy_supply()
	phase_time -= delta
	var dx := target.global_position.x - global_position.x
	var anger := 1.0 - health / max_health
	if attack < 0:
		facing = signf(dx) if absf(dx) > 0.25 else facing
	velocity.x = move_toward(velocity.x, facing * (3.2 + anger * 1.6) if attack < 0 and absf(dx) > 4.1 else 0.0, delta * 21.0)
	velocity.y -= 27.0 * delta
	var previous_x := global_position.x
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_left, arena_right)
	armor.rotation.y = lerp_angle(armor.rotation.y, facing * 1.04, delta * 10.0)
	var stride := sin(clock * 10.0) * minf(absf(global_position.x - previous_x) / delta * 0.12, 0.4)
	left.rotation.x = stride
	right.rotation.x = -stride
	vine.rotation.x = lerpf(vine.rotation.x, -1.05 if attack == 0 else (-0.38 if attack == 2 else 0.0), delta * 10.0)
	spore.rotation.x = lerpf(spore.rotation.x, -0.90 if attack == 1 else 0.0, delta * 8.0)
	for h in hazards.duplicate():
		h["left"] -= delta
		h["tick"] -= delta
		var effect: Node3D = h["node"]
		if h["left"] <= 0.0:
			effect.queue_free()
			hazards.erase(h)
		elif h["tick"] <= 0.0 and absf(target.global_position.x - effect.global_position.x) < float(h.get("radius", 1.65)) and target.global_position.y < body_floor + 2.05:
			h["tick"] = 0.64
			target.take_damage(10.0, effect.global_position)
	if absf(dx) < 1.44 and absf(target.global_position.y - global_position.y) < 1.42:
		target.take_damage(21.0, global_position)
	if phase_time > 0.0:
		return
	if attack >= 0:
		_release()
		attack = -1
		phase_time = 1.5 if exposed_left > 0.0 else lerpf(0.69, 0.30, anger)
		return
	if summons < 3 and anger > 0.25 + 0.25 * summons:
		_summon()
		phase_time = 0.7
		return
	attack = pattern % 4
	pattern += 1
	strike_dir = facing
	strike_x = clampf(target.global_position.x, arena_left - 0.7, arena_right + 0.8)
	phase_time = 1.08 if attack == 3 else lerpf(0.76, 0.51, anger)
	warning = Node3D.new()
	add_child(warning)
	warning.global_position = Vector3(global_position.x + facing * 4.15 if attack == 0 else strike_x, body_floor + 0.09, 0.0)
	var width := (arena_right - arena_left) * 0.55 if attack == 3 else (4.15 if attack == 0 else 1.45)
	if attack == 3:
		warning.global_position.x = (arena_left + arena_right) * 0.5
	var marker := RiftProjectile.part(warning, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(TOXIN if attack in [1, 3] else THORN, 1.3), Vector3.ZERO, Vector3(width, 0.024, 0.59))
	marker.create_tween().tween_property(marker, "scale:z", 0.96, phase_time)
	RiftAudio.play_effect(&"titan_windup")

func _release() -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	var scene := get_parent()
	if attack == 3:
		var flood := Node3D.new()
		add_child(flood)
		flood.top_level = true
		flood.global_position = Vector3((arena_left + arena_right) * 0.5, body_floor + 0.06, 0)
		for i in 14:
			var glow := RiftProjectile.add_glow(flood, TOXIN, 2.7)
			glow.position = Vector3(lerpf(arena_left, arena_right, i / 13.0) - flood.global_position.x, 0.12, 0)
			glow.rotation.x = PI * 0.5
		hazards.append({"node": flood, "left": 3.15, "tick": 0.25, "radius": (arena_right - arena_left) * 0.6})
		exposed_left = 2.1
		return
	if attack == 1:
		var count := 5 if health / max_health < 0.5 else 3
		for i in range(count):
			var shot := RiftProjectile.new()
			shot.collision_layer = 0
			shot.collision_mask = 1
			shot.speed = 12.0 + i * 2.5
			shot.damage = 22.0
			shot.setup(Vector3(strike_dir, (i - (count - 1) * 0.5) * 0.24, 0), "enemy", TOXIN, false, i == count / 2, false, 2, 4)
			scene.add_child(shot)
			shot.global_position = global_position + Vector3(strike_dir * 1.43, 0.52, 0)
		var cloud := Node3D.new()
		add_child(cloud)
		cloud.top_level = true
		cloud.global_position = Vector3(strike_x, body_floor + 0.57, 0)
		for i in range(6):
			RiftProjectile.add_glow(cloud, TOXIN, 1.25 + i * 0.10).position = Vector3((i - 2.5) * 0.50, sin(i * 1.4) * 0.28, -0.23)
		hazards.append({"node": cloud, "left": 2.75, "tick": 0.0})
		return
	var impact := Node3D.new()
	add_child(impact)
	impact.top_level = true
	impact.global_position = Vector3(global_position.x + strike_dir * 4.15 if attack == 0 else strike_x, body_floor + 0.12, 0)
	for i in range(8 if attack == 0 else 5):
		var spike := CylinderMesh.new()
		spike.top_radius = 0.02
		spike.bottom_radius = 0.18
		spike.height = 1.04 + (i % 3) * 0.24
		var piece := RiftProjectile.part(impact, spike, RiftProjectile.light_paint(THORN, 1.45), Vector3((i - (3.5 if attack == 0 else 2.0)) * (0.99 if attack == 0 else 0.54), 0.48, 0), Vector3.ONE)
		piece.rotation.z = -strike_dir * (0.67 if attack == 0 else 0.12)
	impact.scale.y = 0.05
	var tween := impact.create_tween()
	tween.tween_property(impact, "scale:y", 1.0, 0.12)
	var reach := 4.15 if attack == 0 else 1.30
	tween.tween_callback(func():
		if is_instance_valid(target) and absf(target.global_position.x - impact.global_position.x) < reach and target.global_position.y < body_floor + 2.02:
			target.take_damage(33.0, impact.global_position)
	)
	tween.tween_interval(0.38)
	tween.tween_property(impact, "scale:y", 0.05, 0.18)
	tween.tween_callback(impact.queue_free)

func _summon() -> void:
	summons += 1
	var drone := WASP.instantiate()
	drone.position = Vector3(clampf(global_position.x - facing * 4.2, arena_left + 0.8, arena_right - 2.7), body_floor + 3.1, 0)
	drone.target = target
	drone.add_to_group(&"arena_minions")
	get_parent().add_child(drone)

func _break_apart() -> void:
	active = false
	var burst := preload("res://scripts/pit_burst.gd").new()
	var orb := XP.instantiate()
	orb.xp_amount = 70
	orb.large = true
	get_parent().add_child.call_deferred(burst)
	burst.set_deferred("global_position", global_position)
	burst.ignite.call_deferred()
	orb.position = Vector3(global_position.x, body_floor + 0.48, 0.0)
	get_parent().add_child.call_deferred(orb)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	set_deferred("collision_layer", 0)
	queue_free()
