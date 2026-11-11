extends Combatant

const CARRIER := preload("res://scripts/cargo_carrier.gd")
const TRAP_VFX := preload("res://scripts/factory_trap_vfx.gd")
const ORANGE := Color("ff750a")
const CROSS_REACH := [0.247, 0.230, 0.419, 0.547, 0.547, 0.545, 0.515, 0.448, 0.364, 0.283, 0.247]
var faction := "enemy"
var target: RiftPlayer
var active := false
var cooldown := 1.05
var attack_number := 0
var contact_lock := 0.0
var facing := -1.0
var arena_left := -100.0
var arena_right := 100.0
var motion_lock := 0.0
var stride := 0.0
var charge_stage := 0
var charge_left := 0.0
var charge_hit := false
var charge_range := 0.0
var charge_marker: MeshInstance3D
var trace_clock := 0.0
var marker_pulse: Tween
var floor_height := 0.0
var cargo_index := 0
@onready var armor: Node3D = $Armor

@onready var drill := find_child("DrillModule", true, false) as Node3D
@onready var rotor := find_child("DrillRotor", true, false) as Node3D
@onready var leg_left := find_child("LegLeft", true, false) as Node3D
@onready var leg_right := find_child("LegRight", true, false) as Node3D
@onready var fist := find_child("FistModule", true, false) as Node3D

func _ready() -> void:
	max_health *= 1.23
	super._ready()
	died.connect(die)
	health_changed.connect(check_supplies)
	floor_height = global_position.y - 1.45
	var level := get_parent().get_parent()
	if level != null:
		var entry := level.get_node_or_null("Gate") as Node3D
		var exit := level.get_node_or_null("ExitBarrier") as Node3D
		if entry and exit:
			arena_left = entry.global_position.x + 2.35
			arena_right = exit.global_position.x - 2.0
	armor.rotation.y = -1.0
	for catwalk in get_tree().get_nodes_in_group(&"factory_one_way"):
		add_collision_exception_with(catwalk)

func check_supplies(current: float, maximum: float) -> void:
	if current <= 0.0 or not active or not is_instance_valid(target):
		return
	var thresholds := [0.75, 0.5, 0.25]
	while cargo_index < thresholds.size() and current / maximum <= thresholds[cargo_index]:
		drop_supply.call_deferred(cargo_index)
		cargo_index += 1

func drop_supply(index: int) -> void:
	if not active or health <= 0.0:
		return
	var platform_name: String = ["ArenaCatwalkWest", "ArenaCatwalkCenter", "ArenaCatwalkEast"][index]
	var deck := get_parent().get_parent().get_node_or_null("TERRAIN/" + platform_name) as Node3D
	if not deck:
		return
	var carrier := CARRIER.new()
	carrier.position = get_parent_node_3d().to_local(deck.global_position + Vector3.UP * 2.3)
	carrier.adaptive_supply = true
	carrier.supply_target = target
	carrier.add_to_group(&"boss_supply")
	get_parent().add_child(carrier)

func die() -> void:
	active = false
	if charge_stage == 1:
		RiftAudio.stop_effect(&"titan_windup")
	var orb := preload("res://assets/pickups/xp_orb.tscn").instantiate() as Area3D
	orb.large = true
	orb.get_node("Visual").scale *= 1.55
	orb.position = position - Vector3.UP
	get_parent().add_child.call_deferred(orb)
	set_deferred("collision_layer", 0)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	var burst := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.scale = Vector3.ONE * 1.65
	burst.ignite()
	get_tree().create_timer(0.45, false).timeout.connect(burst.queue_free)
	queue_free()

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or target.health <= 0.0 or health <= 0.0:
		return
	var offset := target.global_position.x - global_position.x
	contact_lock = maxf(0.0, contact_lock - delta)
	if rotor:
		rotor.rotate_y(delta * (36.0 if charge_stage == 2 else (17.0 if charge_stage == 1 else 3.5)))
	if charge_stage != 0:
		update_drill_charge(delta)
		return
	motion_lock = maxf(0.0, motion_lock - delta)
	if motion_lock <= 0.0 and absf(offset) > 0.18:
		facing = signf(offset)
	point_armor(delta)
	cooldown -= delta
	var phase := phase_index()
	var walk := 0.0
	if motion_lock <= 0.0:
		if absf(offset) > 5.8:
			walk = facing * (2.25 + phase * 0.43)
		elif absf(offset) < 2.85:
			walk = -facing * 1.55
	move_in_arena(walk, delta)
	if cooldown > 0.0 or motion_lock > 0.0:
		return
	attack_number += 1
	cooldown = [1.46, 1.20, 0.98][phase]
	match attack_number % 5:
		1:
			motion_lock = 0.98
			drill_volley()
		2:
			motion_lock = 0.97
			ground_punch()
		3, 0:
			begin_drill_charge()
		4:
			motion_lock = 0.70
			floor_cascade(phase)

func phase_index() -> int:
	return 2 if health < max_health * 0.38 else (1 if health < max_health * 0.7 else 0)

