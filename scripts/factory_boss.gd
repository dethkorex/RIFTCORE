extends Combatant

const CARRIER := preload("res://scripts/cargo_carrier.gd")
const FLAME := preload("res://scripts/foundry_flame.gd")
const VFX := preload("res://scripts/factory_trap_vfx.gd")
const ORANGE := Color("ff6e31")
const HEAT_MARKER := Color("ff6932")
const MINI_CYCLE := ["low_volley", "firewall", "sweep", "firewall"]
const TITAN_CYCLE := ["drill_volley", "hammer", "rush", "pressure_dump", "rush"]

@export var warden := false
var chassis_height := 1.45
var faction := "enemy"
var target: RiftPlayer
var active := false
var facing := -1.0
var arena_left := -100.0
var arena_right := 100.0
var floor_height := 0.0
var cooldown := 0.85
var step := 0
var motion := ""
var elapsed := 0.0
var stride := 0.0
var exposed := false
var zones: Array[Node3D] = []
var tracks: Node3D
var rush_origin := 0.0
var rush_end := 0.0
var hit_players := {}
var contact_timers := {}
var cargo_index := 0
var move_phase := 0.0
var world_impact := false

@onready var armor: Node3D = $Armor
@onready var drill := find_child("DrillModule", true, false) as Node3D
@onready var rotor := find_child("DrillRotor", true, false) as Node3D
@onready var fist := find_child("FistModule", true, false) as Node3D
@onready var shutter_left := find_child("ShutterLeft", true, false) as Node3D
@onready var shutter_right := find_child("ShutterRight", true, false) as Node3D
@onready var front_left := find_child("WardenLegLeft" if warden else "TitanLegLeft", true, false) as Node3D
@onready var front_right := find_child("WardenLegRight" if warden else "TitanLegRight", true, false) as Node3D
@onready var rear_left := find_child("RearLeft", true, false) as Node3D
@onready var rear_right := find_child("RearRight", true, false) as Node3D
@onready var burner_left := find_child("BurnerLeft", true, false) as Node3D
@onready var burner_right := find_child("BurnerRight", true, false) as Node3D
@onready var fist_home := fist.position if fist else Vector3.ZERO
@onready var shutter_left_home := shutter_left.position if shutter_left else Vector3.ZERO
@onready var shutter_right_home := shutter_right.position if shutter_right else Vector3.ZERO

func _ready() -> void:
	super._ready()
	died.connect(die)
	health_changed.connect(check_supplies)
	floor_height = global_position.y - chassis_height
	var stage := get_parent().get_parent()
	var entry := stage.get_node_or_null("Gate") as Node3D
	var exit := stage.get_node_or_null("ExitBarrier") as Node3D
	if entry and exit:
		floor_height = entry.global_position.y
		arena_left = entry.global_position.x + 2.5
		arena_right = exit.global_position.x - 2.3
	armor.rotation.y = facing * 1.10
	collision_mask = 1
	for catwalk in get_tree().get_nodes_in_group(&"factory_one_way"):
		if stage.is_ancestor_of(catwalk):
			add_collision_exception_with(catwalk)

func phase_index() -> int:
	return 2 if health <= max_health * 0.30 else (1 if health <= max_health * 0.64 else 0)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or target.health <= 0.0 or health <= 0.0:
		return
	for operator in operators():
		var id := operator.get_instance_id()
		contact_timers[id] = maxf(0.0, float(contact_timers.get(id, 0.0)) - delta)
	if motion.is_empty():
		var gap := target.global_position.x - global_position.x
		if absf(gap) > 0.19:
			facing = signf(gap)
		var stop := 5.0 if warden else 6.0
		var pace := (2.5 + phase_index() * 0.46) * facing
		if absf(gap) < stop:
			pace = -pace * 0.53 if absf(gap) < stop * 0.64 else 0.0
		move_in_arena(pace, delta)
		cooldown -= delta
		if cooldown <= 0.0:
			var cycle := MINI_CYCLE if warden else TITAN_CYCLE
			begin_attack(cycle[step % cycle.size()])
			step += 1
	else:
		advance_attack(delta)
	draw_pose(delta)

func operators() -> Array[Node]:
	return get_parent().get_children().filter(func(actor): return actor is RiftPlayer and actor.health > 0.0)

func move_in_arena(speed: float, delta: float) -> void:
	var start_x := global_position.x
	velocity.x = clampf(speed, (arena_left - start_x) / delta, (arena_right - start_x) / delta)
	velocity.y = maxf(-15.0, velocity.y - 30.0 * delta)
	velocity.z = -global_position.z * 12.0
	move_and_slide()
	move_phase = (global_position.x - start_x) / delta
	stride += absf(move_phase) * delta * (4.85 if warden else 3.6)
	for index in get_slide_collision_count():
		var operator := get_slide_collision(index).get_collider() as RiftPlayer
		if operator and motion != "rush":
			hit_operator(operator, 12.0 if warden else 17.0)

