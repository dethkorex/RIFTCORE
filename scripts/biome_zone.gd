@tool
extends Area3D

const SporePod := preload("res://scripts/spore_pod_target.gd")
const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const SURFACE := preload("res://assets/vfx/hazard_surface.gdshader")
const SPARK := preload("res://assets/vfx/kenney/spark_04.png")
const SMOKE := preload("res://assets/vfx/kenney/smoke_05.png")

enum Kind { ICE, WATER, WIND, LOW_GRAVITY, VENT, ELECTRIC, UPDRAFT, MUTATION, SOLAR, PRESS, CORRUPTION }
@export var kind: Kind
@export var dimensions := Vector3(3, 2, 2)
@export var tint := Color("54dfff")
@export var direction := 1.0
@export var period := 4.2
@export var offset := 0.0
@export var power := 20.0
@export var terrain_strength := 1.0
@export var burnable_spore_pod := false
var clock := 0.0
var effect: Node3D
var surface: ShaderMaterial
var indicators: StandardMaterial3D
var particles: CPUParticles3D
var arc: MeshInstance3D
var arc_frame := -1
var pod: SporePod
var warning_strip: MeshInstance3D
var warning_finish: ShaderMaterial
var warning_light: OmniLight3D
var next_hit_by_body: Dictionary = {}
var phase_time: Callable

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	clock = offset
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	effect = Node3D.new()
	effect.name = "HazardEffect"
	effect.position.y = -dimensions.y * 0.5
	add_child(effect)
	if kind <= Kind.LOW_GRAVITY:
		add_to_group("terrain_modifier")
	if kind <= Kind.LOW_GRAVITY or kind == Kind.UPDRAFT:
		set_collision_mask_value(7, true)
	build_visuals()
	if not Engine.is_editor_hint():
		update_visuals(0.0, false)

func build_visuals() -> void:
	if burnable_spore_pod:
		pod = SporePod.new()
		effect.add_child(pod)
		pod.build(tint)
		pod.burned.connect(shut_down)
		build_warning()
		return
	match kind:
		Kind.ICE, Kind.CORRUPTION, Kind.WATER:
			build_surface()
		Kind.VENT, Kind.ELECTRIC, Kind.UPDRAFT, Kind.MUTATION, Kind.SOLAR, Kind.PRESS:
			build_emitter_mounts()
	if kind in [Kind.ELECTRIC, Kind.CORRUPTION, Kind.SOLAR]:
		build_arcs()
	if kind == Kind.PRESS:
		build_press()
	if kind != Kind.ICE and kind != Kind.PRESS:
		build_particles()
	if kind > Kind.LOW_GRAVITY:
		build_warning()

func build_warning() -> void:
	var area := PlaneMesh.new()
	area.size = Vector2(dimensions.x, dimensions.z)
	warning_finish = ShaderMaterial.new()
	warning_finish.shader = preload("res://assets/vfx/biome_warning.gdshader")
	warning_finish.set_shader_parameter("tint", tint)
	warning_strip = mesh_part(self, area, warning_finish, Vector3(0, 0.074 - dimensions.y * 0.5, 0))
	warning_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_strip.hide()
	warning_light = OmniLight3D.new()
	warning_light.position = Vector3(0, 0.65 - dimensions.y * 0.5, 0.45)
	warning_light.omni_range = maxf(3.3, dimensions.x * 0.75)
	warning_light.light_color = tint
	warning_light.hide()
	add_child(warning_light)

func shut_down() -> void:
	set_physics_process(false)
	if warning_strip:
		warning_strip.hide()
		warning_light.hide()

func build_surface() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(dimensions.x * 0.98, minf(dimensions.z, 2.0))
	surface = ShaderMaterial.new()
	surface.shader = SURFACE
	surface.set_shader_parameter("tint", tint)
	surface.set_shader_parameter("style", 1 if kind == Kind.WATER else 0)
	surface.set_shader_parameter("activity", 0.65 if kind != Kind.CORRUPTION else 0.0)
	var y := dimensions.y * 0.80 if kind == Kind.WATER else 0.048
	mesh_part(self, plane, surface, Vector3(0, -dimensions.y * 0.5 + y, 0))

