extends RefCounted

const FoundryRig := preload("res://scripts/foundry_boss_rig.gd")
const Fire := preload("res://addons/pyrolux_fx/nodes_3d/pyrolux_fire_3d.gd")
const Ring := preload("res://assets/vfx/warden_pressure_ring.gdshader")
const Materialize := preload("res://assets/vfx/boss_materialize.gdshader")
const STEAM := Color("a9bbc2")

static func play(director: Node, camera: Camera3D, boss: Combatant, armor: FoundryRig, chamber: Node3D, pad: Node3D, title: String, tint: Color, readout: Control) -> void:
	var landing := boss.global_position
	var floor_at := Vector3(landing.x, pad.global_position.y + .10, landing.z)
	var focal := floor_at + Vector3.UP * 2.0
	var hatch := chamber.global_position + Vector3(0, 3.02, .44)
	var theatre := letterbox(director)
	var fov := camera.fov
	camera.fov = 63.0
	boss.hide()
	chamber.present_hatch(0.0, 0.0)
	RiftAudio.foundry_sound(&"warden_ignition", hatch)
	var seals := director.create_tween()
	seals.tween_method(func(weight: float):
		chamber.present_hatch(weight, 0.0)
		director.aim(camera, hatch + Vector3.RIGHT * lerpf(-1.35, -.32, weight), Vector3(-4.6, .32, 12.3).lerp(Vector3(-3.8, .42, 10.85), weight))
	, 0.0, 1.0, .78)
	await seals.finished
	var steam_left := steam_jet(director, chamber.global_position + Vector3(-2.55, .28, .72), tint)
	var steam_right := steam_jet(director, chamber.global_position + Vector3(2.55, .28, .72), tint)
	RiftAudio.foundry_sound(&"fire_jet", hatch)
	pad.pulse()
	var hatch_tween := director.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	hatch_tween.tween_method(func(weight: float):
		chamber.present_hatch(1.0, weight)
		director.aim(camera, hatch.lerp(focal, weight * .62), Vector3(-3.8, .42, 10.85).lerp(Vector3(-2.7, .28, 9.50), weight))
	, 0.0, 1.0, .62)
	await hatch_tween.finished
	boss.show()
	var scan := ShaderMaterial.new()
	scan.shader = Materialize
	scan.set_shader_parameter("tint", tint)
	var skins: Dictionary[MeshInstance3D, Material] = {}
	for mesh: MeshInstance3D in armor.find_children("*", "MeshInstance3D", true, false):
		skins[mesh] = mesh.material_override
		mesh.material_override = scan
	var exhaust := director.make_charge(pad, tint, 1.7, 2.5) as PyroluxFire3D
	exhaust.flame_height = .68
	exhaust.light_energy = 1.7
	exhaust.embers = 54
	exhaust.puffs = 4
	exhaust.tongues = 0
	exhaust.smoke = 0
	exhaust.ignite()
	var materialize := director.create_tween()
	materialize.tween_method(func(weight: float):
		boss.global_position = landing + Vector3(0, sin(weight * PI) * .24, lerpf(-2.35, 0.0, smoothstep(0.0, 1.0, weight)))
		boss.reset_physics_interpolation()
		armor.rotation.y = lerp_angle(-.67, -.36, weight)
		armor.cinematic_pose(.016, sin(weight * PI), 0.0, weight * .55, weight * .72)
		scan.set_shader_parameter("scan_y", floor_at.y - .08 + 4.65 * smoothstep(0.0, .78, weight))
		director.aim(camera, hatch.lerp(focal, .62 + weight * .38), Vector3(-2.7, .28, 9.50).lerp(Vector3(-2.05, .46, 7.8), weight))
	, 0.0, 1.0, .78)
	await materialize.finished
	steam_left.extinguish()
	steam_right.extinguish()
	exhaust.extinguish()
	for mesh in skins:
		if is_instance_valid(mesh):
			mesh.material_override = skins[mesh]
	boss.global_position = landing
	boss.reset_physics_interpolation()
	pressure_ring(director, floor_at, tint)
	RiftAudio.foundry_sound(&"boulder_roll", floor_at)
	RiftAudio.play_effect(&"armor_hit")
	var title_card := director.show_title(title, tint, 1, camera.get_viewport()) as CanvasLayer
	var hero := Vector3(-2.76, .42, 6.6)
	var hero_focus := focal - Vector3.RIGHT * .84 - Vector3.UP * .17
	var beat := director.create_tween()
	beat.tween_method(func(weight: float):
		var kick := sin(PI * minf(weight * 3.8, 1.0)) * .13
		armor.cinematic_pose(.016, 0.0, kick, smoothstep(0.0, .45, weight), 1.0 - weight * .32)
		director.aim(camera, focal.lerp(hero_focus, smoothstep(0.0, 1.0, weight)), Vector3(-2.05, .46, 7.8).lerp(hero, weight) + Vector3.UP * kick)
	, 0.0, 1.0, 1.04)
	await beat.finished
	title_card.queue_free()

	var hero_camera := camera.transform
	var overview := Vector3(landing.x - 6.8, floor_at.y + 12.15, -.40)
	var pull := director.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pull.tween_method(func(weight: float):
		director.aim(camera, hero_focus.lerp(overview, weight), hero.lerp(Vector3(-1.05, 2.75, 28.85), weight))
		camera.fov = lerpf(63.0, fov, weight)
	, 0.0, 1.0, .60)
	await pull.finished
	await director.get_tree().create_timer(.23, false).timeout
	camera.transform = hero_camera
	camera.fov = fov
	theatre.queue_free()
	readout.boss_name = title.to_upper()
	readout.boss_tint = tint
	readout.boss_sector = 1
	readout.boss_act = 1
	readout.boss_max_health = boss.max_health
	readout.boss_health = boss.health
	readout.boss_visible = true
	readout.queue_redraw()

