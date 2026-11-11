extends RefCounted

const CYAN := Color("55e7ff")
const MUTED := Color("9db4cc")
const WHITE := Color("e7f2ff")
const VIOLET := Color("bf82ff")

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

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 17
	result.set_color("font_color", "Label", WHITE)
	result.set_stylebox("panel", "PanelContainer", frame(Color("101d32"), Color("32617c")))
	result.set_stylebox("panel", "Panel", frame(Color("0b172a"), Color("32617c")))
	result.set_stylebox("normal", "Button", frame(Color("14253d"), Color("355b77")))
	result.set_stylebox("hover", "Button", frame(Color("1b3851"), CYAN, 4))
	result.set_stylebox("pressed", "Button", frame(Color("1c4965"), CYAN, 5))
	result.set_stylebox("focus", "Button", frame(Color.TRANSPARENT, CYAN, 4))
	result.set_stylebox("disabled", "Button", frame(Color("0e1829"), Color("304358")))
	return result

static func label(parent: Node, value: String, font_size := 17, color := WHITE) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

static func button(parent: Node, value: String, action: Callable, primary := false) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 44
	if primary:
		item.add_theme_stylebox_override("normal", frame(Color("12405a"), CYAN, 5))
	if action.is_valid():
		item.pressed.connect(func(): RiftAudio.play_effect(&"menu_confirm"))
		item.mouse_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.focus_entered.connect(func(): RiftAudio.play_effect(&"menu_move"))
		item.pressed.connect(action)
	else:
		item.disabled = true
		item.focus_mode = Control.FOCUS_NONE
	parent.add_child(item)
	return item

static func column(parent: Node, spacing := 12) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", spacing)
	parent.add_child(stack)
	return stack

static func settings(parent: VBoxContainer) -> void:
	var panel := preload("res://scripts/settings_panel.gd").new()
	parent.add_child(panel)
