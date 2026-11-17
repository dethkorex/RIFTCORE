extends RefCounted

const UI := preload("res://scripts/rift_ui.gd")
const ICONS := preload("res://scripts/equipment_icons.gd")
const CATALOG := preload("res://scripts/sector_catalog.gd")
const FILTERS := ["All contacts", "Friends", "In your party", "Online", "Recent"]
const ONLINE_DOT := preload("res://assets/ui/social-online.svg")
const OFFLINE_DOT := preload("res://assets/ui/social-offline.svg")
const Codes := preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")

static func contacts(include_directory := false) -> Array[Dictionary]:
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
	if include_directory and RiftRelay.directory.online():
		for entry in RiftRelay.directory.friends:
			var relation := int(entry.get("FriendStatus", 0))
			if relation == Codes.FRIEND_STATUS.NONE:
				continue
			var online: bool = RiftRelay.directory.is_friend_online(entry)
			var state := "Online" if online else "Offline"
			if relation == Codes.FRIEND_STATUS.INCOMING_REQUEST:
				state = "Friend request"
			elif relation == Codes.FRIEND_STATUS.WAITING_FOR_REPLY:
				state = "Request sent"
			result.append({"key": "directory:" + entry.Username, "id": entry.Username, "name": entry.Username,
				"directory": true, "relation": relation, "chat": "account:" + entry.Username, "saved": relation == Codes.FRIEND_STATUS.FRIEND,
				"joinable": online and not RiftRelay.directory.friend_room_code(entry).is_empty(),
				"party": false, "playing": online, "recent": false, "priority": 0 if online else 2, "status": state})
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
	elif contact.get("directory", false):
		title += "  ·  " + contact.status
	elif contact.playing:
		title += "  ·  Playing"
	return "%s  ·  %d new" % [title, unread] if unread > 0 else title

