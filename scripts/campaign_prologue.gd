extends CanvasLayer

signal finished

const UI := preload("res://scripts/rift_ui.gd")
const BODY_FONT := preload("res://addons/GD-Sync/UI/Fonts/Outfit-Regular.ttf")
const BED := preload("res://assets/audio/dfg_ambient.ogg")
const LOCKDOWN := preload("res://assets/ui/story/lockdown.jpg")
const NEXUS := preload("res://assets/campaign/riftcore_nexus/panorama.png")
const STATION := preload("res://assets/ui/story/station.jpg")
const VOSS := preload("res://assets/ui/story/voss.png")
const SOREN := preload("res://assets/ui/story/soren.png")
const RX07 := preload("res://assets/ui/story/rx07_expressions.png")

const METRO := preload("res://assets/neon_factory/factory_panorama.png")
const ABYSS := preload("res://assets/campaign/abyssal_plant/panorama.png")
const KEY_ART := preload("res://assets/ui/riftcore_title_art.png")
const WORDMARK := preload("res://assets/ui/riftcore-wordmark.svg")

# Panel bounds are normalized to the game viewport so the art and lettering scale together.
const FRAMES := [
	{
		"panels": [[METRO, Rect2(.046, .065, .907, .755)]],
		"caption": Rect2(.068, .875, .59, 0), "title": "MERIDIAN  /  EARTH, 2189",
		"body": "The Riftcore cracked beneath Meridian. The surge took out the district grid. From the air, only the Nexus was still lit.",
		"color": Color("77e9ff"), "blackout": true, "cue": &"enemy_break",
	},
	{
		"panels": [[NEXUS, Rect2(.046, .065, .908, .755)], [SOREN, Rect2(.61, .12, .31, .68)]],
		"caption": Rect2(.068, .875, .52, 0), "title": "DIRECTOR SOREN",
		"body": "Soren ordered the Architect to cut nine districts off the grid. The Nexus stayed lit. Beyond its walls, shelters lost their heat, water, and power.",
		"color": Color("ff9298"),
	},
	{
		"panels": [[STATION, Rect2(.046, .065, .908, .755)], [VOSS, Rect2(.072, .122, .32, .69)]],
		"caption": Rect2(.415, .875, .51, 0), "title": "DR. MARA VOSS",
		"body": "Voss had built RX-07 for a failure like this. “You can hold a district's load until the other crews can help. That's how we bring Meridian back into balance.”",
		"color": Color("7bf1ff"),
	},
	{
		"panels": [[ABYSS, Rect2(.047, .065, .902, .755)], [LOCKDOWN, Rect2(.562, .115, .355, .349)], [RX07, Rect2(.091, .403, .237, .388)]],
		"caption": Rect2(.425, .875, .49, 0), "title": "THE FLOODGATE",
		"body": "RX-07 kept a floodgate powered long enough for the evacuation boats to get through. The gate went dark. So did Voss's transmitter.",
		"color": Color("78e9ff"),
	},
	{
		"panels": [[KEY_ART, Rect2(.035, .055, .93, .807)]],
		"caption": Rect2(.0, .0, .0, .0), "title": "", "body": "",
		"color": Color("5feaff"), "cue": &"checkpoint",
	},
]


var scene_index := -1
var ended := false
var canvas: Control
var page: Control
var shade: ColorRect
var next: Button
var ambient: AudioStreamPlayer
var fade: Tween
var motion: Tween

func play() -> void:
	layer = 48
	canvas = Control.new()
	canvas.theme = UI.theme()
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("060b18")
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.add_theme_constant_override("separation", 10)
	canvas.add_child(controls)
	anchor_to(controls, Rect2(.07, .90, .87, .05))
	next = UI.button(controls, "Next", advance, true, 35)
	UI.button(controls, "Skip intro", close, false, 35)
	next.grab_focus()

	shade = ColorRect.new()
	shade.color = Color("040810")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	ambient = AudioStreamPlayer.new()
	var soundtrack := BED.duplicate() as AudioStreamOggVorbis
	soundtrack.loop = true
	ambient.stream = soundtrack
	ambient.bus = &"Music"
	ambient.volume_db = -24.0
	add_child(ambient)
	ambient.play()
	advance()
	await finished

