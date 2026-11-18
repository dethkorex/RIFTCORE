extends Combatant

# Each guard shares basic movement and gets a dedicated sector attack.
const TITLES := [
	"Kiln Warden", "Briar Sentinel", "Rime Keeper", "Surge Diver", "Glyph Jackal",
	"Jet Talon", "Culture Breaker", "Prism Relay", "Magnet Mauler", "Null Marshal",
]
const SIGNATURES := [
	"KILN PURGE", "BRIAR ERUPTION", "ICICLE DROP", "CROSSFIRE",
	"GLYPH TRAP", "DIVE BOMB", "SPORE RAIN", "PRISM SWEEP", "MAGNET SLAM", "NULL LANES",
]
const MODELS := [
	preload("res://assets/enemies/redesign_v3/heavy.glb"),
	preload("res://assets/machine_jungle/enemies/bark_bulwark.glb"),
	preload("res://assets/campaign/frozen_reactor/enemies/heavy.glb"),
	preload("res://assets/campaign/abyssal_plant/enemies/quad.glb"),
	preload("res://assets/campaign/buried_archives/enemies/scout.glb"),
	preload("res://assets/campaign/sky_dock/enemies/flyer.glb"),
	preload("res://assets/campaign/biolab/enemies/heavy.glb"),
	preload("res://assets/campaign/orbital_array/enemies/turret.glb"),
	preload("res://assets/campaign/scrapyard_expanse/enemies/heavy.glb"),
	preload("res://assets/campaign/riftcore_nexus/enemies/quad.glb"),
]
const BURST := preload("res://scripts/pit_burst.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const ATTACK_FX := preload("res://scripts/attack_fx.gd")
const JungleRig := preload("res://scripts/jungle_boss_rig.gd")
const SeedAnchor := preload("res://scripts/briar_seed_anchor.gd")
const JUNGLE_FX := preload("res://scripts/jungle_boss_fx.gd")
const BRIAR_MODEL := preload("res://assets/machine_jungle/enemies/briar_sentinel_tripo.glb")
const BRIAR_MOTIONS := {"signature": JungleRig.Motion.ERUPT, "volley": JungleRig.Motion.VOLLEY, "charge": JungleRig.Motion.CHARGE}
const BRIAR_ARMOR_THRESHOLDS := [0.67, 0.32]

var sector := 1
var accent := Color.ORANGE
var target: RiftPlayer
var faction := "enemy"
var active := false
var floor_y := 0.0
var left := 0.0
var right := 0.0
var facing := -1.0
var aim := Vector3.ZERO
var locked_direction := -1.0
var cooldown := 0.9
var difficulty_mode := 0
var contact_lock := 0.0
var elapsed := 0.0
var charge_time := 0.0
var dive_x := 0.0
var turn := 0
var attack := ""
var warning: Node3D
var armor: Node3D
var skin: Node3D
var chassis_height := 1.05
var core: MeshInstance3D
var zones: Array[Vector3] = []
var jungle_rig: JungleRig
var windup_duration := 0.0
var pose_recovery := 0.0
var previous_motion := JungleRig.Motion.IDLE
var stagger := 0.0
var root_anchor: SeedAnchor
var root_phase := 0
var exposed := false
var anchor_sites: Array[Vector3] = []
var briar_core_light: OmniLight3D
var briar_core_halo: MeshInstance3D
var briar_charge_fx: Node3D
var last_root_strike: Array = []
var shown_briar_windup := -1
var shown_root_strike := -1
var briar_damage_scale := 1.0
var briar_damage_taken := 1.0

static func for_sector(number: int, tint: Color, weakness: String, gate_position: Vector3, exit_x: float) -> Combatant:
	if number == 1:
		return preload("res://scenes/levels/kiln_warden.tscn").instantiate() as Combatant
	var guard: Combatant = load("res://scripts/sector_miniboss.gd").new()
	guard.configure(number, tint, weakness, gate_position, exit_x)
	return guard

func configure(number: int, tint: Color, weakness: String, gate_position: Vector3, exit_x: float) -> void:
	sector = number
	accent = tint
	max_health = 825.0 if sector == 2 else 315.0 + 66.0 * (sector - 1)
	weakness_weapon = weakness
	fire_weakness = 1.38 if sector in [2, 3] else 1.0
	floor_y = gate_position.y
	left = gate_position.x + 2.65
	right = exit_x - 2.65

func configure_difficulty(mode: int) -> void:
	difficulty_mode = mode
	if sector == 2:
		briar_damage_scale = Difficulty.jungle_boss_damage_scale(mode)
		briar_damage_taken = Difficulty.jungle_boss_damage_taken(mode, true)

func _ready() -> void:
	super._ready()
	ignore_arena_access_decks()
	add_to_group("damageable_enemies")
	var body := CollisionShape3D.new()
	var hull := CapsuleShape3D.new()
	hull.radius = 0.66
	hull.height = 2.1
	body.shape = hull
	add_child(body)
	if sector == 2:
		jungle_rig = JungleRig.new()
		jungle_rig.name = "Armor"
		armor = jungle_rig
		add_child(armor)
		skin = BRIAR_MODEL.instantiate() as Node3D
		armor.add_child(skin)
		jungle_rig.bind_model(skin, 1.95, chassis_height, true)
		root_anchor = SeedAnchor.new()
		root_anchor.name = "SeedAnchor"
		root_anchor.armor_owner = self
		root_anchor.top_level = true
		add_child(root_anchor)
		root_anchor.uprooted.connect(expose_briar)
		briar_core_light = OmniLight3D.new()
		briar_core_light.position = Vector3(0, .34, .92)
		briar_core_light.omni_range = 2.4
		briar_core_light.light_energy = 0.0
		add_child(briar_core_light)
		briar_core_halo = JUNGLE_FX.core_halo(self, Vector3(0, .34, .92), .38)
		briar_charge_fx = JUNGLE_FX.warning_field(self, global_position, 2.1, 2.2, JUNGLE_FX.DANGER, .25, 2.0)
		briar_charge_fx.hide()
		for marker_name in ["BriarSeedWest", "BriarSeedCanopy", "BriarSeedEast"]:
			var site := get_parent().get_parent().get_node("MARKERS/" + marker_name) as Marker3D
			anchor_sites.append(site.global_position)
		for deck in get_tree().get_nodes_in_group("factory_one_way"):
			add_collision_exception_with(deck)
		died.connect(break_apart)
		return
	armor = Node3D.new()
	add_child(armor)
	skin = MODELS[sector - 1].instantiate() as Node3D
	armor.add_child(skin)
	var mesh_bounds := AABB()
	var found_mesh := false
	for child in skin.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.mesh:
			continue
		var bounds := (skin.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		mesh_bounds = mesh_bounds.merge(bounds) if found_mesh else bounds
		found_mesh = true
	var fit := 1.95 / maxf(mesh_bounds.size.y, 0.3)
	skin.scale = Vector3.ONE * fit
	var center := mesh_bounds.get_center()
	skin.position = Vector3(-center.x * fit, -chassis_height - mesh_bounds.position.y * fit, -center.z * fit)
	armor.rotation.y = facing * 0.90
	preload("res://scripts/boss_armor_kit.gd").mount(armor, sector, true, accent)
	core = RiftProjectile.part(armor, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(accent, 2.2), Vector3(0, 0.65, 0.65), Vector3(0.24, 0.24, 0.17))
	for side in [-1.0, 1.0]:
		var band := RiftProjectile.part(armor, BoxMesh.new(), RiftProjectile.light_paint(accent, 1.6), Vector3(side * 0.55, 0.65, 0.44), Vector3(0.12, 0.47, 0.12))
		band.rotation.z = side * -0.32
	for deck in get_tree().get_nodes_in_group("factory_one_way"):
		add_collision_exception_with(deck)
	died.connect(break_apart)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if active:
		if jungle_rig:
			if not exposed or invulnerable_time > 0.0 or health <= 0.0 or amount <= 0.0:
				return
			amount *= briar_damage_taken
			if root_phase < BRIAR_ARMOR_THRESHOLDS.size():
				var limit := max_health * float(BRIAR_ARMOR_THRESHOLDS[root_phase])
				if health - amount <= limit:
					amount = health - limit
					root_phase += 1
					grow_seed_anchor()
		if jungle_rig and attack.is_empty() and charge_time <= 0.0:
			stagger = 0.13
		super.take_damage(amount, source_position)

func apply_burn_tick() -> void:
	if jungle_rig:
		take_damage(burn_power)
	else:
		super.apply_burn_tick()

func damage_on_contact(player: RiftPlayer) -> void:
	if active and contact_lock <= 0.0:
		contact_lock = 0.55
		var power := (34.0 if charge_time > 0.0 else 22.0) * briar_damage_scale if jungle_rig else 11.0 + sector
		player.take_damage(power, global_position)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or target.health <= 0.0:
		return
	if root_anchor and root_phase == 0 and root_anchor.dormant and not exposed:
		grow_seed_anchor()
	elapsed += delta
	contact_lock = maxf(0.0, contact_lock - delta)
	cooldown -= delta
	charge_time = maxf(0.0, charge_time - delta)
	var distance := target.global_position.x - global_position.x
	if attack.is_empty() and charge_time <= 0.0 and absf(distance) > 0.3:
		facing = signf(distance)
	var walk := facing * (2.9 + sector * 0.19) * Difficulty.boss_pursuit_scale(difficulty_mode, true) if absf(distance) > 3.25 and attack.is_empty() else 0.0
	if charge_time > 0.0:
		walk = locked_direction * (18.0 + 1.65 * difficulty_mode)
		if sector == 6 and charge_time > 0.0 and not is_zero_approx(dive_x):
			walk = clampf((dive_x - global_position.x) / maxf(charge_time, 0.08), -32.0, 32.0)
	elif not is_zero_approx(dive_x):
		dive_x = 0.0
	velocity.x = move_toward(velocity.x, walk, delta * (95.0 if charge_time > 0.0 else 22.0))
	velocity.y -= 30.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, left, right)
	if jungle_rig:
		update_briar_pose(delta)
		update_briar_vfx()
	else:
		armor.rotation.y = lerp_angle(armor.rotation.y, facing * 1.03, minf(12.0 * delta, 1.0))
		armor.rotation.z = sin(elapsed * 11.0) * minf(absf(velocity.x) * 0.012, 0.12)
		core.scale = Vector3(0.24, 0.24, 0.17) * (1.0 if attack.is_empty() else 1.5 + sin(elapsed * 25.0) * 0.18)
	if cooldown > 0.0 or charge_time > 0.0:
		if attack == "signature" and sector == 9:
			target.velocity.x = move_toward(target.velocity.x, signf(global_position.x - target.global_position.x) * 5.5, 21.0 * delta)
		return
	if attack.is_empty():
		telegraph()
	else:
		strike()
		attack = ""
		cooldown = (0.72 if health > max_health * 0.55 else 0.42) * Difficulty.boss_recovery_scale(difficulty_mode, true)

func grow_seed_anchor() -> void:
	exposed = false
	root_anchor.present(anchor_sites[root_phase], 2 + difficulty_mode, true)

func expose_briar() -> void:
	exposed = true
	attack = ""
	charge_time = 0.0
	cooldown = 0.64
	if is_instance_valid(warning):
		warning.queue_free()
	JUNGLE_FX.burst(self, global_position + Vector3(0, .42, .76), JUNGLE_FX.OPEN, 1.28, 18)

func encounter_status() -> String:
	if not jungle_rig:
		return ""
	return "CORE EXPOSED" if exposed else "ROOT ARMOR SEALED\nDESTROY THE SEED ANCHOR"

func jungle_snapshot() -> Array:
	var root_strike := last_root_strike.slice(0, 2) if not last_root_strike.is_empty() and elapsed - float(last_root_strike[2]) < .32 else []
	return [jungle_rig.snapshot(), exposed, root_anchor.global_position, root_anchor.durability,
		turn, attack, cooldown, aim, locked_direction, charge_time, root_strike]

func apply_jungle_snapshot(state: Array) -> void:
	if state.size() >= 4 and jungle_rig:
		jungle_rig.apply_snapshot(state[0])
		if not exposed and state[1]:
			JUNGLE_FX.burst(self, global_position + Vector3(0, .42, .76), JUNGLE_FX.OPEN, 1.28, 18)
		exposed = state[1]
		if root_anchor.durability != int(state[3]) or root_anchor.global_position != state[2]:
			root_anchor.present(state[2], state[3], false)
		if state.size() >= 11:
			if state[5] == "" and is_instance_valid(warning):
				warning.queue_free()
			elif state[5] != "" and shown_briar_windup != int(state[4]):
				shown_briar_windup = state[4]
				show_briar_warning(state[5], state[7], state[8], state[6])
			locked_direction = state[8]
			charge_time = state[9]
			var root_strike: Array = state[10]
			if not root_strike.is_empty() and int(root_strike[0]) > shown_root_strike:
				shown_root_strike = root_strike[0]
				draw_root_strike(root_strike[1])
		update_briar_vfx()

func update_briar_vfx() -> void:
	briar_core_light.light_color = JUNGLE_FX.OPEN if exposed else Color("8aff55")
	briar_core_light.light_energy = (1.4 + sin(Time.get_ticks_msec() * .010) * .34) if exposed else .31
	briar_core_halo.visible = exposed
	briar_core_halo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * .007) * .10)
	briar_charge_fx.visible = charge_time > 0.0
	if briar_charge_fx.visible:
		briar_charge_fx.global_position = Vector3(global_position.x - locked_direction * .97, floor_y + .095, 0)

