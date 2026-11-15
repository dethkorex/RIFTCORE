class_name RiftProjectile
extends Area3D

const HALO := preload("res://assets/pickups/pickup_halo.gdshader")
const PACK_VFX := preload("res://scripts/pack_combat_vfx.gd")
const ATTACK_FX := preload("res://scripts/attack_fx.gd")
static var paint_cache: Dictionary = {}
static var mesh_cache: Dictionary = {}
var direction := Vector3.RIGHT
var speed := 22.0
var damage := 18.0
var lifetime := 2.0
var owner_faction := "player"
var spent := false
var palette := Color.CYAN
var skin: Node3D
var spinner: Node3D
var is_charged := false
var is_magma := false
var burn_power := 0.0
var clock := 0.0
var weapon_id := ""
var launch_profile := 0
var range_remaining := INF
var acceleration := 0.0
var vertical_drift := 0.0
var heavy_report := false
var pierces := 0
var struck: Dictionary = {}
var source_operator := 0
var splits_on_impact := false
var core_rebated := false
signal reward_hit(at: Vector3, links: PackedVector3Array)
signal reward_spent(at: Vector3)

func setup(dir: Vector3, faction: String, tint: Color = Color.CYAN, drill := false, charged := false, magma := false, sector := 0, role := 0, saber := false) -> void:
	direction = dir.normalized()
	owner_faction = faction
	launch_profile = -2 if saber else (-1 if drill else (sector << 3) | role)
	if faction == "enemy":
		match sector:
			3: acceleration = 16.0
			4: vertical_drift = -0.8
			5: acceleration = -4.2
			6: acceleration = 8.0
			8: vertical_drift = -0.32
			9: vertical_drift = -0.46 if role == 2 else 0.0
			10: acceleration = 6.2
		heavy_report = drill or charged or role == 4
	add_to_group(&"rift_projectile")
	palette = tint
	is_charged = charged
	is_magma = magma
	skin = Node3D.new()
	add_child(skin)
	var up := Vector3.UP if absf(direction.y) < 0.96 else Vector3.BACK
	skin.basis = Basis.looking_at(direction, up, true)
	var hot := tint.lerp(Color.WHITE, 0.79)
	if saber:
		ATTACK_FX.charged_saber(skin, tint)
	elif drill:
		spinner = drill_visual(skin, tint, 1.0)
		var jet := part(skin, cached_mesh("Orb"), light_paint(hot, 2.0), Vector3(0, 0, -0.47), Vector3(0.12, 0.12, 0.23))
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif sector > 0:
		ATTACK_FX.projectile(skin, sector, role, charged)
	elif magma:
		var width := 0.56 if charged else 0.31
		part(skin, cached_mesh("Orb"), light_paint(Color("e84612"), 1.8), Vector3.ZERO, Vector3(width, width, width * 1.12))
		part(skin, cached_mesh("Orb"), light_paint(Color("ffad38"), 2.5), Vector3(0, 0, width * 0.31), Vector3(width * 0.65, width * 0.65, width * 0.82))
		spinner = Node3D.new()
		skin.add_child(spinner)
		for i in range(5):
			var angle := TAU * i / 5.0
			var tuft := part(spinner, cached_mesh("Orb"), light_paint(Color("ff7021"), 1.85), Vector3(sin(angle) * width * 0.73, cos(angle) * width * 0.73, -width * 0.41), Vector3(width * 0.26, width * 0.32, width * 1.12))
			tuft.rotation.z = angle

	elif not weapon_id.is_empty():
		build_suit_projectile(hot)
	else:
		var caliber := 2.35 if charged else 1.0
		var narrow := 0.14 * caliber
		part(skin, cached_mesh("Orb"), light_paint(tint, 2.05), Vector3.ZERO, Vector3(narrow, narrow, 0.33 * caliber))
		part(skin, cached_mesh("Orb"), light_paint(hot, 2.4), Vector3(0, 0, 0.10 * caliber), Vector3(narrow * 0.62, narrow * 0.62, 0.21 * caliber))
		var wake := part(skin, cached_mesh("Wake"), light_paint(tint.darkened(0.22), 1.05), Vector3(0, 0, -0.28 * caliber), Vector3(0.095, caliber * 0.69, 0.095) * (1.0 if not charged else 1.25))
		wake.rotation.x = PI * 0.5
		if charged:
			spinner = Node3D.new()
			skin.add_child(spinner)
			for i in range(2):
				var coil := part(spinner, cached_mesh("Ring"), light_paint(tint, 1.65), Vector3(0, 0, i * -0.25 + 0.17), Vector3.ONE * 0.68)
				coil.rotation.x = PI * (0.43 + i * 0.22)
	add_glow(self, tint, (2.05 if charged else 1.29) if magma else (1.65 if charged else (1.12 if drill else 0.76)))
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = (0.57 if charged else 0.31) if magma else (0.48 if charged else (0.26 if drill else 0.18))
	if saber or weapon_id == "gale_edge":
		var arc := BoxShape3D.new()
		arc.size = Vector3(1.06, 1.92, .66) if saber else Vector3(.42, .85 if charged else .61, .47)
		collision.shape = arc
		collision.basis = skin.basis
	else:
		collision.shape = sphere
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if clock == 0.0 and owner_faction == "enemy":
		RiftAudio.enemy_shot(global_position, heavy_report)
	var step := minf(speed * delta, range_remaining)
	position += direction * step + Vector3.UP * vertical_drift * clock * delta
	range_remaining -= step
	speed = maxf(4.0, speed + acceleration * delta)
	lifetime -= delta
	clock += delta
	if is_instance_valid(spinner):
		spinner.rotate_z(delta * (11.0 if is_charged else 24.0))
	if lifetime <= 0.0 or range_remaining <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if spent:
		return
	if body.has_method("hit_by_projectile") and body.hit_by_projectile(self):
		spent = true
		impact()
		return
	if body.has_method("take_damage") and body.get("faction") != owner_faction:
		if struck.has(body.get_instance_id()):
			return
		struck[body.get_instance_id()] = true
		if body.has_method("take_projectile_damage"):
			body.take_projectile_damage(damage)
		else:
			var prior: float = body.health if "health" in body else 0.0
			var combo := 0.0
			if launch_profile == -2 and body is Combatant and body.invulnerable_time <= 0.0 and body.health > 0.0 and ("active" not in body or body.get("active")):
				combo = body.detonate_ally_burn(source_operator)
			var corrosion := 1.0
			if weapon_id == "chimera_burst" and body is Combatant and body.has_meta(&"chimera_mark_until"):
				if int(body.get_meta(&"chimera_mark_until")) > Time.get_ticks_msec():
					corrosion = 1.35 if is_charged else 1.22
			if is_magma and body.has_method("take_fire_damage"):
				body.take_fire_damage(damage + combo, global_position)
			elif not weapon_id.is_empty() and body.has_method("take_element_damage"):
				body.take_element_damage(damage * corrosion, global_position, weapon_id)
			else:
				body.take_damage(damage + combo, global_position)
			if combo > 0.0:
				spawn_impact(true)
			elif is_magma and burn_power > 0.0 and body.has_method("ignite") and body.health < prior:
				body.ignite(burn_power, 3.0, source_operator)
			if splits_on_impact and "health" in body and body.health < prior:
				splits_on_impact = false
				spawn_prism_fragments.call_deferred(global_position, body.get_instance_id())
			if "health" in body and body.health < prior:
				apply_reward_effect(body)
		if pierces > 0:
			if weapon_id in ["frost_lance", "data_lance", "core_override"]:
				spawn_impact(false)
			pierces -= 1
			damage *= 0.93 if weapon_id == "data_lance" and is_charged else 0.78
			return
		spent = true
		impact()
	elif body is StaticBody3D or body is AnimatableBody3D:
		spent = true
		impact()

