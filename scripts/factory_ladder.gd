@tool
extends Node3D

@export_range(1.2, 12.0, 0.1) var rise := 3.2

func _ready() -> void:
	var rail := preload("res://assets/neon_factory/platform_rail.tres")
	var rung := preload("res://assets/neon_factory/platform_deck.tres")
	for side in [-1.0, 1.0]:
		piece(Vector3(side * 0.33, rise * 0.5, -0.60), Vector3(0.095, rise + 0.18, 0.11), rail)
	for y in range(floori(rise / 0.32) + 1):
		piece(Vector3(0, y * 0.32 + 0.10, -0.54), Vector3(0.66, 0.065, 0.14), rung)
	var guide := preload("res://assets/neon_factory/cyan.tres")
	piece(Vector3(-0.33, rise + 0.025, -0.53), Vector3(0.105, 0.09, 0.03), guide)
	piece(Vector3(0.33, rise + 0.025, -0.53), Vector3(0.105, 0.09, 0.03), guide)

func piece(at: Vector3, size: Vector3, material: Material) -> void:
	var model := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	model.mesh = box
	model.position = at
	add_child(model)