func build_emitter_mounts() -> void:
	var metal := RiftProjectile.light_paint(Color("1b2534").lerp(tint.darkened(0.78), 0.23), 0.0)
	indicators = RiftProjectile.light_paint(tint, 0.22).duplicate() as StandardMaterial3D
	var width := minf(dimensions.x, 9.0)
	var count := clampi(ceili(width / 0.78), 2, 6)
	for i in count:
		var x := width * ((i + 0.5) / count - 0.5)
		var spacing := width / count
		var y := -dimensions.y * 0.5 + 0.025
		var depth := 0.32 if kind in [Kind.ELECTRIC, Kind.SOLAR] else 0.69
		var z := -0.60 if kind in [Kind.ELECTRIC, Kind.SOLAR] else 0.0
		var base := BoxMesh.new()
		base.size = Vector3(spacing * 0.86, 0.088, depth)
		mesh_part(self, CHAMFER.from_box(base, 0.035), metal, Vector3(x, y, z))
		var slots := BoxMesh.new()
		slots.size = Vector3(spacing * 0.54, 0.014, 0.023)
		for rail in [-1, 0, 1]:
			mesh_part(self, slots, indicators, Vector3(x, y + 0.046, z + rail * depth * 0.25))

func build_press() -> void:
	var steel := RiftProjectile.light_paint(Color("303647"), 0.0)
	var caution := RiftProjectile.light_paint(Color("f4a343"), 0.6)
	var ram := BoxMesh.new()
	ram.size = Vector3(dimensions.x * 0.89, 0.40, 1.50)
	mesh_part(effect, CHAMFER.from_box(ram, 0.09), steel, Vector3.ZERO)
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.27, 0.13, 1.28)
	for i in range(5):
		mesh_part(effect, CHAMFER.from_box(tooth, 0.034), steel, Vector3((i - 2) * dimensions.x * 0.155, -0.22, 0))
		var led := BoxMesh.new()
		led.size = Vector3(0.19, 0.055, 0.025)
		mesh_part(effect, led, caution, Vector3((i - 2) * dimensions.x * 0.155, 0.055, 0.754))
	var guide := BoxMesh.new()
	guide.size = Vector3(0.16, dimensions.y + 0.26, 0.18)
	for side in [-1.0, 1.0]:
		mesh_part(self, CHAMFER.from_box(guide, 0.035), steel, Vector3(side * dimensions.x * 0.39, 0, -0.80))

func build_arcs() -> void:
	arc = MeshInstance3D.new()
	arc.name = "Discharge"
	var lightning := RiftProjectile.light_paint(tint.lerp(Color.WHITE, 0.55), 4.5)
	lightning.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = lightning
	arc.mesh = ImmediateMesh.new()
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(arc)
	for i in range(4):
		var x := (i - 1.5) * dimensions.x * 0.23
		var glow := Sprite3D.new()
		glow.texture = preload("res://assets/vfx/kenney/light_01.png")
		glow.modulate = Color(tint, 0.55)
		glow.shaded = false
		glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glow.pixel_size = dimensions.x * 0.0019
		glow.position = Vector3(x, 0.16, 0.04)
		effect.add_child(glow)

func draw_arcs() -> void:
	var frame := floori(clock * 21.0)
	if arc_frame == frame:
		return
	arc_frame = frame
	var mesh := arc.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var x := (i - 1.5) * dimensions.x * 0.23
		var tip := Vector3(x, 0.07, -0.07 + i * 0.10)
		for segment in range(1, 7):
			var progress := segment / 6.0
			var bend := sin(frame * 13.1 + i * 4.3 + segment * 7.17)
			var next := Vector3(x + bend * dimensions.x * 0.095, progress * dimensions.y * 0.96, tip.z)
			var edge := Vector3(0.085 * (1.10 - progress * 0.67), 0, 0)
			for vertex in [tip - edge, next - edge, tip + edge, tip + edge, next - edge, next + edge]:
				mesh.surface_add_vertex(vertex)
			tip = next
	mesh.surface_end()

