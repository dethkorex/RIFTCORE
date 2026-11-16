extends SubViewportContainer

const PlayerScene := preload("res://scenes/actors/riftcore_player.tscn")
const Pad := preload("res://assets/hub/deploy_pad.tscn")

var actor: RiftPlayer
var compact := false
var skin := ""
var customized: Dictionary = {}
const SkinKit := preload("res://scripts/operator_skins.gd")

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(116, 160) if compact else Vector2(225, 270)
	size_flags_vertical = Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a7bce6")
	environment.environment.ambient_light_energy = 0.75
	view.add_child(environment)
	var display_pad := Pad.instantiate() as Node3D
	display_pad.set("caption", "")
	display_pad.scale = Vector3(0.78, 0.62, 0.78)
	view.add_child(display_pad)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.20
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	view.add_child(camera)
	camera.position = Vector3(0, 1.27, 4.2)
	camera.look_at(Vector3(0, 1.01, 0))
	camera.make_current()
	light(view, Vector3(-1.8, 3.0, 2.3), Color("b9e9ff"), 2.2)
	light(view, Vector3(1.8, 1.8, -1.3), Color("ec64ff"), 1.85)
	actor = PlayerScene.instantiate() as RiftPlayer
	view.add_child(actor)
	actor.position.y = 1.01
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.set_physics_process(false)
	actor.model_root.rotation.y = -0.37
	set_appearance(skin)
	actor.play_character_animation("idle", true)
	if actor.animation_player:
		actor.animation_player.advance(0.0)

func set_appearance(id: String) -> void:
	skin = id
	if not is_instance_valid(actor):
		return
	if not SkinKit.palette(id).is_empty():
		actor.equip_sector_weapon("")
		actor.set_armor_finish(id)
		customized = actor.armor_materials
		return
	actor.set_armor_finish("")
	customized = actor.armor_materials
	if not id.is_empty() and not actor.run_weapon_ids.has(id):
		actor.run_weapon_ids.append(id)
	actor.equip_sector_weapon(id)

func light(view: SubViewport, at: Vector3, tint: Color, brightness: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = tint
	lamp.light_energy = brightness
	lamp.omni_range = 6.0
	view.add_child(lamp)
