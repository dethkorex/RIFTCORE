@tool
extends Node3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")

func _ready() -> void:
	var truss := paint(Color("31373d"), .73)
	var copper := paint(Color("985133"), .57)
	var rail := paint(Color("4d5154"), .60)
	var lamp := paint(Color("ffc268"), .28, 2.25)
	var cladding := paint(Color("767779"), .42)
	cladding.albedo_texture = preload("res://assets/campaign/neon_factory/surfaces/sector_wall.jpg")
	cladding.uv1_triplanar = true
	cladding.uv1_scale = Vector3.ONE * .30
	var deck_y := -9.65
	piece(Vector3(56.8, .62, 2.22), Vector3(2.0, deck_y - .30, -3.15), truss, .05)
	# Continuous roof skin above the crane rails. End frames bear directly on the thresholds.
	piece(Vector3(56.8, .33, 6.5), Vector3(2.0, .22, -.71), cladding, .065)
	for x in [-26.0, 25.0, 30.0]:
		var base := deck_y + 6.49
		piece(Vector3(.84, -base + .37, 6.58), Vector3(x, (base + .37) * .5, -.70), cladding, .07)
		for z in [-3.77, 2.28]:
			piece(Vector3(.82, -deck_y, .40), Vector3(x, deck_y * .5, z), truss, .065)
		piece(Vector3(.94, .24, 6.66), Vector3(x, base + .07, -.70), copper, .05)
	# The extraction gallery continues beyond the seal, with the same tread and sill.
	piece(Vector3(12.2, .40, 6.51), Vector3(36.0, deck_y + 6.44, -.71), cladding, .065)
	piece(Vector3(12.2, 6.68, .45), Vector3(36.0, deck_y + 3.26, -3.75), cladding, .07)
	for x in [33.0, 39.0]:
		var floor_tile := preload("res://assets/neon_factory/foundry/retaining_deck.tscn").instantiate() as StaticBody3D
		floor_tile.collision_layer = 0
		floor_tile.collision_mask = 0
		add_child(floor_tile)
		floor_tile.position = Vector3(x + 1, deck_y, 0)
		piece(Vector3(.45, 6.55, .48), Vector3(x, deck_y + 3.25, -3.47), truss, .05)
		piece(Vector3(1.38, .12, .38), Vector3(x, deck_y + 6.18, -.6), lamp, .03)
	for x in [-22.0, -13.2, -4.4, 4.4, 13.2, 22.0]:
		piece(Vector3(.47, -deck_y, .62), Vector3(x, deck_y * .5, -3.45), truss, .078)
		piece(Vector3(.75, .55, .83), Vector3(x, deck_y + .28, -3.44), copper, .065)
	for z in [-3.75, 2.43]:
		piece(Vector3(56.8, .46, .29), Vector3(2.0, -.03, z), rail, .05)
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
