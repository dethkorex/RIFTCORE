extends RefCounted

const UI := preload("res://scripts/rift_ui.gd")
const ICONS := preload("res://scripts/equipment_icons.gd")
const CATALOG := preload("res://scripts/sector_catalog.gd")
const FILTERS := ["All contacts", "Saved", "In your party", "Playing RIFTCORE", "Recent"]

static func contacts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for friend in RiftSocial.contacts():
		friend.key = "steam:" + friend.id
		friend.chat = int(friend.id)
		friend.party = false
		friend.playing = friend.priority == 0
		friend.recent = false
		result.append(friend)
	for id in RiftSocial.recent_players:
		var person: Dictionary = RiftSocial.recent_players[id]
		var in_party := RiftRelay.party_operators.values().has(id)
		var key: String = "rift:" + id
		result.append({"key": key, "id": id, "chat": key, "name": person.name,
			"saved": RiftSocial.rift_friends.has(id), "party": in_party, "playing": in_party, "recent": true,
			"priority": -1 if in_party else 4, "status": "In your party" if in_party else "Recent teammate"})
	result.sort_custom(func(a, b):
		var a_pin := RiftSocial.pinned.has(a.key)
		var b_pin := RiftSocial.pinned.has(b.key)
		if a_pin != b_pin:
			return a_pin
		if a.priority != b.priority:
			return a.priority < b.priority
		return a.name.nocasecmp_to(b.name) < 0
	)
	return result

static func watch(owner: Control, notice: Signal, update: Callable) -> void:
	notice.connect(update)
	owner.tree_exiting.connect(func():
		if notice.is_connected(update):
			notice.disconnect(update)
	, CONNECT_ONE_SHOT)

static func contact_title(contact: Dictionary) -> String:
	var unread := int(RiftSocial.unread_whispers.get(contact.chat, 0))
	var title: String = ("★  " if RiftSocial.pinned.has(contact.key) else "") + contact.name
	if contact.party:
		title += "  ·  In party"
	elif contact.playing:
		title += "  ·  Playing"
	return "%s  ·  %d new" % [title, unread] if unread > 0 else title

