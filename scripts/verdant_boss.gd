extends Combatant

const Difficulty := preload("res://scripts/mission_difficulty.gd")
const WASP := preload("res://assets/machine_jungle/enemies/canopy_wasp.tscn")
const TOXIN := Color("d45aff")
const JungleRig := preload("res://scripts/jungle_boss_rig.gd")
const DrainBloom := preload("res://scripts/jungle_drain_bloom.gd")
const FX := preload("res://scripts/jungle_boss_fx.gd")
const ATTACK_FX := preload("res://scripts/attack_fx.gd")
const MOTIONS := [JungleRig.Motion.SWEEP, JungleRig.Motion.VOLLEY, JungleRig.Motion.ERUPT, JungleRig.Motion.ROOT_FLOOD]
const PRESSURE_HOLD := 0.62
const CORE_WINDOW := 7.0
var faction := "enemy"
var active := false
var target: RiftPlayer
var facing := -1.0
var phase_time := 0.8
var difficulty_mode := 0
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
var exposed: bool:
	get: return exposed_left > 0.0
var flood_left := 0.0
var flood_tick := 0.0
var drain_charge := 0.0
var drain_index := -1
var drains: Array[DrainBloom] = []
var flood_mist: Node3D
var supply_threshold := 0
var reactor_light: OmniLight3D
var reactor_halo: MeshInstance3D
var flood_tween: Tween
var flood_art_active := false
var windup_duration := 0.0
var pose_recovery := 0.0
var previous_motion := JungleRig.Motion.IDLE
var stagger := 0.0
var last_release: Array = []
var shown_release := -1
var shown_windup := -1
var opened_at := -1
var verdant_damage_scale := 1.0
var verdant_damage_taken := 0.75
@onready var armor: JungleRig = $Armor

func configure_difficulty(mode: int) -> void:
	difficulty_mode = mode
	verdant_damage_scale = Difficulty.jungle_boss_damage_scale(mode)
	verdant_damage_taken = Difficulty.jungle_boss_damage_taken(mode, false)

func damage_model() -> Node3D:
	return armor

func _ready() -> void:
	super._ready()
	ignore_arena_access_decks()
	body_floor = global_position.y - 1.55
	var level := get_parent().get_parent()
	var gate := level.get_node_or_null("Gate") as Node3D
	var exit := level.get_node_or_null("ExitBarrier") as Node3D
	if gate and exit:
		arena_left = gate.global_position.x + 2.4
		arena_right = exit.global_position.x - 3.9
	armor.bind_model($Armor/Model, 3.15, 1.55, false)
	for marker_name in ["CanopyDrainWest", "CanopyDrainEast"]:
		var marker := level.get_node_or_null("MARKERS/" + marker_name) as Marker3D
		if marker:
			var drain := DrainBloom.new()
			drain.top_level = true
			add_child(drain)
			drain.global_position = marker.global_position
			drains.append(drain)
	build_flood_mist()
	died.connect(_break_apart)
	reactor_light = OmniLight3D.new()
	reactor_light.position = Vector3(0, 0.45, 0.5)
	reactor_light.omni_range = 2.6
	reactor_light.light_color = TOXIN
	reactor_light.light_energy = 0.65
	add_child(reactor_light)
	reactor_halo = FX.core_halo(self, Vector3(0, .57, 1.01), .56)
	for platform in get_tree().get_nodes_in_group(&"factory_one_way"):
		add_collision_exception_with(platform as PhysicsBody3D)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if active and (exposed or drains.is_empty()):
		if attack < 0:
			stagger = 0.13
		super.take_damage(amount * verdant_damage_taken, source_position)

func apply_burn_tick() -> void:
	take_damage(burn_power)

func dispatch_canopy_supply() -> void:
	if supply_threshold >= 2 or health / max_health > [0.65, 0.35][supply_threshold]:
		return
	var perch := arena_supply_anchor(supply_threshold)
	supply_threshold += 1
	if not perch:
		return
	var drone := preload("res://scripts/cargo_carrier.gd").new()
	drone.adaptive_supply = true
	drone.supply_target = target
	drone.add_to_group(&"boss_supply")
	var landing: Vector3 = perch.supply_landing_point() if perch.has_method("supply_landing_point") else perch.global_position
	drone.position = get_parent_node_3d().to_local(landing + Vector3.UP * 2.3)
	get_parent().add_child.call_deferred(drone)

