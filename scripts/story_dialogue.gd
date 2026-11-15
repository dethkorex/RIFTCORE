extends CanvasLayer

const UI := preload("res://scripts/rift_ui.gd")
const Reader := preload("res://scripts/dialogue_typewriter.gd")
const NOVA := preload("res://assets/ui/nova_guide.svg")
const RX07 := preload("res://assets/ui/rx07_menu.png")

func play(lines: Array, finish_label: String, automatic := false, boss_name := "", boss_portrait: Texture2D = null, boss_tint := Color.WHITE, hold_timing := false) -> void:
	layer = 39
	if not automatic:
		add_to_group(&"interactive_dialogue")
	var box := PanelContainer.new()
	box.theme = UI.theme()
	box.add_theme_stylebox_override("panel", UI.frame(Color("0c182cf5"), UI.CYAN, 9))
	add_child(box)
	box.anchor_left = 0.16
	box.anchor_right = 0.84
	box.anchor_top = 0.78
	box.anchor_bottom = 0.78
	box.offset_top = -136
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	box.add_child(row)
	var frame := PanelContainer.new()
	row.add_child(frame)
	var image := TextureRect.new()
	image.name = "SpeakerPortrait"
	image.custom_minimum_size = Vector2(92, 96)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(image)
	var pane := UI.column(row, 4)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var speaker := UI.label(pane, "", 23, UI.CYAN)
	speaker.name = "Speaker"
	var speech := UI.label(pane, "", 20)
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	pane.add_child(actions)
	var reader := Reader.new()
	add_child(reader)
	reader.body = speech
	reader.next = UI.button(actions, "Next", reader.advance, true, 32)
	if not automatic:
		UI.button(actions, "Skip", reader.skip, false, 32)
		var hint := UI.label(actions, "START to skip", 14, UI.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var operator_image := AtlasTexture.new()
	operator_image.atlas = RX07
	var source := RX07.get_size()
	operator_image.region = Rect2(source.x * 0.35, source.y * 0.05, source.x * 0.31, source.y * 0.46)
	var total := 0.0
	for line in lines:
		total += Reader.automatic_seconds(line[1])
	var time_remaining := get_tree().create_timer(total, false) if hold_timing else null
	for index in lines.size():
		var line: Array = lines[index]
		var guide: bool = line[0] == "NOVA"
		var boss: bool = line[0] == "BOSS"
		var accent := boss_tint if boss else UI.VIOLET if guide else UI.CYAN
		speaker.text = boss_name if boss else line[0]
		speaker.add_theme_color_override("font_color", accent.lightened(0.2))
		frame.add_theme_stylebox_override("panel", UI.frame(Color("081222"), accent, 3))
		image.texture = boss_portrait if boss else NOVA if guide else operator_image
		reader.next.text = finish_label if index == lines.size() - 1 else "Next"
		await reader.show_line(line[1], automatic)
		if reader.skipped:
			break
	hide()
	if not automatic:
		remove_from_group(&"interactive_dialogue")
	reader.queue_free()
	if time_remaining and time_remaining.time_left > 0.0:
		await time_remaining.timeout
