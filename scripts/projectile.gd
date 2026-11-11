class_name RiftProjectile
extends Area3D

const HALO := preload("res://assets/pickups/pickup_halo.gdshader")
const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
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
var pierces := 0
var struck: Dictionary = {}

func setup(dir: Vector3, faction: String, tint: Color = Color.CYAN, drill := false, charged := false, magma := false, sector := 0, role := 0) -> void:
	direction = dir.normalized()
	owner_faction = faction
	add_to_group(&"rift_projectile")
	palette = tint
	is_charged = charged
	is_magma = magma
	skin = Node3D.new()
	add_child(skin)
	var up := Vector3.UP if absf(direction.y) < 0.96 else Vector3.BACK
	skin.basis = Basis.looking_at(direction, up, true)
	var hot := tint.lerp(Color.WHITE, 0.79)
	if drill:
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
	collision.shape = sphere
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	clock += delta
	if is_instance_valid(spinner):
		spinner.rotate_z(delta * (11.0 if is_charged else 24.0))
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if spent:
		return
	if body.has_method("take_damage") and body.get("faction") != owner_faction:
		if struck.has(body.get_instance_id()):
			return
		struck[body.get_instance_id()] = true
		if body.has_method("take_projectile_damage"):
			body.take_projectile_damage(damage)
		else:
			var prior: float = body.health if "health" in body else 0.0
			if is_magma and body.has_method("take_fire_damage"):
				body.take_fire_damage(damage, global_position)
			elif not weapon_id.is_empty() and body.has_method("take_element_damage"):
				body.take_element_damage(damage, global_position, weapon_id)
			else:
				body.take_damage(damage, global_position)
			if is_magma and burn_power > 0.0 and body.has_method("ignite") and body.health < prior:
				body.ignite(burn_power, 3.0)
			apply_reward_effect(body)
		if pierces > 0:
			pierces -= 1
			damage *= 0.78
			return
		spent = true
		impact()
	elif body is StaticBody3D or body is AnimatableBody3D:
		spent = true
		impact()

func apply_reward_effect(body: Node3D) -> void:
	if weapon_id == "frost_lance" and "stagger_left" in body and "recoil" in body:
		body.stagger_left = maxf(body.stagger_left, 0.45)
		body.recoil = 0.0
	if weapon_id == "chimera_burst" and body.has_method("ignite"):
		body.ignite(5.0, 2.2)
	if weapon_id == "gale_edge" and "recoil" in body and not body.planted_override and body.variant != 3:
		body.recoil = direction.x * 7.5
	if weapon_id not in ["tidal_arc", "singularity_shot", "scrap_reaver", "core_override"]:
		return
	var radius := 4.5 if weapon_id == "tidal_arc" else (3.3 if weapon_id == "singularity_shot" else 2.65)
	var targets: Array[Node3D] = []
	for candidate in get_tree().get_nodes_in_group("damageable_enemies"):
		if candidate != body and candidate.global_position.distance_to(body.global_position) < radius and candidate.health > 0.0:
			targets.append(candidate)
	targets.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_squared_to(body.global_position) < b.global_position.distance_squared_to(body.global_position))
	for i in range(mini(targets.size(), 3 if is_charged else 2)):
		var target := targets[i]
		target.take_damage(damage * 0.38, body.global_position)
		if weapon_id == "singularity_shot" and "recoil" in target and not target.planted_override and target.variant != 3:
			target.recoil = signf(body.global_position.x - target.global_position.x) * 6.5

func impact() -> void:
	var burst := Node3D.new()
	burst.name = "ProjectileImpact"
	get_parent().add_child.call_deferred(burst)
	finish_impact.call_deferred(burst, position, palette, is_charged, direction)
	queue_free()

static func finish_impact(burst: Node3D, at: Vector3, tint: Color, charged: bool, travel: Vector3) -> void:
	if not is_instance_valid(burst) or not burst.is_inside_tree():
		return
	burst.position = at
	var scale_factor := 1.65 if charged else 1.0
	COMBAT_VFX.hit(burst, tint, scale_factor)
	var flash := add_glow(burst, tint, 1.28 * scale_factor)
	var tween := burst.create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 0.02, 0.17)
	for i in range(8 if charged else 5):
		var angle := i * TAU / (8.0 if charged else 5.0) + 0.22
		var offset := Vector3(cos(angle), sin(angle), (i % 3 - 1) * 0.21)
		var fragment := part(burst, cached_mesh("Orb"), light_paint(tint.lerp(Color.WHITE, 0.48), 2.0), Vector3.ZERO, Vector3(0.036, 0.036, 0.12) * scale_factor)
		fragment.basis = Basis.looking_at(offset.normalized(), Vector3.BACK, true).scaled_local(fragment.scale)
		tween.tween_property(fragment, "position", (offset * 0.64 - travel * 0.13) * scale_factor, 0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "scale", Vector3.ZERO, 0.22)
	tween.chain().tween_callback(burst.queue_free)

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
