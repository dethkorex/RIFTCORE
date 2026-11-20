extends Combatant

const CARRIER := preload("res://scripts/cargo_carrier.gd")
const FLAME := preload("res://scripts/foundry_flame.gd")
const VFX := preload("res://scripts/factory_trap_vfx.gd")
const PACK_VFX := preload("res://scripts/pack_combat_vfx.gd")
const FoundryRig := preload("res://scripts/foundry_boss_rig.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const ReliefValve := preload("res://scripts/foundry_relief_valve.gd")
const QuenchLock := preload("res://scripts/foundry_quench_lock.gd")
const WARDEN_WINDOWS := [5.0, 4.25, 3.6]
const TITAN_WINDOWS := [6.0, 5.2, 4.5]
const WARDEN_UNLOCK_TIME := [1.45, 1.28, 1.12]
const RUSH_WINDUP := 0.92
const RUSH_END_TIME := 1.78
const DRILL_REACH := 2.45
const FIRST_SEAL := 0.64
const SECOND_SEAL := 0.30
const ORANGE := Color("ff6e31")
const HEAT_MARKER := Color("ff6932")
const MINI_CYCLE := ["low_volley", "kiln_backdraft", "sweep", "kiln_backdraft", "firewall", "kiln_backdraft"]
const TITAN_CYCLE := ["drill_volley", "rush", "casting_wave", "rush", "hammer", "rush"]
const HARD_WARDEN_CYCLE := ["crossfire", "kiln_backdraft", "sweep", "kiln_backdraft", "low_volley", "kiln_backdraft"]
const HARD_TITAN_CYCLE := ["crossfire", "rush", "casting_wave", "rush", "hammer", "rush", "pressure_dump", "rush"]
const EXPERT_TITAN_CYCLE := ["rupture", "casting_wave", "rupture", "crossfire", "rupture", "hammer", "rupture", "pressure_dump"]

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
var purge_valves: Array[ReliefValve] = []
var pressure_released := false
var elevated_time: Dictionary = {}
var window_end := 0.0
var quench_locks: Array[QuenchLock] = []
var quench_index := -1
var last_attack_was_overhead := false
var block_feedback_left := 0.0
var exposed_light: OmniLight3D

@onready var armor: FoundryRig = $Armor

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
	var ports := stage.get_node_or_null("TERRAIN/BossFloorPorts")
	if ports:
		for port: Node3D in ports.get_children():
			floor_ports.append(port.global_position.x)
		floor_ports.sort()
	if floor_ports.size() < 3:
		floor_ports.clear()
		for index in 10:
			floor_ports.append(lerpf(arena_left, arena_right, (float(index) + 0.5) / 10.0))
	var locks := stage.get_node_or_null("TERRAIN/TitanQuenchLocks")
	if not warden and locks:
		for child in locks.get_children():
			if child is QuenchLock:
				quench_locks.append(child)
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
	refresh_quench_locks()
	if not purge_valves.is_empty():
		return
	if warden:
		var markers := get_parent().get_parent().get_node("MARKERS")
		install_purge_valve(markers.get_node("WardenPurgeWest").global_position, true)
		install_purge_valve(markers.get_node("WardenPurgeEast").global_position, true)

func install_purge_valve(at: Vector3, show_prompt: bool) -> void:
	var valve := ReliefValve.new()
	valve.top_level = true
	valve.position = at
	valve.show_prompt = show_prompt
	add_child(valve)
	valve.released.connect(release_pressure)
	purge_valves.append(valve)

func present_purge_valves(enabled: bool, authority: bool) -> void:
	for valve in purge_valves:
		valve.present_vent(enabled, authority)

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
		elevated_time[id] = held + delta if feet > floor_height + 3.65 else maxf(0.0, held - delta * 2.5)
	if motion.is_empty():
		var gap := target.global_position.x - global_position.x
		if absf(gap) > 0.19:
			facing = signf(gap)
		var stop := 5.0 if warden else 6.0
		var pace := (2.5 + phase_index() * 0.46) * facing * Difficulty.boss_pursuit_scale(difficulty_mode, warden)
		if absf(gap) < stop:
			pace = -pace * 0.53 if absf(gap) < stop * 0.64 else 0.0
		move_in_arena(pace, delta)
		cooldown -= delta
		if cooldown <= 0.0:
			var cycle := attack_cycle()
			var next: String = cycle[step % cycle.size()]
			var camper := elevated_operator()
			if camper and not last_attack_was_overhead and next not in ["kiln_backdraft", "rush", "rupture"]:
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
	operator.take_damage(power, global_position)

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
	window_end = 0.0
	hit_players.clear()
	match motion:
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
			present_purge_valves(true, true)
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
			rush_end = clampf(rush_origin + facing * (21.0 + 1.65 * phase_index()), arena_left, arena_right)
			select_quench_lock()
			show_rush_markers()
			RiftAudio.play_effect(&"titan_windup")

func advance_attack(delta: float) -> void:
	var prior := elapsed
	elapsed += delta
	if exposed:
		move_in_arena(0.0, delta)
		if elapsed >= window_end:
			finish_attack()
		return
	var pressure := phase_index()
	if motion == "kiln_backdraft" and elapsed >= backdraft_warning():
		present_purge_valves(false, true)
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
	return WARDEN_UNLOCK_TIME[difficulty_mode]

func select_quench_lock() -> void:
	quench_index = -1
	var nearest := INF
	var drill_start := rush_origin + facing * DRILL_REACH
	var range_x := absf(rush_end - rush_origin)
	for index in quench_locks.size():
		var distance := (quench_locks[index].global_position.x - drill_start) * facing
		if distance >= 0.0 and distance <= range_x and distance < nearest:
			quench_index = index
			nearest = distance
	refresh_quench_locks()

func refresh_quench_locks() -> void:
	for index in quench_locks.size():
		var lock := quench_locks[index]
		var state := QuenchLock.State.READY
		if index == quench_index:
			state = QuenchLock.State.CLAMPED if exposed else QuenchLock.State.ARMED
		lock.set_state(state)

func rush_destination() -> float:
	if quench_index >= 0:
		return quench_locks[quench_index].global_position.x - facing * DRILL_REACH
	return rush_end

func update_rush(prior: float, delta: float) -> void:
	var charging := elapsed >= RUSH_WINDUP and elapsed <= RUSH_END_TIME and not world_impact
	var start_x := global_position.x
	if charging:
		if prior < RUSH_WINDUP:
			RiftAudio.stop_effect(&"titan_windup")
			RiftAudio.foundry_sound(&"fire_jet", global_position)
		var next_x := rush_destination()
		var speed := minf(27.0 + phase_index() * 3.1, absf(next_x - start_x) / delta)
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
				body.take_boss_hit(33.0 + 5.0 * phase_index(), global_position, 1, true)
		if quench_index >= 0 and absf(next_x - global_position.x) < 0.12:
			world_impact = true
			open_armor()
			refresh_quench_locks()
			return
		if absf(rush_end - global_position.x) < .22 or speed > 0.5 and absf(global_position.x - start_x) < .025:
			world_impact = true
			quench_index = -1
			refresh_quench_locks()
			VFX.impact(armor.drill_tip, 3.0)
			RiftAudio.foundry_sound(&"boulder_roll", global_position)
	else:
		move_in_arena(0.0, delta)
	if not world_impact and elapsed >= RUSH_END_TIME:
		world_impact = true
		quench_index = -1
		refresh_quench_locks()
	if motion == "rupture" and world_impact and zones.is_empty():
		for i in [0, 1, 2]:
			var lane := lerpf(rush_origin, rush_end, (float(i) + .5) / 3.0)
			add_flame(lane, 3.1, 2.0, elapsed + .57 + float(i) * .11)
	update_rush_markers()

func release_pressure() -> void:
	if not active or motion != "kiln_backdraft" or exposed or elapsed >= backdraft_warning():
		return
	pressure_released = true
	present_purge_valves(false, true)
	open_armor()

func open_armor() -> void:
	exposed = true
	exposed_light.show()
	var windows := WARDEN_WINDOWS if warden else TITAN_WINDOWS
	window_end = elapsed + float(windows[difficulty_mode])
	for flame in zones:
		flame.hide()
		flame.queue_free()
	zones.clear()
	if is_instance_valid(tracks):
		tracks.hide()
	RiftAudio.play_effect(&"checkpoint")

func mechanic_preview_target() -> Vector3:
	if warden and not purge_valves.is_empty():
		return purge_valves[0].global_position + Vector3.UP * 0.46
	if not quench_locks.is_empty():
		return quench_locks[0].global_position + Vector3.UP * 1.32
	return global_position

func show_intro_target(enabled: bool) -> void:
	if warden and not purge_valves.is_empty():
		purge_valves[0].show_target(enabled)
	elif not quench_locks.is_empty():
		var lock := quench_locks[0]
		lock.show_target(QuenchLock.State.ARMED if enabled else lock.state)

func encounter_status() -> String:
	if exposed:
		return "CORE EXPOSED   %.1f s\nSHOOT THE BOSS NOW" % maxf(0.0, window_end - elapsed)
	if warden:
		if motion == "kiln_backdraft" and elapsed < backdraft_warning():
			return "SHOOT EITHER LIT VALVE   %.1f s\nHIT IT BEFORE THE FIRE STARTS" % maxf(0.0, backdraft_warning() - elapsed)
		if motion == "kiln_backdraft":
			return "BACKDRAFT   /   DODGE THE FIRE\nTHE ARMOR IS STILL SEALED"
		return "ARMOR SEALED\nWAIT FOR A PURGE VALVE TO LIGHT UP"
	if motion in ["rush", "rupture"] and quench_index >= 0:
		return "LOCK LINED UP   /   JUMP CLEAR\nLET THE DRILL HIT THE AMBER LOCK"
	if motion in ["rush", "rupture"] and world_impact:
		return "CHARGE MISSED\nSTAND PAST A QUENCH LOCK"
	return "ARMOR SEALED\nSTAND PAST A QUENCH LOCK"

func fire_at(prior: float, at: float, height: float, is_drill: bool) -> void:
	if prior >= at or elapsed < at:
		return
	var muzzle := Vector3(global_position.x + facing * 1.5, floor_height + height, 0.0)
	var shot := RiftProjectile.new()
	shot.boss_status_sector = 1
	get_parent().add_child(shot)
	shot.global_position = muzzle
	shot.speed = 23.0 if is_drill else 12.5 + phase_index() * 1.0
	shot.damage = (24.0 if is_drill else 17.0) + phase_index() * 4.0
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
		"overhead_vent":
			flame.style = FLAME.Style.HIGH_VENT
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
					body.take_boss_hit((21.0 if warden else 29.0) + phase_index() * 3.0, flame.global_position, 1, true)

func show_rush_markers() -> void:
	var lo := minf(rush_origin, rush_destination()) - (2.45 if facing < 0 else 0.75)
	var hi := maxf(rush_origin, rush_destination()) + (2.45 if facing > 0 else 0.75)
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
			material.set_shader_parameter("progress", clampf(elapsed / 0.92, 0.0, 1.0))

func draw_pose(delta: float) -> void:
	var mix_weight := 1.0 - exp(-delta * 17.0)
	var windup := 0.0
	var lean := 0.0
	var rise := 0.0
	var hammer := 0.0
	var recoil := 0.0
	match motion:
		"rush", "rupture":
			windup = clampf(elapsed / 0.68, 0.0, 1.0)
			lean = -0.21 * windup if elapsed < RUSH_WINDUP else 0.26
			rise = -0.13 * windup
			if elapsed > RUSH_END_TIME or world_impact:
				windup = clampf((2.21 - elapsed) / 0.53, 0.0, 1.0)
				lean = 0.12 * windup
				rise *= windup
		"hammer":
			var gather := sin(clampf(elapsed / 0.93, 0.0, 1.0) * PI * 0.5)
			var slam := smoothstep(0.75, 0.95, elapsed) * (1.0 - smoothstep(1.12, 1.67, elapsed))
			lean = gather * -0.15 + slam * 0.47
			rise = gather * 0.08 - slam * 0.25
			hammer = -.66 * gather * (1.0 - slam) + .51 * slam
		"low_volley", "drill_volley", "crossfire":
			windup = smoothstep(0.0, 0.50, elapsed) * (1.0 - smoothstep(1.44, 1.8, elapsed))
			recoil = sin(elapsed * 20.0) * 0.12 * windup
			lean = recoil
		"firewall", "sweep", "pressure_dump", "kiln_backdraft", "casting_wave", "overhead_vent":
			windup = smoothstep(0.0, 0.78, elapsed) * (1.0 - smoothstep(2.18, 2.65, elapsed))
			lean = -0.12 * windup
			rise = -0.14 * windup
	var front_pull := sin(stride) * 0.23 * clampf(absf(move_phase) * 0.50, 0.0, 1.0)
	armor.rotation.y = lerpf(armor.rotation.y, facing * BOSS_SIDE_YAW, mix_weight)
	armor.rotation.x = lerpf(armor.rotation.x, lean, mix_weight)
	armor.position.y = lerpf(armor.position.y, rise + absf(front_pull) * 0.195, mix_weight)
	armor.animate(delta, front_pull, windup, hammer, recoil, exposed)

func clear_attack() -> void:
	for flame in zones:
		flame.queue_free()
	zones.clear()
	if is_instance_valid(tracks):
		tracks.queue_free()
		tracks = null
	motion = ""
	exposed = false
	exposed_light.hide()
	window_end = 0.0
	pressure_released = false
	quench_index = -1
	refresh_quench_locks()
	present_purge_valves(false, false)
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
	return [motion, step, elapsed, facing, stride, move_phase, exposed, rush_origin, rush_end, emitters, world_impact, pressure_released, elevations, window_end, quench_index]

func apply_foundry_snapshot(state: Array) -> void:
	if motion != state[0] or step != state[1] or zones.size() != state[9].size():
		clear_attack()
		motion = state[0]
		step = state[1]
		facing = state[3]
		rush_origin = state[7]
		rush_end = state[8]
		quench_index = clampi(int(state[14]), -1, quench_locks.size() - 1) if state.size() > 14 else -1
		for index in state[9].size():
			var emitter: Vector4 = state[9][index]
			var platform_y: float = state[12][index] if state.size() > 12 else floor_height
			add_flame(emitter.x, emitter.y, emitter.z, emitter.w, platform_y)
		if motion in ["rush", "rupture"]:
			show_rush_markers()
	var delta := clampf(float(state[2]) - elapsed, 0.04, 0.11)
	elapsed = state[2]
	facing = state[3]
	stride = state[4]
	move_phase = state[5]
	exposed = state[6]
	exposed_light.visible = exposed
	world_impact = state[10]
	pressure_released = state[11] if state.size() > 11 else false
	window_end = state[13] if state.size() > 13 else elapsed
	quench_index = clampi(int(state[14]), -1, quench_locks.size() - 1) if state.size() > 14 else -1
	refresh_quench_locks()
	present_purge_valves(not pressure_released and motion == "kiln_backdraft" and elapsed < backdraft_warning(), false)
	draw_pose(delta)
	advance_flames(false)
	update_rush_markers()
