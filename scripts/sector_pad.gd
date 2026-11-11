@tool
extends Node3D

@export var extraction := false
var emitters: Node3D
var lamps: StandardMaterial3D
var glow: OmniLight3D
var tint: Color

func _ready() -> void:
	tint = Color("c58aff") if extraction else Color("43dcff")
	var steel := paint(Color("263551"), 0.72)
	var deck := paint(Color("617385"), 0.48)
	var inset := paint(Color("101c29"), 0.65)
	lamps = paint(tint, 0.15)
	lamps.emission_enabled = true
	lamps.emission = tint
	lamps.emission_energy_multiplier = 0.75 if extraction else 1.6
	ring(1.02, 1.08, 0.12, Vector3(0, 0.006, 0), steel, 8)
	ring(0.92, 0.97, 0.035, Vector3(0, 0.074, 0), deck, 8)
	ring(0.75, 0.75, 0.019, Vector3(0, 0.096, 0), inset, 8)
	emitters = Node3D.new()
	add_child(emitters)
	for i in 8:
		var angle := TAU * (i + 0.5) / 8.0
		var spoke := Vector3(sin(angle), 0, cos(angle))
		var cell := box(Vector3(0.35, 0.038, 0.13), spoke * 0.84 + Vector3.UP * 0.093, lamps, emitters)
		cell.rotation.y = angle
		var head := ring(0.048, 0.052, 0.025, spoke * 0.62 + Vector3.UP * 0.105, deck, 6)
		head.rotation.y = angle
	for i in [-1, 1]:
		var sigil := box(Vector3(0.064, 0.019, 0.38), Vector3(i * 0.12, 0.113, 0), lamps, emitters)
		sigil.rotation.y = i * (0.60 if extraction else -0.60)
	glow = OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 0.37
	glow.omni_range = 2.4
	glow.position = Vector3.UP * 0.28
	add_child(glow)

func paint(color: Color, metal: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.40
	return material

func ring(top: float, bottom: float, height: float, at: Vector3, material: Material, sides: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	return piece(mesh, at, material, self)

func box(dimensions: Vector3, at: Vector3, material: Material, host: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return piece(mesh, at, material, host)

func piece(mesh: Mesh, at: Vector3, material: Material, host: Node3D) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material
	model.position = at
	host.add_child(model)
	return model

func pulse() -> void:
	if not is_instance_valid(glow):
		return
	lamps.emission_energy_multiplier = 4.7
	glow.light_energy = 3.8
	var decay := create_tween().set_parallel()
	decay.tween_property(lamps, "emission_energy_multiplier", 1.65, 0.64)
	decay.tween_property(glow, "light_energy", 0.58, 0.64)