static func contact_button(row: VBoxContainer, contact: Dictionary, select: Callable) -> Button:
	var button := UI.button(row, contact_title(contact), select.bind(contact), false, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = contact.status
	button.icon = (ONLINE_DOT if contact.playing else OFFLINE_DOT) if contact.get("directory", false) and contact.saved else ICONS.icon("visor", "visor")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	return button

static func message_contacts() -> Array[Dictionary]:
	var rows := contacts(true)
	for id in RiftSocial.whispers:
		if not id is int or not RiftSocial.can_whisper(id) or rows.any(func(contact): return contact.chat == id):
			continue
		var name := str(id)
		var persona: String = RiftSocial.steam.getFriendPersonaName(id)
		if not persona.is_empty() and persona != "[unknown]":
			name = persona
		rows.append({"key": "steam:" + str(id), "chat": id, "id": str(id), "name": name, "status": "Steam conversation", "party": false, "playing": false, "recent": false, "saved": false})
	return rows

static func can_message(id: Variant) -> bool:
	if id is String:
		if id.begins_with("account:"):
			return RiftRelay.directory.whispers.can_send(id.trim_prefix("account:"))
		return id.begins_with("rift:") and RiftRelay.party_operators.values().has(id.trim_prefix("rift:"))
	return id is int and RiftSocial.can_whisper(id)

static func set_focus(left: Control, right: Control) -> void:
	if is_instance_valid(left) and is_instance_valid(right):
		left.focus_neighbor_right = left.get_path_to(right)
		right.focus_neighbor_left = right.get_path_to(left)

static func build_friends(menu, columns: HBoxContainer) -> void:
	RiftSocial.connect_steam()
	RiftRelay.listen_for_steam_invites()
	var directory: VBoxContainer = menu.card(columns, 0.9)
	var details: VBoxContainer = menu.card(columns, 1.15)
	UI.label(directory, "FRIENDS", 26, UI.CYAN)
	var connection := UI.label(directory, RiftRelay.directory.status, 15, UI.MUTED)
	var search := LineEdit.new()
	search.placeholder_text = "Filter your contacts"
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
	UI.button(tools, "Find Friends", open_find_friends.bind(menu), true, 34)
	var online_setup := UI.button(tools, "Connect Online", menu.show_page.bind("Directory Account"), false, 34)
	online_setup.visible = not RiftRelay.directory.online()
	UI.button(tools, "Setup Guide", menu.show_page.bind("Co-op Setup Guide"), false, 34)
	var name := UI.label(details, "Choose a friend", 32, UI.CYAN)
	var status := UI.label(details, "", 16, UI.MUTED)
	details.add_child(HSeparator.new())
	var actions := UI.column(details, 8)
	var note := UI.label(details, "", 16, UI.CYAN)
	var relay_status := UI.label(details, "Invite Friend opens a private party." if RiftRelay.connected_room.is_empty() else RiftRelay.status, 15, UI.MUTED)
	var conversation := build_conversation(details)

	var selected := {"key": menu.social_contact, "button": null, "action": null}
	var show_contact := func(contact: Dictionary):
		for child in actions.get_children():
			actions.remove_child(child)
			child.queue_free()
		selected.key = contact.get("key", "")
		menu.social_contact = selected.key
		selected.action = null
		conversation.select.call(contact)
		var primary := HBoxContainer.new()
		primary.add_theme_constant_override("separation", 8)
		actions.add_child(primary)
		name.text = contact.get("name", "Choose a friend")
		status.text = contact.get("status", "Use Find Friends to add someone by username.")
		if contact.get("directory", false) and contact.get("saved", false):
			status.text = "●  " + String(contact.status)
			status.add_theme_color_override("font_color", Color("62ea98") if contact.playing else Color("ff687e"))
		else:
			status.add_theme_color_override("font_color", UI.CYAN if contact.get("playing", false) else UI.MUTED)
		if contact.get("directory", false):
			var relation: int = contact.relation
			if relation == Codes.FRIEND_STATUS.FRIEND:
				if contact.joinable:
					var join := UI.button(primary, "Join Game", RiftRelay.join_directory_friend.bind(contact.id), true, 42)
					join.disabled = not RiftRelay.can_receive_invite() or RiftRelay.checking_friend_room
					if not join.disabled:
						selected.action = join
				var invite := UI.button(primary, "Invite Friend", RiftRelay.invite_directory_friend.bind(contact.id), true, 42)
				invite.disabled = not contact.playing or not RiftRelay.can_invite_directory_friend()
				invite.tooltip_text = "Opens a private group if needed and sends a RIFTCORE invite."
				var message := UI.button(primary, "Message", conversation.focus, false, 36)
				message.disabled = not can_message(contact.chat)
				message.tooltip_text = "Only online friends can receive messages." if message.disabled else ""
				if selected.action == null:
					selected.action = invite if not invite.disabled else (message if not message.disabled else null)
			var management := HBoxContainer.new()
			management.add_theme_constant_override("separation", 8)
			actions.add_child(management)
			if relation == Codes.FRIEND_STATUS.INCOMING_REQUEST:
				selected.action = directory_action(management, "Accept Friend", contact.id, "accept", note)
			var remove := directory_action(management, "Remove Friend" if contact.saved else "Dismiss Request", contact.id, "remove", note)
			if selected.action == null:
				selected.action = remove
		elif not contact.is_empty():
			var joined: bool = contact.party
			var chat_allowed := can_message(contact.chat)
			var invite := UI.button(primary, "Invite Friend", RiftRelay.invite_friend.bind(contact.chat), true, 42) if not contact.recent and contact.playing else null
			if invite:
				invite.disabled = joined or not contact.playing or not RiftRelay.can_invite_friend()
				invite.tooltip_text = "Available for Steam friends playing RIFTCORE."
			var whisper: Button
			if chat_allowed:
				whisper = UI.button(primary, "Message", conversation.focus, false, 36)
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
		var code := UI.button(actions, "Copy Room Code", RiftRelay.copy_invite_code, false, 34)
		code.visible = not RiftRelay.connected_room.is_empty()
		code.disabled = not code.visible or not RiftRelay.can_copy_invite_code()
		code.tooltip_text = "Copy the code for your active group."
		if selected.action == null and not code.disabled:
			selected.action = code
		set_focus(selected.button, selected.action)
	var rebuild := func():
		var previous_focus := rows.get_viewport().gui_get_focus_owner()
		var action_focus := previous_focus != null and actions.is_ancestor_of(previous_focus)
		var focused_caption: String = previous_focus.text if action_focus and previous_focus is Button else ""
		var had_focus := previous_focus != null and (rows.is_ancestor_of(previous_focus) or action_focus)
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		var query := search.text.strip_edges().to_lower()
		var chosen := {}
		var first := {}
		for contact in message_contacts():
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
				RiftSocial.unread_whispers.erase(entry.chat)
				if is_instance_valid(selected.button):
					selected.button.text = contact_title(entry)
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
		if action_focus and not focused_caption.is_empty():
			for control in actions.find_children("*", "Button", true, false):
				if control.text == focused_caption and not control.disabled and control.visible:
					control.grab_focus()
					return
		if had_focus or rows.get_viewport().gui_get_focus_owner() == null:
			selected.button.grab_focus()
	search.text_changed.connect(func(_query): rebuild.call())
	filter.item_selected.connect(func(index: int):
		menu.social_filter = index
		rebuild.call()
	)
	watch(directory, RiftRelay.directory.changed, func():
		connection.text = RiftRelay.directory.status if RiftRelay.directory.online() else "Offline directory · Connect to find RIFTCORE friends"
		online_setup.visible = not RiftRelay.directory.online()
		rebuild.call()
	)
	watch(directory, RiftRelay.changed, func():
		relay_status.text = RiftRelay.status
		rebuild.call()
	)
	watch(directory, RiftSocial.whispers_changed, func(id):
		for contact in message_contacts():
			if is_same(contact.chat, id):
				var item := rows.get_node_or_null("Contact_" + String(contact.key).replace(":", "_")) as Button
				if item:
					item.text = contact_title(contact)
				else:
					rebuild.call()
				break
	)
	rebuild.call()
	if rows.get_viewport().gui_get_focus_owner() == null:
		search.grab_focus()

static func directory_action(parent: Container, caption: String, name: String, action: String, message: Label) -> Button:
	var holder := {}
	var button := UI.button(parent, caption, func():
		var control: Button = holder.button
		control.disabled = true
		var result: String = await RiftRelay.directory.friend_action(name, action)
		if is_instance_valid(message):
			message.text = result
		if is_instance_valid(control):
			control.disabled = action != "remove" and (result == "Friend request sent." or result == "Friend request accepted.")
	, action != "remove", 36)
	holder.button = button
	return button

static func build_startup_choices(menu, columns: HBoxContainer) -> void:
	var form: VBoxContainer = menu.card(columns, 1.15)
	UI.label(form, "WELCOME TO RIFTCORE", 38, UI.CYAN)
	UI.label(form, "An online account lets you use cloud saves and find friends. You can play solo with a local profile.", 19, UI.MUTED)
	form.add_child(HSeparator.new())
	var sign_in := UI.button(form, "Sign In", menu.show_page.bind("Sign In"), true)
	UI.button(form, "Create Account", menu.show_page.bind("Create Account"))
	UI.button(form, "Continue Offline", func():
		if menu.account.display_name.is_empty():
			menu.show_page("Offline Setup")
		else:
			RiftSettings.confirm_startup_choice("offline")
			menu.open_after_startup()
	)
	UI.button(form, "Quit Game", RiftRelay.quit_game)
	menu.portrait(menu.card(columns))
	sign_in.grab_focus()

static func build_directory_account(menu, columns: HBoxContainer, create := false) -> void:
	var form: VBoxContainer = menu.card(columns)
	var directory = RiftRelay.directory
	var heading := "Create a RIFTCORE Account" if create else "Sign In to RIFTCORE"
	UI.label(form, heading, 31, UI.CYAN)
	if directory.online():
		UI.label(form, directory.status, 18, UI.CYAN)
		UI.button(form, "Continue", func(): finish_directory_form(menu), true).grab_focus()
		return
	var registration: LineEdit
	if create:
		registration = directory_field(form, "Account username", 20)
	var email := directory_field(form, "Email")
	if not create:
		email.text = menu.sign_in_email_hint
		menu.sign_in_email_hint = ""
	var password := directory_field(form, "Password", 20)
	password.secret = true
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	form.add_child(code_row)
	var code := directory_field(code_row, "Email verification code", 32)
	UI.button(code_row, "Paste Code", func():
		code.text = clean_verification_code(DisplayServer.clipboard_get()).left(code.max_length)
		code.grab_focus()
		code.caret_column = code.text.length()
	, false, 36)
	code_row.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	form.add_child(actions)
	var primary := UI.button(actions, "Create Account" if create else "Sign In", Callable(), true, 36)
	primary.disabled = false
	primary.focus_mode = Control.FOCUS_ALL
	var resend := UI.button(actions, "Resend Code", Callable(), false, 36)
	resend.hide()
	resend.disabled = false
	resend.focus_mode = Control.FOCUS_ALL
	var message := UI.label(form, "", 16, UI.MUTED)
	if not create and directory.linked and directory.remember_sign_in:
		var use_saved := UI.button(form, "Sign In as " + directory.saved_account_name, func():
			if directory.busy:
				return
			message.text = "Restoring sign-in…"
			await directory.configure()
			if not is_instance_valid(form):
				return
			if directory.online():
				finish_directory_form(menu)
			else:
				message.text = directory.status
		, false, 34)
		use_saved.tooltip_text = "Use the saved sign-in on this device."
	var submit := func():
		if directory.busy or primary.disabled:
			return
		var verify := code_row.visible
		var token := clean_verification_code(code.text) if verify else ""
		if verify and token.is_empty():
			message.text = "Enter the verification code from your email."
			code.grab_focus()
			return
		var email_address := email.text.strip_edges()
		var passphrase := password.text
		message.text = "Connecting…"
		primary.disabled = true
		resend.disabled = true
		if create:
			var registration_result: Dictionary = await directory.register_account(email_address, passphrase, registration.text)
			if not is_instance_valid(form):
				return
			if registration_result.created:
				password.clear()
				show_account_created(menu, form, email_address)
				return
			message.text = registration_result.message
			primary.disabled = false
			return
		var result: String = await directory.sign_in(email_address, passphrase, token)
		if not is_instance_valid(form):
			return
		message.text = result
		primary.disabled = false
		resend.disabled = false
		if directory.online():
			password.clear()
			finish_directory_form(menu)
		elif directory.needs_verification:
			if registration:
				registration.hide()
			code_row.show()
			resend.show()
			primary.text = "Verify Email"
			code.grab_focus()
	primary.pressed.connect(submit)
	resend.pressed.connect(func():
		if directory.busy:
			return
		var email_address := email.text.strip_edges()
		var passphrase := password.text
		message.text = "Requesting a new code…"
		resend.disabled = true
		var result: String = await directory.resend_code(email_address, passphrase)
		if is_instance_valid(message):
			message.text = result
			resend.disabled = false
	)
	code.text_submitted.connect(func(_value): submit.call())
	password.text_submitted.connect(func(_value): submit.call())
	if menu.page == "Directory Account":
		var new_page := "Directory Registration"
		UI.button(form, "Create Account", menu.show_page.bind(new_page), false, 34)
	elif menu.page == "Directory Registration":
		UI.button(form, "Sign In", menu.show_page.bind("Directory Account"), false, 34)
	(registration if registration else email).grab_focus()

static func show_account_created(menu, form: Control, email: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Account Created"
	dialog.dialog_text = "Congratulations! Your RIFTCORE account has been created. Sign in with your email and password to continue."
	dialog.ok_button_text = "Continue to Sign In"
	dialog.transient = true
	dialog.exclusive = true
	dialog.unresizable = true
	form.add_child(dialog)
	var sign_in := func():
		menu.sign_in_email_hint = email
		menu.show_page("Directory Account" if menu.station_panel or menu.page == "Directory Registration" else "Sign In")
	dialog.confirmed.connect(sign_in)
	dialog.canceled.connect(sign_in)
	dialog.popup_centered(Vector2i(470, 0))

static func finish_directory_form(menu) -> void:
	if menu.directory_return_page == "Account Settings":
		menu.directory_return_page = ""
		RiftSettings.confirm_startup_choice("online")
		menu.show_page("Account Settings")
		return
	if menu.station_panel:
		RiftSettings.confirm_startup_choice("online")
		menu.show_page("Social")
	else:
		menu.online_setup_finished.emit()

static func build_account_settings(menu, columns: HBoxContainer) -> void:
	var form: VBoxContainer = menu.card(columns)
	var directory = RiftRelay.directory
	UI.label(form, "Account Settings", 30, UI.CYAN)
	var remember := CheckButton.new()
	remember.text = "Remember sign-in on this device"
	remember.button_pressed = directory.remember_sign_in
	remember.toggled.connect(directory.set_remember_sign_in)
	form.add_child(remember)
	if not directory.online():
		UI.label(form, "Sign in to change your account name or password.", 18, UI.MUTED)
		UI.button(form, "Sign In", func():
			menu.directory_return_page = "Account Settings"
			menu.show_page("Directory Account")
		, true).grab_focus()
		return
	var username := directory_field(form, "Username", 20)
	username.text = directory.username
	var profile_status := UI.label(form, "", 16, UI.MUTED)
	UI.button(form, "Save Username", func():
		var result: String = await directory.change_username(username.text)
		if not is_instance_valid(profile_status):
			return
		profile_status.text = result
		if directory.online() and directory.username == username.text.strip_edges():
			menu.username_changed.emit()
	, true)
	UI.button(form, "Sign Out", func():
		await directory.sign_out()
		if is_instance_valid(form):
			menu.show_page("Account Settings")
	)
	var security: VBoxContainer = menu.card(columns)
	UI.label(security, "Change Password", 28, UI.CYAN)
	var email := directory_field(security, "Account email")
	var current := directory_field(security, "Current password", 20)
	var replacement := directory_field(security, "New password", 20)
	var confirmation := directory_field(security, "Confirm new password", 20)
	for field in [current, replacement, confirmation]:
		field.secret = true
	var password_status := UI.label(security, "", 16, UI.MUTED)
	UI.button(security, "Change Password", func():
		if replacement.text != confirmation.text:
			password_status.text = "The new passwords do not match."
			return
		var result: String = await directory.change_password(email.text.strip_edges(), current.text, replacement.text)
		if not is_instance_valid(password_status):
			return
		current.clear()
		replacement.clear()
		confirmation.clear()
		password_status.text = result
	)
	username.grab_focus()

static func clean_verification_code(value: String) -> String:
	return value.strip_edges().replace("\u200b", "").replace("\ufeff", "").replace("\u00a0", "").replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "")

static func directory_field(parent: Container, hint: String, limit := 254) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.max_length = limit
	field.custom_minimum_size = Vector2(300, 38)
	field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(field)
	return field

static func open_find_friends(menu) -> void:
	var previous_focus: Control = menu.get_viewport().gui_get_focus_owner()
	var popup := ColorRect.new()
	popup.name = "FindFriendsPopup"
	popup.color = Color(0.02, 0.04, 0.08, 0.60)
	menu.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	popup.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Dialog"
	panel.add_theme_stylebox_override("panel", UI.frame(Color("11223b"), UI.CYAN))
	var viewport_size: Vector2 = menu.get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(810, viewport_size.x - 48), minf(440, viewport_size.y - 48))
	center.add_child(panel)
	var content := UI.column(panel, 12)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UI.label(header, "Find Friends", 30, UI.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := UI.button(header, "Close", popup.hide, false, 34)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	popup.visibility_changed.connect(func():
		if not popup.visible:
			popup.queue_free()
			if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
				previous_focus.grab_focus()
	)
	var initial := build_player_directory(menu, columns)
	var first: Control = initial if initial else close
	first.grab_focus()
	watch(popup, popup.get_viewport().gui_focus_changed, func(control: Control):
		if popup.visible and control and not popup.is_ancestor_of(control):
			first.grab_focus.call_deferred()
	)

static func build_directory_search(menu, columns: HBoxContainer) -> Control:
	var form: VBoxContainer = menu.card(columns, 1.22)
	var directory = RiftRelay.directory
	UI.label(form, "Search by username", 24, UI.CYAN)
	if not directory.online():
		UI.label(form, "Connect your profile to search live.", 17, UI.MUTED)
		return UI.button(form, "Connect Online", menu.show_page.bind("Directory Account"), true, 36)
	var query := directory_field(form, "Exact RIFTCORE account username", 20)
	var message := UI.label(form, "", 17, UI.MUTED)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	form.add_child(actions)
	var searching := [false]
	var find := func():
		if searching[0]:
			return
		for child in actions.get_children():
			actions.remove_child(child)
			child.queue_free()
		var name := query.text.strip_edges()
		if name.length() < 3 or name.nocasecmp_to(directory.username) == 0:
			message.text = "Enter another player’s full RIFTCORE account username."
			return
		searching[0] = true
		message.text = "Searching…"
		var result: Dictionary = await directory.lookup(name)
		searching[0] = false
		if not is_instance_valid(form):
			return
		var status := int(result.get("Code", 1))
		if status == Codes.ACCOUNT_GET_FRIEND_STATUS_RESPONSE_CODE.USER_DOESNT_EXIST:
			message.text = "No player found with that name."
			return
		if status != 0:
			message.text = directory.response_message("Search unavailable", status)
			return
		var relation := int(result.get("Result", {}).get("FriendStatus", 0))
		match relation:
			Codes.FRIEND_STATUS.FRIEND:
				message.text = "%s is already your friend." % name
			Codes.FRIEND_STATUS.WAITING_FOR_REPLY:
				message.text = "Waiting for %s to accept." % name
			Codes.FRIEND_STATUS.INCOMING_REQUEST:
				message.text = "%s sent you a friend request." % name
				directory_action(actions, "Accept Friend", name, "accept", message).grab_focus()
			_:
				message.text = "Found %s" % name
				directory_action(actions, "Send Friend Request", name, "request", message).grab_focus()
	UI.button(form, "Search", find, true, 36)
	query.text_submitted.connect(func(_value): find.call())
	return query

static func build_player_directory(menu, columns: HBoxContainer) -> Control:
	var initial := build_directory_search(menu, columns)
	var directory = RiftRelay.directory
	if not directory.online():
		return initial
	var form: VBoxContainer = menu.card(columns)
	UI.label(form, "ALL PLAYERS", 26, UI.CYAN)
	var caption := UI.label(form, "Browse discoverable RIFTCORE accounts.", 16, UI.MUTED)
	var rows: VBoxContainer = menu.scroll_entries(form)
	var navigation := HBoxContainer.new()
	form.add_child(navigation)
	navigation.hide()
	var state := {"page": 1, "last": 1, "busy": false}
	var redraw := func(direction: int):
		if state.busy:
			return
		state.busy = true
		var page := clampi(int(state.page) + direction, 1, int(state.last))
		caption.text = "Loading players…"
		var reply: Dictionary = await directory.browse_registered_players(page)
		if not is_instance_valid(form):
			return
		state.busy = false
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		if int(reply.get("Code", 1)) != 0 or not reply.get("Result") is Array:
			caption.text = "The player index is unavailable. You can still search by exact username."
			return
		state.page = page
		state.last = maxi(page, int(reply.get("FinalPage", page)))
		navigation.visible = state.last > 1
		caption.text = "Page %d / %d" % [page, state.last]
		for entry in reply.Result:
			var username := String(entry.get("Username", "")) if entry is Dictionary else ""
			if username.is_empty() or username.nocasecmp_to(directory.username) == 0:
				continue
			var line := HBoxContainer.new()
			rows.add_child(line)
			UI.label(line, username, 18).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			directory_action(line, "Add Friend", username, "request", caption)
		if rows.get_child_count() == 0:
			UI.label(rows, "No other registered players on this page.", 17, UI.MUTED)
	UI.button(navigation, "Previous", redraw.bind(-1), false, 34)
	UI.button(navigation, "Next", redraw.bind(1), false, 34)
	redraw.call(0)
	return initial

static func build_notifications(menu, columns: HBoxContainer) -> void:
	build_friend_requests(menu, columns)
	build_invites(menu, columns)

static func build_friend_requests(menu, columns: HBoxContainer) -> void:
	var form: VBoxContainer = menu.card(columns)
	UI.label(form, "FRIEND REQUESTS", 28, UI.CYAN)
	var directory = RiftRelay.directory
	var rows: VBoxContainer = menu.scroll_entries(form)
	var message := UI.label(form, "", 16, UI.MUTED)
	var redraw := func():
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		if not directory.online():
			UI.label(rows, "Sign in to see incoming friend requests.", 17, UI.MUTED)
			return
		if directory.incoming_names.is_empty():
			UI.label(rows, "No pending friend requests.", 17, UI.MUTED)
		for sender in directory.incoming_names:
			var request := UI.equipment_card(UI.CYAN)
			rows.add_child(request)
			var actions := HBoxContainer.new()
			actions.add_theme_constant_override("separation", 9)
			request.add_child(actions)
			UI.label(actions, sender, 19).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			directory_action(actions, "Accept", sender, "accept", message)
			directory_action(actions, "Decline", sender, "remove", message)
	watch(rows, directory.changed, redraw)
	redraw.call()

static func build_add(menu, columns: HBoxContainer) -> void:
	build_directory_search(menu, columns)
	var form: VBoxContainer = menu.card(columns)
	UI.label(form, "ADD STEAM CONTACT", 26, UI.CYAN)
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

static func build_conversation(parent: VBoxContainer) -> Dictionary:
	var pane := UI.column(parent, 5)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var history := RichTextLabel.new()
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.scroll_following = true
	pane.add_child(history)
	var row := HBoxContainer.new()
	pane.add_child(row)
	var composer := LineEdit.new()
	composer.placeholder_text = "Write a whisper"
	composer.max_length = RiftSocial.WHISPER_LIMIT
	composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(composer)
	var status := UI.label(pane, "", 15, UI.MUTED)
	var current := {"chat": null, "name": ""}
	var send := func():
		if RiftSocial.send_whisper(current.chat, composer.text):
			composer.clear()
		elif not composer.text.strip_edges().is_empty():
			status.text = "Message unavailable. Try again when your friend is connected."
	var submit := UI.button(row, "Send", send, false, 35)
	composer.text_submitted.connect(func(_value): send.call())
	var refresh := func():
		var key: Variant = current.chat
		var active := can_message(key)
		var messages: Array = RiftSocial.whispers.get(key, [])
		pane.visible = active
		composer.editable = active
		submit.disabled = not active
		history.clear()
		status.text = ""
		for line in messages:
			history.add_text("%s  %s
%s

" % [line.get("at", ""), "You" if line.outgoing else current.name, line.body])
		if active and messages.is_empty():
			history.add_text("Send a private message to start the conversation.")
	var select := func(contact: Dictionary):
		var key: Variant = contact.get("chat")
		if not is_same(current.chat, key):
			composer.clear()
		current.chat = key
		current.name = contact.get("name", "")
		refresh.call()
	watch(history, RiftSocial.whispers_changed, func(id):
		if is_same(current.chat, id):
			if composer.has_focus():
				RiftSocial.unread_whispers.erase(id)
			refresh.call()
	)
	watch(history, RiftRelay.directory.whispers.failed, func(recipient: String):
		if current.chat == "account:" + recipient:
			status.text = "Message wasn’t delivered. Check that your friend is still online."
	)
	return {"select": select, "focus": func():
		if composer.is_visible_in_tree() and composer.editable:
			RiftSocial.unread_whispers.erase(current.chat)
			composer.grab_focus()
	}

static func build_invites(menu, columns: HBoxContainer) -> void:
	var pane: VBoxContainer = menu.card(columns)
	UI.label(pane, "GAME INVITES", 32, UI.CYAN)
	var rows: VBoxContainer = menu.scroll_entries(pane)
	var code_button := UI.button(pane, "Enter Room Code", menu.show_page.bind("Party"), false, 36)
	code_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var redraw := func():
		var focus := pane.get_viewport().gui_get_focus_owner()
		var restore_focus := focus != null and rows.is_ancestor_of(focus)
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