static func letterbox(owner: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 23
	owner.add_child(layer)
	var bounds := Control.new()
	bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bounds)
	bounds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in [0.0, 1.0]:
		var bar := ColorRect.new()
		bar.color = Color(.012, .015, .020, 1.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bounds.add_child(bar)
		bar.anchor_right = 1.0
		bar.anchor_top = edge
		bar.anchor_bottom = edge
		bar.offset_top = -41.0 if edge == 1.0 else 0.0
		bar.offset_bottom = 0.0 if edge == 1.0 else 44.0
	return layer

static func steam_jet(owner: Node, at: Vector3, heat: Color) -> PyroluxFire3D:
	var plume := Fire.new()
	plume.autoplay = false
	plume.fade_time = .43
	plume.shape = PyroluxFire3D.Shape.LINE
	plume.size = Vector3(.68, .1, .16)
	plume.tongues = 0
	plume.puffs = 0
	plume.embers = 22
	plume.ember_height = 2.8
	plume.smoke = 26
	plume.smoke_height = 3.0
	plume.smoke_opacity = .42
	plume.flame_height = .28
	plume.flame_width = .72
	plume.light_enabled = false
	var palette := PyroluxPalette.new()
	palette.cool = STEAM.darkened(.26)
	palette.hot = STEAM.lerp(heat, .21)
	palette.core = STEAM.lightened(.18)
	palette.smoke = STEAM.darkened(.24)
	plume.palette = palette
	owner.add_child(plume)
	plume.global_position = at
	plume.ignite()
	return plume

static func pressure_ring(owner: Node, at: Vector3, tint: Color) -> void:
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(10.0, 6.0)
	sheet.mesh = quad
	sheet.rotation.x = -PI * .5
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Ring
	material.set_shader_parameter("heat", tint)
	sheet.material_override = material
	owner.add_child(sheet)
	sheet.global_position = at + Vector3.UP * .095
	var bloom := owner.create_tween()
	bloom.tween_method(func(weight: float): material.set_shader_parameter("travel", weight), 0.0, 1.0, .65)
	bloom.tween_callback(sheet.queue_free)
