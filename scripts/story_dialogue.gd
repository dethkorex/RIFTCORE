extends CanvasLayer

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
var accent := UI.CYAN
var speaking := false
var elapsed := 0.0

static func playback_seconds(lines: Array) -> float:
	var total := 0.0
	for line in lines:
		total += Reader.automatic_seconds(line[1])
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
	var paper := UI.frame(Color("eff4fa"), Color("607896"), 4)
	paper.corner_radius_top_left = 12
	paper.corner_radius_top_right = 12
	paper.corner_radius_bottom_left = 12
	paper.corner_radius_bottom_right = 12
	paper.content_margin_left = 24
	paper.content_margin_right = 22
	paper.content_margin_top = 12
	paper.content_margin_bottom = 11
	paper.shadow_color = Color("030710b0")
	paper.shadow_size = 9
	page.add_theme_stylebox_override("panel", paper)
	row.add_child(page)
	var content := UI.column(page, 6)
	var speaker := UI.label(content, "", 25, Color("163456"))
	speaker.name = "Speaker"
	var speech := UI.label(content, "", 24, Color("13233a"))
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
		var character: String = line[0]
		var boss := character == "BOSS"
		accent = boss_tint if boss else TINTS.get(character, UI.CYAN)
		var nameplate: String = boss_name if boss else NAMES.get(character, character)
		speaker.text = nameplate if tutorial_title.is_empty() else nameplate + "   /   " + tutorial_title
		paper.border_color = accent.darkened(0.45)
		speaker.modulate = Color.WHITE
		speaker.add_theme_color_override("font_color", accent.darkened(0.68))
		var expression := clampi(int(line[2]), 0, operator_portraits.size() - 1) if line.size() > 2 else 0
		var next_image: Texture2D = operator_portraits[expression]
		if boss:
			next_image = boss_portrait
		elif character == "NOVA":
			next_image = NOVA
		elif scientist_portraits.has(character):
			next_image = scientist_portraits[character]
		if portrait_image.texture != next_image:
			portrait_image.texture = next_image
			portrait_image.modulate.a = 0.30
			create_tween().tween_property(portrait_image, "modulate:a", 1.0, 0.19)
		reader.voice_pitch = 0.77 if boss else PITCHES.get(character, 1.0)
		reader.next.text = finish_label + "  ›" if index == lines.size() - 1 else "Next  ›"
		await reader.show_line(line[1], automatic)
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

func set_speaking(active: bool) -> void:
	speaking = active
	elapsed = 0.0
	if not is_instance_valid(portrait_image):
		return
	set_process(active)
	update_portrait()

func _process(delta: float) -> void:
	elapsed += delta
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
