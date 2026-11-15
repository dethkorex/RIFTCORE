extends CanvasLayer

signal toggled(open: bool)

const UI := preload("res://scripts/rift_ui.gd")
const SocialPanel := preload("res://scripts/social_panel.gd")

var card: Control
var notice: Label
var whisper_contact: Variant = 0
var available: Callable

func _ready() -> void:
	layer = 95
	notice = Label.new()
	notice.theme = UI.theme()
	notice.add_theme_color_override("font_color", UI.CYAN)
	notice.add_theme_color_override("font_shadow_color", Color("020814"))
	notice.add_theme_constant_override("shadow_offset_y", 2)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	notice.offset_left = 19.0
	notice.offset_top = -52.0
	notice.offset_bottom = -24.0
	notice.hide()
	RiftSocial.whispers_changed.connect(func(_id): refresh_notice())

func is_open() -> bool:
	return is_instance_valid(card)

func open() -> void:
	RiftSocial.connect_steam()
	var unread: Array = RiftSocial.unread_whispers.keys()
	if not unread.is_empty():
		whisper_contact = unread.back()
	card = PanelContainer.new()
	card.theme = UI.theme()
	card.add_theme_stylebox_override("panel", UI.texture_frame("panel_base_large", 40, Vector2(17, 13)))
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.anchor_left = 0.08
	card.anchor_top = 0.23
	card.anchor_right = 0.92
	card.anchor_bottom = 0.86
	var content := UI.column(card, 8)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UI.label(header, "WHISPERS", 28, UI.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := UI.button(header, "Close  ·  Esc", close, false, 32)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	SocialPanel.build_messages(self, columns, true)
	if get_viewport().gui_get_focus_owner() == null:
		close_button.grab_focus()
	refresh_notice()
	toggled.emit(true)

func close() -> void:
	if not is_open():
		return
	remove_child(card)
	card.queue_free()
	card = null
	refresh_notice()
	toggled.emit(false)

func refresh_notice() -> void:
	var count := 0
	for unread in RiftSocial.unread_whispers.values():
		count += int(unread)
	notice.visible = count > 0 and not is_open() and available.is_valid() and bool(available.call())
	if notice.visible:
		notice.text = "%d new %s   ·   Enter to read" % [count, "whisper" if count == 1 else "whispers"]

func _process(_delta: float) -> void:
	if not available.is_valid():
		return
	if is_open() and not available.call():
		close()
	refresh_notice()