func _physics_process(delta: float) -> void:
	if not active or health <= 0.0 or not is_instance_valid(target):
		return
	exposed_left = maxf(0.0, exposed_left - delta)
	update_root_flood(delta)
	update_encounter_art()
	dispatch_canopy_supply()
	phase_time -= delta
	var dx := target.global_position.x - global_position.x
	var anger := 1.0 - health / max_health
	if attack < 0:
		facing = signf(dx) if absf(dx) > 0.25 else facing
	velocity.x = move_toward(velocity.x, facing * (3.2 + anger * 1.6) * Difficulty.boss_pursuit_scale(difficulty_mode) if attack < 0 and absf(dx) > 4.1 else 0.0, delta * 21.0)
	velocity.y -= 27.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_left, arena_right)
	update_fight_pose(delta)
	for h in hazards.duplicate():
		h["left"] -= delta
		h["tick"] -= delta
		var effect: Node3D = h["node"]
		if h["left"] <= 0.0:
			effect.queue_free()
			hazards.erase(h)
		elif h["tick"] <= 0.0 and absf(target.global_position.x - effect.global_position.x) < float(h.get("radius", 1.65)) and target.global_position.y < body_floor + 2.05:
			h["tick"] = 0.64
			target.take_boss_hit(16.0 * verdant_damage_scale * encounter_attack_scale, effect.global_position, 2, true)
	if absf(dx) < 1.44 and absf(target.global_position.y - global_position.y) < 1.42:
		target.take_damage(33.0 * verdant_damage_scale * encounter_attack_scale, global_position)
	if phase_time > 0.0:
		return
	if attack >= 0:
		_release()
		attack = -1
		phase_time = 1.5 if exposed_left > 0.0 else lerpf(0.69, 0.30, anger) * Difficulty.boss_recovery_scale(difficulty_mode)
		return
	if summons < 3 and anger > 0.25 + 0.25 * summons:
		_summon()
		phase_time = 0.7
		return
	attack = pattern % 4
	pattern += 1
	strike_dir = facing
	strike_x = clampf(target.global_position.x, arena_left - 0.7, arena_right + 0.8)
	phase_time = Difficulty.windup_time(1.08 if attack == 3 else lerpf(0.76, 0.51, anger), difficulty_mode)
	windup_duration = phase_time
	show_windup(attack, strike_x, strike_dir, phase_time)
	RiftAudio.play_effect(&"titan_windup")

func show_windup(move: int, impact_x: float, direction: float, duration: float) -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	var at := Vector3(impact_x, body_floor + .095, 0)
	match move:
		0:
			at.x = global_position.x + direction * 4.15
			warning = FX.warning_field(self, at, 8.3, 2.9, FX.DANGER, duration, direction)
		1:
			warning = FX.warning_field(self, at, 3.30, 2.9, FX.ACID, duration)
			ATTACK_FX.charge(warning, global_position + Vector3(direction * 1.43, .52, 0), TOXIN, duration)
		2:
			warning = FX.warning_field(self, at, 2.6, 2.9, FX.DANGER, duration)
		3:
			if not exposed:
				at.x = (arena_left + arena_right + 1.0) * .5
				warning = FX.warning_field(self, at, arena_right - arena_left + 3.0, 3.4, FX.ACID, duration, .64)

func update_fight_pose(delta: float) -> void:
	pose_recovery = maxf(0.0, pose_recovery - delta)
	stagger = maxf(0.0, stagger - delta)
	var motion := JungleRig.Motion.IDLE
	var weight := 0.0
	if attack >= 0:
		motion = MOTIONS[attack]
		weight = clampf(1.0 - phase_time / windup_duration, 0.16, 1.0)
	elif pose_recovery > 0.0:
		motion = previous_motion
		weight = pose_recovery / 0.31
	elif stagger > 0.0:
		motion = JungleRig.Motion.STAGGER
		weight = stagger / 0.13
	armor.set_combat_pose(facing, absf(velocity.x), motion, weight)

