@tool
extends Area3D

@export var width := 5.4
@export var tint := Color("ff9c45")
@export var shot_height := 6.4
@export var period := 3.8
@export var molten_visual := false
@export var purge_relay: NodePath
@onready var relief_valve := get_node_or_null(purge_relay) if not purge_relay.is_empty() else null

const MOLTEN_SHADER := preload("res://assets/neon_factory/foundry/molten_fireball.gdshader")

const WARNING := 0.69
const ASCENT := 0.86
const BALL_RADIUS := 0.42

var phase_time: Callable
var authority := true
var elapsed := 0.0
var launcher: Node3D
var tell: MeshInstance3D
var warning_embers: Node3D
var fireball: Node3D
var struck := {}
var operators: Array[Node]

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var base := BoxShape3D.new()
	base.size = Vector3(width - 0.12, 0.78, 3.4)
	var fall_limit := CollisionShape3D.new()
	fall_limit.shape = base
	fall_limit.position.y = -0.08
	add_child(fall_limit)

	launcher = Node3D.new()
	add_child(launcher)
	var dark := RiftProjectile.light_paint(Color("171923"), 0.0)
	var plate := RiftProjectile.light_paint(Color("39333b"), 0.0)
	var hot := RiftProjectile.light_paint(Color("ea5921"), 1.45)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.43
	barrel.bottom_radius = 0.62
	barrel.radial_segments = 8
	RiftProjectile.part(launcher, barrel, dark, Vector3(0, -0.38, 0), Vector3(1.68, 0.32, 1.55))
	RiftProjectile.part(launcher, barrel, plate, Vector3(0, -0.11, 0), Vector3(1.16, 0.18, 1.16))
	for side in [-1.0, 1.0]:
		RiftProjectile.part(launcher, BoxMesh.new(), plate, Vector3(side * 0.64, -0.26, 0), Vector3(0.26, 0.27, 1.12))
		RiftProjectile.part(launcher, BoxMesh.new(), hot, Vector3(side * 0.66, -0.15, 0.41), Vector3(0.16, 0.09, 0.14))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.59
	ring.rings = 16
	ring.ring_segments = 6
	RiftProjectile.part(launcher, ring, dark, Vector3(0, 0.04, 0), Vector3(1, 0.27, 1))
	tell = RiftProjectile.part(launcher, ring, RiftProjectile.light_paint(tint.lerp(Color("ff562a"), 0.5), 2.2), Vector3(0, 0.11, 0), Vector3(1.15, 0.26, 1.15))
	warning_embers = Node3D.new()
	launcher.add_child(warning_embers)
	fireball = Node3D.new()
	launcher.add_child(fireball)
	var orange := Color("fa4c1e").lerp(tint, 0.15)
	if molten_visual:
		build_molten_fireball(orange)
	else:
		var flame := RiftProjectile.light_paint(orange, 1.35)
		RiftProjectile.part(fireball, RiftProjectile.cached_mesh("Orb"), flame, Vector3.ZERO, Vector3(0.42, 0.54, 0.41))
		RiftProjectile.part(fireball, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(Color("ffbc55"), 1.9), Vector3(0, 0.07, 0.16), Vector3(0.31, 0.42, 0.30))
		for index in 5:
			var angle := TAU * float(index) / 5.0
			var spot := Vector3(cos(angle), 0, sin(angle))
			var plume := RiftProjectile.part(fireball, RiftProjectile.cached_mesh("Wake"), flame,
				spot * 0.25 + Vector3.DOWN * (0.29 + index * 0.07), Vector3(0.17, 0.89, 0.17))
			plume.rotation.z = 0.27 * spot.x
	for index in 5:
		var angle := TAU * float(index) / 5.0
		var spot := Vector3(cos(angle), 0, sin(angle))
		RiftProjectile.part(warning_embers, RiftProjectile.cached_mesh("Wake"), hot,
			spot * 0.35 + Vector3.UP * (0.7 + index * 0.31), Vector3(0.055, 0.29, 0.055))
	var fire_light := OmniLight3D.new()
	fire_light.light_color = orange
	fire_light.light_energy = 1.7
	fire_light.omni_range = 3.6
	fireball.add_child(fire_light)
	warning_embers.hide()
	fireball.hide()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group(&"pit_flare")
	body_entered.connect(fall_in)
	var stage := get_parent()
	while stage and not stage.has_node("Actors"):
		stage = stage.get_parent()
	if stage:
		find_operators.call_deferred(stage.get_node("Actors"))

func build_molten_fireball(orange: Color) -> void:
	var core := SphereMesh.new()
	core.radius = BALL_RADIUS
	core.height = BALL_RADIUS * 2.35
	core.radial_segments = 24
	core.rings = 12
	var surface := ShaderMaterial.new()
	surface.shader = MOLTEN_SHADER
	surface.set_shader_parameter("flame_tint", orange)
	RiftProjectile.part(fireball, core, surface, Vector3.ZERO, Vector3.ONE)
	var wake := SphereMesh.new()
	wake.radius = BALL_RADIUS
	wake.height = 1.74
	wake.radial_segments = 16
	wake.rings = 10
	var wake_surface := surface.duplicate() as ShaderMaterial
	wake_surface.set_shader_parameter("wake", true)
	RiftProjectile.part(fireball, wake, wake_surface, Vector3(0, -0.61, 0), Vector3.ONE)


func find_operators(actors: Node) -> void:
	if is_instance_valid(actors):
		operators = actors.get_children().filter(func(body): return body is RiftPlayer)

func _physics_process(delta: float) -> void:
	elapsed += delta
	var near := operators.any(func(body):
		return is_instance_valid(body) and body.health > 0.0 and absf(body.global_position.x - global_position.x) < 21.0
	)
	if not near or (is_instance_valid(relief_valve) and relief_valve.shown_power == 1):
		fireball.hide()
		tell.hide()
		warning_embers.hide()
		return
	var clock: float = phase_time.call() if phase_time.is_valid() else elapsed
	var phase := fposmod(clock + fposmod(global_position.x * 0.13, period), period)
	var firing := phase >= WARNING and phase < WARNING + ASCENT
	tell.visible = phase < WARNING
	warning_embers.visible = tell.visible
	warning_embers.scale.y = 0.6 + phase * 1.55
	warning_embers.rotation.y += delta * 3.0
	var pulse := 1.0 + 0.30 * sin(phase * 22.0)
	tell.scale = Vector3(pulse, 0.2, pulse)
	if firing and not fireball.visible:
		RiftAudio.foundry_sound(&"fire_jet", global_position)
	fireball.visible = firing
	if not firing:
		struck.clear()
		return
	var progress := (phase - WARNING) / ASCENT
	fireball.position.y = lerpf(0.12, shot_height, progress)
	fireball.rotation.y += delta * 6.0
	fireball.scale = Vector3.ONE * clampf((1.0 - progress) * 8.0, 0.03, 1.0)
	if not authority:
		return
	for body in operators:
		if not is_instance_valid(body) or body.health <= 0.0 or struck.has(body.get_instance_id()):
			continue
		var offset: Vector3 = body.global_position - fireball.global_position
		if absf(offset.x) < BALL_RADIUS + 0.33 and absf(offset.y) < BALL_RADIUS + 0.65:
			struck[body.get_instance_id()] = true
			body.take_damage(22.0, fireball.global_position)

func fall_in(body: Node3D) -> void:
	if authority and body is RiftPlayer and not body.local_prediction:
		body.die_in_pit()