func show_briar_warning(move: String, point: Vector3, direction: float, duration: float) -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	match move:
		"signature":
			warning = JUNGLE_FX.warning_field(self, Vector3(clampf(point.x, left - .45, right + .45), floor_y + .095, 0), 2.9, 3.0, JUNGLE_FX.DANGER, duration)
		"charge":
			var end := clampf(global_position.x + direction * 12.0, left, right)
			warning = JUNGLE_FX.warning_field(self, Vector3((end + global_position.x) * .5, floor_y + .095, 0), maxf(1.2, absf(end - global_position.x)), 2.6, JUNGLE_FX.DANGER, duration, direction)
		"volley":
			warning = JUNGLE_FX.at_world(self, global_position + Vector3(direction * .87, .18, 0))
			ATTACK_FX.charge(warning, warning.global_position, accent, duration)

func draw_root_strike(zone: Vector3) -> void:
	JUNGLE_FX.roots(self, Vector3(zone.x, floor_y + .04, 0), zone.y * 2.0, zone.z, 7)

func update_briar_pose(delta: float) -> void:
	pose_recovery = maxf(0.0, pose_recovery - delta)
	stagger = maxf(0.0, stagger - delta)
	var motion := JungleRig.Motion.IDLE
	var weight := 0.0
	if charge_time > 0.0:
		motion = JungleRig.Motion.CHARGE
		weight = 1.0
	elif not attack.is_empty():
		motion = BRIAR_MOTIONS[attack]
		weight = clampf(1.0 - cooldown / windup_duration, 0.16, 1.0)
	elif pose_recovery > 0.0:
		motion = previous_motion
		weight = pose_recovery / 0.26
	elif stagger > 0.0:
		motion = JungleRig.Motion.STAGGER
		weight = stagger / 0.13
	jungle_rig.set_combat_pose(facing, absf(velocity.x), motion, weight)

