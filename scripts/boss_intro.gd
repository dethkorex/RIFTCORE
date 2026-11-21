extends Node

const CombatVFX := preload("res://scripts/combat_vfx.gd")
const Story := preload("res://scripts/rift_story.gd")
const StoryDialogue := preload("res://scripts/story_dialogue.gd")
const HUD := preload("res://scripts/factory_hud.gd")
const FoundryRig := preload("res://scripts/foundry_boss_rig.gd")
const JungleRig := preload("res://scripts/jungle_boss_rig.gd")
const Fire := preload("res://addons/pyrolux_fx/nodes_3d/pyrolux_fire_3d.gd")

const DROP_HEIGHT := 7.0
const DROP_TIME := 0.76
const CHARGE_TIME := 1.85

func play(rig: SideCameraRig, boss: Combatant, floor_y: float, title: String, tint: Color, sector: int, act: int, readout: HUD, online := false, combat_target: Node3D = null) -> void:
	var camera := rig.get_node("Camera3D") as Camera3D
	var gameplay_camera := camera.transform
	var landing := boss.global_position
	var original_layer := boss.collision_layer
	boss.show()
	var armor := boss.get_node_or_null("Armor") as Node3D
	if armor == null and "armor" in boss:
		armor = boss.get("armor") as Node3D
	var articulation := armor if armor else boss
	var neutral := articulation.transform
	var foundry := armor as FoundryRig
	var jungle := armor as JungleRig
	var animate := Callable(armor, &"cinematic_pose") if armor and armor.has_method("cinematic_pose") else Callable()
	if jungle:
		jungle.cinematic = true
		jungle.rotation.y = -0.44
	var bounds := visible_bounds(articulation, floor_y)
	var height := maxf(bounds.size.y, 1.5)
	var head := Vector3(landing.x, floor_y + height, landing.z)
	var focus := head - Vector3.UP * height * 0.42
	var wide := maxf(height * 1.55, 5.5)
	var lift := clear_drop_height(boss, bounds, floor_y)
	rig.set_process(false)
	boss.collision_layer = 0
	readout.boss_visible = false
	readout.queue_redraw()

	# Keep a single continuous shot through the fall and floor impact.
	var approach := Vector3(-wide * 0.20, 0.72, wide)
	boss.global_position = landing + Vector3.UP * lift
	aim(camera, focus + Vector3.UP * lift * 0.72, approach)
	if lift > 0.18:
		var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_method(func(remaining: float):
			boss.global_position = landing + Vector3.UP * remaining
			if animate.is_valid():
				animate.call(get_process_delta_time(), smoothstep(0.04, 0.82, remaining), 0.0, 0.0, 0.0)
			aim(camera, focus + Vector3.UP * remaining * 0.72, approach)
		, lift, 0.0, DROP_TIME * sqrt(lift / DROP_HEIGHT))
		await fall.finished
	boss.global_position = landing

	var impact := Node3D.new()
	add_child(impact)
	impact.global_position = Vector3(landing.x, floor_y + 0.10, landing.z)
	CombatVFX.explosion(impact, tint)
	RiftAudio.play_effect(&"enemy_break")
	if foundry:
		RiftAudio.foundry_sound(&"boulder_roll", impact.global_position)
	var recovery := create_tween()
	recovery.tween_method(func(weight: float):
		var brace := sin(PI * weight)
		if animate.is_valid():
			animate.call(get_process_delta_time(), 0.0, brace, 0.0, 0.0)
		aim(camera, focus, approach + Vector3.DOWN * brace * 0.13)
	, 0.0, 1.0, 0.25)
	await recovery.finished

	# The camera moves closer only after the body is planted.
	var hero_offset := Vector3(-wide * 0.32, 0.42, wide * 0.91)
	var opening_rotation := articulation.rotation
	var pose := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pose.tween_method(func(weight: float):
		if armor:
			armor.rotation.y = lerp_angle(opening_rotation.y, -0.36, weight)
		if animate.is_valid():
			animate.call(get_process_delta_time(), 0.0, 0.0, weight, 0.0)
		aim(camera, focus, approach.lerp(hero_offset, weight))
	, 0.0, 1.0, 0.65)
	await pose.finished
	await get_tree().create_timer(0.25, false).timeout

	var charge_tint := Color("d45aff") if jungle and act == 2 else tint
	var charge_fx := make_charge(impact, charge_tint, height, maxf(bounds.size.x, bounds.size.z))
	if jungle:
		charge_fx.light_energy *= 0.70
		charge_fx.flame_height *= 0.78
	var starting_amount := charge_fx.amount
	var starting_light := charge_fx.light_energy
	var peak_light := 3.15 if jungle else 5.4
	charge_fx.ignite()
	readout.boss_name = title.to_upper()
	readout.boss_tint = tint
	readout.boss_sector = sector
	readout.boss_act = act
	readout.boss_max_health = boss.max_health
	readout.boss_health = 0.0
	readout.boss_visible = true
	readout.queue_redraw()
	RiftAudio.play_effect(&"titan_windup")
	var charge := create_tween()
	charge.tween_method(func(weight: float):
		if animate.is_valid():
			animate.call(get_process_delta_time(), 0.0, 0.0, 1.0, weight)
		charge_fx.amount = lerpf(starting_amount, 1.0, weight)
		charge_fx.light_energy = lerpf(starting_light, peak_light, weight)
		readout.boss_health = boss.health * smoothstep(0.08, 1.0, weight)
		readout.queue_redraw()
	, 0.0, 1.0, CHARGE_TIME)
	await charge.finished
	readout.boss_health = boss.health
	readout.queue_redraw()
	RiftAudio.stop_effect(&"titan_windup")
	RiftAudio.play_effect(&"deploy_zap")
	RiftProjectile.suit_flash(impact, boss.global_position, charge_tint, true)
	charge_fx.extinguish()
	await get_tree().create_timer(0.45, false).timeout

	if DisplayServer.get_name() != "headless":
		await play_dialogue(camera, boss, head, height, title, tint, sector, act, online)

	articulation.transform = neutral
	if foundry:
		foundry.cinematic_pose(0.2, 0.0, 0.0, 0.0, 0.0)
	if jungle:
		jungle.finish_cinematic()
	elif armor and armor.has_method("finish_cinematic"):
		armor.finish_cinematic()
	var opponent := combat_target if is_instance_valid(combat_target) else rig.target
	if is_instance_valid(opponent) and armor:
		var separation := opponent.global_position.x - boss.global_position.x
		if absf(separation) > 0.01:
			boss.set("facing", signf(separation))
		var direction := float(boss.get("facing"))
		if armor.has_method("face_immediately"):
			armor.call("face_immediately", direction)
		else:
			armor.rotation.y = direction * Combatant.BOSS_SIDE_YAW
	boss.collision_layer = original_layer
	var target := rig.target
	var position := target.global_position if is_instance_valid(target) else landing
	var facing := target.facing if is_instance_valid(target) else 1.0
	var view_at := Vector3(clampf(position.x + facing * rig.look_ahead, rig.min_x, rig.max_x), maxf(rig.minimum_follow_y, position.y + 0.35), 0.0)
	var camera_from := camera.transform
	var destination := rig.global_transform.affine_inverse() * (Transform3D(rig.global_basis, view_at) * gameplay_camera)
	var pullback := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pullback.tween_method(func(weight: float): camera.transform = camera_from.interpolate_with(destination, weight), 0.0, 1.0, 0.60)
	await pullback.finished
	rig.global_position = view_at
	camera.transform = gameplay_camera
	rig.set_process(true)

