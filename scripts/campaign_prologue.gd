extends CanvasLayer

signal finished

const UI := preload("res://scripts/rift_ui.gd")
const BODY_FONT := preload("res://addons/GD-Sync/UI/Fonts/Outfit-Regular.ttf")
const BED := preload("res://assets/audio/dfg_ambient.ogg")
const FOUNDRY := preload("res://assets/neon_factory/foundry/foundry_panorama.jpg")
const LOCKDOWN := preload("res://assets/ui/story/lockdown.jpg")
const ARCHITECT := preload("res://assets/ui/story/architect.jpg")
const NEXUS := preload("res://assets/campaign/riftcore_nexus/panorama.png")
const STATION := preload("res://assets/ui/story/station.jpg")
const VOSS := preload("res://assets/ui/story/voss.png")
const SOREN := preload("res://assets/ui/story/soren.png")
const NOVA := preload("res://assets/ui/nova_portrait.png")
const RX07 := preload("res://assets/ui/story/rx07_expressions.png")

const METRO := preload("res://assets/neon_factory/factory_panorama.png")
const ORBIT := preload("res://assets/campaign/orbital_array/panorama.png")
const SKY_DOCK := preload("res://assets/campaign/sky_dock/panorama.png")
const ABYSS := preload("res://assets/campaign/abyssal_plant/panorama.png")
const KEY_ART := preload("res://assets/ui/riftcore_title_art.png")
const WORDMARK := preload("res://assets/ui/riftcore-wordmark.svg")

# Panel bounds are normalized to the game viewport so the art and lettering scale together.
const FRAMES := [
	{
		"panels": [[ORBIT, Rect2(.046, .065, .906, .65)], [METRO, Rect2(.577, .507, .34, .327)]],
		"caption": Rect2(.067, .875, .49, 0), "title": "MERIDIAN  /  EARTH, 2189",
		"body": "Meridian grew around a power source called the Riftcore. In 2189 it lit ten districts, from the furnaces below the city to the docks above the clouds.",
		"color": Color("77e9ff"), "hold": 9.4,
	},
	{
		"panels": [[NEXUS, Rect2(.049, .068, .545, .688)], [SKY_DOCK, Rect2(.611, .087, .34, .377)], [ABYSS, Rect2(.645, .478, .293, .292)]],
		"caption": Rect2(.07, .875, .52, 0), "title": "A CITY RUN BY MACHINES",
		"body": "The Architect kept Meridian running. It sent water to the shelters, heat to the streets, and cargo to the docks. Each district could still take the controls in an emergency.",
		"color": Color("a193ff"), "hold": 8.8,
	},
	{
		"panels": [[METRO, Rect2(.046, .065, .908, .668)], [LOCKDOWN, Rect2(.575, .53, .346, .319)]],
		"caption": Rect2(.067, .875, .49, 0), "title": "THE BLACKOUT",
		"body": "Then ten districts dropped off the network in a single night. The streetlights went first. A few minutes later, the shelters stopped answering.",
		"color": Color("ffbe83"), "hold": 8.2, "blackout": true, "cue": &"enemy_break",
	},
	{
		"panels": [[NEXUS, Rect2(.046, .065, .51, .63)], [SOREN, Rect2(.566, .102, .365, .71)]],
		"caption": Rect2(.07, .875, .46, 0), "title": "DR. ILYAN SOREN",
		"body": "Director Soren feared the outage would spread. From the Nexus, he gave the Architect a new order. “If a district goes silent, seal it. No local overrides.”",
		"color": Color("ff9298"), "hold": 9.3,
	},
	{
		"panels": [[ARCHITECT, Rect2(.046, .068, .91, .70)], [LOCKDOWN, Rect2(.092, .425, .33, .30)]],
		"caption": Rect2(.067, .875, .59, 0), "title": "LOCKDOWN",
		"body": "The Architect assumed the silent districts were empty. It locked the gates, cut heat to the shelters, and turned the rescue fleet around. People were still inside.",
		"color": Color("ff82ba"), "hold": 9.6,
	},
	{
		"panels": [[STATION, Rect2(.427, .075, .532, .686)], [VOSS, Rect2(.057, .101, .352, .672)]],
		"caption": Rect2(.427, .875, .50, 0), "title": "DR. MARA VOSS",
		"body": "Voss fitted a rescue frame with a way to override the order. “RX-07, I built you to bring people home. If the Architect tells you to leave them behind, you can say no.”",
		"color": Color("7bf1ff"), "hold": 9.0,
	},
	{
		"panels": [[LOCKDOWN, Rect2(.047, .061, .906, .717)], [RX07, Rect2(.079, .30, .25, .441)]],
		"caption": Rect2(.442, .875, .48, 0), "title": "ORDER REFUSED",
		"body": "At the last evacuation gate, RX-07 disobeyed. He held the door long enough for the convoy to get through. On the other side of the gate, Voss’s signal went silent.",
		"color": Color("78e9ff"), "hold": 8.5,
	},
	{
		"panels": [[FOUNDRY, Rect2(.421, .073, .534, .682)], [NOVA, Rect2(.066, .215, .303, .536)]],
		"caption": Rect2(.421, .875, .51, 0), "title": "THE LAST MESSAGE",
		"body": "NOVA, the station’s little relay drone, saved the last thing Voss sent: a work order for three emergency generators. All three were bound for Ember Foundry.",
		"color": Color("c5b1ff"), "hold": 9.0, "cue": &"pickup",
	},
	{
		"panels": [[STATION, Rect2(.047, .065, .905, .689)], [RX07, Rect2(.083, .42, .227, .387)]],
		"caption": Rect2(.393, .875, .536, 0), "title": "OPERATIONS STATION",
		"body": "RX-07 woke in a repaired frame with gaps in his memory. NOVA was still on the channel. The generators could give the shelters heat again, and the order might tell them where Voss went.",
		"color": Color("8bdeff"), "hold": 8.4,
	},
	{
		"panels": [[FOUNDRY, Rect2(.044, .064, .912, .73)], [RX07, Rect2(.664, .32, .247, .424)]],
		"caption": Rect2(.071, .875, .537, 0), "title": "FIRST DEPLOYMENT  /  EMBER FOUNDRY",
		"body": "The furnaces are still burning. The shipments never arrived. Find those generators, follow Voss’s trail, and get the city back into the hands of the people who live there.",
		"color": Color("ffb98b"), "hold": 8.7,
	},
	{
		"panels": [[KEY_ART, Rect2(.035, .055, .93, .807)]],
		"caption": Rect2(.0, .0, .0, .0), "title": "", "body": "",
		"color": Color("5feaff"), "hold": 5.3, "cue": &"checkpoint",
	},
]