static func contact_button(row: VBoxContainer, contact: Dictionary, select: Callable) -> Button:
	var button := UI.button(row, contact_title(contact), select.bind(contact), false, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = contact.status
	button.icon = ICONS.icon("visor", "visor")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	return button

static func set_focus(left: Control, right: Control) -> void:
	if is_instance_valid(left) and is_instance_valid(right):
		left.focus_neighbor_right = left.get_path_to(right)
		right.focus_neighbor_left = right.get_path_to(left)

static func build_friends(menu, columns: HBoxContainer) -> void:
	RiftSocial.connect_steam()
	RiftRelay.listen_for_steam_invites()
	var directory: VBoxContainer = menu.card(columns, 0.9)
	var details: VBoxContainer = menu.card(columns, 1.15)
	UI.label(directory, "OPERATORS", 26, UI.CYAN)
	var search := LineEdit.new()
	search.placeholder_text = "Find a name or Steam ID"
	search.clear_button_enabled = true
	search.max_length = 64
	directory.add_child(search)
	var filter := OptionButton.new()
	filter.custom_minimum_size.y = 35
	directory.add_child(filter)
	UI.style_button(filter)
	for value in FILTERS:
		filter.add_item(value)
	filter.select(menu.social_filter)
	var rows: VBoxContainer = menu.scroll_entries(directory)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	directory.add_child(tools)
	UI.button(tools, "Add Contact", menu.show_page.bind("Add Contact"), false, 34)
	UI.button(tools, "Co-op Setup", menu.show_page.bind("Co-op Setup Guide"), false, 34)
	var name := UI.label(details, "Choose an operator", 32, UI.CYAN)
	var status := UI.label(details, "", 16, UI.MUTED)
	details.add_child(HSeparator.new())
	var actions := UI.column(details, 8)
	var note := UI.label(details, "", 16, UI.CYAN)
	var relay_status := UI.label(details, RiftRelay.status, 15, UI.MUTED)
	UI.label(details, RiftSocial.message, 15, UI.MUTED)
	var selected := {"key": menu.social_contact, "button": null, "action": null}
	var show_contact := func(contact: Dictionary):
		for child in actions.get_children():
			actions.remove_child(child)
			child.queue_free()
		selected.key = contact.get("key", "")
		menu.social_contact = selected.key
		selected.action = null
		name.text = contact.get("name", "Choose an operator")
		status.text = contact.get("status", "Save a contact or group up to add recent teammates.")
		note.text = ""
		if not contact.is_empty():
			var joined: bool = contact.party
			var chat_allowed: bool = joined or (not contact.recent and RiftSocial.can_whisper(contact.chat))
			var invite := UI.button(actions, "Invite to Game", RiftRelay.invite_friend.bind(contact.chat), false, 36) if not contact.recent and contact.playing else null
			if invite:
				invite.disabled = joined or not contact.playing or not RiftRelay.can_invite_friend()
				invite.tooltip_text = "Available for Steam friends playing RIFTCORE."
			var whisper: Button
			if chat_allowed or RiftSocial.whispers.has(contact.chat):
				whisper = UI.button(actions, "Open Conversation", func():
					menu.whisper_contact = contact.chat
					menu.show_page("Whispers")
				, false, 36)
			selected.action = invite if invite and not invite.disabled else whisper
			var management := HBoxContainer.new()
			management.add_theme_constant_override("separation", 9)
			actions.add_child(management)
			var save := UI.button(management, "Remove Contact" if contact.saved else "Save Contact", func():
				if contact.recent:
					RiftSocial.toggle_rift_friend(contact.id)
				elif not RiftSocial.save_contact(contact.id, "" if contact.saved else contact.name):
					note.text = "Could not save contact."
					return
				menu.show_page("Social")
			, false, 33)
			if selected.action == null:
				selected.action = save
			if contact.saved:
				UI.button(management, "Unpin" if RiftSocial.pinned.has(contact.key) else "Pin", func():
					if RiftSocial.toggle_pin(contact.key):
						menu.show_page("Social")
					else:
						note.text = "Could not save pinned contact."
				, false, 33)
			if not contact.recent:
				UI.button(management, "Copy Steam ID", func():
					DisplayServer.clipboard_set(contact.id)
					note.text = "Steam ID copied."
				, false, 33)
			else:
				var record: Dictionary = RiftSocial.recent_players[contact.id]
				UI.label(actions, "%d sectors timed this season" % record.get("times", {}).size(), 15, UI.MUTED)
		var code := UI.button(actions, "Copy Room Invite", RiftRelay.copy_invite_code, false, 36)
		code.disabled = not RiftRelay.can_copy_invite_code()
		code.tooltip_text = "Create a room if needed, then copy its code."
		if selected.action == null and not code.disabled:
			selected.action = code
		set_focus(selected.button, selected.action)
	var rebuild := func():
		var previous_focus := rows.get_viewport().gui_get_focus_owner()
		var had_focus := previous_focus != null and (rows.is_ancestor_of(previous_focus) or actions.is_ancestor_of(previous_focus))
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		var query := search.text.strip_edges().to_lower()
		var chosen := {}
		var first := {}
		for contact in contacts():
			var selected_filter := filter.selected
			if ((selected_filter == 1 and not contact.saved) or (selected_filter == 2 and not contact.party)
				or (selected_filter == 3 and not contact.playing) or (selected_filter == 4 and not contact.recent)):
				continue
			if not query.is_empty() and not query in contact.name.to_lower() and not query in contact.id:
				continue
			var button := contact_button(rows, contact, func(entry: Dictionary):
				selected.button = rows.get_viewport().gui_get_focus_owner()
				if not is_instance_valid(selected.button) or selected.button.get_parent() != rows:
					selected.button = rows.get_node_or_null("Contact_" + entry.key.replace(":", "_"))
				show_contact.call(entry)
				if is_instance_valid(selected.action):
					selected.action.grab_focus()
			)
			button.name = "Contact_" + contact.key.replace(":", "_")
			if first.is_empty():
				first = {"button": button, "contact": contact}
			if contact.key == selected.key:
				chosen = {"button": button, "contact": contact}
		if first.is_empty():
			UI.label(rows, "No matching contacts.", 17, UI.MUTED)
			selected.button = null
			show_contact.call({})
			if had_focus:
				filter.grab_focus()
			return
		if chosen.is_empty():
			chosen = first
		selected.button = chosen.button
		show_contact.call(chosen.contact)
		if had_focus or rows.get_viewport().gui_get_focus_owner() == null:
			selected.button.grab_focus()
	search.text_changed.connect(func(_query): rebuild.call())
	filter.item_selected.connect(func(index: int):
		menu.social_filter = index
		rebuild.call()
	)
	UI.button(tools, "Refresh", func():
		RiftSocial.connect_steam()
		rebuild.call()
	, false, 34)
	watch(directory, RiftRelay.changed, func():
		relay_status.text = RiftRelay.status
		rebuild.call()
	)
	watch(directory, RiftSocial.whispers_changed, func(_id): rebuild.call())
	rebuild.call()
	if rows.get_viewport().gui_get_focus_owner() == null:
		search.grab_focus()

static func build_add(menu, columns: HBoxContainer) -> void:
	var form: VBoxContainer = menu.card(columns, 1.35)
	UI.label(form, "ADD CONTACT", 32, UI.CYAN)
	UI.label(form, "Steam ID, numeric friend code, or Steam profile link", 17, UI.MUTED)
	var account := LineEdit.new()
	account.placeholder_text = "Steam ID or link"
	account.max_length = 160
	form.add_child(account)
	UI.button(form, "Paste from Clipboard", func():
		account.text = DisplayServer.clipboard_get().strip_edges().left(account.max_length)
		account.grab_focus()
		account.caret_column = account.text.length()
	, false, 35)
	var alias := LineEdit.new()
	alias.placeholder_text = "Name (optional)"
	alias.max_length = 40
	form.add_child(alias)
	var message := UI.label(form, "", 16, UI.VIOLET)
	var submit := func():
		var id := RiftSocial.resolve_contact_id(account.text)
		if id.is_empty():
			message.text = "Enter a numeric friend code, Steam ID, or numeric Steam profile link."
			return
		var display := alias.text.strip_edges()
		if not RiftSocial.save_contact(id, id if display.is_empty() else display):
			message.text = "Could not save this contact."
			return
		menu.social_contact = "steam:" + id
		menu.social_filter = 0
		menu.show_page("Social")
	UI.button(form, "Save Contact", submit, false, 36)
	account.text_submitted.connect(func(_value): submit.call())
	alias.text_submitted.connect(func(_value): submit.call())
	UI.label(form, "Players you meet in co-op also appear under Recent.", 16, UI.MUTED)
	account.grab_focus()

static func build_messages(menu, columns: HBoxContainer) -> void:
	var threads: VBoxContainer = menu.card(columns, 0.7)
	UI.label(threads, "CONVERSATIONS", 24, UI.CYAN)
	var entries: VBoxContainer = menu.scroll_entries(threads)
	var pane: VBoxContainer = menu.card(columns, 1.3)
	var heading := UI.label(pane, "Choose a contact", 30, UI.CYAN)
	var history := RichTextLabel.new()
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.bbcode_enabled = false
	history.scroll_following = true
	pane.add_child(history)
	var composer := LineEdit.new()
	composer.placeholder_text = "Write a whisper"
	composer.max_length = RiftSocial.WHISPER_LIMIT
	pane.add_child(composer)
	var status := UI.label(pane, "", 16, UI.MUTED)
	var current: Dictionary = {"contact": {}, "button": null}
	var listed := {}
	var refresh := func():
		var contact: Dictionary = current.contact
		var key: Variant = contact.get("chat", 0)
		var active: bool = contact.get("party", false) if key is String else RiftSocial.can_whisper(key)
		if key is String:
			active = RiftRelay.party_operators.values().has(key.trim_prefix("rift:"))
		composer.editable = active
		history.clear()
		heading.text = contact.get("name", "Choose a contact")
		status.text = "" if active or contact.is_empty() else "This contact is outside your party or unavailable on Steam."
		for line in RiftSocial.whispers.get(key, []):
			history.add_text("%s  %s\n%s\n\n" % [line.get("at", ""), "You" if line.outgoing else heading.text, line.body])
		if active and history.get_paragraph_count() == 1:
			history.add_text("Send a private message to start the conversation.")
	var send := func():
		if current.contact.is_empty() or not RiftSocial.send_whisper(current.contact.chat, composer.text):
			if not composer.text.strip_edges().is_empty():
				status.text = "Message unavailable. Check that your friend is connected and try again."
			return
		composer.clear()
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	pane.add_child(controls)
	var submit := UI.button(controls, "Send", send, false, 35)
	composer.text_submitted.connect(func(_value): send.call())
	for phrase in ["Ready to deploy", "Meet at the hub", "One minute"]:
		UI.button(controls, phrase, func():
			if composer.editable:
				composer.text = phrase
				composer.grab_focus()
				composer.caret_column = composer.text.length()
		, false, 35)
	var select := func(contact: Dictionary):
		current.contact = contact
		menu.whisper_contact = contact.chat
		RiftSocial.unread_whispers.erase(contact.chat)
		if listed.has(contact.chat):
			listed[contact.chat].text = contact_title(contact)
		refresh.call()
		submit.disabled = not composer.editable
	var first := {}
	for contact in contacts():
		var connected: bool = contact.party if contact.recent else RiftSocial.can_whisper(contact.chat)
		if connected or RiftSocial.whispers.has(contact.chat):
			var button := contact_button(entries, contact, select)
			listed[contact.chat] = button
			button.focus_entered.connect(func(): set_focus(button, composer))
			if first.is_empty():
				first = contact
			if contact.chat == menu.whisper_contact:
				select.call(contact)
			if not button.disabled:
				set_focus(button, composer)
	if current.contact.is_empty() and not first.is_empty():
		select.call(first)
	if not current.contact.is_empty():
		listed[current.contact.chat].grab_focus()
	if first.is_empty():
		UI.label(entries, "Join a party or connect a Steam friend to send private messages.", 17, UI.MUTED)
		composer.editable = false
		submit.disabled = true
	watch(history, RiftSocial.whispers_changed, func(id):
		if current.contact.get("chat") == id:
			RiftSocial.unread_whispers.erase(id)
			refresh.call()
		if listed.has(id):
			for contact in contacts():
				if contact.chat == id:
					listed[id].text = contact_title(contact)
					break
	)
	watch(history, RiftRelay.changed, func():
		refresh.call()
		submit.disabled = not composer.editable
	)

static func build_invites(menu, columns: HBoxContainer) -> void:
	var pane: VBoxContainer = menu.card(columns)
	UI.label(pane, "GAME INVITES", 32, UI.CYAN)
	var rows: VBoxContainer = menu.scroll_entries(pane)
	var code_button := UI.button(pane, "Enter Room Code", menu.show_page.bind("Party"), false, 36)
	code_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var redraw := func():
		var focus := pane.get_viewport().gui_get_focus_owner()
		var restore_focus := focus == null or rows.is_ancestor_of(focus)
		var first_action: Button
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		if RiftSocial.invites.is_empty():
			UI.label(rows, "No pending invites.", 18, UI.MUTED)
		for code in RiftSocial.invites:
			var record: Dictionary = RiftSocial.invites[code]
			var card := UI.equipment_card(UI.CYAN)
			rows.add_child(card)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 9)
			card.add_child(row)
			var name := UI.label(row, record.name, 21)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var join := UI.button(row, "Join Game", func():
				if RiftRelay.can_receive_invite():
					RiftSocial.remove_invite(code)
					RiftRelay.join_room(code)
					menu.show_page("Party")
			, false, 36)
			join.disabled = not RiftRelay.can_receive_invite()
			var reject := UI.button(row, "Dismiss", RiftSocial.remove_invite.bind(code), false, 36)
			if first_action == null:
				first_action = reject if join.disabled else join
		if restore_focus:
			(first_action if first_action else code_button).grab_focus()
	watch(pane, RiftSocial.invites_changed, redraw)
	watch(pane, RiftRelay.changed, redraw)
	redraw.call()
