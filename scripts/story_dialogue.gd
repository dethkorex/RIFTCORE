extends CanvasLayer

const Story := preload("res://scripts/rift_story.gd")
const NOVA_DRONE := preload("res://assets/hub/nova_drone.glb")
const NOVA_EFFECT := preload("res://assets/ui/nova_transmission.gdshader")
const NOVA_FADE_TIME := 0.36

const UI := preload("res://scripts/rift_ui.gd")
const Reader := preload("res://scripts/dialogue_typewriter.gd")
const NOVA := preload("res://assets/ui/nova_portrait.png")
const RX07 := preload("res://assets/ui/story/rx07_expressions.png")
const VOSS := preload("res://assets/ui/story/voss.png")
const SOREN := preload("res://assets/ui/story/soren.png")
const BODY_FONT := preload("res://addons/GD-Sync/UI/Fonts/Outfit-Regular.ttf")
const NAMES := {"VOSS": "Dr. Mara Voss", "SOREN": "Dr. Ilyan Soren"}
const TINTS := {"NOVA": UI.VIOLET, "VOSS": Color("76ded5"), "SOREN": Color("f28082")}
const PITCHES := {"NOVA": 1.32, "VOSS": 1.14, "SOREN": 0.87}

var tutorial_title := ""
var disable_tips: Callable
var portrait_image: TextureRect
var portrait_style: StyleBoxFlat
var meter: HBoxContainer
var nova_image: TextureRect
var nova_view: SubViewport
var nova_model: Node3D
var nova_material: ShaderMaterial
var nova_fade: Tween
var accent := UI.CYAN
var speaking := false
var elapsed := 0.0

static func playback_seconds(lines: Array) -> float:
	var total := 0.0
	for index in lines.size():
		var line: Array = lines[index]
		total += Reader.automatic_seconds(line[1])
		if line[0] == Story.GUIDE and (index == lines.size() - 1 or lines[index + 1][0] != Story.GUIDE):
			total += NOVA_FADE_TIME
	return total

func play(lines: Array, finish_label: String, automatic := false, boss_name := "", boss_portrait: Texture2D = null, boss_tint := Color.WHITE, hold_timing := false) -> void:
	if lines.is_empty():
		return
	layer = 39
	set_process(false)
	if not automatic:
		add_to_group(&"interactive_dialogue")
	var backdrop := ColorRect.new()
	backdrop.color = Color("03071070")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if not automatic else Control.MOUSE_FILTER_IGNORE
	backdrop.theme = UI.theme()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.name = "Transmission"
	row.add_theme_constant_override("separation", 12)
	backdrop.add_child(row)
	row.anchor_left = 0.10
	row.anchor_right = 0.90
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -71
	row.offset_bottom = -71
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := UI.frame(Color("0c182c"), UI.CYAN, 4)
	panel_style.border_width_top = 2
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 13
	panel_style.shadow_color = Color("030710d8")
	panel_style.shadow_size = 9
	page.add_theme_stylebox_override("panel", panel_style)
	row.add_child(page)
	var content := UI.column(page, 6)
	var speaker := UI.label(content, "", 25, UI.CYAN)
	speaker.name = "Speaker"
	speaker.autowrap_mode = TextServer.AUTOWRAP_OFF
	var speech := UI.label(content, "", 24, UI.WHITE)
	speech.name = "Speech"
	speech.add_theme_font_override("font", BODY_FONT)
	speech.add_theme_constant_override("line_spacing", 5)
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 9)
	content.add_child(actions)

	var reader := Reader.new()
	add_child(reader)
	reader.body = speech
	reader.next = UI.button(actions, "Next", reader.advance, true, 34)
	reader.lettering_changed.connect(set_speaking)
	if not automatic:
		var skip := UI.button(actions, "Skip", reader.skip, false, 34)
		if disable_tips.is_valid():
			UI.button(actions, "Turn off tips", func():
				disable_tips.call()
				reader.skip()
			, false, 34)
		skip.focus_neighbor_left = skip.get_path_to(reader.next)
		reader.next.focus_neighbor_right = reader.next.get_path_to(skip)
		reader.next.grab_focus()
	else:
		actions.hide()

	build_portrait(row)
	var operator_portraits: Array[AtlasTexture] = []
	var cell := RX07.get_size() * 0.5
	for expression in 4:
		var at := Vector2(expression % 2, floori(expression / 2.0)) * cell
		operator_portraits.append(crop(RX07, Rect2(at, cell)))
	var scientist_portraits := {"VOSS": VOSS, "SOREN": SOREN}

	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.17)
	var time_remaining := get_tree().create_timer(playback_seconds(lines), false) if hold_timing else null
	for index in lines.size():
		var line: Array = lines[index]
		var guidance: bool = line[0] == Story.GUIDE
		var character: String = "NOVA" if guidance else line[0]
		var boss := character == "BOSS"
		accent = boss_tint if boss else TINTS.get(character, UI.CYAN)
		var nameplate: String = boss_name if boss else NAMES.get(character, character)
		var heading := Story.TUTORIAL_TITLE if guidance and tutorial_title.is_empty() else tutorial_title
		speaker.text = nameplate if heading.is_empty() else nameplate + "   /   " + heading
		panel_style.bg_color = Color("0c182c").lerp(accent, 0.05)
		panel_style.border_color = accent.darkened(0.25)
		speaker.add_theme_color_override("font_color", accent.lightened(0.16))
		var expression := clampi(int(line[2]), 0, operator_portraits.size() - 1) if line.size() > 2 else 0
		var next_image: Texture2D = operator_portraits[expression]
		if boss:
			next_image = boss_portrait
		elif character == "NOVA":
			next_image = NOVA
		elif scientist_portraits.has(character):
			next_image = scientist_portraits[character]
		if guidance and not nova_image.visible:
			show_nova()
		if portrait_image.texture != next_image:
			portrait_image.texture = next_image
			portrait_image.modulate.a = 0.30
			create_tween().tween_property(portrait_image, "modulate:a", 1.0, 0.19)
		reader.voice_pitch = 0.77 if boss else PITCHES.get(character, 1.0)
		reader.next.text = finish_label + "  ›" if index == lines.size() - 1 else "Next  ›"
		await reader.show_line(line[1], automatic)
		if guidance and (reader.skipped or index == lines.size() - 1 or lines[index + 1][0] != Story.GUIDE):
			await dismiss_nova()
		if reader.skipped:
			break
	hide()
	set_speaking(false)
	if not automatic:
		remove_from_group(&"interactive_dialogue")
	reader.queue_free()
	if time_remaining and time_remaining.time_left > 0.0:
		await time_remaining.timeout

