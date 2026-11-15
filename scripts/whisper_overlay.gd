extends CanvasLayer

signal toggled(open: bool)

const UI := preload("res://scripts/rift_ui.gd")
const SocialPanel := preload("res://scripts/social_panel.gd")

var card: PanelContainer
var notice: Label
var selector: OptionButton
var history: RichTextLabel
var composer: LineEdit
var send_button: Button
var status: Label
var channel: Variant = null
var available: Callable
var recent_sender: Variant = null
var recent_sender_name := ""

func _ready() -> void:
	layer = 95
	notice = Label.new()
	notice.theme = UI.theme()
	notice.add_theme_color_override("font_color", UI.VIOLET.lightened(0.35))
	notice.add_theme_color_override("font_outline_color", Color("020814"))
	notice.add_theme_constant_override("outline_size", 7)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	notice.offset_left = 18
	notice.offset_top = -60
	notice.offset_bottom = -32
	notice.hide()
	RiftSocial.whispers_changed.connect(whisper_changed)
	RiftRelay.party_chat_changed.connect(refresh_history)
	RiftRelay.changed.connect(refresh_channels)

func is_open() -> bool:
	return is_instance_valid(card)

func open() -> void:
	if is_open():
		return
	RiftSocial.connect_steam()
	if recent_sender != null and RiftSocial.unread_whispers.has(recent_sender):
		channel = recent_sender
	card = PanelContainer.new()
	card.theme = UI.theme()
	card.add_theme_stylebox_override("panel", UI.frame(Color("09172af2"), UI.CYAN, 6))
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	card.offset_left = 16
	card.offset_top = -320
	card.offset_right = 407
	card.offset_bottom = -66
	var content := UI.column(card, 5)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UI.label(header, "CHAT", 21, UI.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(header, "Close", close, false, 29)
	selector = OptionButton.new()
	UI.style_button(selector)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.fit_to_longest_item = false
	selector.item_selected.connect(select_channel)
	content.add_child(selector)
	history = RichTextLabel.new()
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.scroll_following = true
	history.add_theme_font_size_override("normal_font_size", 16)
	content.add_child(history)
	status = UI.label(content, "", 15, UI.MUTED)
	status.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	composer = LineEdit.new()
	composer.max_length = RiftSocial.WHISPER_LIMIT
	composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer.text_submitted.connect(func(_value): send_message())
	row.add_child(composer)
	send_button = UI.button(row, "Send", send_message, false, 31)
	refresh_channels()
	if composer.editable:
		composer.grab_focus()
	else:
		selector.grab_focus()
	toggled.emit(true)

func close() -> void:
	if not is_open():
		return
	var closing := card
	card = null
	remove_child(closing)
	closing.queue_free()
	toggled.emit(false)

func refresh_channels() -> void:
	if not is_open():
		return
	selector.clear()
	selector.add_item("Party")
	selector.set_item_metadata(0, null)
	var chosen := 0
	for contact in SocialPanel.message_contacts():
		var id: Variant = contact.chat
		if not can_send(id) and not RiftSocial.whispers.has(id):
			continue
		var unread := int(RiftSocial.unread_whispers.get(id, 0))
		selector.add_item("Whisper · %s%s" % [contact.name, " (%d new)" % unread if unread else ""])
		var index := selector.item_count - 1
		selector.set_item_metadata(index, id)
		if id == channel:
			chosen = index
	channel = selector.get_item_metadata(chosen)
	selector.select(chosen)
	refresh_history()

func select_channel(index: int) -> void:
	channel = selector.get_item_metadata(index)
	if channel != null:
		RiftSocial.unread_whispers.erase(channel)
	status.hide()
	refresh_channels()
	if composer.editable:
		composer.grab_focus()

func can_send(target: Variant) -> bool:
	if target == null:
		return RiftRelay.room_size >= 2 and not RiftRelay.connected_room.is_empty()
	if target is String:
		return RiftRelay.party_operators.values().has(target.trim_prefix("rift:"))
	return RiftSocial.can_whisper(target)

func sender_name(id: Variant) -> String:
	for contact in SocialPanel.message_contacts():
		if contact.chat == id:
			return contact.name
	return "Player"

func whisper_changed(id: Variant) -> void:
	if RiftSocial.unread_whispers.has(id):
		recent_sender = id
		recent_sender_name = sender_name(id)
	refresh_channels()

func refresh_history() -> void:
	if not is_open():
		return
	history.clear()
	var private_name := "" if channel == null else sender_name(channel)
	var active := can_send(channel)
	var messages: Array = RiftRelay.party_messages if channel == null else RiftSocial.whispers.get(channel, [])
	for line in messages:
		var alias := "You" if line.outgoing else String(line.get("name", private_name))
		history.push_color(UI.CYAN if channel == null else UI.VIOLET.lightened(0.35))
		history.add_text(alias + "  ")
		history.pop()
		history.add_text(line.body + "\n")
	if messages.is_empty():
		history.add_text("Everyone in your room can read this." if channel == null else "Only you and %s can read this." % private_name)
	if not active:
		status.text = "Join a party to send a message." if channel == null else "This player is unavailable."
		status.show()
	else:
		status.hide()
	composer.editable = active
	composer.placeholder_text = "Message party" if channel == null else "Whisper to " + private_name
	send_button.disabled = not active

func send_message() -> void:
	if composer.text.strip_edges().is_empty():
		return
	var sent := RiftRelay.send_party_message(composer.text) if channel == null else RiftSocial.send_whisper(channel, composer.text)
	if sent:
		composer.clear()
		composer.grab_focus()
	else:
		status.text = "Message could not be sent. Try again."
		status.show()

func _process(_delta: float) -> void:
	if not available.is_valid():
		return
	var usable := bool(available.call())
	if is_open() and not usable:
		close()
	if usable and is_open() and channel != null and RiftSocial.unread_whispers.has(channel):
		RiftSocial.unread_whispers.erase(channel)
		refresh_channels()
	if (recent_sender == null or not RiftSocial.unread_whispers.has(recent_sender)) and not RiftSocial.unread_whispers.is_empty():
		recent_sender = RiftSocial.unread_whispers.keys().back()
		recent_sender_name = sender_name(recent_sender)
	var unread := recent_sender != null and RiftSocial.unread_whispers.has(recent_sender)
	notice.visible = usable and unread and (not is_open() or channel != recent_sender)
	if notice.visible:
		notice.text = "Whisper from %s%s" % [recent_sender_name, "" if is_open() else "  ·  Enter to read"]
