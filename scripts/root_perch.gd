@tool
extends StaticBody3D

func _ready() -> void:
	for i in range(10):
		var angle := TAU * i / 10
		var root := CylinderMesh.new()
		root.top_radius = 0.075
		root.bottom_radius = 0.13
		root.height = 0.80
		root.radial_segments = 7
		root.material = preload("res://assets/machine_jungle/tread.tres")
		var twig := MeshInstance3D.new()
		twig.mesh = root
		twig.position = Vector3(sin(angle) * 1.26, -0.22, cos(angle) * 0.80)
		twig.rotation.z = sin(angle) * 0.47
		twig.rotation.x = cos(angle) * -0.47
		add_child(twig)
