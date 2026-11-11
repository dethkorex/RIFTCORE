extends Node3D

const ATTACK_FX := preload("res://scripts/attack_fx.gd")
const CATALOG := preload("res://scripts/sector_catalog.gd")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const PROP_NAMES := ["sci-vent", "sci-beacon", "sci-reactor", "sci-cable-spool"]
var player: Node3D
var sector := 1
var act := 1
var atmosphere: CPUParticles3D
var tint: Color
var trim_scene: PackedScene

func install(level: Node3D, target: Node3D, number: int, act_number: int) -> void:
	player = target
	sector = number
	act = act_number
	tint = ATTACK_FX.tint_for(sector)
	trim_scene = load("res://assets/campaign/%s/terrain/sector_trim.tscn" % CATALOG.info(sector).id)
	level.add_child(self)
	for deck in level.get_node("TERRAIN").get_children():
		if deck is Node3D:
			fit_platform(deck)
	add_atmosphere()
	await get_tree().physics_frame
	if not is_instance_valid(player) or not is_inside_tree():
		return
	var decor := level.get_node("DECOR")
	mount_pillars(level.get_node("TERRAIN"), decor)
	for item in decor.get_children():
		if item is Node3D and is_arch(item):
			align_arch(item, true)
	for gate in ["Gate", "ForgeHallDoor"]:
		var frame := level.get_node_or_null(gate + "/PortalFrame") as Node3D
		if frame:
			align_arch(frame, false)
			var door := level.get_node_or_null(gate + "/Door") as Node3D
			if door:
				fit_model(door, floor_width(frame.global_position) * 0.95, 3.1)
	var seal := level.get_node_or_null("ExitBarrier/Seal") as Node3D
	if seal:
		fit_model(seal, floor_width(seal.global_position), 3.15)
	for marker_path in ["MARKERS/PlayerSpawn", "TERRAIN/MidpointCheckpoint", "TERRAIN/ForgeHallCheckpoint", "Gate", "MARKERS/RoomExit"]:
		var marker := level.get_node_or_null(marker_path) as Node3D
		if marker:
			add_detail(marker.global_position, marker.name == "Gate")
	var index := 0
	for deck in level.get_node("TERRAIN").get_children():
		if deck is Node3D and deck.has_meta("wall_trim") and not deck is AnimatableBody3D:
			index += 1
			if index % (4 if act == 2 else 6) == 0:
				add_detail(deck.global_position, false)