func point_armor(delta: float) -> void:
	# Positive local Z is the face. Keep a slight three-quarter presentation.
	armor.rotation.y = lerp_angle(armor.rotation.y, facing * 1.18, 1.0 - exp(-delta * 15.0))

func move_in_arena(speed: float, delta: float) -> void:
	velocity.x = clampf(speed, (arena_left - global_position.x) / delta, (arena_right - global_position.x) / delta)
	velocity.y = maxf(-14.0, velocity.y - 30.0 * delta)
	velocity.z = -global_position.z * 14.0
	move_and_slide()
	stride += absf(velocity.x) * delta * 3.9
	armor.position.y = lerpf(armor.position.y, sin(stride) * 0.044 if absf(velocity.x) > 0.2 else 0.0, 0.4)
	var swing := sin(stride) * 0.14 if absf(velocity.x) > 0.2 else 0.0
	if leg_left and leg_right:
		leg_left.rotation.x = lerpf(leg_left.rotation.x, swing, 0.41)
		leg_right.rotation.x = lerpf(leg_right.rotation.x, -swing, 0.41)
	for i in range(get_slide_collision_count()):
		var player_body := get_slide_collision(i).get_collider() as RiftPlayer
		if player_body:
			damage_on_contact(player_body)

func begin_drill_charge() -> void:
	charge_stage = 1
	charge_left = 0.69 - phase_index() * 0.075
	charge_hit = false
	trace_clock = 0.0
	var room := arena_right - global_position.x if facing > 0.0 else global_position.x - arena_left
	charge_range = clampf(room, 0.0, 11.5 + phase_index() * 1.35)
	var center := global_position.x + facing * charge_range * 0.5
	charge_marker = make_effect_box(Vector3(center, floor_height + 0.032, 0), Vector3(maxf(charge_range, 0.2), 0.028, 0.48))
	marker_pulse = create_tween().set_loops()
	marker_pulse.tween_property(charge_marker, "scale:z", 1.7, 0.11)
	marker_pulse.tween_property(charge_marker, "scale:z", 0.85, 0.11)
	RiftAudio.play_effect(&"titan_windup")

func update_drill_charge(delta: float) -> void:
	point_armor(delta)
	charge_left -= delta
	match charge_stage:
		1:
			drill.rotation.x = move_toward(drill.rotation.x, -1.58, delta * 6.7)
			armor.rotation.x = move_toward(armor.rotation.x, -0.08, delta * 1.4)
			move_in_arena(0.0, delta)
			if charge_left <= 0.0:
				if is_instance_valid(charge_marker):
					marker_pulse.kill()
					charge_marker.queue_free()
				charge_stage = 2
				charge_left = 0.65
				RiftAudio.stop_effect(&"titan_windup")
				RiftAudio.play_effect(&"dash")
		2:
			armor.rotation.x = move_toward(armor.rotation.x, 0.16, delta * 2.5)
			var speed := 17.5 + phase_index() * 2.2
			var before := global_position.x
			move_in_arena(facing * speed, delta)
			var traveled := absf(global_position.x - before)
			charge_range -= traveled
			trace_clock -= delta
			if trace_clock <= 0.0:
				trace_clock = 0.07
				var spark := make_effect_box(Vector3(global_position.x - facing * 1.0, floor_height + 0.13, 0.28), Vector3(1.6, 0.12, 0.44))
				var fade := create_tween()
				fade.tween_property(spark, "scale", Vector3.ONE * 0.01, 0.2)
				fade.tween_callback(spark.queue_free)
			var ahead := (target.global_position.x - global_position.x) * facing
			if ahead >= -0.6 and ahead < 2.1 and target.global_position.y < floor_height + 1.87:
				apply_charge_hit(target)
			if charge_left <= 0.0 or charge_range <= 0.0 or traveled < delta:
				charge_stage = 3
				charge_left = 0.49
				var impact := make_effect_box(Vector3(global_position.x + facing, floor_height + 0.12, 0), Vector3(2.5, 0.19, 1.25))
				var fade := create_tween()
				fade.tween_property(impact, "scale", Vector3.ONE * 0.01, 0.25)
				fade.tween_callback(impact.queue_free)
		3:
			move_in_arena(0.0, delta)
			drill.rotation.x = move_toward(drill.rotation.x, 0.0, delta * 4.1)
			armor.rotation.x = move_toward(armor.rotation.x, 0.0, delta * 1.2)
			if charge_left <= 0.0:
				charge_stage = 0
				cooldown = 0.98 if phase_index() == 0 else 0.72

func apply_charge_hit(player_body: RiftPlayer) -> void:
	if charge_hit:
		return
	charge_hit = true
	contact_lock = 0.8
	player_body.take_damage(30.0 + phase_index() * 4.0, global_position)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if active:
		super.take_damage(amount, source_position)