func advance() -> void:
	if ended:
		return
	if scene_index >= FRAMES.size() - 1:
		close()
		return
	stop_motion()
	if is_instance_valid(page):
		page.hide()
		page.queue_free()
	scene_index += 1
	var shot: Dictionary = FRAMES[scene_index]
	var tint: Color = shot.color
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	canvas.move_child(page, 1)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion = create_tween().set_parallel()
	for index in shot.panels.size():
		var panel: Array = shot.panels[index]
		add_art_panel(panel[0], panel[1], tint, index, index == 0 and shot.get("blackout", false), shot.title.is_empty())
	if shot.title.is_empty():
		add_title_card()
	else:
		add_caption(shot.caption, shot.title, shot.body, tint)
	if shot.has("cue"):
		RiftAudio.play_effect(shot.cue)
	next.text = "Continue" if scene_index == FRAMES.size() - 1 else "Next"
	shade.color.a = 0.85
	fade = create_tween()
	fade.tween_property(shade, "color:a", 0.0, 0.33)

func add_art_panel(texture: Texture2D, bounds: Rect2, tint: Color, index: int, blackout: bool, title_card: bool) -> void:
	if texture == RX07:
		var operator_portrait := AtlasTexture.new()
		operator_portrait.atlas = RX07
		operator_portrait.region = Rect2(0, RX07.get_height() * .5, RX07.get_width() * .5, RX07.get_height() * .5)
		operator_portrait.filter_clip = true
		texture = operator_portrait

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0
	page.add_child(frame)
	anchor_to(frame, bounds)
	var outline := UI.frame(Color("0a111e"), tint.lightened(0.18), 2)
	outline.set_border_width_all(2)
	outline.corner_radius_bottom_left = 0
	outline.corner_radius_top_right = 0
	outline.shadow_color = Color("020409cf")
	outline.shadow_size = 7
	outline.shadow_offset = Vector2(5, 6)
	frame.add_theme_stylebox_override("panel", outline)

	var aperture := Control.new()
	aperture.clip_contents = true
	aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(aperture)
	aperture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aperture.offset_left = 3
	aperture.offset_top = 3
	aperture.offset_right = -3
	aperture.offset_bottom = -3
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = texture
	if title_card:
		picture.modulate = Color("a7abcf")
	aperture.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var delay := index * 0.28
	motion.tween_property(frame, "modulate:a", 1.0, 0.44).set_delay(delay)
	if blackout:
		motion.tween_property(picture, "modulate", Color("53607a"), 0.82).set_delay(1.2)

func add_title_card() -> void:
	var mark := TextureRect.new()
	mark.texture = WORDMARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(mark)
	anchor_to(mark, Rect2(.49, .181, .408, .175))
	var subtitle := UI.label(page, "ROGUE PROTOCOL", 33, UI.WHITE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_outline_color", Color("101629"))
	subtitle.add_theme_constant_override("outline_size", 9)
	anchor_to(subtitle, Rect2(.49, .363, .408, .09))
	for item in [mark, subtitle]:
		item.modulate.a = 0.0
		motion.tween_property(item, "modulate:a", 1.0, 0.55).set_delay(0.42)

func add_caption(bounds: Rect2, title: String, detail: String, tint: Color) -> void:
	var caption := PanelContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(caption)
	anchor_to(caption, bounds)
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.offset_right = -11
	caption.modulate.a = 0.0
	var panel := UI.frame(Color("0c1627"), tint.darkened(0.26), 5)
	panel.content_margin_left = 19
	panel.content_margin_right = 19
	panel.shadow_color = Color("01040ad9")
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(5, 6)
	caption.add_theme_stylebox_override("panel", panel)
	var copy := UI.column(caption, 5)
	UI.label(copy, title, 27, tint)
	var body := UI.label(copy, detail, 25, UI.WHITE)
	body.add_theme_font_override("font", BODY_FONT)
	body.add_theme_constant_override("line_spacing", 3)
	motion.tween_property(caption, "modulate:a", 1.0, 0.48).set_delay(0.51)

func anchor_to(control: Control, bounds: Rect2) -> void:
	control.anchor_left = bounds.position.x
	control.anchor_top = bounds.position.y
	control.anchor_right = bounds.end.x
	control.anchor_bottom = bounds.end.y

func stop_motion() -> void:
	for tween in [motion, fade]:
		if tween and tween.is_running():
			tween.kill()

func close() -> void:
	if ended:
		return
	ended = true
	stop_motion()
	var exit_fade := create_tween()
	exit_fade.tween_property(shade, "color:a", 1.0, 0.25)
	exit_fade.parallel().tween_property(ambient, "volume_db", -55.0, 0.25)
	await exit_fade.finished
	finished.emit()

func _input(event: InputEvent) -> void:
	if ended or not is_instance_valid(next):
		return
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"ui_accept") and not event.is_echo():
		var focused := get_viewport().gui_get_focus_owner() as Button
		get_viewport().set_input_as_handled()
		if focused and is_ancestor_of(focused):
			focused.pressed.emit()
		else:
			advance()
