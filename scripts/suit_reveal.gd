extends Node3D

const UI := preload("res://scripts/rift_ui.gd")
const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const ChargingOrb := preload("res://scripts/buster_charge_orb.gd")

func play(actor: RiftPlayer, rig: SideCameraRig, hud: CanvasLayer, reward: Dictionary) -> void:
	name = "SuitReveal"
	# An airborne boss kill still lands under normal physics first. Animate
	# only the mesh from there so the live collider never leaves the floor.
	for frame in 90:
		if actor.health<=0.0 or actor.grounded():
			break
		await get_tree().physics_frame
	if actor.health<=0.0 or not actor.grounded():
		return
	actor.suit_showcase_active = true
	actor.velocity = Vector3.ZERO
	actor.wall_sliding = false
	actor.melee_lock = 0.0
	actor.cancel_saber_charge()
	actor.present_saber_charge(-1.0,false)
	actor.set_crouch(false)
	actor.landing_left = 0.0
	rig.set_process(false)
	var id: String = reward.reward
	var tint := Color(reward.color)
	var landing := actor.global_position
	var original_model_y := actor.model_root.position.y
	global_position = landing-Vector3.UP*(actor.standing_capsule.height*.5-.04)
	var lens := rig.get_node("Camera3D") as Camera3D
	var zoom := lens.position.z
	var focus := landing + Vector3(0.8, 0.44, 0)
	var view := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	view.tween_property(rig, "global_position", focus, 0.58)
	view.tween_property(lens, "position:z", zoom * 0.73, 0.58)
	view.tween_property(actor.model_root, "position:y", original_model_y + 0.41, 0.58)
	actor.play_character_animation("idle", true)
	actor.model_root.rotation = Vector3(0, -0.20, 0)
	var aura := build_floor_light(tint)
	RiftAudio.play_effect(&"titan_windup")
	for equipped in ["", id, "", id]:
		actor.equip_sector_weapon(equipped)
		aura.light_energy = 1.8 if equipped.is_empty() else 3.6
		await get_tree().create_timer(0.32, false).timeout
	var descent := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	descent.tween_property(actor.model_root, "position:y", original_model_y, 0.20)
	await descent.finished
	actor.play_character_animation("land", true)
	RiftAudio.stop_effect(&"titan_windup")
	RiftAudio.play_effect(&"deploy_zap")
	RiftAudio.play_effect(&"level_up")
	COMBAT_VFX.explosion(self, tint)
	RiftProjectile.suit_flash(self, global_position + Vector3.UP * 1.05, tint, true)
	var light_out := create_tween()
	light_out.tween_property(aura, "light_energy", 1.45, 0.43).from(5.0)
	var plate := ability_card(hud, reward, tint)
	await get_tree().create_timer(0.50, false).timeout
	await demonstrate(actor, rig, plate)
	var resume := create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	resume.tween_property(lens, "position:z", zoom, 0.4)
	resume.tween_property(rig, "global_position", landing + Vector3(rig.look_ahead * actor.facing, 0.35, 0), 0.4)
	resume.tween_property(aura, "light_energy", 0.0, 0.4)
	resume.tween_property(plate, "modulate:a", 0.0, 0.28)
	await resume.finished
	plate.queue_free()
	actor.model_root.rotation = Vector3(0,PI*.5*actor.facing,0)
	actor.play_character_animation("idle",true)
	actor.suit_showcase_active = false
	rig.set_process(true)

func demonstrate(actor: RiftPlayer, rig: SideCameraRig, plate: PanelContainer) -> void:
	var camera := rig.get_node("Camera3D") as Camera3D
	var pull_back := create_tween().set_parallel()
	pull_back.tween_property(camera, "position:z", camera.position.z * 1.27, 0.45)
	pull_back.tween_property(rig, "global_position:x", actor.global_position.x + 2.15, 0.45)
	await pull_back.finished
	actor.facing = 1.0
	actor.model_root.rotation.y = PI * 0.5
	actor.showcase_projectiles = self
	actor.play_character_animation("idle", true)
	var demo := plate.get_node("AbilityCopy/Demonstration") as Label
	var tint := Color(Catalog.weapon(actor.equipped_suit()).color)
	for i in 3:
		demo.text = "WINDING UP   %d / 3" % (i + 1)
		if actor.buster_pose:
			actor.buster_pose.ladder_direction = 0.0
			actor.buster_pose.water_direction = Vector3.ZERO
			actor.buster_pose.crouched = false
			actor.buster_pose.influence = 1.0
			await actor.buster_pose.modification_processed
		var orb := ChargingOrb.new()
		add_child(orb)
		RiftAudio.play_effect(&"buster_charge")
		var charge := create_tween()
		charge.tween_method(func(amount: float):
			orb.global_position = actor.cannon_muzzle(actor.facing)
			orb.charge(amount,tint,amount>.8)
		,0.0,1.0,.36)
		await charge.finished
		orb.hide()
		orb.queue_free()
		RiftAudio.stop_effect(&"buster_charge")
		demo.text = "CHARGED SUIT SHOT   %d / 3" % (i + 1)
		actor.play_character_animation("shoot",true)
		await actor.shoot(true, true, true)
		if actor.buster_pose:
			create_tween().tween_property(actor.buster_pose,"influence",0.0,.16)
		await get_tree().create_timer(.23,false).timeout
		actor.play_character_animation("idle",true)
		await get_tree().create_timer(.23,false).timeout
	actor.showcase_projectiles = null
	actor.fire_lock = 0.0
	if actor.buster_pose:
		actor.buster_pose.influence = 0.0
	demo.text = "L / RT  Fire suit weapon"

func build_floor_light(tint: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position.y = 0.48
	light.omni_range = 4.0
	light.light_color = tint
	add_child(light)
	for i in range(2):
		var size := 1.72 + i * 0.56
		var ring := RiftProjectile.part(self, RiftProjectile.cached_mesh("Ring"), RiftProjectile.light_paint(tint, 1.65),
			Vector3(0, 0.018 + i * 0.015, 0), Vector3(size, 0.13, size * 0.72))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale *= 0.12
		create_tween().tween_property(ring, "scale", Vector3(size, 0.13, size * 0.72), 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in range(12):
		var angle := i * TAU / 12.0
		var glyph := RiftProjectile.part(self, RiftProjectile.cached_mesh("Orb"), RiftProjectile.light_paint(tint.lerp(Color.WHITE, 0.25), 1.2),
			Vector3(cos(angle) * 1.25, 0.04, sin(angle) * 0.91), Vector3(0.065, 0.024, 0.028))
		glyph.rotation.y = -angle
	return light

func ability_card(hud: CanvasLayer, reward: Dictionary, tint: Color) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UI.hud_frame(tint, Vector2(16, 12), true))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(plate)
	plate.anchor_left = 0.64
	plate.anchor_right = 0.95
	plate.anchor_top = 0.40
	var stack := UI.column(plate, 7)
	stack.name = "AbilityCopy"
	UI.label(stack, "SUIT ACQUIRED", 15, tint)
	UI.label(stack, String(reward.reward_name).to_upper(), 28)
	var details := UI.label(stack, Catalog.WEAPON_EFFECTS[reward.reward], 17, UI.MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(stack, "LB / RB  Cycle suits", 14, tint).name = "Demonstration"
	plate.modulate.a = 0.0
	create_tween().tween_property(plate, "modulate:a", 1.0, 0.22)
	return plate
