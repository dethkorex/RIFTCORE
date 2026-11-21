extends RefCounted

const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
const KIT := "res://assets/ui/riftcore_kit/"

const CYAN := Color("55e7ff")
const MUTED := Color("9db4cc")
const WHITE := Color("e7f2ff")
const VIOLET := Color("bf82ff")
const COOP_NAME_SCALE := 1.3225
const PARTY_COLORS := [CYAN, Color("ffd072"), Color("e0a0ff"), Color("7cfac0")]
const ITEM_SIZE := 48
const ITEM_GAP := 5
static var button_texture: ImageTexture

static func operator_tint(id: int, host: int, members: Array) -> Color:
	if id == host:
		return PARTY_COLORS[0]
	var guests := members.duplicate()
	guests.erase(host)
	guests.sort()
	return PARTY_COLORS[1 + posmod(guests.find(id), PARTY_COLORS.size() - 1)]

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

static func theme(station := false) -> Theme:
	var result := Theme.new()
	result.default_font = DISPLAY
	result.default_font_size = 16
	result.set_color("font_color", "Label", WHITE)
	result.set_stylebox("panel", "PanelContainer", texture_frame("panel_base_small", 31, Vector2(21, 14)))
	result.set_stylebox("panel", "Panel", texture_frame("panel_base_small", 31, Vector2(21, 14)))
	result.set_stylebox("normal", "Button", texture_frame("button_secondary", 30, Vector2(16, 6)))
	result.set_stylebox("hover", "Button", texture_frame("button_primary", 31, Vector2(16, 6)))
	result.set_stylebox("pressed", "Button", texture_frame("button_primary", 31, Vector2(16, 6)))
	result.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	result.set_stylebox("disabled", "Button", texture_frame("button_disabled", 27, Vector2(16, 6)))
	var text_idle := frame(Color("0c192b"), Color("3b6384"), 1)
	var text_focus := text_idle.duplicate() as StyleBoxFlat
	text_focus.draw_center = false
	text_focus.border_color = VIOLET
	result.set_stylebox("normal", "LineEdit", text_idle)
	result.set_stylebox("focus", "LineEdit", text_focus)
	result.set_stylebox("read_only", "LineEdit", frame(Color("0b1421"), Color("354257"), 1))
	result.set_color("caret_color", "LineEdit", CYAN)
	if station:
		var surface := hud_frame(CYAN, Vector2(12, 10))
		result.set_stylebox("panel", "PanelContainer", surface)
		result.set_stylebox("panel", "Panel", surface)
		result.set_stylebox("panel", "PopupMenu", profile_frame(Color("0b1a28"), Color("437da1"), Vector2(5, 5)))
		result.set_stylebox("hover", "PopupMenu", profile_frame(Color("1c3b51"), CYAN, Vector2(8, 3)))
		result.set_stylebox("normal", "LineEdit", profile_frame(Color("091827"), Color("436586")))
		result.set_stylebox("focus", "LineEdit", text_focus)
		for kind in ["HSeparator", "VSeparator"]:
			var divider := StyleBoxLine.new()
			divider.color = Color("376686")
			divider.vertical = kind == "VSeparator"
			result.set_stylebox("separator", kind, divider)
		var rail := profile_frame(Color("0a1725"), Color("1b354c"), Vector2(4, 4))
		var thumb := profile_frame(Color("619ab8"), Color("90cae3"), Vector2(4, 4))
		for kind in ["VScrollBar", "HScrollBar"]:
			result.set_stylebox("scroll", kind, rail)
			result.set_stylebox("grabber", kind, thumb)
			result.set_stylebox("grabber_highlight", kind, profile_frame(Color("4eafd2"), CYAN, Vector2(4, 4)))
			result.set_stylebox("grabber_pressed", kind, profile_frame(Color("4592b5"), CYAN, Vector2(4, 4)))
		result.set_stylebox("station_skin", "Button", surface)
	return result

static func label(parent: Node, value: String, font_size := 16, color := WHITE) -> Label:
	var item := Label.new()
	item.text = value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", maxi(12, roundi(font_size * 0.91)))
	item.add_theme_font_override("font", DISPLAY)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