func hit_operator(operator: RiftPlayer, power: float) -> void:
	var id := operator.get_instance_id()
	if float(contact_timers.get(id, 0.0)) > 0.0:
		return
	contact_timers[id] = 0.67
	operator.take_damage(power, global_position)

func begin_attack(kind: String) -> void:
	motion = kind
	elapsed = 0.0
	world_impact = false
	hit_players.clear()
	match motion:
		"firewall":
			var goal := target.global_position.x
			for span in [-2.85, 0.0, 2.85]:
				add_flame(goal + span, 2.65, 1.17, 0.89 + absf(span) * 0.07)
		"sweep":
			for index in range(4 + int(phase_index() > 0)):
				add_flame(global_position.x + facing * (2.8 + 2.75 * index), 2.13, 1.40, 0.89 + index * 0.17)
		"hammer":
			var goal := target.global_position.x
			add_flame(goal, 3.75, 1.65, 0.95)
			if phase_index() > 0:
				add_flame(goal + facing * 3.2, 3.2, 1.32, 1.30)
		"pressure_dump":
			var goal := target.global_position.x
			for offset in [-5.7, -2.85, 0.0, 2.85, 5.7]:
				add_flame(goal + offset, 3.65, 1.52, 0.95 + absf(offset) * 0.13)
		"rush":
			rush_origin = global_position.x
			rush_end = clampf(rush_origin + facing * (12.8 + 2.05 * phase_index()), arena_left, arena_right)
			show_rush_markers()
			RiftAudio.play_effect(&"titan_windup")

func advance_attack(delta: float) -> void:
	var prior := elapsed
	elapsed += delta
	var pressure := phase_index()
	exposed = motion == "pressure_dump" and elapsed > 1.62
	if motion == "rush":
		update_rush(prior, delta)
	else:
		move_in_arena(0.0, delta)
		if motion == "low_volley":
			fire_at(prior, 0.56, 0.51, false)
			fire_at(prior, 1.04, 1.15 if pressure > 0 else 0.51, false)
			if pressure >= 2:
				fire_at(prior, 1.46, 0.51, false)
		elif motion == "drill_volley":
			fire_at(prior, 0.53, 0.94, true)
			fire_at(prior, 0.89, 1.75, true)
			if pressure > 0:
				fire_at(prior, 1.26, 0.74, true)
		elif motion == "hammer" and prior < 0.95 and elapsed >= 0.95:
			VFX.throw_sparks(fist, HEAT_MARKER, 2.65)
			RiftAudio.foundry_sound(&"boulder_roll", global_position)
	advance_flames(true)
	var end_at := 3.40 if motion == "pressure_dump" else (2.52 if motion == "sweep" else (2.26 if motion in ["firewall", "hammer", "rush"] else 1.8))
	if elapsed > end_at:
		clear_attack()
		cooldown = 0.82 - pressure * 0.12

func update_rush(prior: float, delta: float) -> void:
	var charging := elapsed >= 0.92 and elapsed <= 1.68 and not world_impact
	var start_x := global_position.x
	if charging:
		if prior < 0.92:
			RiftAudio.stop_effect(&"titan_windup")
			RiftAudio.foundry_sound(&"fire_jet", global_position)
		var speed := minf(18.5 + phase_index() * 3.1, absf(rush_end - start_x) / delta)
		move_in_arena(speed * facing, delta)
		var lo := minf(start_x, global_position.x) - 0.75
		var hi := maxf(start_x, global_position.x) + 0.75
		lo -= 1.7 if facing < 0.0 else 0.0
		hi += 1.7 if facing > 0.0 else 0.0
		for body in operators():
			var where: Vector3 = body.global_position
			var id: int = body.get_instance_id()
			if not hit_players.has(id) and where.x > lo and where.x < hi and where.y < floor_height + 2.30:
				hit_players[id] = true
				body.take_damage(33.0 + 5.0 * phase_index(), global_position)
		if absf(rush_end - global_position.x) < .22 or speed > 0.5 and absf(global_position.x - start_x) < .025:
			world_impact = true
			VFX.throw_sparks(drill, HEAT_MARKER, 3.0)
			RiftAudio.foundry_sound(&"boulder_roll", global_position)
	else:
		move_in_arena(0.0, delta)
	update_rush_markers()