func build_particles() -> void:
	particles = CPUParticles3D.new()
	particles.amount = clampi(roundi(dimensions.x * 7.0), 23, 55)
	particles.lifetime = 1.25
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var ambient := kind in [Kind.WATER, Kind.WIND, Kind.LOW_GRAVITY]
	particles.emission_box_extents = Vector3(dimensions.x * 0.43, dimensions.y * 0.42 if ambient else 0.035, 0.53)
	particles.position.y = dimensions.y * 0.48 if ambient else 0.085
	particles.direction = Vector3(signf(direction), 0.17, 0) if kind == Kind.WIND else Vector3.UP
	particles.gravity = Vector3(0, 0.17, 0)
	particles.spread = 14.0 if kind in [Kind.WIND, Kind.VENT, Kind.UPDRAFT] else 42.0
	particles.initial_velocity_min = dimensions.y * 0.38
	particles.initial_velocity_max = dimensions.y * 0.90
	particles.scale_amount_min = 0.32
	particles.scale_amount_max = 1.16
	particles.visibility_range_end = 48.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.16, 0.66, 1.0])
	fade.colors = PackedColorArray([Color(tint, 0), Color(tint.lightened(0.46), 0.91), Color(tint, 0.63), Color(tint, 0)])
	particles.color_ramp = fade
	var sprite := QuadMesh.new()
	sprite.size = Vector2(1.50, 1.44) if kind in [Kind.VENT, Kind.MUTATION, Kind.UPDRAFT] else Vector2(0.35, 0.70)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = SMOKE if kind in [Kind.VENT, Kind.MUTATION, Kind.UPDRAFT] else SPARK
	sprite.material = material
	particles.mesh = sprite
	effect.add_child(particles)

func mesh_part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part

func update_visuals(phase: float, live: bool) -> void:
	var charge := smoothstep(0.39, 0.65, phase) * (1.0 - smoothstep(0.90, 0.99, phase))
	var camera := get_viewport().get_camera_3d()
	var nearby := camera != null and absf(camera.global_position.x - global_position.x) < 33.0
	if pod:
		pod.update_pressure(charge, nearby and live)
	var warning := phase >= 0.42 and phase < 0.65
	if warning_strip:
		warning_strip.visible = nearby and (warning or live)
		warning_light.visible = warning_strip.visible
		if warning_strip.visible:
			warning_finish.set_shader_parameter("live", live)
			warning_light.light_color = tint if live else Color("ffba4e")
			warning_light.light_energy = 2.45 if live else 0.7 + charge * 0.8
	if indicators:
		indicators.emission_energy_multiplier = 0.48 + charge * 4.0
	if surface:
		surface.set_shader_parameter("activity", 0.70 if kind < Kind.VENT else charge)
	if particles:
		particles.emitting = nearby and (live or kind < Kind.VENT)
	if arc:
		arc.visible = nearby and live
		for child in effect.get_children():
			if child is Sprite3D:
				child.visible = nearby and live
		if arc.visible:
			draw_arcs()
	if kind == Kind.PRESS:
		effect.position.y = lerpf(dimensions.y * 0.67, -dimensions.y * 0.22, smoothstep(0.51, 0.67, phase) * (1.0 - smoothstep(0.90, 1.0, phase)))

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var length := maxf(period, 2.4)
	clock = fposmod(float(phase_time.call()) + offset if phase_time.is_valid() else clock + delta, length)
	var phase := clock / length
	var live := kind >= Kind.VENT and phase >= 0.65 and phase <= 0.90
	update_visuals(phase, live)
	if not live:
		next_hit_by_body.clear()
		return
	for body in get_overlapping_bodies():
		if not body is RiftPlayer or body.health <= 0.0 or (body.local_prediction and kind != Kind.UPDRAFT):
			continue
		var id: int = body.get_instance_id()
		if clock < float(next_hit_by_body.get(id, 0.0)):
			continue
		if kind == Kind.UPDRAFT:
			body.velocity.y = maxf(body.velocity.y, 13.2)
			body.air_dash_available = true
			next_hit_by_body[id] = clock + 0.42
		else:
			body.take_projectile_damage(power)
			next_hit_by_body[id] = clock + 0.62
