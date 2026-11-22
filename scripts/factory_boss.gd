extends Combatant

const CARRIER := preload("res://scripts/cargo_carrier.gd")
const FLAME := preload("res://scripts/foundry_flame.gd")
const VFX := preload("res://scripts/factory_trap_vfx.gd")
const PACK_VFX := preload("res://scripts/pack_combat_vfx.gd")
const FoundryRig := preload("res://scripts/foundry_boss_rig.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const ReliefValve := preload("res://scripts/foundry_relief_valve.gd")
const FallingCore := preload("res://scripts/foundry_falling_core.gd")
const LavaShader := preload("res://assets/neon_factory/foundry/rising_lava.gdshader")
const Burst := preload("res://scripts/pit_burst.gd")
const WARDEN_WINDOWS := [5.0, 4.25, 3.6]
const TITAN_WINDOWS := [6.0, 5.2, 4.5]
const WARDEN_BACKDRAFT_WARNING := [1.45, 1.28, 1.12]
const SLAM_TIME := .82
const CORE_LAND_TIME := 1.56
const AIM_LOCK_TIME := 2.65
const RUSH_WINDUP := 3.68
const RUSH_END_TIME := 4.84
const CORE_START_HEIGHT := 6.42
const LAVA_WARNING := [3.75, 3.35, 3.0]
const LAVA_RISE_TIME := 1.1
const LAVA_HOLD_TIME := 2.0
const LAVA_DRAIN_TIME := .90
const WARDEN_JUMP_START := .46
const WARDEN_PERCH_TIME := 1.98
const WARDEN_FLOOD_WARNING := [5.35, 5.0, 4.7]
const WARDEN_RISE_TIME := .95
const WARDEN_FLOOD_HEIGHT := 5.85
const WARDEN_LOWER_FLOOD_HEIGHT := 1.48
const WARDEN_UPPER_SURGE_DELAY := 2.0
const WARDEN_UPPER_SURGE_TIME := 2.65
const WARDEN_DRAIN_TIME := 1.08
const WARDEN_DROP_TIME := 1.0
const WARDEN_LANDING_WIDTH := 5.8
const FLOOD_DEPTH := 7.7
const SURFACE_CREST := .055
const DRILL_REACH := 2.45
const FIRST_SEAL := 0.64
const SECOND_SEAL := 0.30
const ORANGE := Color("ff6e31")
const HEAT_MARKER := Color("ff6932")
const MINI_CYCLE := ["low_volley", "kiln_backdraft", "lava_surge", "firewall", "lava_surge"]
const TITAN_CYCLE := ["drill_volley", "rush", "lava_surge", "rush", "casting_wave", "rush"]
const HARD_WARDEN_CYCLE := ["crossfire", "kiln_backdraft", "lava_surge", "low_volley", "lava_surge", "firewall"]
const HARD_TITAN_CYCLE := ["crossfire", "rush", "lava_surge", "rush", "hammer", "rush", "pressure_dump", "rush"]
const EXPERT_TITAN_CYCLE := ["rupture", "lava_surge", "rupture", "crossfire", "rupture", "hammer", "rupture", "pressure_dump"]

@export var warden := false
var chassis_height := 1.45
var faction := "enemy"
var target: RiftPlayer
var active := false
var facing := -1.0
var arena_left := -100.0
var arena_right := 100.0
var floor_ports := PackedFloat32Array()
var floor_height := 0.0
var cooldown := 0.85
var step := 0
var motion := ""
var elapsed := 0.0
var stride := 0.0
var exposed := false
var zones: Array[Node3D] = []
var tracks: MeshInstance3D
var rush_origin := 0.0
var rush_end := 0.0
var hit_players := {}
var contact_timers := {}
var cargo_index := 0
var move_phase := 0.0
var world_impact := false
var difficulty_mode := 0
var purge_valve: ReliefValve
var pressure_released := false
var elevated_time: Dictionary = {}
var window_end := 0.0
var drop_points: Array[Node3D] = []
var core_index := -1
var falling_core: FallingCore
var intro_core: FallingCore
var rush_hits_core := false
var core_shattered := false
var last_shatter_step := -1
var lava_surface: MeshInstance3D
var warden_perch: Node3D
var warden_launch := Vector3.ZERO
var warden_drain_started := -1.0
var warden_impact_mark: MeshInstance3D
var last_attack_was_overhead := false
var block_feedback_left := 0.0
var exposed_light: OmniLight3D

@onready var armor: FoundryRig = $Armor

func damage_model() -> Node3D:
	return armor

func _ready() -> void:
	super._ready()
	ignore_arena_access_decks()
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
	if warden:
		warden_perch = stage.get_node_or_null("TERRAIN/WardenLavaPerch")
	var ports := stage.get_node_or_null("TERRAIN/BossFloorPorts")
	if ports:
		for port: Node3D in ports.get_children():
			floor_ports.append(port.global_position.x)
		floor_ports.sort()
	if floor_ports.size() < 3:
		floor_ports.clear()
		for index in 10:
			floor_ports.append(lerpf(arena_left, arena_right, (float(index) + 0.5) / 10.0))
	var points := stage.get_node_or_null("TERRAIN/TitanDropPoints")
	if not warden and points:
		for marker: Node3D in points.get_children():
			drop_points.append(marker)
	exposed_light = OmniLight3D.new()
	exposed_light.light_color = Color("82ffe1")
	exposed_light.light_energy = 1.15
	exposed_light.omni_range = 3.0
	exposed_light.position = Vector3(0, 0.18 if warden else 1.12, 0.88)
	exposed_light.hide()
	add_child(exposed_light)
	armor.rotation.y = facing * BOSS_SIDE_YAW
	collision_mask = 1
	for catwalk in get_tree().get_nodes_in_group(&"factory_one_way"):
		if stage.is_ancestor_of(catwalk):
			add_collision_exception_with(catwalk)

func phase_index() -> int:
	return 2 if health <= max_health * SECOND_SEAL else (1 if health <= max_health * FIRST_SEAL else 0)

func configure_difficulty(mode: int) -> void:
	difficulty_mode = clampi(mode, Difficulty.NORMAL, Difficulty.NIGHTMARE)
	if warden and not is_instance_valid(purge_valve):
		var marker := get_parent().get_parent().get_node("MARKERS/WardenPurge") as Node3D
		purge_valve = ReliefValve.new()
		purge_valve.top_level = true
		add_child(purge_valve)
		purge_valve.global_position = marker.global_position

func attack_cycle() -> Array:
	if warden:
		return HARD_WARDEN_CYCLE if difficulty_mode > Difficulty.NORMAL else MINI_CYCLE
	if difficulty_mode == Difficulty.NIGHTMARE:
		return EXPERT_TITAN_CYCLE
	return HARD_TITAN_CYCLE if difficulty_mode == Difficulty.HARD else TITAN_CYCLE

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or target.health <= 0.0 or health <= 0.0:
		return
	block_feedback_left = maxf(0.0, block_feedback_left - delta)
	for operator in operators():
		var id := operator.get_instance_id()
		contact_timers[id] = maxf(0.0, float(contact_timers.get(id, 0.0)) - delta)
		var feet: float = operator.global_position.y - operator.standing_capsule.height * 0.5
		var held := float(elevated_time.get(id, 0.0))
		var elevated_floor := 1.8 if warden and motion == "lava_surge" else 3.65
		elevated_time[id] = held + delta if feet > floor_height + elevated_floor else maxf(0.0, held - delta * 2.5)
	if motion.is_empty():
		var gap := target.global_position.x - global_position.x
		if absf(gap) > 0.19:
			facing = signf(gap)
		var stop := 5.0 if warden else 6.0
		var pace := (2.5 + phase_index() * 0.46) * facing * Difficulty.boss_pursuit_scale(difficulty_mode, warden)
		if absf(gap) < stop:
			pace = -pace * 0.53 if absf(gap) < stop * 0.64 else 0.0
		var cycle := attack_cycle()
		var next: String = cycle[step % cycle.size()]
		var staging := warden_perch != null and next == "lava_surge"
		var runup := 0.0
		if staging:
			runup = warden_landing_position().x - global_position.x
			pace = clampf(runup / delta, -8.5, 8.5)
			if absf(runup) > .08:
				facing = signf(runup)
		move_in_arena(pace, delta)
		cooldown -= delta
		if cooldown <= 0.0 and (not staging or absf(runup) < .12):
			var camper := elevated_operator()
			if camper and not last_attack_was_overhead and next not in ["kiln_backdraft", "rush", "rupture", "lava_surge"]:
				begin_attack("overhead_vent", camper)
				elevated_time[camper.get_instance_id()] = 0.0
			else:
				begin_attack(next)
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
		if operator and motion not in ["rush", "rupture"]:
			hit_operator(operator, 12.0 if warden else 17.0)

func hit_operator(operator: RiftPlayer, power: float) -> void:
	var id := operator.get_instance_id()
	if float(contact_timers.get(id, 0.0)) > 0.0:
		return
	contact_timers[id] = 0.67
	operator.take_damage(power * encounter_attack_scale, global_position)

func elevated_operator() -> RiftPlayer:
	for operator: RiftPlayer in operators():
		if operator.is_on_floor() and float(elevated_time.get(operator.get_instance_id(), 0.0)) >= 3.15:
			return operator
	return null

func begin_attack(kind: String, elevated: RiftPlayer = null) -> void:
	motion = kind
	last_attack_was_overhead = kind == "overhead_vent"
	elapsed = 0.0
	world_impact = false
	pressure_released = false
	warden_drain_started = -1.0
	window_end = 0.0
	hit_players.clear()
	match motion:
		"lava_surge":
			warden_launch = global_position
			build_lava_surge()
		"overhead_vent":
			if elevated:
				var platform_y := elevated.global_position.y - elevated.standing_capsule.height * 0.5
				add_flame(elevated.global_position.x, 2.22, 2.30, 0.95, platform_y + 0.025)
		"kiln_backdraft":
			var nearest := 1
			for index in range(2, floor_ports.size() - 1):
				if absf(floor_ports[index] - target.global_position.x) < absf(floor_ports[nearest] - target.global_position.x):
					nearest = index
			for index in range(nearest - 1, nearest + 2):
				add_flame(floor_ports[index], 2.38, 2.45, backdraft_warning())
		"casting_wave":
			var middle := floori(floor_ports.size() * 0.5)
			var east := target.global_position.x >= (floor_ports[middle - 1] + floor_ports[middle]) * 0.5
			var count := floor_ports.size() - middle if east else middle
			for index in count:
				var port := middle + index if east else middle - 1 - index
				add_flame(floor_ports[port], 1.70, 3.15, 1.10 + index * 0.20)
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
		"crossfire":
			var goal := target.global_position.x
			add_flame(goal, 2.65, 1.5, 0.93)
			if difficulty_mode == Difficulty.NIGHTMARE:
				add_flame(goal + facing * 4.0, 3.10, 1.28, 1.38)
		"rush", "rupture":
			rush_origin = global_position.x
			var lure := target.global_position.x - rush_origin
			if absf(lure) > 0.20:
				facing = signf(lure)
			rush_end = rush_origin
			select_drop_point()
			RiftAudio.play_effect(&"titan_windup")

func advance_attack(delta: float) -> void:
	var prior := elapsed
	elapsed += delta
	if exposed:
		if not warden or motion != "lava_surge":
			move_in_arena(0.0, delta)
		if elapsed >= window_end:
			finish_attack()
		return
	var pressure := phase_index()
	if motion == "lava_surge":
		if warden_perch:
			update_warden_leap(prior)
			update_warden_lava(true)
			if warden_drain_started >= 0.0 and elapsed >= warden_landing_time():
				warden_landing_impact()
				if active and motion == "lava_surge":
					open_armor()
			elif warden_drain_started < 0.0:
				maybe_target_warden_ledge()
				advance_flames(true)
			return
		move_in_arena(0.0, delta)
		update_lava_surge(true)
		if elapsed >= lava_warning_time() + LAVA_RISE_TIME + LAVA_HOLD_TIME + LAVA_DRAIN_TIME:
			finish_attack()
		return
	if motion in ["rush", "rupture"]:
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
		elif motion == "crossfire":
			fire_at(prior, .52, .66, not warden)
			fire_at(prior, .88, 1.86, not warden)
			fire_at(prior, 1.33, .70, not warden)
		elif motion == "hammer" and prior < 0.95 and elapsed >= 0.95:
			VFX.impact(armor.hammer_head, 2.65)
			RiftAudio.foundry_sound(&"boulder_roll", global_position)
	if exposed:
		return
	advance_flames(true)
	var end_at := 3.40 if motion in ["pressure_dump", "rupture"] else (2.52 if motion in ["sweep", "crossfire"] else (2.26 if motion in ["firewall", "hammer", "rush"] else 1.8))
	match motion:
		"rush", "rupture":
			end_at = RUSH_END_TIME + (1.4 if motion == "rupture" else .36)
		"overhead_vent":
			end_at = 1.90
		"kiln_backdraft":
			end_at = backdraft_warning() + 1.45
		"casting_wave":
			end_at = 4.32
	if elapsed > end_at:
		finish_attack()

func finish_attack() -> void:
	clear_attack()
	cooldown = (0.82 - phase_index() * 0.12) * Difficulty.boss_recovery_scale(difficulty_mode, warden)

func backdraft_warning() -> float:
	return WARDEN_BACKDRAFT_WARNING[difficulty_mode]

func select_drop_point() -> void:
	var best := INF
	for index in drop_points.size():
		var offset := drop_points[index].global_position.x - rush_origin
		if absf(offset) < 5.0 or absf(offset) > 25.0:
			continue
		var score := absf(offset) + (27.0 if signf(offset) != facing else 0.0)
		if score < best:
			core_index = index
			best = score
	if core_index >= 0:
		facing = signf(drop_points[core_index].global_position.x - rush_origin)
		show_falling_core()

func show_falling_core() -> void:
	if core_index < 0 or is_instance_valid(falling_core):
		return
	falling_core = FallingCore.new()
	falling_core.top_level = true
	add_child(falling_core)
	falling_core.global_position = drop_points[core_index].global_position
	present_core()

func present_core() -> void:
	if is_instance_valid(falling_core):
		falling_core.present(elapsed, SLAM_TIME, CORE_LAND_TIME, CORE_START_HEIGHT, core_shattered)

func slam_effect() -> void:
	var at := Vector3(rush_origin, floor_height + .12, 0.0)
	Burst.spawn(self, at, Color("ff8030"), .65)
	RiftAudio.foundry_sound(&"boulder_roll", at)

func core_landing_effect() -> void:
	if not is_instance_valid(falling_core):
		return
	VFX.impact(falling_core, 2.6)
	RiftAudio.foundry_sound(&"boulder_roll", falling_core.global_position)

func shatter_core() -> void:
	if core_index < 0 or last_shatter_step == step:
		return
	last_shatter_step = step
	Burst.spawn(get_parent(), drop_points[core_index].global_position + Vector3.UP * 1.10, Color("ffc858"), 1.1)
	RiftAudio.play_effect(&"barricade_crack")

func lock_charge() -> void:
	var lure := target.global_position.x
	if core_index >= 0:
		var core_x := drop_points[core_index].global_position.x
		var side := signf(core_x - rush_origin)
		for operator in operators():
			if (operator.global_position.x - core_x) * side >= .68:
				rush_hits_core = true
				facing = side
				rush_end = core_x - facing * DRILL_REACH
				break
	if not rush_hits_core:
		facing = signf(lure - rush_origin) if absf(lure - rush_origin) > .18 else facing
		var range_x := clampf(absf(lure - rush_origin) + .45, 1.0, 24.0)
		if core_index >= 0:
			var gap := (drop_points[core_index].global_position.x - rush_origin) * facing
			if gap > 0.0:
				range_x = minf(range_x, gap - DRILL_REACH - .25)
		rush_end = clampf(rush_origin + facing * range_x, arena_left, arena_right)
	show_rush_markers()

func update_rush(prior: float, delta: float) -> void:
	if prior < SLAM_TIME and elapsed >= SLAM_TIME:
		slam_effect()
		for body in operators():
			if absf(body.global_position.x - rush_origin) < 4.0 and body.global_position.y < floor_height + 2.05:
				body.take_boss_hit(23.0 * encounter_attack_scale, global_position, 1)
	if prior < CORE_LAND_TIME and elapsed >= CORE_LAND_TIME:
		core_landing_effect()
		if core_index >= 0:
			var at := drop_points[core_index].global_position
			for body in operators():
				if absf(body.global_position.x - at.x) < 1.25 and body.global_position.y < floor_height + 2.9:
					body.take_boss_hit(19.0 * encounter_attack_scale, at, 1)
	if prior < AIM_LOCK_TIME and elapsed >= AIM_LOCK_TIME:
		lock_charge()
	present_core()
	var charging := elapsed >= RUSH_WINDUP and elapsed <= RUSH_END_TIME and not world_impact
	var start_x := global_position.x
	if charging:
		if prior < RUSH_WINDUP:
			RiftAudio.stop_effect(&"titan_windup")
			RiftAudio.foundry_sound(&"fire_jet", global_position)
		var speed := minf(27.0 + phase_index() * 3.1, absf(rush_end - start_x) / delta)
		move_in_arena(speed * facing, delta)
		var lo := minf(start_x, global_position.x) - (.75 + (1.7 if facing < 0.0 else 0.0))
		var hi := maxf(start_x, global_position.x) + (.75 + (1.7 if facing > 0.0 else 0.0))
		for body in operators():
			var where: Vector3 = body.global_position
			var id: int = body.get_instance_id()
			if not hit_players.has(id) and where.x > lo and where.x < hi and where.y < floor_height + 2.30:
				hit_players[id] = true
				body.take_boss_hit((33.0 + 5.0 * phase_index()) * encounter_attack_scale, global_position, 1, true)
		if absf(rush_end - global_position.x) < .14:
			world_impact = true
			if rush_hits_core:
				core_shattered = true
				present_core()
				shatter_core()
				open_armor()
				return
		elif speed > .5 and absf(global_position.x - start_x) < .025:
			world_impact = true
		if world_impact:
			VFX.impact(armor.drill_tip, 3.0)
			RiftAudio.foundry_sound(&"boulder_roll", global_position)
	else:
		move_in_arena(0.0, delta)
	if not world_impact and elapsed >= RUSH_END_TIME:
		world_impact = true
	if motion == "rupture" and world_impact and zones.is_empty():
		for i in [0, 1, 2]:
			var lane := lerpf(rush_origin, rush_end, (float(i) + .5) / 3.0)
			add_flame(lane, 3.1, 2.0, elapsed + .42 + float(i) * .11)
	update_rush_markers()

func lava_warning_time() -> float:
	return LAVA_WARNING[difficulty_mode]

func build_lava_surge() -> void:
	if warden_perch:
		add_to_group(&"warden_lava_phase")
		warden_impact_mark = FLAME.floor_mark(WARDEN_LANDING_WIDTH, 3.9, FLAME.Style.CASTING, Color("ff8b36"))
		warden_impact_mark.top_level = true
		add_child(warden_impact_mark)
		warden_impact_mark.global_position = warden_landing_position() + Vector3.DOWN * (chassis_height - .12)
		warden_impact_mark.hide()
	var width := arena_right - arena_left + 4.8
	tracks = FLAME.floor_mark(width, 3.6, FLAME.Style.CASTING, Color("ff5627"))
	tracks.top_level = true
	add_child(tracks)
	tracks.global_position = Vector3((arena_left + arena_right) * .5, floor_height + .12, 0.0)
	lava_surface = make_lava_surface(width + 1.6, FLOOD_DEPTH)
	lava_surface.material_override.set_shader_parameter("pool_half_size", Vector2(width + 1.6, FLOOD_DEPTH) * .5)
	lava_surface.material_override.set_shader_parameter("pool_feather", 1.10)

func make_lava_surface(width: float, depth: float) -> MeshInstance3D:
	var surface := PlaneMesh.new()
	surface.size = Vector2(width, depth)
	surface.subdivide_width = clampi(roundi(width * 3.0), 24, 132)
	surface.subdivide_depth = 22
	var material := ShaderMaterial.new()
	material.shader = LavaShader
	material.set_shader_parameter("flat_surface", true)
	var lava := MeshInstance3D.new()
	lava.mesh = surface
	lava.material_override = material
	lava.top_level = true
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lava.hide()
	add_child(lava)
	return lava

func warden_perch_position() -> Vector3:
	return warden_perch.global_position + Vector3.UP * chassis_height

func warden_landing_position() -> Vector3:
	return Vector3(warden_perch.global_position.x - 10.5, floor_height + chassis_height, 0.0)

func warden_drop_start() -> float:
	return INF if warden_drain_started < 0.0 else warden_drain_started + WARDEN_DRAIN_TIME

func warden_landing_time() -> float:
	return warden_drop_start() + WARDEN_DROP_TIME

func update_warden_leap(prior: float) -> void:
	var perch := warden_perch_position()
	var landing := warden_landing_position()
	velocity = Vector3.ZERO
	move_phase = 0.0
	if elapsed < WARDEN_PERCH_TIME:
		var leap := clampf(inverse_lerp(WARDEN_JUMP_START, WARDEN_PERCH_TIME, elapsed), 0.0, 1.0)
		global_position = warden_launch.lerp(perch, leap)
		# Gain height in the open shaft, cross the nose of the dock, then settle onto it.
		global_position.y += 41.0 * leap * (1.0 - leap)
		if absf(perch.x - warden_launch.x) > .1:
			facing = signf(perch.x - warden_launch.x)
	else:
		var leap := clampf((elapsed - warden_drop_start()) / WARDEN_DROP_TIME, 0.0, 1.0)
		global_position = perch.lerp(landing, leap)
		global_position.y += 41.0 * leap * (1.0 - leap)
		var target_side := target.global_position.x - global_position.x
		if absf(target_side) > .4:
			facing = signf(target_side)
	if (prior < WARDEN_PERCH_TIME and elapsed >= WARDEN_PERCH_TIME) or (prior < warden_landing_time() and elapsed >= warden_landing_time()):
		VFX.impact(armor, 1.1)

func warden_flood_warning() -> float:
	return WARDEN_FLOOD_WARNING[difficulty_mode]

func update_warden_lava(authority: bool) -> void:
	var draining := warden_drain_started >= 0.0
	var time := warden_drain_started if draining else elapsed
	var warning := warden_flood_warning()
	var age := time - warning
	var drainage := 1.0 - smoothstep(0.0, WARDEN_DRAIN_TIME, elapsed - time)
	var lower := WARDEN_LOWER_FLOOD_HEIGHT * smoothstep(0.0, WARDEN_RISE_TIME, age)
	var upper := (WARDEN_FLOOD_HEIGHT - WARDEN_LOWER_FLOOD_HEIGHT) * smoothstep(WARDEN_UPPER_SURGE_DELAY, WARDEN_UPPER_SURGE_DELAY + WARDEN_UPPER_SURGE_TIME, age)
	var height := (lower + upper) * drainage
	purge_valve.present(not draining and elapsed >= warning + .70, 1.0 - drainage)
	present_lava_warning(age, warning)
	present_boss_flood(height, authority)
	warden_impact_mark.visible = draining and elapsed >= warden_drop_start() and elapsed < warden_landing_time()
	if warden_impact_mark.visible:
		warden_impact_mark.material_override.set_shader_parameter("progress", (elapsed - warden_drop_start()) / WARDEN_DROP_TIME)

func warden_steam_warning() -> float:
	return 1.18 - float(phase_index()) * .09

func maybe_target_warden_ledge() -> void:
	if not zones.is_empty() or elapsed < warden_flood_warning() + WARDEN_RISE_TIME:
		return
	for operator: RiftPlayer in operators():
		if not operator.grounded() or absf(operator.velocity.x) > .75 or float(elevated_time.get(operator.get_instance_id(), 0.0)) < 1.0:
			continue
		var at := operator.global_position
		var feet := at.y - operator.standing_capsule.height * .5
		# The operating deck is safe so the valve can always be used.
		if feet > floor_height + 1.8 and feet < purge_valve.global_position.y - 1.5:
			add_flame(at.x, 1.65, 2.6, elapsed + warden_steam_warning(), feet + .025)
			return

func warden_landing_impact() -> void:
	warden_impact_mark.hide()
	RiftAudio.foundry_sound(&"boulder_roll", global_position)
	for operator: RiftPlayer in operators():
		var feet := operator.global_position.y - operator.standing_capsule.height * .5
		if absf(operator.global_position.x - global_position.x) < WARDEN_LANDING_WIDTH * .5 and feet < floor_height + .55:
			operator.take_damage(18.0 * encounter_attack_scale, global_position)

func update_lava_surge(authority: bool) -> void:
	var warning := lava_warning_time()
	var age := elapsed - warning
	var drain := LAVA_RISE_TIME + LAVA_HOLD_TIME
	var progress := smoothstep(0.0, LAVA_RISE_TIME, age) * (1.0 - smoothstep(drain, drain + LAVA_DRAIN_TIME, age))
	present_lava_warning(age, warning)
	present_boss_flood(progress * 3.38, authority)

func present_lava_warning(age: float, warning_time: float) -> void:
	tracks.visible = age < 0.0
	if tracks.visible:
		tracks.material_override.set_shader_parameter("progress", clampf(elapsed / warning_time, 0.0, 1.0))

func present_boss_flood(height: float, authority: bool) -> void:
	var appeared := height > .035 and not lava_surface.visible
	lava_surface.visible = height > .035
	var center := (arena_left + arena_right) * .5
	lava_surface.global_position = Vector3(center, floor_height + height, .1)
	var surface_material := lava_surface.material_override as ShaderMaterial
	surface_material.set_shader_parameter("pool_height", height)
	if appeared:
		RiftAudio.foundry_sound(&"fire_jet", Vector3(center, floor_height, 0.0))
	if not authority or not lava_surface.visible:
		return
	for operator: RiftPlayer in operators():
		var at := operator.global_position
		var radius := operator.standing_capsule.radius
		if at.x + radius < arena_left - 2.5 or at.x - radius > arena_right + 2.3 or absf(at.z - .1) - radius > FLOOD_DEPTH * .5 - .5:
			continue
		var feet := at.y - operator.standing_capsule.height * .5
		if feet <= floor_height + height + SURFACE_CREST:
			operator.die_in_pit()

func interact_purge_valve(operator: RiftPlayer) -> bool:
	if not active or motion != "lava_surge" or not is_instance_valid(purge_valve):
		return false
	if elapsed < warden_flood_warning() + .70 or warden_drain_started >= 0.0 or not purge_valve.operator_can_reach(operator):
		return false
	warden_drain_started = elapsed
	pressure_released = true
	purge_valve.present(false, 0.0)
	clear_flames()
	RiftAudio.foundry_sound(&"fire_jet", purge_valve.global_position)
	return true

func open_armor() -> void:
	exposed = true
	exposed_light.show()
	var windows := WARDEN_WINDOWS if warden else TITAN_WINDOWS
	window_end = elapsed + float(windows[difficulty_mode])
	clear_flames()
	if is_instance_valid(tracks):
		tracks.hide()
	RiftAudio.play_effect(&"checkpoint")

func mechanic_preview_target() -> Vector3:
	if is_instance_valid(purge_valve):
		return purge_valve.global_position + Vector3.UP * 0.46
	if drop_points.size() > 1:
		return drop_points[1].global_position + Vector3.UP * 5.0
	return global_position

func show_intro_target(enabled: bool) -> void:
	if is_instance_valid(purge_valve):
		purge_valve.show_target(enabled)
	elif enabled and drop_points.size() > 1:
		intro_core = FallingCore.new()
		intro_core.top_level = true
		add_child(intro_core)
		intro_core.global_position = drop_points[1].global_position
		intro_core.present(0.0, SLAM_TIME, CORE_LAND_TIME, 5.0, false)
		intro_core.footprint.hide()
	elif is_instance_valid(intro_core):
		intro_core.queue_free()
		intro_core = null

func encounter_status() -> String:
	if exposed:
		return "CORE EXPOSED   %.1f s\nSHOOT THE BOSS NOW" % maxf(0.0, window_end - elapsed)
	if motion == "lava_surge":
		if warden_perch:
			if warden_drain_started >= 0.0:
				return "WARDEN DROPPING\nCLEAR THE MARKED LANDING" if elapsed >= warden_drop_start() else "LAVA DRAINING\nWATCH THE WARDEN'S LANDING"
			if elapsed < warden_flood_warning():
				return "LAVA RISES IN %.1f s\nKICK OFF THE LIT COLUMN" % (warden_flood_warning() - elapsed)
			return "FLOOR FLOODED\nWALL-KICK TO THE PURGE VALVE"
		if elapsed < lava_warning_time():
			return "LAVA SURGE   %.1f s\nCLIMB TO AN UPPER PLATFORM" % (lava_warning_time() - elapsed)
		return "LAVA ON THE FLOOR\nSTAY ON THE UPPER PLATFORMS"
	if warden:
		if motion == "kiln_backdraft":
			return "BACKDRAFT\nCLEAR THE MARKED VENTS"
		return "ARMOR SEALED\nWATCH FOR THE WARDEN'S LEAP"
	if motion in ["rush", "rupture"]:
		if elapsed < CORE_LAND_TIME:
			return "GROUND SLAM\nCLEAR THE AMBER DROP ZONE"
		if world_impact:
			return "CHARGE MISSED\nBAIT THE NEXT CHARGE PAST THE CORE"
		if elapsed >= AIM_LOCK_TIME:
			return "CHARGE LOCKED\nJUMP CLEAR" if rush_hits_core else "CHARGE LOCKED\nDODGE THE DRILL"
		return "AMBER CORE LANDED\nMOVE TO ITS FAR SIDE"
	return "ARMOR SEALED\nWAIT FOR THE GROUND SLAM"

func fire_at(prior: float, at: float, height: float, is_drill: bool) -> void:
	if prior >= at or elapsed < at:
		return
	var muzzle := Vector3(global_position.x + facing * 1.5, floor_height + height, 0.0)
	var shot := RiftProjectile.new()
	shot.boss_status_sector = 1
	get_parent().add_child(shot)
	shot.global_position = muzzle
	shot.speed = 23.0 if is_drill else 12.5 + phase_index() * 1.0
	shot.damage = ((24.0 if is_drill else 17.0) + phase_index() * 4.0) * encounter_attack_scale
	shot.lifetime = 2.45
	shot.setup(Vector3(facing, 0.0, 0.0), faction, ORANGE, is_drill, false, not is_drill)
	var source := armor.drill_tip if is_drill else (armor.left_burner if height < 1.0 else armor.right_burner)
	VFX.impact(source, 1.2)

func add_flame(at: float, height: float, width: float, delay: float, raised_y: float = INF) -> void:
	var locked := clampf(at, arena_left, arena_right)
	for zone in zones:
		if absf(zone.global_position.x - locked) < 0.67:
			return
	var flame := FLAME.new()
	flame.height = height
	flame.width = width
	flame.warning_time = delay
	flame.burst_time = 0.72 if warden else 0.80
	match motion:
		"casting_wave":
			flame.style = FLAME.Style.CASTING
		"overhead_vent", "lava_surge":
			flame.style = FLAME.Style.HIGH_VENT
			if motion == "lava_surge":
				flame.warning_start = maxf(0.0, delay - warden_steam_warning())
	flame.top_level = true
	flame.position = Vector3(locked, floor_height if is_inf(raised_y) else raised_y, 0.0)
	add_child(flame)
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
					var power := (21.0 if warden else 29.0) + phase_index() * 3.0
					body.take_boss_hit(power * encounter_attack_scale, flame.global_position, 1, true)

func show_rush_markers() -> void:
	var lo := minf(rush_origin, rush_end) - (2.45 if facing < 0 else 0.75)
	var hi := maxf(rush_origin, rush_end) + (2.45 if facing > 0 else 0.75)
	tracks = FLAME.floor_mark(hi - lo, 2.35, FLAME.Style.DRILL, Color("ff632d"))
	add_child(tracks)
	tracks.top_level = true
	tracks.global_position = Vector3((lo + hi) * 0.5, floor_height + 0.11, 0)
	var material := tracks.material_override as ShaderMaterial
	material.set_shader_parameter("direction", facing)

func update_rush_markers() -> void:
	if is_instance_valid(tracks):
		tracks.visible = not exposed and elapsed < RUSH_WINDUP
		if tracks.visible:
			var material := tracks.material_override as ShaderMaterial
			material.set_shader_parameter("progress", clampf(inverse_lerp(AIM_LOCK_TIME, RUSH_WINDUP, elapsed), 0.0, 1.0))

func draw_pose(delta: float) -> void:
	var mix_weight := 1.0 - exp(-delta * 17.0)
	var windup := 0.0
	var lean := 0.0
	var rise := 0.0
	var hammer := 0.0
	var recoil := 0.0
	match motion:
		"hammer", "rush", "rupture":
			var slam_time := .95 if motion == "hammer" else SLAM_TIME
			var gather := sin(clampf(elapsed / slam_time, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(slam_time, slam_time + .56, elapsed))
			var slam := smoothstep(slam_time - .20, slam_time, elapsed) * (1.0 - smoothstep(slam_time + .15, slam_time + .72, elapsed))
			lean = gather * -0.15 + slam * 0.47
			rise = gather * 0.08 - slam * 0.25
			hammer = -.66 * gather * (1.0 - slam) + .51 * slam
			if motion != "hammer" and elapsed >= AIM_LOCK_TIME:
				windup = clampf(inverse_lerp(AIM_LOCK_TIME, RUSH_WINDUP, elapsed), 0.0, 1.0)
				lean = -0.21 * windup if elapsed < RUSH_WINDUP else 0.26
				rise = -0.13 * windup
				if world_impact:
					windup = .12 if exposed else 0.0
					lean = .22 if exposed else .05
					rise = -.34 if exposed else 0.0
		"low_volley", "drill_volley", "crossfire":
			windup = smoothstep(0.0, 0.50, elapsed) * (1.0 - smoothstep(1.44, 1.8, elapsed))
			recoil = sin(elapsed * 20.0) * 0.12 * windup
			lean = recoil
		"firewall", "sweep", "pressure_dump", "kiln_backdraft", "casting_wave", "overhead_vent", "lava_surge":
			windup = smoothstep(0.0, 0.78, elapsed) * (1.0 - smoothstep(2.18, 2.65, elapsed))
			lean = -0.12 * windup
			rise = -0.14 * windup
	if warden_perch and motion == "lava_surge":
		var launch := smoothstep(0.0, WARDEN_JUMP_START, elapsed)
		var airborne := launch * (1.0 - smoothstep(WARDEN_PERCH_TIME - .25, WARDEN_PERCH_TIME, elapsed))
		var braced := smoothstep(WARDEN_PERCH_TIME, WARDEN_PERCH_TIME + .24, elapsed) * (1.0 - smoothstep(warden_drop_start() - .24, warden_drop_start(), elapsed) if warden_drain_started >= 0.0 else 1.0)
		windup = maxf(airborne, braced * .52)
		lean = .17 * airborne + .23 * braced
		rise = -.27 * (launch - airborne) * braced
	var front_pull := sin(stride) * 0.23 * clampf(absf(move_phase) * 0.50, 0.0, 1.0)
	armor.rotation.y = lerpf(armor.rotation.y, facing * BOSS_SIDE_YAW, mix_weight)
	armor.rotation.x = lerpf(armor.rotation.x, lean, mix_weight)
	armor.position.y = lerpf(armor.position.y, rise + absf(front_pull) * 0.195, mix_weight)
	if warden_perch and motion == "lava_surge":
		var ascending := smoothstep(WARDEN_JUMP_START, WARDEN_JUMP_START + .22, elapsed) * (1.0 - smoothstep(WARDEN_PERCH_TIME - .22, WARDEN_PERCH_TIME, elapsed))
		var descending := 0.0
		if warden_drain_started >= 0.0:
			descending = smoothstep(warden_drop_start(), warden_drop_start() + .24, elapsed) * (1.0 - smoothstep(warden_landing_time() - .18, warden_landing_time(), elapsed))
		var landing := 1.0 - smoothstep(0.0, .28, minf(absf(elapsed - WARDEN_PERCH_TIME), absf(elapsed - warden_landing_time())))
		armor.cinematic_pose(delta, maxf(ascending, descending), landing, windup * .5, windup)
	else:
		armor.animate(delta, front_pull, windup, hammer, recoil, exposed)

func clear_flames() -> void:
	for flame in zones:
		flame.hide()
		flame.queue_free()
	zones.clear()

func clear_attack() -> void:
	clear_flames()
	if is_instance_valid(tracks):
		tracks.queue_free()
		tracks = null
	if is_instance_valid(falling_core):
		falling_core.queue_free()
		falling_core = null
	if is_instance_valid(lava_surface):
		lava_surface.queue_free()
		lava_surface = null
	if is_instance_valid(warden_impact_mark):
		warden_impact_mark.queue_free()
	warden_impact_mark = null
	if is_in_group(&"warden_lava_phase"):
		remove_from_group(&"warden_lava_phase")
	motion = ""
	exposed = false
	exposed_light.hide()
	window_end = 0.0
	pressure_released = false
	core_index = -1
	rush_hits_core = false
	core_shattered = false
	warden_drain_started = -1.0
	if is_instance_valid(purge_valve):
		purge_valve.present(false, 0.0)
	stop_core_burn()

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if not active or amount <= 0.0 or health <= 0.0:
		return
	if not exposed:
		if block_feedback_left <= 0.0:
			block_feedback_left = 0.33
			VFX.impact(armor, 0.75)
		return
	var seal := 0.0
	match phase_index():
		0: seal = max_health * FIRST_SEAL
		1: seal = max_health * SECOND_SEAL
	var remaining_in_phase := health - seal
	var damage := minf(amount * (1.58 if warden else 1.48), remaining_in_phase)
	var previous_health := health
	super.take_damage(damage, source_position)
	if seal > 0.0 and health < previous_health and damage == remaining_in_phase:
		finish_attack()

func ignite(power: float, seconds: float, source := 0) -> void:
	if active and exposed:
		super.ignite(power, seconds, source)

func apply_burn_tick() -> void:
	take_damage(burn_power)

func stop_core_burn() -> void:
	burn_left = 0.0
	burn_power = 0.0
	burn_source = 0
	if is_instance_valid(burn_effect):
		burn_effect.queue_free()
		burn_effect = null

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
	if motion in ["rush", "rupture"] and elapsed < RUSH_WINDUP:
		RiftAudio.stop_effect(&"titan_windup")
	clear_attack()
	set_deferred("collision_layer", 0)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	var burst := Node3D.new()
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.56
	PACK_VFX.explosion(burst, ORANGE if warden else HEAT_MARKER, 2.05 if warden else 3.05)
	get_tree().create_timer(2.0, false).timeout.connect(burst.queue_free)
	queue_free()

func foundry_snapshot() -> Array:
	var emitters := []
	var elevations := PackedFloat32Array()
	for flame in zones:
		emitters.append(Vector4(flame.global_position.x, flame.height, flame.width, flame.warning_time))
		elevations.append(flame.global_position.y)
	return [motion, step, elapsed, facing, stride, move_phase, exposed, rush_origin, rush_end, emitters, world_impact, pressure_released, elevations, window_end, core_index, rush_hits_core, core_shattered, warden_drain_started]

func apply_foundry_snapshot(state: Array) -> void:
	var prior := elapsed if step == state[1] and motion == state[0] else 0.0
	if motion != state[0] or step != state[1]:
		clear_attack()
		motion = state[0]
		step = state[1]
		if motion == "lava_surge":
			build_lava_surge()
	if zones.size() != state[9].size():
		clear_flames()
		for index in state[9].size():
			var emitter: Vector4 = state[9][index]
			var platform_y: float = state[12][index] if state.size() > 12 else floor_height
			add_flame(emitter.x, emitter.y, emitter.z, emitter.w, platform_y)
	var delta := clampf(float(state[2]) - elapsed, 0.04, 0.11)
	elapsed = state[2]
	facing = state[3]
	stride = state[4]
	move_phase = state[5]
	exposed = state[6]
	exposed_light.visible = exposed
	world_impact = state[10]
	rush_origin = state[7]
	rush_end = state[8]
	pressure_released = state[11] if state.size() > 11 else false
	window_end = state[13] if state.size() > 13 else elapsed
	core_index = clampi(int(state[14]), -1, drop_points.size() - 1) if state.size() > 14 else -1
	rush_hits_core = state.size() > 15 and bool(state[15])
	core_shattered = state.size() > 16 and bool(state[16])
	warden_drain_started = float(state[17]) if state.size() > 17 else -1.0
	draw_pose(delta)
	advance_flames(false)
	if motion == "lava_surge":
		if warden_perch:
			update_warden_lava(false)
		else:
			update_lava_surge(false)
	elif motion in ["rush", "rupture"]:
		show_falling_core()
		present_core()
		if prior < SLAM_TIME and elapsed >= SLAM_TIME and elapsed < CORE_LAND_TIME:
			slam_effect()
		if prior < CORE_LAND_TIME and elapsed >= CORE_LAND_TIME and not core_shattered:
			core_landing_effect()
		if core_shattered:
			shatter_core()
		if elapsed >= AIM_LOCK_TIME and elapsed < RUSH_WINDUP and not is_instance_valid(tracks):
			show_rush_markers()
		update_rush_markers()