func fire_at(prior: float, at: float, height: float, is_drill: bool) -> void:
	if prior >= at or elapsed < at:
		return
	var muzzle := Vector3(global_position.x + facing * 1.5, floor_height + height, 0.0)
	var shot := RiftProjectile.new()
	get_parent().add_child(shot)
	shot.global_position = muzzle
	shot.speed = 23.0 if is_drill else 12.5 + phase_index() * 1.0
	shot.damage = (24.0 if is_drill else 17.0) + phase_index() * 4.0
	shot.lifetime = 2.45
	shot.setup(Vector3(facing, 0.0, 0.0), faction, ORANGE, is_drill, false, not is_drill)
	var source := drill if is_drill else (burner_left if height < 1.0 else burner_right)
	VFX.throw_sparks(source, ORANGE, 1.2)

func add_flame(at: float, height: float, width: float, delay: float) -> void:
	var locked := clampf(at, arena_left, arena_right)
	for zone in zones:
		if absf(zone.global_position.x - locked) < 0.67:
			return
	var flame := FLAME.new()
	flame.height = height
	flame.width = width
	flame.warning_time = delay
	flame.burst_time = 0.72 if warden else 0.80
	add_child(flame)
	flame.top_level = true
	flame.global_position = Vector3(locked, floor_height, 0.0)
	flame.set_meta(&"lit", false)
	flame.set_meta(&"struck", {})
	zones.append(flame)

func advance_flames(authority: bool) -> void:
	for flame in zones:
		flame.show_phase(elapsed)
		var burning: bool = elapsed >= flame.warning_time and elapsed < flame.warning_time + flame.burst_time - 0.10
		if burning and not flame.get_meta(&"lit"):
			RiftAudio.foundry_sound(&"fire_jet", flame.global_position)
			flame.set_meta(&"lit", true)
		if burning and authority:
			var struck: Dictionary = flame.get_meta(&"struck")
			for body in operators():
				var id: int = body.get_instance_id()
				var at: Vector3 = body.global_position - flame.global_position
				if not struck.has(id) and absf(at.x) < flame.width * 0.49 + 0.32 and at.y > 0.0 and at.y < flame.height + 0.49:
					struck[id] = true
					body.take_damage((21.0 if warden else 29.0) + phase_index() * 3.0, flame.global_position)

func show_rush_markers() -> void:
	tracks = Node3D.new()
	add_child(tracks)
	tracks.top_level = true
	tracks.global_position = Vector3(rush_origin, floor_height + 0.09, 0.0)
	var length := absf(rush_end - rush_origin)
	for distance in range(1, ceili(length), 2):
		for z in [-0.42, 0.42]:
			var slat := RiftProjectile.part(tracks, BoxMesh.new(), RiftProjectile.light_paint(HEAT_MARKER, 2.0),
				Vector3(facing * distance, 0, z), Vector3(0.46, 0.065, 0.15))
			slat.rotation.y = facing * -signf(z) * 0.47

func update_rush_markers() -> void:
	if is_instance_valid(tracks):
		tracks.visible = elapsed < 0.92
		tracks.scale.y = 0.55 + 0.45 * absf(sin(elapsed * 23.0))

func draw_pose(delta: float) -> void:
	var mix_weight := 1.0 - exp(-delta * 17.0)
	var windup := 0.0
	var lean := 0.0
	var rise := 0.0
	match motion:
		"rush":
			windup = clampf(elapsed / 0.68, 0.0, 1.0)
			lean = -0.21 * windup if elapsed < 0.92 else 0.26
			rise = -0.13 * windup
			if elapsed > 1.68 or world_impact:
				windup = clampf((2.21 - elapsed) / 0.53, 0.0, 1.0)
				lean = 0.12 * windup
				rise *= windup
		"hammer":
			var gather := sin(clampf(elapsed / 0.93, 0.0, 1.0) * PI * 0.5)
			var slam := smoothstep(0.75, 0.95, elapsed) * (1.0 - smoothstep(1.12, 1.67, elapsed))
			lean = gather * -0.15 + slam * 0.47
			rise = gather * 0.08 - slam * 0.25
			fist.position = fist_home + Vector3(0, gather * 0.75 * (1.0 - slam) - slam * 0.42, slam * 0.44)
			fist.rotation.x = -0.72 * gather + 1.15 * slam
		"low_volley", "drill_volley":
			windup = smoothstep(0.0, 0.50, elapsed) * (1.0 - smoothstep(1.44, 1.8, elapsed))
			lean = sin(elapsed * 20.0) * 0.12 * windup
		"firewall", "sweep", "pressure_dump":
			windup = smoothstep(0.0, 0.78, elapsed) * (1.0 - smoothstep(2.18, 2.65, elapsed))
			lean = -0.12 * windup
			rise = -0.14 * windup
	if fist and motion != "hammer":
		fist.position = fist.position.lerp(fist_home, mix_weight)
		fist.rotation.x = lerpf(fist.rotation.x, 0.0, mix_weight)
	var front_pull := sin(stride) * 0.23 * clampf(absf(move_phase) * 0.50, 0.0, 1.0)
	armor.rotation.y = lerp_angle(armor.rotation.y, facing * 1.13, mix_weight)
	armor.rotation.x = lerpf(armor.rotation.x, lean, mix_weight)
	armor.position.y = lerpf(armor.position.y, rise + absf(front_pull) * 0.195, mix_weight)
	front_left.rotation.x = lerpf(front_left.rotation.x, front_pull, mix_weight)
	front_right.rotation.x = lerpf(front_right.rotation.x, -front_pull, mix_weight)
	if warden:
		rear_left.rotation.x = -front_pull
		rear_right.rotation.x = front_pull
		burner_left.rotation.x = lerpf(burner_left.rotation.x, windup * 0.42, mix_weight)
		burner_right.rotation.x = lerpf(burner_right.rotation.x, -windup * 0.30, mix_weight)
	else:
		rotor.rotate_z(delta * (4.0 + windup * 29.0))
		drill.rotation.x = lerpf(drill.rotation.x, 0.25 - windup * 0.33, mix_weight)
		var open := 0.30 if exposed else 0.0
		shutter_left.position = shutter_left.position.lerp(shutter_left_home - Vector3.RIGHT * open, mix_weight)
		shutter_right.position = shutter_right.position.lerp(shutter_right_home + Vector3.RIGHT * open, mix_weight)

