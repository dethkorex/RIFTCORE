@tool
extends Node3D

static var by_albedo: Dictionary = {}

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		if not piece.mesh:
			continue
		for index in range(piece.mesh.get_surface_count()):
			var base := piece.get_active_material(index) as StandardMaterial3D
			if not base or not base.albedo_texture:
				continue
			var id := base.albedo_texture.get_instance_id()
			if not by_albedo.has(id):
				var finish := ShaderMaterial.new()
				finish.shader = preload("res://assets/enemies/security_finish.gdshader")
				finish.set_shader_parameter("armor_albedo", base.albedo_texture)
				finish.set_shader_parameter("trim_height", preload("res://assets/enemies/security_height.png"))
				by_albedo[id] = finish
			piece.set_surface_override_material(index, by_albedo[id])
