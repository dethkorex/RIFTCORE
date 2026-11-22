extends Node3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")
const FLAME := preload("res://scripts/foundry_flame.gd")
const AMBER := Color("ffb743")

var core: Node3D
var footprint: MeshInstance3D
var ring_material: StandardMaterial3D

func _ready() -> void:
	core = Node3D.new()
	add_child(core)
	var frame := RiftProjectile.light_paint(Color("28333c"), 0.0)
	var bronze := RiftProjectile.light_paint(Color("be6338"), 0.0)
	var copper := RiftProjectile.light_paint(Color("f19142"), .25)
	ring_material = RiftProjectile.light_paint(AMBER, 1.7)
	box(core, Vector3(1.9, 2.1, 1.40), Vector3(0, 1.14, 0), frame, .20)
	for height in [.37, 1.93]:
		box(core, Vector3(2.04, .33, 1.53), Vector3(0, height, 0), bronze, .09)
		box(core, Vector3(1.73, .11, .07), Vector3(0, height, .788), ring_material, .02)
	for side in [-1.0, 1.0]:
		box(core, Vector3(.23, 1.50, 1.50), Vector3(side * .69, 1.17, 0), copper, .055)
		var brace := box(core, Vector3(.18, .94, .16), Vector3(side * .29, 1.17, .82), bronze, .045)
		brace.rotation.z = side * .31
	box(core, Vector3(.43, .79, .10), Vector3(0, 1.14, .90), ring_material, .055)
	box(core, Vector3(.64, .24, .43), Vector3(0, 2.28, 0), frame, .055)
	var glow := OmniLight3D.new()
	glow.light_color = AMBER
	glow.light_energy = 1.1
	glow.omni_range = 3.8
	glow.position = Vector3(0, 1.15, .8)
	core.add_child(glow)
	footprint = FLAME.floor_mark(3.45, 3.15, FLAME.Style.BACKDRAFT, AMBER)
	add_child(footprint)

func present(elapsed: float, drop_start: float, drop_end: float, height: float, shattered: bool) -> void:
	visible = not shattered
	var fall := clampf(inverse_lerp(drop_start, drop_end, elapsed), 0.0, 1.0)
	core.position.y = height * (1.0 - fall * fall)
	core.rotation.z = sin(fall * PI) * -.19
	ring_material.emission_energy_multiplier = 1.4 + (sin(elapsed * 15.0) + 1.0) * .55
	var mark := footprint.material_override as ShaderMaterial
	mark.set_shader_parameter("progress", clampf(elapsed / drop_end, 0.0, 1.0))

static func box(parent: Node3D, size: Vector3, at: Vector3, material: Material, bevel: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return RiftProjectile.part(parent, CHAMFER.from_box(mesh, bevel), material, at, Vector3.ONE)