static func style_button(item: Button) -> void:
	if item.has_theme_stylebox("station_skin", "Button"):
		profile_button(item)
		return
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
	var active := texture_frame("button_primary", 31, Vector2(26, 8))
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
	item.focus_entered.connect(func(): item.add_theme_stylebox_override("normal", active))
	item.focus_exited.connect(func(): item.add_theme_stylebox_override("normal", inactive))

static func button(parent: Node, value: String, action: Callable, primary := false, height := 40.0, apply_default_style := true) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = height
	if parent is VBoxContainer and not value.is_empty():
		item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if apply_default_style and height >= 40.0:
			item.custom_minimum_size.x = 148.0
	if primary:
		item.add_theme_color_override("font_color", WHITE)
	if action.is_valid():
		item.pressed.connect(func(): RiftAudio.play_effect(&"menu_confirm"))
		item.focus_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.pressed.connect(action)
	else:
		item.disabled = true
		item.focus_mode = Control.FOCUS_NONE
	parent.add_child(item)
	if apply_default_style:
		if item.has_theme_stylebox("station_skin", "Button"):
			profile_button(item, primary)
		else:
			style_button(item)
	return item

static func item_tile(parent: Container, icon: Texture2D, rarity: Color, rarity_index: int, caption: String, action: Callable) -> Button:
	var tile := button(parent, "", action, false, ITEM_SIZE, false)
	tile.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE)
	tile.icon = icon
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.add_theme_constant_override("icon_max_width", 26)
	var variants := ["common", "rare", "epic", "legendary"]
	var idle := tile_frame("item_slot_" + variants[rarity_index])
	idle.content_margin_bottom = 16
	var active := idle.duplicate() as StyleBoxTexture
	active.modulate_color = Color("f1f7ff")
	var down := active.duplicate() as StyleBoxTexture
	down.modulate_color = Color("ccc0e4")
	set_button_states(tile, idle, active, down)
	var badge := label(tile, caption, 12, rarity)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	badge.offset_top = -16
	badge.offset_bottom = -2
	badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.draw.connect(func():
		if not tile.has_focus():
			return
		var right := tile.size.x - 4.0
		var bottom := tile.size.y - 4.0
		var brackets := [
			PackedVector2Array([Vector2(4, 14), Vector2(4, 4), Vector2(14, 4)]),
			PackedVector2Array([Vector2(right - 10, 4), Vector2(right, 4), Vector2(right, 14)]),
			PackedVector2Array([Vector2(4, bottom - 10), Vector2(4, bottom), Vector2(14, bottom)]),
			PackedVector2Array([Vector2(right - 10, bottom), Vector2(right, bottom), Vector2(right, bottom - 10)]),
		]
		for bracket in brackets:
			tile.draw_polyline(bracket, Color("071c2b"), 5.0, true)
			tile.draw_polyline(bracket, Color("d7ffff"), 2.5, true)
		tile.draw_colored_polygon(PackedVector2Array([
			Vector2(right - 11, 6), Vector2(right - 2, 6), Vector2(right - 2, 15),
		]), CYAN)
	)
	tile.focus_entered.connect(tile.queue_redraw)
	tile.focus_exited.connect(tile.queue_redraw)
	return tile

static func item_grid_columns(scroll: ScrollContainer, limit: int) -> int:
	var inner_width := scroll.size.x - scroll.get_v_scroll_bar().get_combined_minimum_size().x
	return clampi(floori((inner_width + ITEM_GAP) / (ITEM_SIZE + ITEM_GAP)), 1, limit)

static func make_readable_scroll(scroll: ScrollContainer) -> void:
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.draw_focus_border = true
	var edge := frame(Color.TRANSPARENT, CYAN, 2)
	edge.draw_center = false
	scroll.add_theme_stylebox_override("focus", edge)

