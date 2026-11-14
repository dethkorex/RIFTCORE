@tool
extends StaticBody3D

const COMBAT_FX := preload("res://scripts/pack_combat_vfx.gd")
const CRACKS := preload("res://assets/vfx/barricade_cracks.gdshader")
const HITS_TO_BREAK := 5
@export var accent := Color("ffbb63")
var fractures := 0
var cracks: ShaderMaterial

func _ready() -> void:
	add_to_group(&"factory_breakable")
	collision_layer = 1 | 16
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.88, 2.12, 2.9)
	collider.shape = shape
	collider.position.y = 1.06
	add_child(collider)
	var alloy := StandardMaterial3D.new()
	alloy.albedo_color = accent.darkened(.79).lerp(Color("445b76"), .48)
	alloy.metallic = .65
	alloy.roughness = .42
	var frame := alloy.duplicate() as StandardMaterial3D
	frame.albedo_color = Color("111a29")
	var light := alloy.duplicate() as StandardMaterial3D
	light.albedo_color = accent
	light.emission_enabled = true
	light.emission = accent
	light.emission_energy_multiplier = .7
	box(Vector3(.91, 2.08, 2.92), Vector3(0, 1.05, 0), frame)
	box(Vector3(.81, 1.76, 2.82), Vector3(0, 1.05, .09), alloy)
	for side in [-1, 1]:
		var x := float(side) * .31
		box(Vector3(.11, 1.92, .06), Vector3(x, 1.06, 1.49), frame)
		box(Vector3(.055, .46, .067), Vector3(x, 1.56, 1.52), light)
	for y in [.22, 1.87]:
		box(Vector3(.76, .12, .08), Vector3(0, y, 1.50), frame)
	cracks = ShaderMaterial.new()
	cracks.shader = CRACKS
	cracks.set_shader_parameter("accent", accent)
	for size_and_side in [[Vector2(.68, 1.49), 0], [Vector2(2.65, 1.58), -1], [Vector2(2.65, 1.58), 1]]:
		var face := QuadMesh.new()
		face.size = size_and_side[0]
		var plane := MeshInstance3D.new()
		plane.mesh = face
		plane.material_override = cracks
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side: int = size_and_side[1]
		plane.position = Vector3(side * .46, 1.06, 1.52 if side == 0 else 0.0)
		plane.rotation.y = side * PI * .5
		add_child(plane)

func box(dimensions: Vector3, at: Vector3, material: Material) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	block.mesh = mesh
	block.material_override = material
	block.position = at
	add_child(block)

func hit_by_projectile(projectile: RiftProjectile) -> bool:
	if projectile.owner_faction != "player" or projectile.launch_profile == -2 or fractures >= HITS_TO_BREAK:
		return false
	set_fractures(fractures + 1)
	return true

func set_fractures(count: int) -> void:
	if count <= fractures:
		return
	fractures = count
	cracks.set_shader_parameter("fractures", mini(fractures, HITS_TO_BREAK - 1))
	RiftAudio.play_effect(&"barricade_crack")
	if fractures < HITS_TO_BREAK:
		return
	set_deferred("collision_layer", 0)
	hide()
	break_apart.call_deferred()

func break_apart() -> void:
	var fragments := Node3D.new()
	get_parent().add_child(fragments)
	fragments.global_position = global_position + Vector3.UP
	COMBAT_FX.explosion(fragments, accent, 1.3)
	get_tree().create_timer(1.35, false).timeout.connect(fragments.queue_free)
	queue_free()