func telegraph() -> void:
	var pattern := ["signature", "volley", "signature", "charge"]
	if difficulty_mode == Difficulty.HARD:
		pattern = ["signature", "charge", "volley", "signature", "charge"]
	elif difficulty_mode == Difficulty.NIGHTMARE:
		pattern = ["signature", "charge", "signature", "volley", "charge", "volley"]
	attack = pattern[turn % pattern.size()]
	turn += 1
	aim = target.global_position
	locked_direction = facing
	cooldown = Difficulty.windup_time(0.82 if attack == "signature" else 0.63, difficulty_mode)
	windup_duration = cooldown
	zones.clear()
	if jungle_rig:
		if attack == "signature":
			zones.append(Vector3(clampf(aim.x, left - .45, right + .45), 1.45, 2.5))
		show_briar_warning(attack, aim, locked_direction, cooldown)
		RiftAudio.play_effect(&"titan_windup")
		return
	warning = Node3D.new()
	add_child(warning)
	warning.top_level = true
	warning.global_position = Vector3(0, floor_y + 0.075, 0)
	if attack == "signature":
		var label := Label3D.new()
		label.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
		label.text = SIGNATURES[sector - 1]
		label.modulate = accent.lerp(Color.WHITE, 0.45)
		label.pixel_size = 0.0046
		label.font_size = 39
		label.position = Vector3(global_position.x, global_position.y - floor_y + 1.67, 0.38)
		warning.add_child(label)
		match sector:
			3:
				for offset in [-3.25, 0.0, 3.25]:
					mark(aim.x + offset, 0.65, 6.0)
			5:
				mark(aim.x - 2.35, 1.12, 1.65)
				mark(aim.x + 2.35, 1.12, 1.65)
			6: mark(clampf(aim.x, global_position.x - 11.5, global_position.x + 11.5), 1.9, 2.3)
			7:
				mark(aim.x, 1.65, 4.6)
				mark(aim.x + locked_direction * 4.1, 1.25, 4.6)
			9: mark(global_position.x, 3.2, 2.05)
			10:
				mark((left + aim.x) * 0.5 - 1.05, maxf(0.4, (aim.x - left) * 0.5 - 1.05), 1.95)
				mark((right + aim.x) * 0.5 + 1.05, maxf(0.4, (right - aim.x) * 0.5 - 1.05), 1.95)
			_: mark((left + right) * 0.5, (right - left) * 0.5, 1.55)
	elif attack == "charge":
		var end := clampf(global_position.x + locked_direction * 12.0, left, right)
		mark((global_position.x + end) * 0.5, maxf(0.6, absf(end - global_position.x) * 0.5), 1.85)
	else:
		var ray := RiftProjectile.part(warning, BoxMesh.new(), RiftProjectile.light_paint(accent, 1.3),
			Vector3((global_position.x + aim.x) * 0.5, aim.y - floor_y, 0), Vector3(maxf(absf(aim.x - global_position.x), 0.7), 0.06, 0.18))
		ray.transparency = 0.3
	RiftAudio.play_effect(&"titan_windup")