func make_charge(parent: Node3D, tint: Color, height: float, width: float) -> PyroluxFire3D:
	var fire := Fire.new()
	fire.name = "ReactorCharge"
	fire.autoplay = false
	fire.fade_time = 0.26
	fire.shape = PyroluxFire3D.Shape.RING
	fire.size = Vector3(clampf(width * 0.55, 1.55, 3.3), 0.1, 0.56)
	fire.flame_height = clampf(height * 0.74, 1.28, 3.0)
	fire.flame_width = 0.94
	fire.tongues = 30
	fire.puffs = 42
	fire.embers = 104
	fire.ember_height = height * 1.65
	fire.smoke = 9
	fire.smoke_height = height * 1.18
	fire.smoke_opacity = 0.18
	fire.light_range = maxf(5.0, height * 2.5)
	fire.light_energy = 2.2
	fire.amount = 0.55
	var palette := PyroluxPalette.new()
	palette.cool = tint.darkened(0.55)
	palette.hot = tint.lightened(0.08)
	palette.core = Color("fff4bd").lerp(tint, 0.24)
	palette.light = tint
	fire.palette = palette
	parent.add_child(fire)
	return fire

func play_dialogue(camera: Camera3D, boss: Combatant, head: Vector3, height: float, title: String, tint: Color, sector: int, act: int, online: bool) -> void:
	var hint := Story.foundry_boss_hint(act) if sector == 1 else Story.jungle_boss_hint(act) if sector == 2 else ""
	var beat := "%d_%d" % [sector, act]
	if not online and RiftSettings.show_hub_tips and not hint.is_empty() and RiftSettings.claim_story_beat("arena_hint_" + beat):
		var boss_shot := camera.transform
		var show_target := sector == 1 and boss.has_method("mechanic_preview_target")
		if show_target:
			var prop_focus: Vector3 = boss.mechanic_preview_target()
			aim(camera, prop_focus, Vector3(1.4, 0.9, 5.7))
			boss.show_intro_target(true)
		await play_nova_hint(hint)
		if show_target:
			boss.show_intro_target(false)
		camera.transform = boss_shot
	var exchange := Story.boss_exchange(sector, act)
	var first_view := RiftSettings.claim_story_beat("arena_story_v3_" + beat)
	if not online and not first_view:
		return
	var portrait := await capture_portrait(camera, head, height)
	var dialogue := StoryDialogue.new()
	dialogue.add_to_group(&"boss_dialogue")
	add_child(dialogue)
	await dialogue.play(exchange, "Continue", online, title, portrait, tint, online)
	dialogue.queue_free()