func _release() -> void:
	previous_motion = MOTIONS[attack]
	pose_recovery = 0.31
	if is_instance_valid(warning):
		warning.queue_free()
	var scene := get_parent()
	var at := Vector3(global_position.x + strike_dir * 4.15 if attack == 0 else strike_x, body_floor, 0)
	if attack == 3:
		if not exposed:
			flood_left = 5.1 if difficulty_mode == Difficulty.NORMAL else 4.6
			flood_tick = 0.23
			drain_index = -1
			drain_charge = 0.0
		return
	last_release = [pattern, attack, at, strike_dir, Time.get_ticks_msec()]
	if attack == 1:
		var count := (5 if health / max_health < 0.5 else 3) + difficulty_mode
		for i in range(count):
			var shot := RiftProjectile.new()
			shot.boss_status_sector = 2
			shot.collision_layer = 0
			shot.collision_mask = 1
			shot.speed = 12.0 + i * 2.5
			shot.damage = 34.0 * verdant_damage_scale * encounter_attack_scale
			shot.setup(Vector3(strike_dir, (i - (count - 1) * 0.5) * 0.24, 0), "enemy", TOXIN, false, i == count / 2, false, 2, 4)
			scene.add_child(shot)
			shot.global_position = global_position + Vector3(strike_dir * 1.43, 0.52, 0)
		var cloud := draw_spore_pool(at)
		hazards.append({"node": cloud, "left": 2.75, "tick": 0.0})
		return
	draw_root_attack(attack, at, strike_dir)
	var reach := 4.15 if attack == 0 else 1.30
	create_tween().tween_callback(func():
		if active and is_instance_valid(target) and absf(target.global_position.x - at.x) < reach and target.global_position.y < body_floor + 2.02:
			target.take_damage(49.0 * verdant_damage_scale * encounter_attack_scale, at)
	).set_delay(.12)

func draw_root_attack(move: int, at: Vector3, direction: float) -> void:
	var sweeping := move == 0
	FX.roots(self, at, 8.3 if sweeping else 2.6, 1.62 if sweeping else 1.94, 10 if sweeping else 6, direction if sweeping else 0.0)

func draw_spore_pool(at: Vector3) -> Node3D:
	var cloud := FX.at_world(self, at + Vector3.UP * .39)
	FX.mist(cloud, 3.30, 1.50, FX.ACID, 3)
	FX.burst(cloud, cloud.global_position, TOXIN, 1.52, 12)
	return cloud

func draw_drain_opening() -> void:
	if opened_at >= 0 and opened_at < drains.size():
		drains[opened_at].discharge()
	FX.burst(self, global_position + Vector3(0, .57, 1.01), FX.OPEN, 1.85, 24)

func build_flood_mist() -> void:
	flood_mist = Node3D.new()
	flood_mist.top_level = true
	add_child(flood_mist)
	flood_mist.global_position = Vector3((arena_left + arena_right + 1.0) * .5, body_floor + 0.53, 0)
	FX.mist(flood_mist, arena_right - arena_left + 3.0, 1.78, FX.ACID, 4)
	flood_mist.hide()

func update_root_flood(delta: float) -> void:
	if flood_left <= 0.0:
		return
	flood_left = maxf(0.0, flood_left - delta)
	if flood_left == 0.0:
		drain_charge = 0.0
		drain_index = -1
		return
	flood_tick -= delta
	var occupied := -1
	for actor in get_parent().get_children():
		if not actor is RiftPlayer or actor.health <= 0.0:
			continue
		for index in drains.size():
			if drains[index].occupied_by(actor):
				occupied = index if occupied < 0 else mini(occupied, index)
		if flood_tick <= 0.0 and actor.global_position.x > arena_left - 1.0 and actor.global_position.x < arena_right + 2.0 and actor.global_position.y < body_floor + 2.05:
			actor.take_boss_hit(16.0 * verdant_damage_scale * encounter_attack_scale, flood_mist.global_position, 2, true)
	if flood_tick <= 0.0:
		flood_tick = 0.64
	if occupied != drain_index:
		drain_index = occupied
		drain_charge = 0.0
	if occupied >= 0:
		drain_charge = minf(1.0, drain_charge + delta / PRESSURE_HOLD)
		if drain_charge >= 1.0:
			open_after_drain()