func mark(x: float, radius: float, height: float) -> void:
	x = clampf(x, left - 0.45, right + 0.45)
	zones.append(Vector3(x, radius, height))
	var footprint := Node3D.new()
	warning.add_child(footprint)
	footprint.position.x = x
	ATTACK_FX.telegraph(footprint, radius * 2.0, accent, cooldown)

func strike() -> void:
	if jungle_rig:
		previous_motion = BRIAR_MOTIONS[attack]
		pose_recovery = 0.26
	if is_instance_valid(warning):
		warning.queue_free()
	var power := 32.0 * briar_damage_scale if jungle_rig else 15.0 + sector * 1.65
	match attack:
		"charge":
			charge_time = 0.53
		"volley":
			var muzzle := global_position + Vector3(locked_direction * 0.87, 0.18, 0)
			var direction := (aim - muzzle).normalized()
			var spread := [-0.25, -0.12, 0.0, 0.12, 0.25] if difficulty_mode == Difficulty.NIGHTMARE else [-0.14, 0.0, 0.14]
			for angle in spread:
				fire(muzzle, direction.rotated(Vector3.BACK, angle), power * 0.7, 16.0 + sector * 0.6)
		"signature":
			signature(power)

func signature(power: float) -> void:
	match sector:
		1:
			fire(Vector3(global_position.x + locked_direction, floor_y + 0.62, 0), Vector3(locked_direction, 0, 0), power * 1.4, 23.0, true)
		2:
			var zone := zones[0]
			last_root_strike = [turn, zone, elapsed]
			draw_root_strike(zone)
			if absf(target.global_position.x - zone.x) < zone.y and target.global_position.y < floor_y + zone.z + .26:
				target.take_boss_hit(power * 1.25, Vector3(zone.x, floor_y, 0), sector, true)
		3:
			for zone in zones:
				fire(Vector3(zone.x, floor_y + 6.3, 0), Vector3.DOWN, power, 18.5)
		4:
			fire(Vector3(left, floor_y + 0.53, 0), Vector3.RIGHT, power, 21.0)
			fire(Vector3(right, floor_y + 1.9, 0), Vector3.LEFT, power, 17.0)
		6:
			dive_x = clampf(zones[0].x, left, right)
			velocity.y = 7.2
			charge_time = 0.48
			pulse(zones[0], power, 0.48)
		7:
			for zone in zones:
				for offset in [-0.8, 0.0, 0.8]:
					fire(Vector3(zone.x + offset, floor_y + 5.6 + absf(offset), 0), Vector3(offset * 0.15, -1, 0), power * 0.85, 12.0)
		8:
			var muzzle := global_position + Vector3(locked_direction, 0.18, 0)
			for step in range(6):
				var ray := Vector3(locked_direction, (step - 2) * 0.26, 0)
				get_tree().create_timer(0.08 * step, false).timeout.connect(func():
					if active:
						fire(muzzle, ray, power * 0.8, 20.0)
				)
		_:
			for zone in zones:
				pulse(zone, power * 1.25, 0.0)