func spawn_prism_fragments(at: Vector3, original: int) -> void:
	for slope in [-0.22, 0.22]:
		var fragment := RiftProjectile.new()
		fragment.collision_mask = collision_mask
		fragment.damage = damage * 0.57
		fragment.speed = 25.0
		fragment.range_remaining = 8.5
		fragment.struck[original] = true
		get_parent().add_child(fragment)
		fragment.global_position = at + direction * 0.32
		fragment.setup(Vector3(direction.x, slope, 0.0), "player", Color("b9a5ff"))

func apply_reward_effect(body: Node3D) -> void:
	match weapon_id:
		"thorn_swarm":
			if is_charged:
				spread_reward_impact(body, 2.8)
		"magma_breaker":
			if is_charged:
				spread_reward_impact(body, 1.8)
		"frost_lance":
			root_mobile(body, 1.05 if is_charged else 0.40)
		"tidal_arc":
			chain_reward_lightning(body)
		"gale_edge":
			if movable_target(body):
				body.recoil = direction.x * (11.5 if is_charged else 7.5)
		"chimera_burst":
			if body is Combatant:
				body.corrosion_left = 3.7
		"singularity_shot":
			spread_reward_impact(body, 4.0 if is_charged else 2.7)
		"scrap_reaver":
			spread_reward_impact(body, 3.65 if is_charged else 2.25)
		"core_override":
			if is_charged and not core_rebated and body.health <= 0.0:
				var operator := instance_from_id(source_operator) as RiftPlayer
				if is_instance_valid(operator) and operator.health > 0.0:
					core_rebated = true
					operator.restore_energy(9.0, true)

