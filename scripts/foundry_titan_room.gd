@tool
extends Node3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")

func _ready() -> void:
	var truss := paint(Color("31373d"), .73)
	var copper := paint(Color("985133"), .57)
	var rail := paint(Color("4d5154"), .60)
	var lamp := paint(Color("ffc268"), .28, 2.25)
	for span in range(-2, 3):
		var x := span * 8.8
		piece(Vector3(8.6, .28, 6.0), Vector3(x, 0, -.75), truss, .07)
		piece(Vector3(.38, .48, 6.15), Vector3(x - 4.1, -.32, -.75), copper, .09)
		piece(Vector3(7.3, .27, .35), Vector3(x, -.30, 1.24), rail, .06)
		piece(Vector3(2.0, .10, .16), Vector3(x, -.47, 1.22), lamp, .035)
		piece(Vector3(.47, 2.45, .5), Vector3(x - 4.0, -1.23, -3.25), copper, .10)
		var brace := piece(Vector3(.34, 2.55, .35), Vector3(x - 3.52, -1.02, -3.04), truss, .05)
		brace.rotation.z = -.53
	for x in [-11.0, 1.0, 12.0]:
		piece(Vector3(2.30, .51, 1.76), Vector3(x, -.43, 0), copper, .13)
		piece(Vector3(1.48, .48, .98), Vector3(x, -.78, 0), truss, .08)
		piece(Vector3(1.08, .10, .19), Vector3(x, -.96, .55), lamp, .035)
	for z in [-2.65, .85]:
		piece(Vector3(44.0, .39, .46), Vector3(0, -.75, z), truss, .07)

func piece(size: Vector3, at: Vector3, material: Material, bevel: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = CHAMFER.from_box(mesh, bevel)
	part.position = at
	part.material_override = material
	add_child(part)
	return part

static func paint(color: Color, metallic: float, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = .49
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material