static func profile_frame(fill: Color, edge: Color, margins := Vector2(12, 8), glow := false) -> StyleBoxFlat:
	var style := frame(fill, edge, 1)
	style.set_corner_radius_all(9)
	style.corner_detail = 1
	style.content_margin_left = margins.x
	style.content_margin_right = margins.x
	style.content_margin_top = margins.y
	style.content_margin_bottom = margins.y
	if glow:
		style.set_border_width_all(2)
		style.shadow_color = Color(edge, 0.26)
		style.shadow_size = 4
	return style

static func profile_button(item: Button, selected := false) -> void:
	var normal := profile_frame(Color("0c2031"), CYAN if selected else Color("436586"), Vector2(15, 5), selected)
	var active := profile_frame(Color("103347"), CYAN, Vector2(15, 5), true)
	var pressed := profile_frame(Color("173649"), CYAN, Vector2(15, 5))
	set_button_states(item, normal, active, pressed)
	item.add_theme_stylebox_override("disabled", profile_frame(Color("0b1727"), Color("2a4056"), Vector2(15, 5)))

static func profile_panel(parent: Container, ratio := 1.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", profile_frame(Color("071522"), Color("4097bd"), Vector2(12, 12), true))
	parent.add_child(panel)
	return column(panel, 8)

static func profile_label(parent: Node, value: String, font_size: int, color := WHITE) -> Label:
	var item := label(parent, value, font_size, color)
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return item

static func hud_frame(tint := CYAN, padding := Vector2(14, 8), emphasized := false) -> StyleBoxFlat:
	return profile_frame(Color("0a1828f2"), tint if emphasized else tint.darkened(0.48), padding, emphasized)

# All overhead notifications use the active gameplay camera and its viewport space.
static func operator_popup_position(popup: Control, operator: Node3D, rise: float) -> Vector2:
	var viewport := popup.get_viewport()
	var visible_area := viewport.get_visible_rect()
	var head := Vector2(visible_area.get_center().x, visible_area.size.y * 0.42)
	var camera := viewport.get_camera_3d()
	if is_instance_valid(operator) and operator.is_inside_tree() and is_instance_valid(camera):
		var world_head: Vector3 = operator.popup_head_position() if operator is RiftPlayer else operator.global_position + Vector3.UP
		if not camera.is_position_behind(world_head):
			head = camera.unproject_position(world_head)
	var parent := popup.get_parent() as CanvasItem
	if parent:
		var to_local := parent.get_global_transform_with_canvas().affine_inverse()
		head = to_local * head
		visible_area = to_local * visible_area
	var left := maxf(visible_area.position.x + 12.0, visible_area.end.x - popup.size.x - 12.0)
	return Vector2(
		clampf(head.x - popup.size.x * 0.5, visible_area.position.x + 12.0, left),
		clampf(head.y - popup.size.y - 12.0 - rise, visible_area.position.y + 12.0, visible_area.end.y - popup.size.y - 12.0)
	)

static func hud_readout(parent: Node, top: float, width: float, tint := CYAN, font_size := 22) -> Label:
	var label := profile_label(parent, "", font_size, tint)
	label.add_theme_stylebox_override("normal", hud_frame(tint, Vector2(14, 7)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -width * 0.5
	label.offset_right = width * 0.5
	label.offset_top = top
	label.offset_bottom = top
	label.hide()
	return label

static func tile_frame(asset: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(KIT + asset + ".png") as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 5)
	return style

static func column(parent: Node, spacing := 12) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", spacing)
	parent.add_child(stack)
	return stack

static func card(parent: Container, ratio := 1.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", texture_frame("panel_base_large", 40, Vector2(17, 13)))
	parent.add_child(panel)
	return column(panel, 8)

static func scroll_entries(parent: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	parent.add_child(scroll)
	var entries := column(scroll, 10)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return entries

static func currency_row(parent: Control, title: String, shard := false) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/ui/core-shard.svg") if shard else preload("res://assets/ui/bolt.svg")
	icon.custom_minimum_size = Vector2(21, 21)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var amount := label(row, title, 16)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	return amount

static func settings(parent: VBoxContainer, can_restart := false) -> Control:
	var panel := preload("res://scripts/settings_panel.gd").new()
	panel.name = "RiftSettingsPanel"
	panel.can_restart = can_restart
	parent.add_child(panel)
	return panel
