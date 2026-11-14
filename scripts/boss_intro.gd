extends Node

const UI := preload("res://scripts/rift_ui.gd")
const CombatVFX := preload("res://scripts/combat_vfx.gd")

func play(rig: SideCameraRig, boss: Node3D, floor_y: float, title: String, tint: Color) -> void:
	var camera := rig.get_node("Camera3D") as Camera3D
	var zoom := camera.position.z
	var landing := boss.global_position
	var original_layer: int = boss.get("collision_layer")
	var height := maxf(1.5, landing.y - floor_y)
	rig.set_process(false)
	boss.set("collision_layer", 0)
	boss.global_position = landing + Vector3.UP * 5.1
	boss.show()
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(boss, "global_position", landing, 0.70)

	var shots := [
		[Vector3(landing.x - 0.65, landing.y + 3.45, 0.0), zoom * 0.81, 0.27],
		[Vector3(landing.x + 0.55, landing.y + height + 1.35, 0.0), zoom * 0.69, 0.23],
		[Vector3(landing.x, landing.y + height * 0.55, 0.0), zoom * 0.78, 0.27],
	]
	for shot in shots:
		rig.global_position = shot[0]
		camera.position.z = shot[1]
		await get_tree().create_timer(shot[2], false).timeout
	boss.set("collision_layer", original_layer)
	var impact := Node3D.new()
	add_child(impact)
	impact.global_position = Vector3(landing.x, floor_y + 0.15, 0.0)
	CombatVFX.explosion(impact, tint)
	RiftAudio.play_effect(&"enemy_break")
	var shake := create_tween()
	var shot_y := rig.global_position.y
	shake.tween_property(rig, "global_position:y", shot_y - 0.19, 0.055)
	shake.tween_property(rig, "global_position:y", shot_y, 0.13)
	var layer := CanvasLayer.new()
	layer.layer = 32
	add_child(layer)
	var nameplate := CenterContainer.new()
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(nameplate)
	nameplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nameplate.offset_top = 164
	var label := UI.label(nameplate, title.to_upper(), 53, tint.lerp(Color.WHITE, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color("070d22"))
	label.add_theme_constant_override("outline_size", 12)
	label.modulate.a = 0.0
	var name_reveal := create_tween()
	name_reveal.tween_property(label, "modulate:a", 1.0, 0.15)
	name_reveal.tween_interval(0.67)
	name_reveal.tween_property(label, "modulate:a", 0.0, 0.23)
	await name_reveal.finished
	var target := rig.target
	var position := target.global_position if is_instance_valid(target) else landing
	var facing := target.facing if is_instance_valid(target) else 1.0
	var pullback := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pullback.tween_property(rig, "global_position", Vector3(clampf(position.x + facing * rig.look_ahead, rig.min_x, rig.max_x), maxf(0.85, position.y + 0.35), 0.0), 0.45)
	pullback.tween_property(camera, "position:z", zoom, 0.45)
	await pullback.finished
	rig.set_process(true)