func movable_target(target: Node3D) -> bool:
	return target is WalkerBot and not target.planted_override and target.variant != WalkerBot.Variant.TURRET

func root_mobile(target: Node3D, duration: float) -> void:
	if movable_target(target) and target.health > 0.0:
		target.stagger_left = maxf(target.stagger_left, duration)
		target.recoil = 0.0

func reward_neighbors(at: Vector3, radius: float, excluded: Array) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(&"damageable_enemies"):
		var target := node as Combatant
		if target and target.health > 0 and not excluded.has(target) and at.distance_squared_to(target.global_position) <= radius * radius:
			var ray := PhysicsRayQueryParameters3D.create(at, target.global_position, 1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				targets.append(target)
	targets.sort_custom(func(a: Combatant, b: Combatant): return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	return targets

func spread_reward_impact(body: Node3D, radius: float) -> void:
	if weapon_id == "thorn_swarm":
		root_mobile(body, 1.6)
	var at := body.global_position
	var targets := reward_neighbors(at, radius, [body])
	var links := PackedVector3Array([at])
	for target in targets.slice(0, 5):
		match weapon_id:
			"magma_breaker":
				target.ignite(burn_power * 0.48, 2.0, source_operator)
			"thorn_swarm":
				target.take_damage(damage * 0.22, at)
				root_mobile(target, 1.3)
			"singularity_shot":
				target.take_damage(damage * 0.44, at)
				if movable_target(target):
					target.recoil = signf(at.x - target.global_position.x) * (11.0 if is_charged else 6.5)
			"scrap_reaver":
				target.take_damage(damage * 0.50, at)
				if movable_target(target):
					target.recoil = signf(target.global_position.x - at.x) * 8.0
		links.append(target.global_position)
	reward_hit.emit(at, links)
	draw_reward_hit.call_deferred(get_parent(), at, palette, weapon_id, links)

func chain_reward_lightning(body: Node3D) -> void:
	var at := body.global_position
	var origin := at
	var used: Array = [body]
	var links := PackedVector3Array([at])
	var power := damage * 0.55
	for index in (4 if is_charged else 2):
		var targets := reward_neighbors(origin, 4.1 if is_charged else 3.25, used)
		if targets.is_empty():
			break
		var next := targets.front() as Combatant
		next.take_damage(power, origin)
		used.append(next)
		origin = next.global_position
		links.append(origin)
		power *= 0.77
	reward_hit.emit(at, links)
	draw_reward_hit.call_deferred(get_parent(), at, palette, weapon_id, links)

func impact() -> void:
	if not weapon_id.is_empty():
		reward_spent.emit(global_position)
	spawn_impact(is_charged)
	queue_free()

static func draw_reward_hit(parent: Node, at: Vector3, tint: Color, weapon: String, links: PackedVector3Array) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var effect := Node3D.new()
	parent.add_child(effect)
	effect.global_position = at
	for index in range(1, links.size()):
		var from := links[index - 1] if weapon == "tidal_arc" else at
		var vector := links[index] - from
		if vector.length() < 0.05:
			continue
		var beam := part(effect, cached_mesh("Orb"), light_paint(tint.lerp(Color.WHITE, 0.38), 2.0),
			from - at + vector * 0.5, Vector3(0.062, 0.062, vector.length() * 0.5))
		var up := Vector3.BACK if absf(vector.normalized().y) > .96 else Vector3.UP
		beam.basis = Basis.looking_at(vector, up) * Basis.from_scale(beam.scale)
	var ring := part(effect, cached_mesh("Ring"), light_paint(tint, 2.15), Vector3.ZERO, Vector3.ONE * 0.2)
	if weapon in ["thorn_swarm", "scrap_reaver", "magma_breaker"]:
		ring.position.y = -0.3
	else:
		ring.rotate_x(PI * 0.48)
	effect.create_tween().tween_property(ring, "scale", Vector3.ONE * (2.45 if weapon == "singularity_shot" else 1.6), 0.26).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	effect.get_tree().create_timer(0.30, false).timeout.connect(effect.queue_free)

static func suit_flash(parent: Node, at: Vector3, tint: Color, charged: bool) -> void:
	var flash := Node3D.new()
	parent.add_child(flash)
	flash.global_position = at
	add_glow(flash, tint, 1.55 if charged else 0.78)
	for index in range(2 if charged else 1):
		var ring := part(flash, cached_mesh("Ring"), light_paint(tint.lerp(Color.WHITE, .2), 2.4), Vector3.ZERO, Vector3.ONE * 0.28)
		ring.rotate_x(PI * (.38 + index * .28))
		flash.create_tween().tween_property(ring, "scale", Vector3.ONE * (1.36 if charged else 0.83), 0.17)
	flash.get_tree().create_timer(0.18, false).timeout.connect(flash.queue_free)

func build_suit_projectile(hot: Color) -> void:
	var size := 1.55 if is_charged else 1.0
	var paint := light_paint(palette, 2.45)
	var bright := light_paint(hot, 2.55)
	var orb := cached_mesh("Orb")
	var ring := cached_mesh("Ring")
	var wake := cached_mesh("Wake")
	var center := part(skin, orb, bright, Vector3.ZERO, Vector3(.11, .11, .34) * size)
	match weapon_id:
		"thorn_swarm", "chimera_burst":
			center.scale = Vector3(.24, .24, .26) * size
			var thorn_count := 3 if weapon_id == "thorn_swarm" else 5
			for i in thorn_count:
				var angle := TAU * float(i) / thorn_count
				var spine := part(skin, wake, paint, Vector3(cos(angle) * .15, sin(angle) * .15, -.14) * size, Vector3(.09, .43, .10) * size)
				spine.rotate_x(PI * .43)
				spine.rotate_z(angle)
		"frost_lance", "data_lance":
			center.scale = Vector3(.096, .096, .56) * size
			var shards := 3 if weapon_id == "frost_lance" else 2
			for i in shards:
				var flank := part(skin, cached_mesh("Prism"), paint, Vector3(0, 0, -.21) * size, Vector3(.20, .30, .94) * size)
				flank.rotation.z = PI * i / shards
		"tidal_arc":
			center.scale = Vector3(.22, .20, .25) * size
			for i in 3:
				var coil := part(skin, ring, paint, Vector3(0, 0, -i * .17) * size, Vector3.ONE * .40 * size)
				coil.rotation.x = PI * (.38 + i * .10)
		"gale_edge":
			center.scale = Vector3(.065, .34, .14) * size
			var crescent := part(skin, ring, paint, Vector3(0, 0, -.05), Vector3(.24, .69, .20) * size)
			crescent.rotation.x = PI * .5
		"singularity_shot":
			center.material_override = light_paint(Color("171128"), .12)
			center.scale = Vector3.ONE * .27 * size
			spinner = Node3D.new()
			skin.add_child(spinner)
			for i in 2:
				var orbit := part(spinner, ring, paint, Vector3.ZERO, Vector3.ONE * .71 * size)
				orbit.rotation.x = PI * (.21 + i * .36)
		"scrap_reaver":
			spinner = drill_visual(skin, palette, .58 * size)
			center.scale = Vector3(.11, .11, .31) * size
		"core_override":
			center.scale = Vector3(.16, .16, .65) * size
			for i in 2:
				var edge := part(skin, cached_mesh("Prism"), paint, Vector3.ZERO, Vector3(.24, .36, 1.10) * size)
				edge.rotation.z = i * PI / 2

func spawn_impact(charged: bool) -> void:
	var burst := Node3D.new()
	burst.name = "ProjectileImpact"
	get_parent().add_child.call_deferred(burst)
	finish_impact.call_deferred(burst, global_position, palette, charged, direction, weapon_id)

static func finish_impact(burst: Node3D, at: Vector3, tint: Color, charged: bool, travel: Vector3, weapon: String) -> void:
	if not is_instance_valid(burst) or not burst.is_inside_tree():
		return
	burst.global_position = at
	PACK_VFX.projectile_hit(burst, travel, tint, charged, weapon)
	var flash := add_glow(burst, tint, 1.55 if charged else 0.90)
	burst.create_tween().tween_property(flash, "scale", Vector3.ONE * 0.02, 0.16)
	burst.get_tree().create_timer(0.72, false).timeout.connect(burst.queue_free)

static func drill_visual(parent: Node3D, tint: Color, factor: float) -> Node3D:
	var rotor := Node3D.new()
	parent.add_child(rotor)
	rotor.scale = Vector3.ONE * factor
	var bit := part(rotor, cached_mesh("DrillBit"), light_paint(Color("33445e"), 0.0), Vector3.ZERO, Vector3.ONE)
	bit.rotation.x = PI * 0.5
	for i in range(4):
		var ring := part(rotor, cached_mesh("Ring"), light_paint(tint, 2.3), Vector3(0.0, 0.0, -0.37 + i * 0.18), Vector3.ONE * (0.62 - i * 0.127))
		ring.rotation.x = PI * 0.5
	var accent := part(rotor, cached_mesh("Orb"), light_paint(tint.lerp(Color.WHITE, 0.37), 1.85), Vector3(0.175, 0.0, -0.14), Vector3(0.031, 0.019, 0.16))
	accent.rotation.z = 0.35
	return rotor

static func add_glow(parent: Node3D, tint: Color, diameter: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = HALO
	mat.set_shader_parameter("tint", tint)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	return part(parent, quad, mat, Vector3.ZERO, Vector3.ONE)

static func part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, dimensions: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.position = at
	piece.scale = dimensions
	parent.add_child(piece)
	return piece

static func light_paint(tint: Color, energy: float) -> StandardMaterial3D:
	var key := tint.to_html() + ":" + str(energy)
	if not paint_cache.has(key):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = tint
		paint.roughness = 0.38
		paint.emission_enabled = energy > 0.0
		paint.emission = tint
		paint.emission_energy_multiplier = energy
		paint_cache[key] = paint
	return paint_cache[key]

static func cached_mesh(key: String) -> Mesh:
	if not mesh_cache.has(key):
		match key:
			"Orb":
				var orb := SphereMesh.new()
				orb.radius = 1.0
				orb.height = 2.0
				orb.radial_segments = 12
				orb.rings = 5
				mesh_cache[key] = orb
			"Prism":
				mesh_cache[key] = PrismMesh.new()
			"Ring":
				var ring := TorusMesh.new()
				ring.inner_radius = 0.46
				ring.outer_radius = 0.53
				ring.rings = 14
				ring.ring_segments = 5
				mesh_cache[key] = ring
			_:
				var cone := CylinderMesh.new()
				cone.height = 1.06
				cone.radial_segments = 10
				cone.rings = 1
				cone.top_radius = 0.015 if key == "DrillBit" else 0.78
				cone.bottom_radius = 0.26 if key == "DrillBit" else 0.02
				mesh_cache[key] = cone
	return mesh_cache[key]
