extends Node3D

func ignite(direction: float) -> void:
	var ribbon := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	for index in range(5):
		var height := (index - 2) * 0.15
		var tail := -direction * (0.95 + (2 - absf(index - 2)) * 0.27)
		var tip := Vector3(-direction * 0.12, height, 0.22)
		var width := 0.032 + (2 - absf(index - 2)) * 0.013
		ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
		ribbon.surface_set_color(Color("a7faff"))
		ribbon.surface_add_vertex(tip)
		ribbon.surface_set_color(Color("51caffa8"))
		ribbon.surface_add_vertex(tip + Vector3(tail * 0.32, width, 0))
		ribbon.surface_set_color(Color("3885ff00"))
		ribbon.surface_add_vertex(tip + Vector3(tail, height * 0.24, -0.03))
		ribbon.surface_set_color(Color("a7faff"))
		ribbon.surface_add_vertex(tip)
		ribbon.surface_set_color(Color("3885ff00"))
		ribbon.surface_add_vertex(tip + Vector3(tail, height * 0.24, -0.03))
		ribbon.surface_set_color(Color("51caff76"))
		ribbon.surface_add_vertex(tip + Vector3(tail * 0.32, -width, 0))
		ribbon.surface_end()
	var wake := MeshInstance3D.new()
	wake.mesh = ribbon
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake)
	var fade := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(wake, "position:x", -direction * 0.56, 0.22)
	fade.tween_property(wake, "scale:x", 1.35, 0.22)
	fade.tween_property(wake, "transparency", 1.0, 0.22)
	fade.chain().tween_callback(queue_free)