func mount_pillars(terrain: Node3D, decor: Node3D) -> void:
	var supports: Array[CollisionShape3D] = []
	for node in terrain.find_children("*", "CollisionShape3D", true, false):
		var collider := node as CollisionShape3D
		if not collider.get_parent() is PhysicsBody3D or not collider.shape is BoxShape3D:
			continue
		var size := (collider.shape as BoxShape3D).size
		if size.x >= 1.4 and size.y <= 0.9 and size.z >= 0.72:
			supports.append(collider)
	var finish := RiftProjectile.light_paint(Color("243043").lerp(tint.darkened(0.76), 0.30), 0.0)
	for item in decor.get_children():
		if not item is Node3D or not is_pillar(item):
			continue
		var support: CollisionShape3D
		var distance := INF
		var position: Vector3 = item.global_position
		for candidate in supports:
			var local := candidate.to_local(position)
			var half := (candidate.shape as BoxShape3D).size * 0.5
			var deck_x := clampf(local.x, -half.x + 0.18, half.x - 0.18)
			var anchor := candidate.to_global(Vector3(deck_x, half.y, 0))
			var score := absf(position.x - anchor.x) * 1.4 + absf(position.y - anchor.y) * 1.7
			if score < distance:
				distance = score
				support = candidate
		if not support:
			continue
		var bounds := pillar_bounds(item)
		if bounds.size == Vector3.ZERO:
			continue
		var half := (support.shape as BoxShape3D).size * 0.5
		var local := support.to_local(position)
		var deck_x := clampf(local.x, -half.x + 0.18, half.x - 0.18)
		var edge := support.to_global(Vector3(deck_x, half.y, -half.z))
		var front := bounds.end.z - position.z
		var bottom := bounds.position.y - position.y
		item.reparent(support, true)
		item.global_position = Vector3(edge.x, edge.y - 0.23 - bottom, edge.z - front + 0.075)
		if item is CollisionObject3D:
			item.collision_layer = 0
			item.collision_mask = 0
		for body in item.find_children("*", "CollisionObject3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
		var bracket := Node3D.new()
		bracket.name = "PillarBracket"
		support.add_child(bracket)
		bracket.global_transform = Transform3D(Basis.IDENTITY, edge)
		chassis_panel(bracket, Vector3(clampf(bounds.size.x, 0.45, 1.4), 0.27, 0.48), Vector3(0, -0.18, -0.07), finish)
		chassis_panel(bracket, Vector3(0.26, 0.37, 0.24), Vector3(0, -0.36, -0.08), finish)

func is_pillar(item: Node3D) -> bool:
	return item.name.begins_with("MidgroundFrame") or item.scene_file_path.ends_with("/relay.tscn") or item.scene_file_path.ends_with("/spore_reservoir.tscn") or item.scene_file_path.ends_with("/reactor_core.tscn")

func pillar_bounds(item: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in item.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh:
			var part: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = part if first else bounds.merge(part)
			first = false
	return bounds

func is_arch(item: Node3D) -> bool:
	return item.scene_file_path.ends_with("/arch.tscn") or item.scene_file_path.ends_with("/door_frame.tscn") or item.scene_file_path.ends_with("/root_arch.tscn")

func align_arch(frame: Node3D, decorative: bool) -> void:
	var rotation := frame.rotation_degrees
	rotation.y = 90.0
	frame.rotation_degrees = rotation
	for body in frame.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	if not decorative:
		fit_model(frame, floor_width(frame.global_position) + 0.65, 3.75)
		return
	var origin := frame.global_position
	for offset in [0.0, -0.65, 0.65, -1.45, 1.45]:
		var at := Vector3(origin.x + offset, origin.y + 1.15, 0.0)
		var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.2, 1, [player.get_rid()])
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not floor_hit.is_empty() and floor_hit.collider is StaticBody3D and floor_hit.normal.y > 0.7:
			frame.global_position = floor_hit.position
			fit_model(frame, floor_width(frame.global_position) + 0.68, 3.85)
			return

func floor_width(at: Vector3) -> float:
	var from := Vector3(at.x, at.y + 0.30, 0.0)
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.9, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		for child in hit.collider.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D and child.shape.size.y < 1.3:
				return clampf(child.shape.size.z * child.global_basis.z.length(), 1.55, 3.1)
	return 2.15

func fit_model(model: Node3D, width: float, height: float) -> void:
	var bounds := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		if not child.mesh:
			continue
		var part: AABB = (model.global_transform.affine_inverse() * child.global_transform) * child.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	if not first and bounds.size.x > 0.1 and bounds.size.y > 0.1:
		model.scale.x = width / bounds.size.x
		model.scale.y = height / bounds.size.y

func fit_platform(deck: Node3D) -> void:
	if deck.has_meta("wall_trim"):
		return
	var path := deck.scene_file_path
	var is_deck := deck.name.begins_with("RouteDeck") or path.contains("platform") or path.contains("floor") or path.contains("catwalk") or path.contains("perch") or path.ends_with("/deck.tscn") or path.ends_with("/lift.tscn") or path.ends_with("/phase.tscn")
	if not is_deck:
		return
	var colliders := deck.find_children("*", "CollisionShape3D", true, false)
	for candidate in colliders:
		var collider := candidate as CollisionShape3D
		if not collider.get_parent() is StaticBody3D or not collider.shape is BoxShape3D:
			continue
		var box := collider.shape as BoxShape3D
		var size := box.size
		if size.x < 1.4 or size.y > 0.66 or size.z < 0.72:
			continue
		var thickness := maxf(size.y, 0.66 if collider.get_parent().is_in_group("factory_one_way") else 0.78)
		var extra := thickness - size.y
		var expanded := box.duplicate() as BoxShape3D
		expanded.size.y = thickness
		collider.shape = expanded
		collider.position -= collider.basis.y * (extra * 0.5)
		build_deck_chassis(deck, collider, size, extra)
		deck.set_meta("wall_trim", true)
		return

func deck_material(deck: Node3D, panel: int, fallback: Material) -> Material:
	for prefix in ["PanelM", "Detail"]:
		var piece := deck.get_node_or_null(prefix + str(panel)) as MeshInstance3D
		if piece and piece.mesh:
			var material := piece.get_active_material(0)
			if material:
				return material
	return fallback

func chassis_panel(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.position = at
	var shape := BoxMesh.new()
	shape.size = size
	piece.mesh = CHAMFER.from_box(shape, minf(0.055, size.y * 0.35))
	piece.material_override = material
	parent.add_child(piece)

func build_deck_chassis(deck: Node3D, collider: CollisionShape3D, size: Vector3, extra: float) -> void:
	var base := deck_material(deck, 0, preload("res://assets/neon_factory/platform_tread.tres"))
	var plate := deck_material(deck, 1, base)
	var y := -size.y * 0.5
	chassis_panel(collider, Vector3(size.x - 0.03, extra + 0.065, size.z - 0.045), Vector3(0, y + 0.030, 0), base)
	chassis_panel(collider, Vector3(size.x - 0.12, 0.075, size.z - 0.07), Vector3(0, y - extra * 0.40, 0), plate)
	for side in [-1.0, 1.0]:
		chassis_panel(collider, Vector3(0.14, extra * 0.82, size.z - 0.08),
			Vector3(side * (size.x * 0.5 - 0.10), y, 0), plate)
	var count := clampi(floori(size.x / 2.0), 1, 4)
	for i in range(count):
		var x := ((i + 0.5) / count - 0.5) * size.x
		chassis_panel(collider, Vector3(size.x / count * 0.92, extra * 0.63, 0.065),
			Vector3(x, y + 0.04, size.z * 0.5 - 0.025), plate)
		var trim := trim_scene.instantiate() as Node3D
		trim.position = Vector3(x, y + 0.05, size.z * 0.5 + 0.028)
		trim.scale = Vector3(0.74, minf(0.24, extra * 0.57), 0.59)
		trim.get_node("ArmorPlate").material_override = base
		collider.add_child(trim)

func add_detail(at: Vector3, arena: bool) -> void:
	var rig := Node3D.new()
	add_child(rig)
	rig.global_position = Vector3(at.x + (0.0 if arena else -1.55), at.y, -1.45)
	var metal := Color("152838").lerp(tint.darkened(0.8), 0.32)
	var beam := BoxMesh.new()
	ATTACK_FX.piece(rig, beam, Vector3(0, 0.38, 0), Vector3(0.31, 0.75, 0.36), metal)
	ATTACK_FX.piece(rig, beam, Vector3(0, 0.09, 0), Vector3(0.45, 0.18, 0.46), metal.lightened(0.13))
	for stripe in range(3):
		ATTACK_FX.piece(rig, beam, Vector3(0, 0.32 + stripe * 0.12, 0.19), Vector3(0.21, 0.046, 0.035), tint.darkened(stripe * 0.16))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.55, 0.4)
	light.light_color = tint
	light.light_energy = 0.36 if not arena else 0.70
	light.omni_range = 2.2
	rig.add_child(light)
	var prop_name: String = PROP_NAMES[(sector - 1 + (1 if arena else 0)) % PROP_NAMES.size()]
	var prop_scene := load("res://assets/campaign/props/%s.glb" % prop_name) as PackedScene
	var prop := prop_scene.instantiate() as Node3D
	prop.scale = Vector3.ONE * (0.95 if arena else 0.68)
	prop.position = Vector3(0.87, 0.07, -0.51)
	rig.add_child(prop)
	var emitter := create_local_emitter()
	emitter.position += Vector3(0.86, 0.44, -0.39)
	rig.add_child(emitter)

func create_local_emitter() -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.amount = 14 if sector in [1, 5, 6, 9] else 11
	emitter.lifetime = 2.4
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = Vector3(0.7, 0.32, 0.27)
	emitter.spread = 26.0
	emitter.direction = Vector3.UP
	emitter.gravity = Vector3(0.13, 0.14, 0)
	emitter.initial_velocity_min = 0.24
	emitter.initial_velocity_max = 0.74
	emitter.scale_amount_min = 0.52
	emitter.scale_amount_max = 1.25
	emitter.visibility_range_end = 24.0
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dust := SphereMesh.new()
	dust.radius = 0.046
	dust.height = 0.092
	dust.radial_segments = 7
	dust.rings = 4
	var particle_mesh: PrimitiveMesh = dust
	match sector:
		1, 9:
			emitter.lifetime = 1.23
			emitter.direction = Vector3(0.32, 0.94, 0)
			emitter.gravity = Vector3.DOWN * 2.45
			emitter.initial_velocity_min = 1.10
			emitter.initial_velocity_max = 2.5
			var spark := BoxMesh.new()
			spark.size = Vector3(0.025, 0.16, 0.022)
			particle_mesh = spark
		3, 8:
			emitter.position.y = 2.2
			emitter.direction = Vector3(0.29, -0.95, 0)
			emitter.gravity = Vector3.DOWN * 0.25
			var flake := PrismMesh.new()
			flake.size = Vector3(0.068, 0.105, 0.035)
			particle_mesh = flake
		4:
			emitter.initial_velocity_max = 1.25
			dust.radius = 0.063
			dust.height = 0.126
		5, 6:
			emitter.lifetime = 1.45
			emitter.direction = Vector3(1, 0.17, 0).normalized()
			emitter.initial_velocity_min = 1.1
			emitter.initial_velocity_max = 2.75
			emitter.gravity = Vector3.ZERO
			var streak := BoxMesh.new()
			streak.size = Vector3(0.24 if sector == 6 else 0.095, 0.025, 0.027)
			particle_mesh = streak
		10:
			var chip := BoxMesh.new()
			chip.size = Vector3(0.072, 0.072, 0.044)
			particle_mesh = chip
			emitter.angular_velocity_min = -120.0
			emitter.angular_velocity_max = 120.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0, 0.16, 0.64, 1])
	ramp.colors = PackedColorArray([Color(tint, 0.0), Color(tint.lerp(Color.WHITE, 0.42), 0.82), Color(tint, 0.44), Color(tint, 0.0)])
	emitter.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	particle_mesh.material = material
	emitter.mesh = particle_mesh
	return emitter

func add_atmosphere() -> void:
	atmosphere = CPUParticles3D.new()
	atmosphere.amount = 32 if act == 2 else 24
	atmosphere.lifetime = 4.2
	atmosphere.local_coords = false
	atmosphere.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	atmosphere.emission_box_extents = Vector3(10, 3.8, 1.7)
	atmosphere.direction = Vector3(0.9 if sector == 6 else 0.21, -1 if sector in [3, 4, 8] else 1, 0)
	atmosphere.gravity = Vector3.ZERO
	atmosphere.spread = 24 if sector == 6 else 48
	atmosphere.initial_velocity_min = 0.20
	atmosphere.initial_velocity_max = 1.25 if sector in [1, 3, 6, 9] else 0.55
	atmosphere.scale_amount_min = 0.45
	atmosphere.scale_amount_max = 1.05
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = ATTACK_FX.paint(tint.darkened(0.50))
	atmosphere.mesh = mesh
	atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(atmosphere)

func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(atmosphere):
		atmosphere.global_position = player.global_position + Vector3(3.5, 1.1, -2.6)
