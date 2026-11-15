extends Node

const UI := preload("res://scripts/rift_ui.gd")
const CombatVFX := preload("res://scripts/combat_vfx.gd")
const Story := preload("res://scripts/rift_story.gd")
const StoryDialogue := preload("res://scripts/story_dialogue.gd")

func play(rig: SideCameraRig, boss: Node3D, floor_y: float, title: String, tint: Color, sector: int, act: int, online := false) -> void:
	var camera := rig.get_node("Camera3D") as Camera3D
	var gameplay_camera := camera.transform
	var landing := boss.global_position
	var original_layer: int = boss.get("collision_layer")
	boss.show()
	var bounds := visible_bounds(boss, floor_y)
	var height := maxf(bounds.size.y, 1.5)
	var head := Vector3(bounds.get_center().x, bounds.end.y, landing.z)
	var focus := head - Vector3.UP * height * 0.29
	var near_distance := maxf(height * 0.95, 2.7)
	var wide_distance := maxf(height * 1.42, 5.15)
	var lift := 6.8
	rig.set_process(false)
	boss.set("collision_layer", 0)

	# Keep both close-ups on the gameplay side of the arena.
	for side in [-1.0, 1.0]:
		var shot_start := boss.global_position
		if side < 0.0:
			shot_start = landing + Vector3.UP * lift
		var shot_end := landing + Vector3.UP * (lift * 0.84 if side < 0.0 else lift * 0.68)
		boss.global_position = shot_start
		var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_method(func(reading: Vector3):
			boss.global_position = reading
			aim(camera, focus + reading - landing, Vector3(side * near_distance * 0.39, 0.22, near_distance))
		, shot_start, shot_end, 1.0)
		await fall.finished

	var wide_focus := head - Vector3.UP * height * 0.26
	var descent := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	descent.tween_method(func(reading: Vector3):
		boss.global_position = reading
		aim(camera, wide_focus + (reading - landing) * 0.61, Vector3(0, 0.25, wide_distance))
	, boss.global_position, landing, 0.49)
	await descent.finished
	boss.set("collision_layer", original_layer)
	var impact := Node3D.new()
	add_child(impact)
	impact.global_position = Vector3(landing.x, floor_y + 0.15, landing.z)
	CombatVFX.explosion(impact, tint)
	RiftAudio.play_effect(&"enemy_break")
	var impact_eye := camera.global_position
	var shake := create_tween()
	shake.tween_property(camera, "global_position", impact_eye + Vector3.DOWN * 0.13, 0.05)
	shake.tween_property(camera, "global_position", impact_eye, 0.16)
	await shake.finished

	var layer := CanvasLayer.new()
	layer.layer = 32
	add_child(layer)
	var label := UI.label(layer, title.to_upper(), 53, tint.lerp(Color.WHITE, 0.4))
	label.name = "BossName"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_outline_color", Color("070d22"))
	label.add_theme_constant_override("outline_size", 12)
	label.size = label.get_combined_minimum_size()
	var screen := camera.get_viewport().get_visible_rect().size
	var anchor := camera.unproject_position(head + Vector3.UP * 0.20)
	label.position = Vector2(clampf(anchor.x - label.size.x * 0.5, 18.0, maxf(18.0, screen.x - label.size.x - 18.0)), maxf(12.0, anchor.y - label.size.y))
	label.modulate.a = 0.0
	var name_reveal := create_tween()
	name_reveal.tween_property(label, "modulate:a", 1.0, 0.23)
	name_reveal.tween_interval(1.25)
	name_reveal.tween_property(label, "modulate:a", 0.0, 0.33)
	await name_reveal.finished
	if DisplayServer.get_name() != "headless":
		var portrait := await capture_portrait(camera, head, height)
		var dialogue := StoryDialogue.new()
		dialogue.add_to_group(&"boss_dialogue")
		add_child(dialogue)
		await dialogue.play(Story.boss_exchange(sector, act), "Begin Fight", online, title, portrait, tint, online)
		dialogue.queue_free()
	var target := rig.target
	var position := target.global_position if is_instance_valid(target) else landing
	var facing := target.facing if is_instance_valid(target) else 1.0
	var view_at := Vector3(clampf(position.x + facing * rig.look_ahead, rig.min_x, rig.max_x), maxf(0.85, position.y + 0.35), 0.0)
	var camera_from := camera.transform
	var destination := rig.global_transform.affine_inverse() * (Transform3D(rig.global_basis, view_at) * gameplay_camera)
	var pullback := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pullback.tween_method(func(weight: float): camera.transform = camera_from.interpolate_with(destination, weight), 0.0, 1.0, 0.74)
	await pullback.finished
	rig.global_position = view_at
	camera.transform = gameplay_camera
	rig.set_process(true)

func aim(camera: Camera3D, target: Vector3, offset: Vector3) -> void:
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)

func visible_bounds(boss: Node3D, floor_y: float) -> AABB:
	var bounds := AABB(Vector3(boss.global_position.x, floor_y, boss.global_position.z), Vector3.ZERO)
	for child in boss.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh and mesh.is_visible_in_tree():
			bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	return bounds

func capture_portrait(camera: Camera3D, head: Vector3, height: float) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var viewport := camera.get_viewport()
	var frame := viewport.get_texture().get_image()
	if not frame or frame.is_empty():
		return null
	var point := camera.unproject_position(head - Vector3.UP * height * 0.25)
	var edge := camera.unproject_position(head + Vector3.UP * height * 0.12)
	var factor := Vector2(frame.get_size()) / viewport.get_visible_rect().size
	var span := maxi(2, roundi(absf(point.y - edge.y) * factor.y * 2.0))
	var crop := Rect2i(Vector2i(point * factor) - Vector2i(span, span) / 2, Vector2i(span, span))
	return ImageTexture.create_from_image(frame.get_region(crop.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))))