func floor_cascade(phase: int) -> void:
	var base := floor_height
	var center := clampf(target.global_position.x, arena_left, arena_right)
	for i in range(3 + phase):
		var x := clampf(center + facing * (i - 1) * 2.25, arena_left, arena_right)
		var marker := make_spike_warning(Vector3(x, base + 0.043, 0), 1.52)
		var warning := create_tween()
		warning.tween_interval(0.57 + i * 0.13)
		warning.tween_callback(raise_spike.bind(x, base, marker))

func damage_on_contact(body: RiftPlayer) -> void:
	if charge_stage == 2:
		if body.global_position.y < floor_height + 1.87:
			apply_charge_hit(body)
		return
	if not active or contact_lock > 0.0 or health <= 0.0:
		return
	contact_lock = 0.8
	body.take_damage(16.0, global_position)

func drill_volley() -> void:
	var direction := facing
	var windup := create_tween()
	windup.tween_property(drill, "rotation:x", -1.23, 0.24)
	windup.tween_callback(launch_drill.bind(direction, 0.05))
	windup.tween_interval(0.23)
	windup.tween_callback(launch_drill.bind(direction, 0.57))
	if health < max_health * 0.5:
		windup.tween_interval(0.23)
		windup.tween_callback(launch_drill.bind(direction, 0.28))
	windup.tween_property(drill, "rotation:x", 0.0, 0.22)

func launch_drill(direction: float, height: float) -> void:
	if health <= 0.0:
		return
	var projectile := RiftProjectile.new()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(direction * 1.55, height, 0.0)
	projectile.speed = 21.0
	projectile.damage = 25.0 + phase_index() * 3.0
	projectile.setup(Vector3(direction, 0.0, 0.0), faction, ORANGE, true)

func ground_punch() -> void:
	var locked_x := target.global_position.x
	var base := floor_height
	var marker := make_spike_warning(Vector3(locked_x, base + 0.043, 0), 1.48)
	var resting := fist.position
	var windup := create_tween()
	windup.tween_method(pose_punch.bind(resting), 0.0, 1.0, 0.52)
	windup.tween_callback(raise_spike.bind(locked_x, base, marker))
	windup.tween_property(fist, "position", resting, 0.34)
	windup.parallel().tween_property(fist, "rotation:x", 0.0, 0.34)
	if health < max_health * 0.5:
		windup.tween_callback(followup_spike.bind(base))

func pose_punch(progress: float, resting: Vector3) -> void:
	# Quaternius Punch_Cross wrist reach projected onto the rigid fist joint.
	var cursor := progress * (CROSS_REACH.size() - 1)
	var key := mini(floori(cursor), CROSS_REACH.size() - 2)
	var extension := lerpf(CROSS_REACH[key], CROSS_REACH[key + 1], cursor - key) - CROSS_REACH[0]
	fist.position = resting + Vector3(0, sin(progress * PI) * 0.6 - progress * progress * 0.7, extension * 2.5)
	fist.rotation.x = -extension * 3.8

func followup_spike(base: float) -> void:
	if not is_instance_valid(target) or health <= 0.0:
		return
	var locked_x := target.global_position.x
	var marker := make_spike_warning(Vector3(locked_x, base + 0.043, 0), 1.48)
	var warning := create_tween()
	warning.tween_interval(0.34)
	warning.tween_callback(raise_spike.bind(locked_x, base, marker))

func raise_spike(locked_x: float, base: float, marker: MeshInstance3D) -> void:
	marker.queue_free()
	if health <= 0.0:
		return
	var spike := TRAP_VFX.make_spikes(1.65)
	add_child(spike)
	spike.global_position = Vector3(locked_x, base, 0)
	spike.scale.y = 0.04
	TRAP_VFX.throw_sparks(spike, TRAP_VFX.EMBER, 1.3)
	var impact := create_tween()
	impact.tween_property(spike, "scale:y", 1.0, 0.12)
	var drill_piece := spike.find_child("DrillRotor", true, false) as Node3D
	if drill_piece:
		var spin := spike.create_tween()
		spin.tween_method(drill_piece.rotate_z, 0.13, 0.24, 0.38)
	impact.tween_callback(func():
		if is_instance_valid(target) and absf(target.global_position.x - locked_x) < 0.79 and target.global_position.y < base + 2.05:
			target.take_damage(29.0 + phase_index() * 3.0, spike.global_position)
	)
	impact.tween_interval(0.27)
	impact.tween_property(spike, "scale:y", 0.02, 0.2)
	impact.tween_callback(spike.queue_free)

func make_spike_warning(at: Vector3, width: float) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var decal := QuadMesh.new()
	decal.size = Vector2(width, 1.4)
	marker.mesh = decal
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://assets/neon_factory/spike_warning.gdshader")
	marker.material_override = paint
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.global_position = at
	marker.rotation.x = -PI * 0.5
	return marker

func make_effect_box(at: Vector3, size: Vector3) -> MeshInstance3D:
	var effect := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	effect.mesh = geometry
	effect.material_override = preload("res://assets/neon_factory/lava.tres")
	add_child(effect)
	effect.global_position = at
	return effect
