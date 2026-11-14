@tool
extends Node3D

const Height := 2.4
var warning_mesh: MeshInstance3D
var beam: MeshInstance3D
var light: OmniLight3D
var phase := 0.0
var mode := -1

func _ready() -> void:
	warning_mesh = cylinder(0.026, Color("ffba52"), 2.2, Height, Vector3.UP * Height * 0.5)
	beam = cylinder(0.058, Color("fff1f7"), 4.2, Height, Vector3.UP * Height * 0.5)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.035, 0.24, 0.26)
	var sheath := CylinderMesh.new()
	sheath.height = Height
	sheath.top_radius = 0.24
	sheath.bottom_radius = 0.24
	RiftProjectile.part(beam, sheath, glow, Vector3.ZERO, Vector3.ONE)
	for end in [-1.0, 1.0]:
		var cap := TorusMesh.new()
		cap.inner_radius = 0.12
		cap.outer_radius = 0.25
		RiftProjectile.part(beam, cap, RiftProjectile.light_paint(Color("ff4791"), 3.0), Vector3.UP * (0.035 + end * 1.16), Vector3.ONE)
	light = OmniLight3D.new()
	light.position = Vector3(0, 1.18, -0.10)
	light.light_color = Color("ff397d")
	light.omni_range = 3.2
	add_child(light)
	show_phase(0)

func cylinder(radius: float, tint: Color, emission: float, height: float, at: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return RiftProjectile.part(self, mesh, RiftProjectile.light_paint(tint, emission), at, Vector3.ONE)

func show_phase(value: int) -> void:
	mode = value
	warning_mesh.visible = mode == 1
	beam.visible = mode == 2
	light.visible = mode == 2
	set_process(mode != 0 and not Engine.is_editor_hint())

func _process(delta: float) -> void:
	phase += delta
	if mode == 1:
		warning_mesh.scale.x = 0.7 + sin(phase * 16.0) * 0.29
		warning_mesh.scale.z = warning_mesh.scale.x
	elif mode == 2:
		light.light_energy = 1.30 + sin(phase * 24.0) * 0.22