func clear_attack() -> void:
	for flame in zones:
		flame.queue_free()
	zones.clear()
	if is_instance_valid(tracks):
		tracks.queue_free()
		tracks = null
	motion = ""
	exposed = false

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if active:
		var multiplier := 1.22 if exposed else (1.0 if warden else 0.92)
		super.take_damage(amount * multiplier, source_position)

func check_supplies(current: float, total: float) -> void:
	if warden or current <= 0.0 or not active or not is_instance_valid(target):
		return
	var thresholds := [0.75, 0.5, 0.25]
	while cargo_index < thresholds.size() and current / total <= thresholds[cargo_index]:
		drop_supply.call_deferred(cargo_index)
		cargo_index += 1

func drop_supply(index: int) -> void:
	if not active or health <= 0.0:
		return
	var shelves := ["TitanWestHatch", "TitanHighRun", "TitanEastDrop"]
	var deck := get_parent().get_parent().get_node_or_null("TERRAIN/" + shelves[index]) as Node3D
	if not deck:
		return
	var carrier := CARRIER.new()
	var landing: Vector3 = deck.supply_landing_point() if deck.has_method("supply_landing_point") else deck.global_position
	carrier.position = get_parent_node_3d().to_local(landing + Vector3.UP * 2.35)
	carrier.adaptive_supply = true
	carrier.supply_target = target
	carrier.add_to_group(&"boss_supply")
	get_parent().add_child(carrier)

func die() -> void:
	active = false
	if motion == "rush" and elapsed < 0.92:
		RiftAudio.stop_effect(&"titan_windup")
	clear_attack()
	var orb := preload("res://assets/pickups/xp_orb.tscn").instantiate() as Area3D
	orb.large = true
	orb.position = position - Vector3.UP
	get_parent().add_child.call_deferred(orb)
	set_deferred("collision_layer", 0)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	var burst := preload("res://scripts/pit_burst.gd").new()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.scale = Vector3.ONE * (1.13 if warden else 1.75)
	burst.ignite()
	get_tree().create_timer(0.58, false).timeout.connect(burst.queue_free)
	queue_free()

func foundry_snapshot() -> Array:
	var emitters := []
	for flame in zones:
		emitters.append(Vector4(flame.global_position.x, flame.height, flame.width, flame.warning_time))
	return [motion, step, elapsed, facing, stride, move_phase, exposed, rush_origin, rush_end, emitters, world_impact]

func apply_foundry_snapshot(state: Array) -> void:
	if motion != state[0] or step != state[1]:
		clear_attack()
		motion = state[0]
		step = state[1]
		facing = state[3]
		rush_origin = state[7]
		rush_end = state[8]
		for emitter: Vector4 in state[9]:
			add_flame(emitter.x, emitter.y, emitter.z, emitter.w)
		if motion == "rush":
			show_rush_markers()
	var delta := clampf(float(state[2]) - elapsed, 0.04, 0.11)
	elapsed = state[2]
	facing = state[3]
	stride = state[4]
	move_phase = state[5]
	exposed = state[6]
	world_impact = state[10]
	draw_pose(delta)
	advance_flames(false)
	update_rush_markers()