func crop(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = texture
	portrait.region = region
	portrait.filter_clip = true
	return portrait

func build_portrait(row: HBoxContainer) -> void:
	var card := Panel.new()
	card.name = "PortraitCard"
	card.custom_minimum_size = Vector2(172, 166)
	row.add_child(card)
	var aperture := Control.new()
	aperture.clip_contents = true
	aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(aperture)
	aperture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aperture.offset_left = 4
	aperture.offset_top = 4
	aperture.offset_right = -4
	aperture.offset_bottom = -4

	portrait_image = TextureRect.new()
	portrait_image.name = "SpeakerPortrait"
	portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aperture.add_child(portrait_image)
	portrait_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_image.offset_left = -4
	portrait_image.offset_right = 4
	portrait_image.offset_top = -4
	portrait_image.offset_bottom = 4

	nova_image = TextureRect.new()
	nova_image.name = "NovaHologram"
	nova_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nova_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nova_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aperture.add_child(nova_image)
	nova_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nova_image.hide()

	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_style = UI.frame(Color("0b1528"), UI.CYAN, 4)
	card.add_theme_stylebox_override("panel", portrait_style.duplicate())
	portrait_style.draw_center = false
	portrait_style.set_border_width_all(4)
	portrait_style.set_corner_radius_all(5)
	border.add_theme_stylebox_override("panel", portrait_style)

	meter = HBoxContainer.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_constant_override("separation", 3)
	card.add_child(meter)
	meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	meter.offset_left = -42
	meter.offset_right = -12
	meter.offset_top = -19
	meter.offset_bottom = -9
	for index in 4:
		var segment := ColorRect.new()
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.custom_minimum_size.x = 4
		meter.add_child(segment)

func show_nova() -> void:
	if not nova_view:
		nova_view = SubViewport.new()
		nova_view.size = Vector2i(256, 256)
		nova_view.transparent_bg = true
		nova_view.own_world_3d = true
		nova_view.msaa_3d = Viewport.MSAA_2X
		add_child(nova_view)
		nova_model = NOVA_DRONE.instantiate() as Node3D
		nova_view.add_child(nova_model)
		var camera := Camera3D.new()
		nova_view.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.45
		camera.position = Vector3(0.0, 0.13, 2.2)
		camera.look_at(Vector3.ZERO)
		camera.make_current()
		var light := DirectionalLight3D.new()
		nova_view.add_child(light)
		light.rotation_degrees = Vector3(-28, 30, 0)
		light.light_energy = 1.4
		nova_material = ShaderMaterial.new()
		nova_material.shader = NOVA_EFFECT
		nova_image.material = nova_material
		nova_image.texture = nova_view.get_texture()
	nova_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	nova_image.show()
	portrait_image.hide()
	nova_fade = create_tween()
	nova_fade.tween_method(set_nova_signal, 0.0, 1.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func dismiss_nova() -> void:
	if nova_fade and nova_fade.is_running():
		nova_fade.kill()
	var strength: float = nova_material.get_shader_parameter("strength")
	nova_fade = create_tween()
	nova_fade.tween_method(set_nova_signal, strength, 0.0, NOVA_FADE_TIME)
	await nova_fade.finished
	nova_image.hide()
	nova_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	portrait_image.show()

func set_nova_signal(strength: float) -> void:
	nova_material.set_shader_parameter("strength", strength)
	nova_image.scale = Vector2.ONE * lerpf(0.9, 1.0, strength)
	nova_image.pivot_offset = nova_image.size * 0.5

func set_speaking(active: bool) -> void:
	speaking = active
	elapsed = 0.0
	if not is_instance_valid(portrait_image):
		return
	set_process(active or (is_instance_valid(nova_model) and nova_image.visible))
	update_portrait()

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(nova_model) and nova_image.visible:
		nova_model.position.y = sin(elapsed * 4.2) * 0.044
		nova_model.rotation.y = sin(elapsed * 2.4) * 0.16
	update_portrait()

func update_portrait() -> void:
	var weight := 0.50 + 0.50 * sin(elapsed * 15.0) if speaking else 0.0
	var lift := 2.2 * weight
	portrait_image.offset_top = -4 - lift
	portrait_image.offset_bottom = 4 - lift
	portrait_style.border_color = accent.darkened(0.25).lerp(Color.WHITE, weight * 0.34)
	for index in meter.get_child_count():
		var segment := meter.get_child(index) as ColorRect
		var pulse := 0.5 + 0.5 * sin(elapsed * 22.0 - index * 1.35) if speaking else 0.0
		segment.color = Color("182740").lerp(accent, 0.40 + pulse * 0.6)