func open_after_drain() -> void:
	opened_at = drain_index
	flood_left = 0.0
	drain_charge = 0.0
	drain_index = -1
	exposed_left = CORE_WINDOW
	attack = -1
	phase_time = 1.25
	if is_instance_valid(warning):
		warning.queue_free()
	RiftAudio.play_effect(&"deploy_zap")
	draw_drain_opening()

func update_encounter_art() -> void:
	reactor_light.light_color = FX.OPEN if exposed else TOXIN
	reactor_light.light_energy = 2.7 + sin(Time.get_ticks_msec() * .009) * .52 if exposed else .65
	reactor_halo.visible = exposed
	reactor_halo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * .007) * .11)
	var flooding := flood_left > 0.0
	if flooding != flood_art_active:
		flood_art_active = flooding
		if flood_tween:
			flood_tween.kill()
		flood_tween = flood_mist.create_tween()
		if flooding:
			flood_mist.scale.y = .22
			flood_mist.show()
			flood_tween.tween_property(flood_mist, "scale:y", 1.0, .23)
		else:
			flood_tween.tween_property(flood_mist, "scale:y", .04, .25)
			flood_tween.tween_callback(flood_mist.hide)
	for index in drains.size():
		drains[index].present(flood_left > 0.0, drain_charge if index == drain_index else 0.0)

func encounter_status() -> String:
	if drains.is_empty():
		return ""
	if exposed:
		return "CORE EXPOSED  %ds\nDROP DOWN AND FIRE" % ceili(exposed_left)
	if flood_left > 0.0:
		return "TOXIC FLOOD\nSTAND ON A LIT CANOPY DRAIN"
	return "REACTOR SEALED\nGET HIGH WHEN THE FLOOD STARTS"

func jungle_snapshot() -> Array:
	var release: Array = []
	if not last_release.is_empty():
		var age := float(Time.get_ticks_msec() - int(last_release[4])) / 1000.0
		if age < (2.75 if last_release[1] == 1 else .32):
			release = last_release.slice(0, 4) + [age]
	return [armor.snapshot(), exposed_left, flood_left, drain_index, drain_charge,
		pattern, attack, strike_x, strike_dir, phase_time, release, opened_at]

func apply_jungle_snapshot(state: Array) -> void:
	if state.size() >= 5:
		armor.apply_snapshot(state[0])
		var just_opened := not exposed and float(state[1]) > 0.0
		exposed_left = state[1]
		flood_left = state[2]
		drain_index = state[3]
		drain_charge = state[4]
		if state.size() >= 12:
			opened_at = state[11]
			if state[6] < 0 and is_instance_valid(warning):
				warning.queue_free()
			elif state[6] >= 0 and shown_windup != int(state[5]):
				shown_windup = state[5]
				show_windup(state[6], state[7], state[8], state[9])
			var move: Array = state[10]
			if not move.is_empty() and int(move[0]) > shown_release:
				shown_release = move[0]
				if move[1] == 1:
					var cloud := draw_spore_pool(move[2])
					cloud.create_tween().tween_callback(cloud.queue_free).set_delay(maxf(.04, 2.75 - float(move[4])))
				else:
					draw_root_attack(move[1], move[2], move[3])
		if just_opened:
			draw_drain_opening()
		update_encounter_art()

func _summon() -> void:
	summons += 1
	var drone := WASP.instantiate()
	drone.position = Vector3(clampf(global_position.x - facing * 4.2, arena_left + 0.8, arena_right - 2.7), body_floor + 3.1, 0)
	drone.target = target
	drone.add_to_group(&"arena_minions")
	get_parent().add_child(drone)
	drone.scale_for_sector(2, 2, difficulty_mode, get_parent().get_meta("party_size", 1))

func _break_apart() -> void:
	active = false
	preload("res://scripts/pit_burst.gd").spawn.call_deferred(get_parent(), global_position, TOXIN, .5)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	set_deferred("collision_layer", 0)
	queue_free()
