@tool
extends Node3D

const Chamfer := preload("res://scripts/factory_chamfer.gd")

func _ready() -> void:
	for part in get_parent().find_children("Panel*", "MeshInstance3D", true, false):
		var box := part.mesh as BoxMesh
		if box == null:
			continue
		part.material_override = box.material
		part.mesh = Chamfer.from_box(box, minf(0.037, box.size.y * 0.31))
