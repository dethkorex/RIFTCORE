extends Node3D

func ignite(direction: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("57eaff")
	for index in range(7):
		var trail := MeshInstance3D.new()
		var streak := BoxMesh.new()
		streak.size = Vector3(0.38 + (index % 3) * 0.19, 0.038, 0.08)
		streak.material = material
		trail.mesh = streak
		trail.position = Vector3(-direction * (0.12 + index * 0.16), (index - 3) * 0.13, 0.12)
		add_child(trail)
		var fade := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade.tween_property(trail, "position:x", trail.position.x - direction * (0.55 + index * 0.12), 0.22)
		fade.tween_property(trail, "scale", Vector3(1.5, 0.01, 0.01), 0.22)
	get_tree().create_timer(0.24, false).timeout.connect(queue_free)
