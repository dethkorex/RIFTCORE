extends RefCounted

const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-Medium.ttf")
const KIT := "res://assets/ui/riftcore_kit/"

const CYAN := Color("55e7ff")
const MUTED := Color("9db4cc")
const WHITE := Color("e7f2ff")
const VIOLET := Color("bf82ff")
const FOCUS_COLORS := [CYAN, VIOLET, Color("f9c65a"), Color("68f0bb"), Color("ff87db")]
static var highlight_texture: ImageTexture

static func frame(fill: Color, edge: Color, accent := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.border_width_left = accent
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func texture_frame(name: String, corner: float, padding: Vector2) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(KIT + name + ".png") as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, corner)
		style.set_content_margin(side, padding.x if side in [SIDE_LEFT, SIDE_RIGHT] else padding.y)
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = BODY
	result.default_font_size = 18
	result.set_color("font_color", "Label", WHITE)
	result.set_stylebox("panel", "PanelContainer", texture_frame("panel_base_small", 31, Vector2(21, 14)))
	result.set_stylebox("panel", "Panel", texture_frame("panel_base_small", 31, Vector2(21, 14)))
	result.set_stylebox("normal", "Button", texture_frame("button_secondary", 30, Vector2(22, 8)))
	result.set_stylebox("hover", "Button", texture_frame("button_primary", 31, Vector2(22, 8)))
	result.set_stylebox("pressed", "Button", texture_frame("button_primary", 31, Vector2(22, 8)))
	result.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	result.set_stylebox("disabled", "Button", texture_frame("button_disabled", 27, Vector2(22, 8)))
	return result

static func label(parent: Node, value: String, font_size := 17, color := WHITE) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_font_override("font", DISPLAY if font_size >= 23 else BODY)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

static func style_button(item: Button, accent: Color) -> void:
	if not highlight_texture:
		var source := load(KIT + "button_primary.png") as Texture2D
		var pixels := source.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		for y in pixels.get_height():
			for x in pixels.get_width():
				var pixel := pixels.get_pixel(x, y)
				var value := pixel.v
				pixels.set_pixel(x, y, Color(value, value, value, pixel.a))
		highlight_texture = ImageTexture.create_from_image(pixels)
	var active := texture_frame("button_primary", 31, Vector2(22, 8))
	active.texture = highlight_texture
	active.modulate_color = accent
	var down := active.duplicate() as StyleBoxTexture
	down.modulate_color = accent.darkened(0.22)
	var inactive := item.get_theme_stylebox("normal")
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item.add_theme_stylebox_override("hover", active)
	item.add_theme_stylebox_override("pressed", down)
	item.add_theme_stylebox_override("hover_pressed", down)
	item.focus_entered.connect(func(): item.add_theme_stylebox_override("normal", active))
	item.focus_exited.connect(func(): item.add_theme_stylebox_override("normal", inactive))

static func button(parent: Node, value: String, action: Callable, primary := false) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 44
	if primary:
		item.add_theme_stylebox_override("normal", texture_frame("button_primary", 31, Vector2(22, 8)))
	if action.is_valid():
		item.pressed.connect(func(): RiftAudio.play_effect(&"menu_confirm"))
		item.mouse_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.focus_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.pressed.connect(action)
	else:
		item.disabled = true
		item.focus_mode = Control.FOCUS_NONE
	parent.add_child(item)
	style_button(item, FOCUS_COLORS[item.get_index() % FOCUS_COLORS.size()])
	return item

static func column(parent: Node, spacing := 12) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", spacing)
	parent.add_child(stack)
	return stack

static func settings(parent: VBoxContainer) -> void:
	var panel := preload("res://scripts/settings_panel.gd").new()
	parent.add_child(panel)
