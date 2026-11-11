@tool
extends Node3D

const CHAMFER := preload("res://scripts/factory_chamfer.gd")

func _ready() -> void:
	var platform := get_parent()
	for piece in platform.find_children("Detail*", "MeshInstance3D", true, false):
		var box := piece.mesh as BoxMesh
		if not box or not box.material:
			continue
		var kind := box.material.resource_path.get_file().get_basename()
		if not kind.begins_with("platform_"):
			continue
		piece.material_override = box.material
		var bevel := 0.046 if box.size.y > 0.13 else 0.012
		piece.mesh = CHAMFER.from_box(box, bevel)