func play_nova_hint(hint: String) -> void:
	var guide := StoryDialogue.new()
	guide.add_to_group(&"boss_dialogue")
	add_child(guide)
	await guide.play([[Story.GUIDE, hint]], "Continue")
	guide.queue_free()

func clear_drop_height(boss: CollisionObject3D, bounds: AABB, floor_y: float) -> float:
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(bounds.size.x + 0.25, 1.4), maxf(bounds.end.y - floor_y - 0.16, 1.1),
		maxf(bounds.size.z + 0.2, 0.9))
	var center := bounds.get_center()
	center.y = floor_y + 0.16 + shape.size.y * 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.exclude = [boss.get_rid()]
	var space := boss.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return 0.0
	query.motion = Vector3.UP * DROP_HEIGHT
	var clearance := space.cast_motion(query)
	return maxf(0.0, DROP_HEIGHT * clearance[0] - 0.12) if clearance.size() > 0 else 0.0

func aim(camera: Camera3D, target: Vector3, offset: Vector3) -> void:
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)

func visible_bounds(actor: Node3D, floor_y: float) -> AABB:
	var bounds := AABB(Vector3(actor.global_position.x, floor_y, actor.global_position.z), Vector3.ZERO)
	for child in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh and mesh.is_visible_in_tree():
			bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	return bounds

func capture_portrait(camera: Camera3D, head: Vector3, height: float) -> Texture2D:
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
	crop = crop.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	return ImageTexture.create_from_image(frame.get_region(crop)) if crop.has_area() else null