func pulse(zone: Vector3, power: float, delay: float) -> void:
	var impact := RiftProjectile.part(self, BoxMesh.new(), RiftProjectile.light_paint(accent, 2.5),
		Vector3.ZERO, Vector3(zone.y * 1.9, zone.z, 0.56))
	impact.top_level = true
	impact.global_position = Vector3(zone.x, floor_y + zone.z * 0.5, 0)
	impact.hide()
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		if not active:
			return
		impact.show()
		if absf(target.global_position.x - zone.x) < zone.y and target.global_position.y < floor_y + zone.z + 0.26:
			target.take_boss_hit(power, Vector3(zone.x, floor_y, 0), sector, true)
	)
	tween.tween_property(impact, "transparency", 1.0, 0.32)
	tween.tween_callback(impact.queue_free)

func fire(at: Vector3, direction: Vector3, power: float, speed: float, drill := false) -> void:
	var shot := RiftProjectile.new()
	shot.boss_status_sector = sector
	shot.collision_layer = 0
	shot.collision_mask = 1 | 128
	shot.damage = power
	shot.speed = speed
	shot.lifetime = 3.0
	shot.setup(direction, faction, ATTACK_FX.tint_for(sector), drill, false, false, sector, 3)
	get_parent().add_child(shot)
	shot.global_position = at
	ATTACK_FX.muzzle(get_parent(), at, accent, 0.63)

func break_apart() -> void:
	active = false
	BURST.spawn.call_deferred(get_parent(), global_position, accent, .5)
	set_deferred("collision_layer", 0)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	queue_free()
