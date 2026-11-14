extends RefCounted

const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-Medium.ttf")
const KIT := "res://assets/ui/riftcore_kit/"

const CYAN := Color("55e7ff")
const MUTED := Color("9db4cc")
const WHITE := Color("e7f2ff")
const VIOLET := Color("bf82ff")
static var button_texture: ImageTexture

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

static func equipment_card(tint: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var frame_owner := Control.new()
	frame_owner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame_owner)
	frame_owner.draw.connect(func():
		var width := frame_owner.size.x
		var height := frame_owner.size.y
		var corner := 14.0
		var points := PackedVector2Array([
			Vector2(corner, 1), Vector2(width - corner, 1),
			Vector2(width - 1, corner), Vector2(width - 1, height - corner),
			Vector2(width - corner, height - 1), Vector2(corner, height - 1),
			Vector2(1, height - corner), Vector2(1, corner),
		])
		frame_owner.draw_colored_polygon(points, Color("102038"))
		points.append(points[0])
		frame_owner.draw_polyline(points, tint.darkened(0.32), 1.6, true)
		frame_owner.draw_line(Vector2(corner + 5, 4), Vector2(83, 4), tint, 2.0, true)
		frame_owner.draw_line(Vector2(width - 59, height - 4), Vector2(width - corner - 5, height - 4), tint, 2.0, true)
	)
	frame_owner.resized.connect(frame_owner.queue_redraw)
	var spacing := StyleBoxEmpty.new()
	spacing.content_margin_top = 9
	spacing.content_margin_bottom = 9
	spacing.content_margin_left = 14
	spacing.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", spacing)
	# The artwork fills the panel while the other children retain content margins.
	panel.fit_child_in_rect(frame_owner, Rect2(Vector2.ZERO, panel.size))
	panel.sort_children.connect(func(): panel.fit_child_in_rect(frame_owner, Rect2(Vector2.ZERO, panel.size)))
	return panel

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

static func style_button(item: Button) -> void:
	if item.custom_minimum_size.y < 40:
		var compact := frame(Color("12253d"), Color("3b6384"))
		var compact_active := frame(Color("34244f"), VIOLET)
		var compact_pressed := frame(Color("251936"), VIOLET.darkened(0.2))
		set_button_states(item, compact, compact_active, compact_pressed)
		return
	if not button_texture:
		var source := load(KIT + "button_primary.png") as Texture2D
		var pixels := source.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		for y in pixels.get_height():
			for x in pixels.get_width():
				var pixel := pixels.get_pixel(x, y)
				var value := pixel.v
				pixels.set_pixel(x, y, Color(value, value, value, pixel.a))
		button_texture = ImageTexture.create_from_image(pixels)
	var active := texture_frame("button_primary", 31, Vector2(22, 8))
	active.texture = button_texture
	active.set_texture_margin(SIDE_TOP, 19)
	active.set_texture_margin(SIDE_BOTTOM, 19)
	active.modulate_color = VIOLET
	var idle := active.duplicate() as StyleBoxTexture
	idle.modulate_color = Color("5a9ac7")
	var down := active.duplicate() as StyleBoxTexture
	down.modulate_color = VIOLET.darkened(0.22)
	set_button_states(item, idle, active, down)

static func set_button_states(item: Button, inactive: StyleBox, active: StyleBox, down: StyleBox) -> void:
	item.add_theme_stylebox_override("normal", inactive)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item.add_theme_stylebox_override("hover", active)
	item.add_theme_stylebox_override("pressed", down)
	item.add_theme_stylebox_override("hover_pressed", down)
	item.mouse_entered.connect(func():
		if not item.disabled and item.focus_mode != Control.FOCUS_NONE:
			item.grab_focus()
	)
	item.focus_entered.connect(func(): item.add_theme_stylebox_override("normal", active))
	item.focus_exited.connect(func(): item.add_theme_stylebox_override("normal", inactive))

static func button(parent: Node, value: String, action: Callable, primary := false, height := 44.0, apply_default_style := true) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = height
	if primary:
		item.add_theme_color_override("font_color", WHITE)
	if action.is_valid():
		item.pressed.connect(func(): RiftAudio.play_effect(&"menu_confirm"))
		item.mouse_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.focus_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.pressed.connect(action)
	else:
		item.disabled = true
		item.focus_mode = Control.FOCUS_NONE
	parent.add_child(item)
	if apply_default_style:
		style_button(item)
	return item

static func item_tile(parent: GridContainer, icon: Texture2D, rarity: Color, rarity_index: int, caption: String, action: Callable) -> Button:
	var tile := button(parent, "", action, false, 78, false)
	tile.custom_minimum_size = Vector2(78, 78)
	tile.icon = icon
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.add_theme_constant_override("icon_max_width", 38)
	var variants := ["common", "rare", "epic", "legendary"]
	var idle := texture_frame("item_slot_" + variants[rarity_index], 16, Vector2(8, 7))
	idle.content_margin_bottom = 26
	var active := texture_frame("item_slot_epic", 16, Vector2(8, 7))
	active.content_margin_bottom = 26
	var down := active.duplicate() as StyleBoxTexture
	down.modulate_color = Color("ccc0e4")
	set_button_states(tile, idle, active, down)
	var badge := label(tile, caption, 12, rarity)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	badge.offset_top = -23
	badge.offset_bottom = -4
	return tile

static func column(parent: Node, spacing := 12) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", spacing)
	parent.add_child(stack)
	return stack

static func settings(parent: VBoxContainer) -> void:
	var panel := preload("res://scripts/settings_panel.gd").new()
	parent.add_child(panel)
