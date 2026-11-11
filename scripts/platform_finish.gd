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
	add_service_details.call_deferred(platform)

func add_service_details(platform: Node3D) -> void:
	if not is_instance_valid(platform) or not platform.is_inside_tree() or platform.has_node("ServiceDetails"):
		return
	for collider in platform.find_children("*", "CollisionShape3D", true, false):
		if not collider.shape is BoxShape3D:
			continue
		var dimensions: Vector3 = collider.shape.size
		if dimensions.x < 1.6 or dimensions.z < 1.4 or dimensions.y > 0.7:
			continue
		var group := Node3D.new()
		group.name = "ServiceDetails"
		platform.add_child(group)
		group.position = platform.to_local(collider.global_position)
		var bolt := CylinderMesh.new()
		bolt.top_radius = 0.032
		bolt.bottom_radius = 0.039
		bolt.height = 0.028
		bolt.radial_segments = 6
		bolt.material = preload("res://assets/neon_factory/platform_rail.tres")
		for x in [-dimensions.x * 0.5 + 0.16, dimensions.x * 0.5 - 0.16]:
			for z in [-dimensions.z * 0.5 - 0.022, dimensions.z * 0.5 + 0.022]:
				var screw := MeshInstance3D.new()
				screw.mesh = bolt
				screw.rotation.x = PI * 0.5
				screw.position = Vector3(x, -0.018, z)
				group.add_child(screw)
		var vent := BoxMesh.new()
		vent.size = Vector3(0.31, 0.058, 0.025)
		vent.material = preload("res://assets/neon_factory/platform_tread.tres")
		for side in [-1.0, 1.0]:
			for i in 3:
				var grille := MeshInstance3D.new()
				grille.mesh = vent
				grille.position = Vector3(side * dimensions.x * 0.24, -0.048 + i * 0.068, dimensions.z * 0.5 + 0.025)
				group.add_child(grille)
		return
