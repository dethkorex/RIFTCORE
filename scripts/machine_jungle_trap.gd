@tool
extends Area3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const SporePod := preload("res://scripts/spore_pod_target.gd")

enum Kind { THORN_BED, SPORE_POD, SNAP_VINE }
@export var kind: Kind
@export var cycle_seconds := 4.3
@export var phase_offset := 0.0

const LEAF := Color("79eeb1")
const POISON := Color("cc5cf2")
const BARK := Color("143c30")
var clock := 0.0
var delay := 0.0
var live := false
var device: Node3D
var warning: MeshInstance3D
var pod: SporePod

func _ready() -> void:
	collision_layer = 0
	clock = phase_offset
	device = Node3D.new()
	device.name = "MovingHazard"
	add_child(device)
	match kind:
		Kind.THORN_BED:
			build_thorns()
		Kind.SPORE_POD:
			build_pod()
		Kind.SNAP_VINE:
			build_vine()
	warning = RiftProjectile.add_glow(self, LEAF, 1.20)
	warning.position = Vector3(0, 0.22, 0.25)
	if Engine.is_editor_hint():
		return
	var shape := BoxShape3D.new()
	var sizes := [Vector3(2.44, 0.88, 1.45), Vector3(2.0, 1.42, 1.55), Vector3(1.75, 1.54, 1.48)]
	shape.size = sizes[kind]
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.size.y * 0.5
	add_child(collider)
	device.hide()
	warning.hide()

func build_thorns() -> void:
	for i in range(5):
		var root := RiftProjectile.part(self, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(BARK, 0.0), Vector3((i - 2) * 0.45, 0.025, 0.09), Vector3(0.38, 0.093, 0.54))
		root.rotation.y = 0.21 * (i - 2)
	for i in range(5):
		var x := (i - 2) * 0.45
		var spike := CylinderMesh.new()
		spike.height = 0.81 if i % 2 == 0 else 0.64
		spike.bottom_radius = 0.19
		spike.top_radius = 0.014
		spike.radial_segments = 5
		var armor := RiftProjectile.part(device, spike, RiftProjectile.light_paint(BARK.lerp(LEAF, 0.30), 0.15), Vector3(x, spike.height * 0.5, 0.08), Vector3.ONE)
		armor.rotation.z = (i - 2) * -0.07
		block(device, Vector3(x, spike.height * 0.28, 0.22), Vector3(0.09, spike.height * 0.40, 0.034), LEAF, 1.1)
		block(self, Vector3(x, -0.008, 0.54), Vector3(0.12, 0.024, 0.23), LEAF, 0.28)

func build_pod() -> void:
	pod = SporePod.new()
	add_child(pod)
	pod.build(SporePod.GREEN)
	pod.burned.connect(func(): set_physics_process(false); warning.hide())

func build_vine() -> void:
	RiftProjectile.part(self, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(BARK, 0.0), Vector3(-0.35, 0.04, 0), Vector3(0.71, 0.11, 0.44))
	var pivot := Node3D.new()
	device.add_child(pivot)
	pivot.position = Vector3(-0.67, 0.09, 0.07)
	for i in range(4):
		var arm := block(pivot, Vector3(i * 0.34, 0.13 + sin(i * 0.65) * 0.40, 0), Vector3(0.49, 0.16, 0.19), BARK.lerp(LEAF, 0.32), 0.09)
		arm.rotation.z = cos(i * 0.65) * 0.42
		block(pivot, arm.position + Vector3(0, 0.075, 0.11), Vector3(0.12, 0.031, 0.022), LEAF, 1.1)
	var tip := CylinderMesh.new()
	tip.top_radius = 0
	tip.bottom_radius = 0.14
	tip.height = 0.42
	tip.radial_segments = 5
	var fang := RiftProjectile.part(pivot, tip, RiftProjectile.light_paint(POISON, 1.3), Vector3(1.25, 0.57, 0), Vector3.ONE)
	fang.rotation.z = -1.0

func block(host: Node3D, at: Vector3, dimensions: Vector3, tint: Color, emission: float) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	return RiftProjectile.part(host, CHAMFER.from_box(geometry, 0.036), RiftProjectile.light_paint(tint, emission), at, Vector3.ONE)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock = fposmod(clock + delta, maxf(cycle_seconds, 2.8))
	var p := clock / maxf(cycle_seconds, 2.8)
	var active := p >= 0.63 and p < (0.96 if kind == Kind.SPORE_POD else 0.82)
	warning.visible = p >= 0.48 and p < 0.96 and kind != Kind.SPORE_POD
	if pod:
		var camera := get_viewport().get_camera_3d()
		var nearby := camera != null and absf(camera.global_position.x - global_position.x) < 32.0
		pod.update_pressure(smoothstep(0.43, 0.63, p) * (1.0 - smoothstep(0.93, 1.0, p)), nearby and active)
	device.visible = active
	if active and not live:
		device.scale.y = 0.08
		var extension := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		extension.tween_property(device, "scale:y", 1.0, 0.14)
		delay = 0.0
	live = active
	delay = maxf(0.0, delay - delta)
	if not active or delay > 0.0:
		return
	for body in get_overlapping_bodies():
		if body is RiftPlayer and body.health > 0.0:
			body.take_projectile_damage([16.0, 8.0, 19.0][kind])
			delay = 0.72 if kind == Kind.SPORE_POD else 2.0
			break
