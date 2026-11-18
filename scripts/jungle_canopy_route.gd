extends Node3D

const Vine := preload("res://scripts/jungle_swing_vine.gd")
const JADE := preload("res://assets/machine_jungle/jade.tres")
const BARK := preload("res://assets/machine_jungle/tread.tres")
const FERN := preload("res://assets/machine_jungle/fern.tres")
const MIST := preload("res://assets/machine_jungle/terrain/canopy_spore_mist.gdshader")
const PAD_TINT := Color("98ff63")

@export var practice := false
var cloud: Node3D
var clock := 0.0
var participants := {}

func _ready() -> void:
	add_to_group(&"jungle_canopy_route")
	make_launch_bloom()
	if practice:
		make_bough(Vector3(2.8, 1.4, -2.8), Vector3(4.5, 6.35, -0.8), 0.58)
		hang_vine(Vector3(4.5, 6.35, 0.0), 3.45)
		make_leaf_deck(Vector3(10.25, 3.40, 0.0), 4.3)
	else:
		make_bough(Vector3(1.0, -1.9, -3.9), Vector3(5.3, 7.10, -0.8), 0.78)
		make_bough(Vector3(5.3, 7.10, -0.8), Vector3(15.3, 8.45, -0.8), 0.56)
		make_bough(Vector3(15.3, 8.45, -0.8), Vector3(25.3, 9.5, -0.8), 0.46)
		make_bough(Vector3(32.4, 1.0, -3.1), Vector3(25.3, 9.5, -0.8), 0.43)
		hang_vine(Vector3(5.3, 7.10, 0.0), 4.0)
		hang_vine(Vector3(15.3, 8.45, 0.0), 4.15)
		hang_vine(Vector3(25.3, 9.5, 0.0), 4.0)
		make_leaf_deck(Vector3(33.7, 5.7, 0.0), 5.0)
		make_mist()
	make_instructions()
	set_physics_process(not practice)

func hang_vine(at: Vector3, reach: float) -> void:
	var vine := Vine.new()
	vine.position = at
	vine.length = reach
	add_child(vine)

func make_bough(start: Vector3, finish: Vector3, radius: float) -> void:
	var direction := finish - start
	var branch := CylinderMesh.new()
	branch.top_radius = radius * 0.62
	branch.bottom_radius = radius
	branch.height = direction.length()
	branch.radial_segments = 12
	var span := RiftProjectile.part(self, branch, BARK, start.lerp(finish, 0.5), Vector3.ONE)
	span.quaternion = Quaternion(Vector3.UP, direction.normalized())
	var cover := SphereMesh.new()
	cover.radius = 0.5
	cover.height = 1.0
	var moss := RiftProjectile.part(self, cover, FERN, span.position + Vector3(0, radius * 0.6, -0.18), Vector3(radius * 1.7, branch.height * 0.91, radius * 0.94))
	moss.quaternion = span.quaternion

func make_launch_bloom() -> void:
	var cup := CylinderMesh.new()
	cup.top_radius = 1.08
	cup.bottom_radius = 0.50
	cup.height = 0.29
	RiftProjectile.part(self, cup, BARK, Vector3.UP * 0.13, Vector3.ONE)
	var button := SphereMesh.new()
	button.radius = 0.5
	button.height = 1.0
	var lamp := RiftProjectile.light_paint(PAD_TINT, 1.3)
	RiftProjectile.part(self, button, lamp, Vector3.UP * 0.28, Vector3(1.04, 0.23, 0.92))
	for index in 7:
		var angle := TAU * index / 7.0
		var petal := RiftProjectile.part(self, button, FERN, Vector3(cos(angle) * 0.81, 0.24, sin(angle) * 0.70), Vector3(.98, .15, .45))
		petal.rotation.y = -angle
		petal.rotation.z = 0.22
	# A lightweight visual cue makes the direction of the pad readable from the ground.
	var glow := RiftProjectile.add_glow(self, PAD_TINT, 1.65)
	glow.position.y = 0.55

func make_leaf_deck(at: Vector3, width: float) -> void:
	var floor := StaticBody3D.new()
	floor.position = at
	floor.add_to_group(&"factory_one_way")
	add_child(floor)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.12, 0.26, 2.15)
	collision.shape = shape
	collision.position.y = -0.13
	floor.add_child(collision)
	var leaf := CylinderMesh.new()
	leaf.top_radius = 1.0
	leaf.bottom_radius = 0.87
	leaf.height = 0.26
	leaf.radial_segments = 32
	RiftProjectile.part(floor, leaf, FERN, Vector3.DOWN * 0.13, Vector3(width * 0.54, 1, 1.37))
	var vein := SphereMesh.new()
	vein.radius = 0.5
	vein.height = 1.0
	RiftProjectile.part(floor, vein, JADE, Vector3(0, .012, 0.0), Vector3(width * 0.99, .05, .15))
	for index in range(1, 5):
		for side in [-1.0, 1.0]:
			var rib := RiftProjectile.part(floor, vein, JADE, Vector3(width * (float(index) / 5.0 - .5), 0.015, side * .51), Vector3(width * .24, 0.042, 0.09))
			rib.rotation.y = -side * 0.65
	var root := CylinderMesh.new()
	root.top_radius = 0.29
	root.bottom_radius = 0.37
	root.height = 1.45
	for side in [-1.0, 1.0]:
		var brace := RiftProjectile.part(floor, root, BARK, Vector3(side * width * .20, -.70, -.59), Vector3.ONE)
		brace.rotation.z = side * .72

func make_mist() -> void:
	cloud = Node3D.new()
	cloud.hide()
	add_child(cloud)
	var layer := QuadMesh.new()
	layer.size = Vector2(35.0, 2.8)
	for index in 3:
		var density := ShaderMaterial.new()
		density.shader = MIST
		density.set_shader_parameter("drift", float(index) * 5.7)
		RiftProjectile.part(cloud, layer, density, Vector3(18.0, -1.06 - index * 0.26, -1.35 + index * 0.59), Vector3.ONE)

func make_instructions() -> void:
	var prompt := Label3D.new()
	prompt.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	prompt.font_size = 47
	prompt.outline_size = 12
	prompt.pixel_size = 0.0065
	prompt.modulate = Color("e6ffac")
	prompt.position = Vector3(-0.25, 2.18, -0.86)
	prompt.text = "CANOPY LIFT\nHold Up to grab a vine · Jump to release" if practice else "CANOPY ESCAPE\nHold Up to grab · Jump at the forward swing"
	add_child(prompt)

func launch_rider(operator: CharacterBody3D) -> void:
	if practice:
		return
	if participants.is_empty():
		clock = 0.0
	participants[operator.get_instance_id()] = weakref(operator)

func _physics_process(delta: float) -> void:
	if participants.is_empty():
		cloud.hide()
		return
	clock += delta
	var rising := clock > 1.7
	cloud.visible = rising
	cloud.position.y = lerpf(0.4, 6.0, clampf((clock - 1.7) / 7.4, 0.0, 1.0))
	for id in participants.keys():
		var operator = participants[id].get_ref()
		if not is_instance_valid(operator) or not operator.visible or operator.health <= 0.0:
			participants.erase(id)
			continue
		var point := to_local(operator.global_position)
		if point.x > 36.0 or point.x < -3.0 or point.y < -4.0:
			participants.erase(id)
		elif rising and point.x > 3.0 and point.y < cloud.position.y and not operator.local_prediction:
			operator.take_boss_hit(5.0, cloud.global_position, 2, false)
