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
var peek: Label
var peek_left := 0.0
var previous_party: Dictionary
var draft := ""
var notice_error := ""
var notice_left := 0.0

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
	RiftRelay.party_chat_changed.connect(party_changed)
	RiftRelay.directory.whispers.failed.connect(func(recipient: String):
		notice_error = "Could not deliver to %s. Have them sign in and try again." % recipient
		notice_left = 7.0
		if is_open():
			status.text = notice_error
			status.show())
	peek = Label.new()
	peek.theme = UI.theme()
	peek.add_theme_color_override("font_color", Color("d0eafa"))
	peek.add_theme_color_override("font_outline_color", Color("020814"))
	peek.add_theme_constant_override("outline_size", 5)
	peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	peek.clip_text = true
	add_child(peek)
	peek.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	peek.offset_left = 18
	peek.offset_right = 468
	peek.offset_top = -95
	peek.offset_bottom = -66
	peek.hide()
	RiftRelay.changed.connect(refresh_channels)
	RiftRelay.directory.changed.connect(refresh_channels)

func is_open() -> bool:
	return is_instance_valid(card)

func open() -> void:
	if is_open():
		return
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
	var title := UI.label(header, "COMMS", 19, UI.CYAN)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shortcuts := UI.label(header, "Enter to send  ·  Esc to close", 13, UI.MUTED)
	shortcuts.autowrap_mode = TextServer.AUTOWRAP_OFF
	shortcuts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector = OptionButton.new()
	UI.style_button(selector)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.fit_to_longest_item = false
	selector.item_selected.connect(select_channel)
	content.add_child(selector)
	history = RichTextLabel.new()
	history.custom_minimum_size.y = 54
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
	composer.custom_minimum_size.y = 31
	composer.max_length = RiftSocial.WHISPER_LIMIT
	composer.text = draft
	composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer.text_submitted.connect(func(_value): send_message())
	row.add_child(composer)
	send_button = UI.button(row, "Send", send_message, false, 31)
	refresh_channels()
	composer.grab_focus()
	composer.caret_column = composer.text.length()
	toggled.emit(true)

func close() -> void:
	if not is_open():
		return
	draft = composer.text
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
		if not can_send(id):
			continue
		var unread := int(RiftSocial.unread_whispers.get(id, 0))
		selector.add_item("Whisper · %s%s" % [contact.name, " (%d new)" % unread if unread else ""])
		var index := selector.item_count - 1
		selector.set_item_metadata(index, id)
		if id == channel:
			chosen = index
	var selected: Variant = selector.get_item_metadata(chosen)
	if channel != null and selected == null:
		composer.clear()
		draft = ""
	channel = selected
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
	return SocialPanel.can_message(target)

func sender_name(id: Variant) -> String:
	for contact in SocialPanel.message_contacts():
		if contact.chat == id:
			return contact.name
	return "Player"

func whisper_changed(id: Variant) -> void:
	if RiftSocial.unread_whispers.has(id):
		recent_sender = id
		recent_sender_name = sender_name(id)
		var lines: Array = RiftSocial.whispers.get(id, [])
		if not lines.is_empty():
			show_peek("[Whisper] " + recent_sender_name + ": " + String(lines.back().body))
	refresh_channels()

func party_changed() -> void:
	if RiftRelay.party_messages.is_empty():
		previous_party = {}
		peek_left = 0.0
		if channel == null:
			draft = ""
			if is_open():
				composer.clear()
	else:
		var line: Dictionary = RiftRelay.party_messages.back()
		if not is_same(line, previous_party):
			previous_party = line
			if not line.outgoing:
				show_peek("[Party] " + String(line.name) + ": " + String(line.body))
	refresh_history()

func show_peek(line: String) -> void:
	peek.text = line
	peek_left = 7.0

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
	composer.placeholder_text = "Party  ·  /w name message" if channel == null else "Whisper to " + private_name
	if not active and channel == null:
		composer.placeholder_text = "/w name message  ·  whisper to a friend"

func send_message() -> void:
	var body := composer.text.strip_edges()
	if body.is_empty():
		close()
		return
	if body.begins_with("/"):
		var command := body.get_slice(" ", 0).to_lower()
		var remainder := body.substr(command.length()).strip_edges()
		if command in ["/p", "/party"]:
			channel = null
			body = remainder
		elif command in ["/r", "/reply"] and recent_sender != null:
			if not can_send(recent_sender):
				show_status("That player is no longer online.")
				return
			channel = recent_sender
			body = remainder
		elif command in ["/w", "/whisper"]:
			var target: Dictionary = {}
			for candidate in SocialPanel.message_contacts():
				var name: String = candidate.name
				if (remainder.nocasecmp_to(name) == 0 or remainder.to_lower().begins_with(name.to_lower() + " ")) and can_send(candidate.chat):
					if target.is_empty() or name.length() > String(target.name).length():
						target = candidate
			if target.is_empty():
				show_status("Use /w followed by an online friend's name and a message.")
				return
			channel = target.chat
			body = remainder.substr(String(target.name).length()).strip_edges()
		else:
			show_status("Use /p for party, /w name for whispers, or /r to reply.")
			return
		if body.is_empty():
			refresh_channels()
			composer.clear()
			return
	if not (RiftRelay.send_party_message(body) if channel == null else RiftSocial.send_whisper(channel, body)):
		show_status("Could not send. Check the channel or try again.")
		return
	composer.clear()
	close()

func show_status(message: String) -> void:
	status.text = message
	status.show()

func _process(delta: float) -> void:
	if not available.is_valid():
		return
	var usable := bool(available.call())
	peek_left = maxf(0.0, peek_left - delta)
	notice_left = maxf(0.0, notice_left - delta)
	peek.visible = usable and not is_open() and peek_left > 0.0
	if is_open() and not usable:
		close()
	if usable and is_open() and channel != null and RiftSocial.unread_whispers.has(channel):
		RiftSocial.unread_whispers.erase(channel)
		refresh_channels()
	if (recent_sender == null or not RiftSocial.unread_whispers.has(recent_sender)) and not RiftSocial.unread_whispers.is_empty():
		recent_sender = RiftSocial.unread_whispers.keys().back()
		recent_sender_name = sender_name(recent_sender)
	var unread := recent_sender != null and RiftSocial.unread_whispers.has(recent_sender)
	notice.visible = usable and not is_open() and (notice_left > 0.0 or unread)
	if notice.visible:
		notice.text = notice_error if notice_left > 0.0 else "Whisper from %s  ·  Enter to reply" % recent_sender_name
