extends SubViewportContainer

const PlayerScene := preload("res://scenes/actors/riftcore_player.tscn")
const Pad := preload("res://assets/hub/deploy_pad.tscn")

var actor: RiftPlayer
var compact := false
var hud_portrait := false
var neutral_lighting := false
var allow_zoom := false
var camera: Camera3D
var skin := ""
var frame := ""
var customized: Dictionary = {}
var dragging := false
var rotation_axis := 0.0
const SkinKit := preload("res://scripts/operator_skins.gd")

func _ready() -> void:
	stretch = true
	if not hud_portrait:
		enable_controls()
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if neutral_lighting:
		view.msaa_3d = Viewport.MSAA_4X
	elif hud_portrait:
		view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	build_preview(view)

func enable_controls() -> void:
	custom_minimum_size = Vector2(116, 160) if compact else Vector2(225, 270)
	size_flags_vertical = Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	focus_mode = Control.FOCUS_ALL
	add_to_group(&"operator_preview")
	focus_exited.connect(func(): rotation_axis = 0.0)

func build_preview(view: SubViewport) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e4ebf8" if neutral_lighting else "a7bce6")
	environment.environment.ambient_light_energy = 0.75
	view.add_child(environment)
	if not hud_portrait:
		var display_pad := Pad.instantiate() as Node3D
		display_pad.set("caption", "")
		display_pad.scale = Vector3(0.78, 0.62, 0.78)
		view.add_child(display_pad)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.94 if hud_portrait else 2.20
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	view.add_child(camera)
	camera.position = Vector3(0.03, 1.66, 4.2) if hud_portrait else Vector3(0, 1.27, 4.2)
	camera.look_at(Vector3(0.03, 1.49, 0) if hud_portrait else Vector3(0, 1.01, 0))
	camera.make_current()
	light(view, Vector3(-1.8, 3.0, 2.3), Color("f9fcff" if neutral_lighting else "b9e9ff"), 1.85 if neutral_lighting else 2.2)
	light(view, Vector3(1.8, 1.8, -1.3), Color("b8c6df" if neutral_lighting else "ec64ff"), 1.85)
	actor = PlayerScene.instantiate() as RiftPlayer
	view.add_child(actor)
	actor.position.y = 1.01
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.set_physics_process(false)
	actor.model_root.rotation.y = -0.37
	if neutral_lighting:
		(actor.get_node("CoreLight") as OmniLight3D).light_energy = 0.65
	set_appearance(skin)
	actor.play_character_animation("idle", true)
	if actor.animation_player:
		actor.animation_player.advance(0.0)
	if not compact and not hud_portrait:
		var controls := "Drag to rotate  ·  Scroll to zoom  ·  Focus for right stick" if allow_zoom else "Drag to rotate  ·  Focus for right stick"
		var hint := preload("res://scripts/rift_ui.gd").profile_label(self, controls, 14, Color("a9c5dd"))
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -25.0
		hint.offset_bottom = -5.0
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_entered.connect(func(): hint.modulate = Color("72dcff"))
		focus_exited.connect(func(): hint.modulate = Color.WHITE)

func sync_operator(source: RiftPlayer) -> void:
	if not is_instance_valid(source) or not is_instance_valid(actor):
		return
	if frame != source.operator_frame or skin != source.armor_finish:
		frame = source.operator_frame
		set_appearance(source.armor_finish)
	var equipped := source.equipped_suit()
	if actor.equipped_suit() != equipped:
		if not equipped.is_empty() and equipped not in actor.run_weapon_ids:
			actor.run_weapon_ids.append(equipped)
		actor.equip_sector_weapon(equipped)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			grab_focus()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		dragging = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if dragging:
			rotate_operator(event.relative.x * 0.012)
			accept_event()
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_X:
		rotation_axis = event.axis_value if absf(event.axis_value) >= .20 else 0.0
		accept_event()
	elif allow_zoom and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(1.77, camera.size - 0.09)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(2.65, camera.size + 0.09)
			accept_event()

func _process(delta: float) -> void:
	if has_focus() and not is_zero_approx(rotation_axis):
		rotate_operator(rotation_axis * 2.8 * delta)

func rotate_operator(amount: float) -> void:
	if is_instance_valid(actor):
		actor.model_root.rotation.y = wrapf(actor.model_root.rotation.y + amount, -PI, PI)

func set_appearance(id: String) -> void:
	skin = id
	if not is_instance_valid(actor):
		return
	if not SkinKit.palette(id).is_empty():
		actor.equip_sector_weapon("")
		actor.set_operator_appearance(frame, id)
		customized = actor.armor_materials
		return
	actor.set_operator_appearance(frame, "")
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
