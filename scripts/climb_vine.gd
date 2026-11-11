@tool
extends Node3D

@export_range(1.2, 12.0, 0.1) var rise := 3.2

func _ready() -> void:
	var bark := preload("res://assets/machine_jungle/tread.tres")
	var living := preload("res://assets/machine_jungle/fern.tres")
	var light := preload("res://assets/machine_jungle/jade.tres")
	var count := ceili(rise / 0.24)
	for i in count:
		var y := rise * i / count
		for strand in 2:
			var angle := i * 0.78 + strand * PI
			var root := CylinderMesh.new()
			root.height = rise / count * 1.20
			root.top_radius = 0.080
			root.bottom_radius = 0.091
			root.radial_segments = 8
			root.material = bark
			var twig := MeshInstance3D.new()
			twig.mesh = root
			twig.position = Vector3(sin(angle) * 0.13, y + 0.12, -0.55 + cos(angle) * 0.08)
			twig.rotation.z = cos(angle) * -0.36
			add_child(twig)
		if i % 3 == 0:
			var leaf := PrismMesh.new()
			leaf.size = Vector3(0.36, 0.12, 0.16)
			leaf.material = living
			var blade := MeshInstance3D.new()
			blade.mesh = leaf
			blade.position = Vector3((-1 if i % 2 == 0 else 1) * 0.20, y + 0.10, -0.49)
			blade.rotation.z = -0.38 if i % 2 == 0 else 0.38
			add_child(blade)
		if i % 4 == 0:
			var bud := SphereMesh.new()
			bud.radius = 0.045
			bud.height = 0.09
			bud.material = light
			var pearl := MeshInstance3D.new()
			pearl.mesh = bud
			pearl.position = Vector3(0, y + 0.14, -0.42)
			add_child(pearl)