var scene_index := -1
var ended := false
var canvas: Control
var page: Control
var shade: ColorRect
var next: Button
var ambient: AudioStreamPlayer
var timing: Tween
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
	var duration: float = shot.hold
	var tint: Color = shot.color
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	canvas.move_child(page, 1)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion = create_tween().set_parallel()
	for index in shot.panels.size():
		var panel: Array = shot.panels[index]
		add_art_panel(panel[0], panel[1], tint, index, duration, index == 0 and shot.get("blackout", false), shot.title.is_empty())
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
	timing = create_tween()
	timing.tween_interval(duration)
	timing.tween_callback(advance)

func add_art_panel(texture: Texture2D, bounds: Rect2, tint: Color, index: int, duration: float, blackout: bool, title_card: bool) -> void:
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

	var direction := -1.0 if (scene_index + index) % 2 == 0 else 1.0
	var delay := index * 0.34
	var entry := 38.0 * direction
	frame.offset_left = entry
	frame.offset_right = entry
	motion.tween_property(frame, "modulate:a", 1.0, 0.38).set_delay(delay)
	motion.tween_method(func(value: float):
		frame.offset_left = value
		frame.offset_right = value
	, entry, 0.0, 0.56).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var scientist_portrait := texture == VOSS or texture == SOREN
	var horizontal_bleed := 10.0 if scientist_portrait else 31.0
	var vertical_bleed := 0.0 if scientist_portrait else 18.0
	var drift := 8.0 if scientist_portrait else 18.0
	motion.tween_method(func(value: float):
		picture.offset_left = -horizontal_bleed + value
		picture.offset_right = horizontal_bleed + value
		var tilt := 0.0 if scientist_portrait else value * 0.13
		picture.offset_top = -vertical_bleed + tilt
		picture.offset_bottom = vertical_bleed + tilt
	, -drift * 0.83 * direction, drift * direction, duration).set_trans(Tween.TRANS_SINE)
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
	caption.offset_top = 11
	caption.offset_bottom = 11
	caption.offset_right = -11
	caption.modulate.a = 0.0
	var paper := UI.frame(Color("eff4fb"), tint.darkened(0.4), 5)
	paper.content_margin_left = 19
	paper.content_margin_right = 19
	paper.shadow_color = Color("01040ad9")
	paper.shadow_size = 8
	paper.shadow_offset = Vector2(5, 6)
	caption.add_theme_stylebox_override("panel", paper)
	var copy := UI.column(caption, 5)
	UI.label(copy, title, 27, Color("17283f"))
	var body := UI.label(copy, detail, 25, Color("182638"))
	body.add_theme_font_override("font", BODY_FONT)
	body.add_theme_constant_override("line_spacing", 3)
	motion.tween_property(caption, "modulate:a", 1.0, 0.48).set_delay(0.51)
	motion.tween_method(func(value: float):
		caption.offset_top = value
		caption.offset_bottom = value
	, 11.0, 0.0, 0.62).set_delay(0.51).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func anchor_to(control: Control, bounds: Rect2) -> void:
	control.anchor_left = bounds.position.x
	control.anchor_top = bounds.position.y
	control.anchor_right = bounds.end.x
	control.anchor_bottom = bounds.end.y

func stop_motion() -> void:
	for tween in [motion, fade, timing]:
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
