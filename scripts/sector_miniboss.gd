extends Combatant

# Each guard shares basic movement and gets a dedicated sector attack.
const TITLES := [
	"Drill Sergeant", "Briar Sentinel", "Rime Keeper", "Surge Diver", "Glyph Jackal",
	"Jet Talon", "Culture Breaker", "Prism Relay", "Magnet Mauler", "Null Marshal",
]
const SIGNATURES := [
	"DRILL RUN", "BRIAR ERUPTION", "ICICLE DROP", "CROSSFIRE",
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
const ATTACK_FX := preload("res://scripts/attack_fx.gd")
const REWARD := preload("res://assets/pickups/xp_orb.tscn")

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

func configure(number: int, tint: Color, weakness: String, gate_position: Vector3, exit_x: float) -> void:
	sector = number
	accent = tint
	max_health = 315.0 + 66.0 * (sector - 1)
	weakness_weapon = weakness
	fire_weakness = 1.38 if sector in [2, 3] else 1.0
	floor_y = gate_position.y
	left = gate_position.x + 2.65
	right = exit_x - 2.65

func _ready() -> void:
	super._ready()
	add_to_group("damageable_enemies")
	var body := CollisionShape3D.new()
	var hull := CapsuleShape3D.new()
	hull.radius = 0.66
	hull.height = 2.1
	body.shape = hull
	add_child(body)
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
	core = RiftProjectile.part(armor, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(accent, 2.2), Vector3(0, 0.65, 0.65), Vector3(0.24, 0.24, 0.17))
	for side in [-1.0, 1.0]:
		var band := RiftProjectile.part(armor, BoxMesh.new(), RiftProjectile.light_paint(accent, 1.6), Vector3(side * 0.55, 0.65, 0.44), Vector3(0.12, 0.47, 0.12))
		band.rotation.z = side * -0.32
	for deck in get_tree().get_nodes_in_group("factory_one_way"):
		add_collision_exception_with(deck)
	died.connect(break_apart)

func take_damage(amount: float, source_position := Vector3.ZERO) -> void:
	if active:
		super.take_damage(amount, source_position)

func damage_on_contact(player: RiftPlayer) -> void:
	if active and contact_lock <= 0.0:
		contact_lock = 0.55
		player.take_damage(11.0 + sector, global_position)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target) or target.health <= 0.0:
		return
	elapsed += delta
	contact_lock = maxf(0.0, contact_lock - delta)
	cooldown -= delta
	charge_time = maxf(0.0, charge_time - delta)
	var distance := target.global_position.x - global_position.x
	if attack.is_empty() and charge_time <= 0.0 and absf(distance) > 0.3:
		facing = signf(distance)
	var walk := facing * (2.9 + sector * 0.19) if absf(distance) > 3.8 and attack.is_empty() else 0.0
	if charge_time > 0.0:
		walk = locked_direction * 18.0
		if sector == 6 and charge_time > 0.0 and not is_zero_approx(dive_x):
			walk = clampf((dive_x - global_position.x) / maxf(charge_time, 0.08), -32.0, 32.0)
	elif not is_zero_approx(dive_x):
		dive_x = 0.0
	velocity.x = move_toward(velocity.x, walk, delta * (95.0 if charge_time > 0.0 else 22.0))
	velocity.y -= 30.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, left, right)
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
		cooldown = 0.72 if health > max_health * 0.45 else 0.40

func telegraph() -> void:
	var pattern := ["signature", "volley", "signature", "charge"]
	attack = pattern[turn % pattern.size()]
	turn += 1
	aim = target.global_position
	locked_direction = facing
	cooldown = 0.82 if attack == "signature" else 0.63
	warning = Node3D.new()
	add_child(warning)
	warning.top_level = true
	warning.global_position = Vector3(0, floor_y + 0.075, 0)
	zones.clear()
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
			2: mark(aim.x, 1.45, 2.5)
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
	RiftProjectile.part(warning, BoxMesh.new(), RiftProjectile.light_paint(accent, 1.5),
		Vector3(x, 0, 0), Vector3(radius * 2.0, 0.045, 1.38))
	for edge in [-1.0, 1.0]:
		var column := RiftProjectile.part(warning, BoxMesh.new(), RiftProjectile.light_paint(accent, 1.2),
			Vector3(x + edge * radius * 0.98, height * 0.25, 0), Vector3(0.045, height * 0.5, 0.09))
		column.transparency = 0.42

func strike() -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	var power := 15.0 + sector * 1.65
	match attack:
		"charge":
			charge_time = 0.53
		"volley":
			var muzzle := global_position + Vector3(locked_direction * 0.87, 0.18, 0)
			var direction := (aim - muzzle).normalized()
			for angle in [-0.14, 0.0, 0.14]:
				fire(muzzle, direction.rotated(Vector3.BACK, angle), power * 0.7, 16.0 + sector * 0.6)
		"signature":
			signature(power)

func signature(power: float) -> void:
	match sector:
		1:
			fire(Vector3(global_position.x + locked_direction, floor_y + 0.62, 0), Vector3(locked_direction, 0, 0), power * 1.4, 23.0, true)
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
			target.take_damage(power, Vector3(zone.x, floor_y, 0))
	)
	tween.tween_property(impact, "transparency", 1.0, 0.32)
	tween.tween_callback(impact.queue_free)

func fire(at: Vector3, direction: Vector3, power: float, speed: float, drill := false) -> void:
	var shot := RiftProjectile.new()
	shot.collision_layer = 0
	shot.collision_mask = 1
	shot.damage = power
	shot.speed = speed
	shot.lifetime = 3.0
	shot.setup(direction, faction, ATTACK_FX.tint_for(sector), drill, false, false, sector, 3)
	get_parent().add_child(shot)
	shot.global_position = at
	ATTACK_FX.muzzle(get_parent(), at, accent, 0.63)

func break_apart() -> void:
	active = false
	var xp := REWARD.instantiate()
	xp.xp_amount = 55 + sector * 9
	xp.large = true
	xp.position = Vector3(global_position.x, floor_y + 0.42, 0)
	get_parent().add_child.call_deferred(xp)
	var burst := BURST.new()
	get_parent().add_child.call_deferred(burst)
	burst.set_deferred("global_position", global_position)
	burst.ignite.call_deferred(accent)
	get_tree().create_timer(0.5, false).timeout.connect(burst.queue_free)
	set_deferred("collision_layer", 0)
	RiftAudio.play_effect(&"enemy_break")
	hide()
	queue_free()
