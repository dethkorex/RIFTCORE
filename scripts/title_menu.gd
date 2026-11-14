class_name RiftTitleMenu
extends Control

signal start_requested
signal load_requested
signal hub_requested
signal station_closed
signal sector_requested(number: int)
signal slot_requested(number: int, fresh: bool, operator_name: String)
signal save_requested

var active_slot := 0
var developer_session := false
var replace_slot := 0
var new_operator_name := ""
var slot_error := ""
var save_status: Label
var relay_status: Label
var relay_code: LineEdit
var relay_host: Button
var relay_join: Button
var relay_paste: Button
var relay_deploy: Button
var relay_copy: Button
var relay_leave: Button
var steam_invite_buttons: Array[Button] = []

var can_load := false
var saved_sector := 1
var saved_act := 1
var saved_level := 1
var saved_experience := 0
var run_cleared_through := 0
var at_sector_start := false
var run_unlocks: Array = []
var profile
var shop_status := ""
var challenge_sector := 1
var inventory_slot := "frame"
var inventory_status := ""
var shop_item := ""
var focused_item := ""
var station_panel := false
var deploy_error := ""

const CoopSetup := preload("res://scripts/coop_setup.gd")
const Story := preload("res://scripts/rift_story.gd")
const EquipmentDisplay := preload("res://scripts/equipment_display.gd")
const EquipmentStats := preload("res://scripts/equipment_stats.gd")
const UI := preload("res://scripts/rift_ui.gd")
const PORTRAIT := preload("res://assets/ui/rx07_menu.png")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const ManualSave := preload("res://scripts/manual_save_session.gd")
const EquipmentBody := preload("res://scripts/equipment_body.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")

var equipment_view := "Gear"
var storage_filter := "All"
var leaderboard_sector := 1
var party_from_deploy := false
var layout: VBoxContainer
var page := "Title"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	RiftRelay.changed.connect(refresh_online_room)
	RiftSocial.records_changed.connect(func():
		if is_visible_in_tree() and page == "Leaderboard":
			show_page.call_deferred(page)
	)
	show_page("Title")

func show_page(next: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if next == "Hub":
		hub_requested.emit()
		return
	if next == "Replace Slot" and ManualSave.read_slot(replace_slot) == null:
		slot_requested.emit(replace_slot, true, new_operator_name)
		return
	page = next
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if page == "Title":
		build_start_screen()
		return
	if station_panel:
		var veil := ColorRect.new()
		veil.color = Color(0.025, 0.044, 0.084, 0.89)
		add_child(veil)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		add_menu_art(true)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 27)
	layout = UI.column(margins, 12)
	var header := HBoxContainer.new()
	layout.add_child(header)
	if station_panel:
		build_station_header(header)
	else:
		var logo := UI.label(header, "RIFTCORE", 42, UI.CYAN)
		logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var section := UI.label(header, page.to_upper(), 18, UI.MUTED)
		section.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout.add_child(HSeparator.new())
	var tabs := station_tabs()
	if not tabs.is_empty():
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 8)
		layout.add_child(strip)
		for tab_page in tabs:
			var label: String = tabs[tab_page]
			var button := UI.button(strip, label, show_page.bind(tab_page), false, 35)
			if page == tab_page:
				button.add_theme_color_override("font_color", UI.CYAN)
		var hint := UI.label(strip, "LB / RB   Switch tab", 14, UI.MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	match page:
		"New Game", "Load Game":
			build_save_slots(columns, page == "New Game")
		"Replace Slot":
			var form := card(columns)
			UI.label(form, "Start over in Slot %d?" % replace_slot, 32, UI.CYAN)
			UI.label(form, "Your next manual save will replace the existing file.", 19, UI.MUTED)
			UI.button(form, "Keep Existing Save", show_page.bind("New Game"), true).grab_focus()
			UI.button(form, "Start New Game", func(): slot_requested.emit(replace_slot, true, new_operator_name))
		"Save Game":
			var form := card(columns, 1.35)
			UI.label(form, "Save Game", 34, UI.CYAN)
			UI.label(form, "Save your station inventory, banked bolts, and current deployment to this slot.", 19, UI.MUTED)
			var save_button := UI.button(form, "Save to Slot %d" % active_slot, func(): save_requested.emit(), true)
			save_button.disabled = active_slot == 0
			if not save_button.disabled:
				save_button.grab_focus()
			save_status = UI.label(form, "", 19, UI.CYAN)
			portrait(card(columns))
		"Sector select":
			build_sector(columns)
		"Level select", "Co-op Sectors":
			build_level_select(columns)
		"New run":
			var confirmation := card(columns)
			UI.label(confirmation, "Start a new run?", 34, UI.CYAN)
			UI.label(confirmation, "Your current deployment, run XP and level unlocks will be reset.", 20, UI.MUTED)
			UI.button(confirmation, "Start in Neon Factory", deploy, true).grab_focus()
			UI.button(confirmation, "Keep current run", show_page.bind("Sector select"))
		"Upgrades":
			build_workshop(columns)
		"Fabrication":
			build_fabrication(columns)
		"Storage":
			build_storage(columns)
		"Shop":
			build_shop(columns)
		"Craft Item":
			build_purchase(columns)
		"Social":
			build_social(columns)
		"Party":
			build_online_room(columns)
		"Leaderboard":
			build_leaderboard(columns)
		"Collection":
			build_archive(columns)
		"Challenges":
			build_challenges(columns)
		"Co-op Setup Guide":
			CoopSetup.build(card(columns, 1.75), leave_page)
			portrait(card(columns))
		"Settings":
			var settings := UI.settings(card(columns), not station_panel)
			settings.initial_focus.grab_focus()
	if page not in ["Title", "Co-op Setup Guide"]:
		var back_title := "Back to Title"
		if station_panel:
			back_title = "Back to Deployment" if page in ["Level select", "New run"] else "Back to Station"
			if page == "Craft Item":
				back_title = "Back to Fabrication"
		var back := UI.button(layout, back_title, leave_page)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if get_viewport().gui_get_focus_owner() == null:
			back.grab_focus()

func station_tabs() -> Dictionary:
	if not station_panel:
		return {}
	if page in ["Fabrication", "Upgrades"]:
		return {"Fabrication": "Crafting", "Upgrades": "Core Enhancements"}
	if page in ["Save Game", "Settings"]:
		return {"Save Game": "Save Game", "Settings": "Settings"}
	if page in ["Social", "Party", "Leaderboard"]:
		return {"Social": "Friends", "Party": "Party", "Leaderboard": "Leaderboard"}
	return {}

func build_station_header(header: HBoxContainer) -> void:
	header.add_theme_constant_override("separation", 9)
	var wordmark := TextureRect.new()
	wordmark.texture = preload("res://assets/ui/riftcore-wordmark.svg")
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wordmark.custom_minimum_size = Vector2(178, 44)
	header.add_child(wordmark)
	var station_name := page.to_upper()
	if page in ["Fabrication", "Upgrades", "Craft Item"]:
		station_name = "WORKSHOP"
	elif page in ["Save Game", "Settings"]:
		station_name = "SYSTEM"
	elif page in ["Social", "Party", "Leaderboard"]:
		station_name = "SOCIAL"
	var heading := UI.label(header, station_name, 25, UI.CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats := UI.label(header, "%d bolts   ·   %d core shards" % [profile.credits, profile.core_shards], 16, Color("ffd079"))
	stats.autowrap_mode = TextServer.AUTOWRAP_OFF

func open_station(next: String) -> void:
	station_panel = true
	deploy_error = ""
	inventory_status = ""
	shop_item = ""
	focused_item = ""
	equipment_view = "Gear"
	storage_filter = "All"
	party_from_deploy = false
	show()
	show_page(next)

func leave_page() -> void:
	if page == "Settings" and find_children("RiftSettingsPanel", "", true, false).any(func(panel): return panel.installing):
		return
	if page == "Co-op Setup Guide":
		show_page("Party")
		return
	if page in ["Party", "Social", "Leaderboard", "Co-op Sectors"] and party_from_deploy:
		party_from_deploy = false
		show_page("Sector select")
		return
	if page in ["Party", "Social", "Leaderboard"] and not RiftRelay.pending.is_empty():
		RiftRelay.leave()
	if station_panel:
		if page == "Co-op Sectors":
			show_page("Party")
			return
		if page == "Craft Item":
			show_page("Fabrication")
			return
		if page in ["Level select", "New run"]:
			show_page("Sector select")
			return
		station_panel = false
		hide()
		station_closed.emit()
		return
	show_page("New Game" if page == "Replace Slot" else "Title")

func show_deploy_error() -> void:
	deploy_error = "Could not save the selected deployment."
	show_page("Level select")

func card(parent: Container, ratio := 1.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", UI.texture_frame("panel_base_large", 40, Vector2(22, 18)))
	parent.add_child(panel)
	return UI.column(panel, 12)

func portrait(parent: VBoxContainer) -> void:
	var hero := TextureRect.new()
	hero.texture = PORTRAIT
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hero)

func add_menu_art(dimmed: bool) -> void:
	var backdrop := TitleBackdrop.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/riftcore_title_art.png"):
		var art := TextureRect.new()
		art.texture = load("res://assets/ui/riftcore_title_art.png") as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dimmed:
		var shade := ColorRect.new()
		shade.color = Color(0.009, 0.021, 0.055, 0.81)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func build_start_screen() -> void:
	add_menu_art(false)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.texture_frame("panel_base_large", 40, Vector2(28, 20)))
	add_child(panel)
	panel.anchor_left = 0.60
	panel.anchor_right = 0.96
	panel.anchor_top = 0.19
	var stack := UI.column(panel, 10)
	var brand := TextureRect.new()
	brand.texture = preload("res://assets/ui/riftcore-wordmark.svg")
	brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.custom_minimum_size.y = 72
	stack.add_child(brand)
	UI.label(stack, "ROGUE PROTOCOL", 17, UI.VIOLET)
	stack.add_child(HSeparator.new())
	var buttons: Array[Button] = []
	if active_slot > 0 or developer_session:
		var label := "Continue Station  /  Slot %d" % active_slot if active_slot > 0 else "Enter Station"
		buttons.append(UI.button(stack, label, func(): hub_requested.emit(), true))
	buttons.append(UI.button(stack, "New Game", open_slot_picker.bind("New Game"), buttons.is_empty()))
	for number in range(1, ManualSave.SLOT_COUNT + 1):
		if ManualSave.read_slot(number) != null:
			buttons.append(UI.button(stack, "Load Game", open_slot_picker.bind("Load Game")))
			break
	buttons.append(UI.button(stack, "Settings", show_page.bind("Settings")))
	buttons.append(UI.button(stack, "Quit Game", get_tree().quit))
	for i in range(buttons.size()):
		var button := buttons[i]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 43
		button.add_theme_font_size_override("font_size", 21)
		button.focus_neighbor_top = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(i + 1) % buttons.size()])
	UI.label(stack, "RX-07    //    SYSTEM READY", 13, UI.MUTED)
	buttons[0].grab_focus()

func build_archive(columns: HBoxContainer) -> void:
	var archive := card(columns, 1.65)
	UI.label(archive, "NOVA Archive", 32, UI.CYAN)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive.add_child(scroll)
	var records := UI.column(scroll, 14)
	records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(records, Story.INTRO, 18)
	UI.label(records, "MEMORY FRAGMENTS   /   %d OF %d" % [profile.memories.size() if profile else 0, Story.MEMORIES.size()], 19, UI.CYAN)
	if profile:
		for index in range(1, Story.MEMORIES.size() + 1):
			if profile.memories.has(index):
				UI.label(records, Story.MEMORIES[index - 1], 17)
		for ending in profile.endings:
			UI.label(records, Story.ending(ending == "secret"), 17, UI.MUTED)
	var guide := card(columns)
	UI.label(guide, "Field Guide", 28, UI.CYAN)
	UI.label(guide, "Green restores health. Blue restores energy. Purple orbs award XP. Gold adds bolts.", 17)
	UI.label(guide, "Pink salvage drops carry materials for Fabrication. Extract to bank them.", 17, UI.MUTED)
	UI.label(guide, "Shoot cargo carriers to release their crates.", 17, UI.MUTED)

func build_social(columns: HBoxContainer) -> void:
	steam_invite_buttons.clear()
	RiftSocial.connect_steam()
	RiftRelay.listen_for_steam_invites()
	var list := card(columns, 1.2)
	UI.label(list, "Friends", 30, UI.CYAN)
	UI.label(list, "Add someone you recently grouped with to compare sector times.", 16, UI.MUTED)
	var copy_notice := UI.label(list, "", 14, UI.CYAN)
	var rows := scroll_entries(list)
	for id in RiftSocial.recent_players:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var person := UI.label(row, RiftSocial.recent_players[id].name, 17)
		person.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var saved: bool = RiftSocial.rift_friends.has(id)
		UI.button(row, "Remove Friend" if saved else "Add Friend", func():
			RiftSocial.toggle_rift_friend(id)
			show_page("Social")
		, false, 34)
	UI.label(rows, "Steam Contacts", 22, UI.CYAN)
	for friend in RiftSocial.contacts():
		var row := HBoxContainer.new()
		rows.add_child(row)
		var tint := UI.CYAN if friend.priority == 0 else UI.MUTED
		var identity := UI.column(row, 2)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.label(identity, friend.name, 17, tint)
		UI.label(identity, "%s  ·  %s" % [friend.status, friend.id], 14, UI.MUTED)
		UI.button(row, "Copy ID", func():
			DisplayServer.clipboard_set(friend.id)
			copy_notice.text = "Copied %s’s Steam ID." % friend.name
		, false, 34)
		UI.button(row, "Profile", RiftSocial.open_profile.bind(friend.id), false, 34)
		if friend.priority == 0:
			var invite := UI.button(row, "Quick Invite", RiftRelay.invite_friend.bind(int(friend.id)), false, 34)
			steam_invite_buttons.append(invite)
		if not friend.saved:
			UI.button(row, "Add Friend", func():
				inventory_status = "Contact saved." if RiftSocial.save_contact(friend.id, friend.name) else "Could not save contact."
				show_page("Social")
			, false, 34)
		else:
			UI.button(row, "Remove", func():
				var removed := RiftSocial.save_contact(friend.id, "")
				inventory_status = "" if removed else "Could not remove contact."
				show_page("Social")
			, false, 34)
	if RiftSocial.contacts().is_empty():
		UI.label(rows, "No Steam contacts yet.", 16, UI.MUTED)
	var tools := card(columns, 0.8)
	UI.label(tools, "Add by Steam ID", 27, UI.CYAN)
	UI.label(tools, "Paste a friend code, Steam ID, or numeric profile link.", 16, UI.MUTED)
	var steam_id := LineEdit.new()
	steam_id.placeholder_text = "Steam ID, friend code, or profile link"
	steam_id.max_length = 160
	tools.add_child(steam_id)
	UI.button(tools, "Paste Steam ID", func():
		steam_id.text = DisplayServer.clipboard_get().strip_edges().left(steam_id.max_length)
		steam_id.grab_focus()
		steam_id.caret_column = steam_id.text.length()
	, false, 34)
	var alias := LineEdit.new()
	alias.placeholder_text = "Display name (optional)"
	alias.max_length = 40
	tools.add_child(alias)
	var notice := UI.label(tools, inventory_status, 15, UI.VIOLET)
	UI.button(tools, "Save Contact", func():
		var id := RiftSocial.resolve_contact_id(steam_id.text)
		if id.is_empty():
			notice.text = "Use a Steam ID, numeric friend code, or a numeric Steam profile link."
			return
		if RiftSocial.save_contact(id, alias.text.strip_edges() if not alias.text.strip_edges().is_empty() else id):
			inventory_status = "Contact saved."
			show_page("Social")
		else:
			notice.text = "Could not save contact."
	, false, 36)
	tools.add_child(HSeparator.new())
	UI.label(tools, RiftSocial.message, 15, UI.MUTED)
	UI.button(tools, "Refresh Steam Presence", show_page.bind("Social"), false, 36)
	UI.button(tools, "Open Party", show_page.bind("Party"), false, 36)
	refresh_steam_invites()

func refresh_steam_invites() -> void:
	for invite in steam_invite_buttons:
		if is_instance_valid(invite):
			invite.disabled = not RiftRelay.available or not RiftRelay.pending.is_empty() or RiftRelay.pending_invite != 0 or RiftRelay.room_size >= 2

func build_leaderboard(columns: HBoxContainer) -> void:
	var panel := card(columns)
	UI.label(panel, "Sector Best Times", 32, UI.CYAN)
	UI.label(panel, "Resets every 30 days  ·  %d days remaining" % RiftSocial.season_days_left(), 17, UI.MUTED)
	var selector := OptionButton.new()
	panel.add_child(selector)
	UI.style_button(selector)
	for number in range(1, Catalog.SECTORS.size() + 1):
		selector.add_item(Catalog.info(number).title, number)
	selector.select(leaderboard_sector - 1)
	selector.item_selected.connect(func(index: int):
		leaderboard_sector = selector.get_item_id(index)
		show_page("Leaderboard")
	)
	selector.grab_focus()
	var entries := scroll_entries(panel)
	var ranks := RiftSocial.leaderboard(leaderboard_sector, profile.operator_name)
	UI.label(entries, "Clear both acts and extract to record a time. Friends’ times sync when you join a group together.", 16, UI.MUTED)
	if ranks.is_empty():
		UI.label(entries, "No clear times for this sector yet.", 19)
	for index in ranks.size():
		var result: Dictionary = ranks[index]
		var time: int = result.time
		add_stat_group(entries, "%02d  %s" % [index + 1, result.name], "%02d:%02d.%03d" % [time / 60000, (time / 1000) % 60, time % 1000])

func build_online_room(columns: HBoxContainer) -> void:
	var form := card(columns)
	UI.label(form, "Start or Join a Group", 32, UI.CYAN)
	UI.label(form, "With both players connected, the leader chooses a campaign sector.", 18, UI.MUTED)
	relay_host = UI.button(form, "Create Group", RiftRelay.host_room, true)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	form.add_child(join_row)
	relay_code = LineEdit.new()
	relay_code.placeholder_text = "Friend’s room code"
	relay_code.max_length = 14
	relay_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relay_code.text_submitted.connect(RiftRelay.join_room)
	join_row.add_child(relay_code)
	relay_paste = UI.button(join_row, "Paste Code", func():
		relay_code.text = DisplayServer.clipboard_get().strip_edges().left(relay_code.max_length)
		relay_code.grab_focus()
		relay_code.caret_column = relay_code.text.length()
	)
	relay_join = UI.button(join_row, "Join Room", func(): RiftRelay.join_room(relay_code.text))
	relay_status = UI.label(form, "", 18, UI.CYAN)
	relay_deploy = UI.button(form, "Choose Co-op Sector", show_page.bind("Co-op Sectors"), true)
	relay_copy = UI.button(form, "Copy Room Code", func(): DisplayServer.clipboard_set(RiftRelay.connected_room))
	relay_leave = UI.button(form, "Leave Room", func(): RiftRelay.leave())
	UI.button(form, "Co-op Setup Guide", show_page.bind("Co-op Setup Guide"))
	refresh_online_room()
	if not relay_host.disabled:
		relay_host.grab_focus()

func refresh_online_room() -> void:
	if page == "Social":
		refresh_steam_invites()
	if page != "Party" or not is_instance_valid(relay_status):
		return
	var joined := not RiftRelay.connected_room.is_empty()
	var requesting := not RiftRelay.pending.is_empty()
	relay_host.disabled = not RiftRelay.available or joined or requesting
	relay_join.disabled = relay_host.disabled
	relay_paste.disabled = relay_join.disabled
	relay_code.editable = not joined and not requesting
	relay_deploy.visible = RiftRelay.can_deploy()
	relay_copy.visible = joined
	relay_leave.visible = joined or requesting
	relay_leave.text = "Leave Room" if joined else "Cancel Connection"
	relay_status.text = "%s   /   Code %s" % [RiftRelay.status, RiftRelay.connected_room] if joined else RiftRelay.status
	if relay_deploy.visible:
		relay_deploy.grab_focus()
	elif joined:
		relay_copy.grab_focus()
	elif requesting or get_viewport().gui_get_focus_owner() == relay_leave:
		if requesting:
			relay_leave.grab_focus()
		else:
			relay_host.grab_focus()

func open_slot_picker(mode: String) -> void:
	slot_error = ""
	new_operator_name = ""
	show_page(mode)

func build_save_slots(columns: HBoxContainer, fresh: bool) -> void:
	var slots := card(columns, 1.35)
	UI.label(slots, "Choose a Save Slot", 34, UI.CYAN)
	UI.label(slots, "Save manually at the station or from Pause." if fresh else "Choose a slot to return to its station.", 19, UI.MUTED)
	var name_field: LineEdit
	if fresh:
		UI.label(slots, "Player Name", 18, UI.CYAN)
		name_field = LineEdit.new()
		name_field.max_length = 20
		name_field.placeholder_text = "RX-07"
		name_field.text = new_operator_name
		name_field.text_changed.connect(func(value: String): new_operator_name = value)
		slots.add_child(name_field)
	var first: Button
	for number in range(1, ManualSave.SLOT_COUNT + 1):
		var data := ManualSave.read_slot(number)
		var description := "Empty"
		if data:
			description = "Station"
			if data.has_section("checkpoint"):
				var sector := clampi(int(data.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
				var level := RiftPlayer.level_for_experience(int(data.get_value("checkpoint", "experience", 0)))
				description = "%s  /  Act %d  /  Lv. %d" % [Catalog.info(sector).title, data.get_value("checkpoint", "act", 1), level]
		if not fresh and data == null:
			continue
		var button := UI.button(slots, "Slot %d   /   %s" % [number, description], choose_slot.bind(number, fresh))
		if not first:
			first = button
	if not fresh and not first:
		UI.label(slots, "No saved games yet.", 19, UI.MUTED)
	if name_field:
		name_field.grab_focus()
	elif first:
		first.grab_focus()
	if not slot_error.is_empty():
		UI.label(slots, slot_error, 18, UI.CYAN)
	portrait(card(columns))

func choose_slot(number: int, fresh: bool) -> void:
	if fresh and ManualSave.read_slot(number) != null:
		replace_slot = number
		show_page("Replace Slot")
	else:
		slot_requested.emit(number, fresh, new_operator_name if fresh else "")

func show_slot_error() -> void:
	slot_error = "That save could not be opened."
	show_page("Load Game")

func show_save_result(result: String) -> void:
	save_status.text = result

func build_workshop(columns: HBoxContainer) -> void:
	var fitting := card(columns)
	UI.label(fitting, "RX-07 Upgrade Sockets", 26, UI.CYAN)
	var body := EquipmentBody.new()
	fitting.add_child(body)
	body.install(profile, inventory_slot, select_inventory_slot, true)
	var store := card(columns, 1.15)
	UI.label(store, "Core Enhancements  /  " + String(Profile.GEAR_SLOTS[inventory_slot]), 29, UI.CYAN)
	UI.label(store, "%d Core Shards  ·  Player Lv. %d" % [profile.core_shards, profile.player_level()], 17, Color("ffd079"))
	var rows := scroll_entries(store)
	for upgrade in profile.all_upgrades():
		if String(upgrade.get("slot", Profile.UPGRADE_SLOTS.get(upgrade.id, ""))) != inventory_slot:
			continue
		var installed: int = profile.rank(upgrade.id)
		var maxed: bool = installed >= upgrade.prices.size()
		var tier: int = upgrade.get("rarity", 0)
		var box := UI.equipment_card(Profile.RARITY_COLORS[tier])
		rows.add_child(box)
		var row := UI.column(box, 3)
		UI.label(row, "%s  ·  %s" % [upgrade.name, Profile.RARITY_NAMES[tier]], 18, Profile.RARITY_COLORS[tier])
		UI.label(row, String(upgrade.effects[mini(installed, upgrade.effects.size() - 1)]), 15, UI.MUTED)
		var cost: int = 0 if maxed else upgrade.prices[installed]
		var required: int = profile.enhancement_level(upgrade.id, installed)
		var button := UI.button(row, "Installed" if maxed else ("Install  /  %d shards  ·  Lv. %d" % [cost, required]), purchase_upgrade.bind(upgrade.id), false, 33)
		button.disabled = maxed or profile.core_shards < cost or profile.player_level() < required
	if not shop_status.is_empty():
		UI.label(store, shop_status, 15, UI.VIOLET)

func build_shop(columns: HBoxContainer) -> void:
	var card_body := card(columns)
	UI.label(card_body, "Station Shop", 32, UI.CYAN)
	UI.label(card_body, "Supplies and materials  ·  %d bolts" % profile.credits, 17, Color("ffd079"))
	var entries := scroll_entries(card_body)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", UI.ITEM_GAP)
	grid.add_theme_constant_override("v_separation", UI.ITEM_GAP)
	entries.add_child(grid)
	var info := card(columns, 0.68)
	var title := UI.label(info, "", 27, UI.CYAN)
	var rarity := UI.label(info, "", 17)
	var description := UI.label(info, "", 18, UI.MUTED)
	var buy := UI.button(info, "Purchase", func():
		inventory_status = profile.buy_supply(focused_item)
		show_page("Shop")
	)
	var reveal := func(id: String):
		focused_item = id
		var item: Dictionary = profile.stock[id]
		title.text = item.name
		rarity.text = Profile.RARITY_NAMES[item.rarity]
		rarity.add_theme_color_override("font_color", Profile.RARITY_COLORS[item.rarity])
		description.text = item.detail
		buy.text = "Buy  /  %d bolts" % item.price
		buy.disabled = profile.credits < item.price
	var first := true
	var selected: String = focused_item if profile.stock.has(focused_item) else profile.stock.keys()[0]
	for id in profile.stock:
		var item: Dictionary = profile.stock[id]
		var tile := UI.item_tile(grid, EquipmentIcons.icon(item.icon, item.icon), Profile.RARITY_COLORS[item.rarity], item.rarity, "%d" % item.price, func():
			reveal.call(id)
			if not buy.disabled:
				buy.grab_focus()
		)
		tile.tooltip_text = item.name
		tile.focus_entered.connect(reveal.bind(id))
		if first or id == selected:
			tile.grab_focus()
		first = false
	reveal.call(selected)
	if not inventory_status.is_empty():
		UI.label(info, inventory_status, 16, UI.VIOLET)

func build_challenges(columns: HBoxContainer) -> void:
	var sectors := card(columns, 0.8)
	UI.label(sectors, "Unlocked sectors", 25, UI.CYAN)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	sectors.add_child(scroll)
	var list := UI.column(scroll, 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := card(columns, 1.65)
	var available: int = profile.unlocked_sector if profile else 1
	challenge_sector = clampi(challenge_sector, 1, available)
	var group := ButtonGroup.new()
	for number in range(1, available + 1):
		var label := "%02d   %s" % [number, Catalog.info(number).title]
		var option := UI.button(list, label, select_challenge_sector.bind(number, details))
		option.toggle_mode = true
		option.button_group = group
		option.set_pressed_no_signal(number == challenge_sector)
		if number == challenge_sector:
			option.grab_focus()
	select_challenge_sector(challenge_sector, details)

func select_challenge_sector(number: int, details: VBoxContainer) -> void:
	challenge_sector = number
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	UI.label(details, Catalog.info(number).title, 30, UI.CYAN)
	for tier in range(Profile.CHALLENGES.size()):
		var data: Dictionary = Profile.CHALLENGES[tier]
		var done: bool = profile != null and profile.completed_challenges.has(Profile.challenge_key(number, tier))
		details.add_child(HSeparator.new())
		var line := HBoxContainer.new()
		details.add_child(line)
		var title := UI.label(line, "Tier %s  /  %s" % [["I", "II", "III"][tier], data.name], 21)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		var status := UI.label(line, "COMPLETE" if done else "OPEN", 17, Color("91f7a1") if done else UI.MUTED)
		status.autowrap_mode = TextServer.AUTOWRAP_OFF
		UI.label(details, data.objective, 17, UI.MUTED)
		var amount := Profile.challenge_credits(number, tier)
		UI.label(details, "%s  %d bolts  ·  1 reserve life" % ["Earned" if done else "Reward", amount], 17, Color("ffe28e"))
	var reserve: int = profile.reserve_lives if profile else 0
	details.add_child(HSeparator.new())
	UI.label(details, "Reserve lives: %d. Used automatically when you lose your last life." % reserve, 16, UI.MUTED)

func purchase_upgrade(id: String) -> void:
	shop_status = profile.buy(id)
	show_page("Upgrades")

func build_sector(columns: HBoxContainer) -> void:
	var route := card(columns, 1.4)
	UI.label(route, "Deployment", 38, UI.CYAN)
	var sector_title: String = Catalog.info(saved_sector if can_load else 1).title
	UI.label(route, "%s  /  Act %s" % [sector_title, "II" if can_load and saved_act == 2 else "I"], 23, UI.WHITE)
	route.add_child(HSeparator.new())
	UI.label(route, "NOVA  /  " + Story.briefing(saved_sector if can_load else 1), 18, UI.MUTED)
	if not RiftRelay.connected_room.is_empty():
		UI.label(route, "Your group leader chooses the next sector.", 18, UI.MUTED)
		if RiftRelay.can_deploy():
			UI.button(route, "Choose Co-op Sector", show_page.bind("Co-op Sectors"), true).grab_focus()
	elif can_load:
		UI.label(route, "RX-07  /  Level %d" % saved_level, 17, UI.MUTED)
		UI.button(route, "Continue run  ›" if at_sector_start else "Resume checkpoint  ›", func(): load_requested.emit(), true).grab_focus()
		if run_cleared_through > 0:
			UI.button(route, "Level Select", show_page.bind("Level select"))
		UI.button(route, "Start a new run", show_page.bind("New run"))
	else:
		UI.button(route, "Deploy to Neon Factory  ›", deploy, true).grab_focus()
	var equipment := card(columns)
	UI.label(equipment, "Co-op", 24, UI.CYAN)
	UI.button(equipment, "Start a Group" if RiftRelay.connected_room.is_empty() else "Manage Group", func():
		party_from_deploy = true
		show_page("Party")
	)
	UI.label(equipment, "Standard Equipment", 24, UI.CYAN)
	UI.label(equipment, "Buster Cannon\nEnergy Blade\nDash Module")
	portrait(equipment)

func build_level_select(columns: HBoxContainer) -> void:
	var panel := card(columns)
	var cooperative := page == "Co-op Sectors"
	UI.label(panel, "Co-op Campaign" if cooperative else "Level Select", 34, UI.CYAN)
	UI.label(panel, "The leader selects a sector. Complete both acts together to unlock the next sector." if cooperative else "Choose a sector unlocked in this run. Changing sectors starts at Act I with your current gear and remaining lives.", 18, UI.MUTED)
	if not deploy_error.is_empty():
		UI.label(panel, deploy_error, 17, Color("ff9e95"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	panel.add_child(scroll)
	var entries := GridContainer.new()
	entries.columns = 3
	entries.add_theme_constant_override("h_separation", 15)
	entries.add_theme_constant_override("v_separation", 15)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entries)
	var choices: Array[Button] = []
	var last_sector := RiftRelay.unlocked_sector if cooperative else run_cleared_through + 1
	for number in range(1, mini(last_sector, Catalog.SECTORS.size()) + 1):
		var state := "Act I → Act II" if cooperative else ("Current deployment" if number == saved_sector else ("Cleared" if number <= run_cleared_through else "Unlocked"))
		var choice := sector_card(entries, number, state)
		choices.append(choice)
		if number == saved_sector:
			choice.grab_focus()
	for blank in range(choices.size(), entries.columns):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entries.add_child(spacer)
	for index in range(choices.size()):
		if index + entries.columns < choices.size():
			choices[index].focus_neighbor_bottom = choices[index].get_path_to(choices[index + entries.columns])
		if index >= entries.columns:
			choices[index].focus_neighbor_top = choices[index].get_path_to(choices[index - entries.columns])

func sector_card(entries: GridContainer, number: int, state: String) -> Button:
	var sector := Catalog.info(number)
	var accent := Color(sector.color)
	var choice := UI.button(entries, "%02d  %s" % [number, sector.title], func(): sector_requested.emit(number))
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size.y = 166.0
	choice.clip_contents = true
	choice.tooltip_text = "%s · %s" % [sector.title, state]
	var art := TextureRect.new()
	var art_path := "res://assets/campaign/%s/panorama.png" % sector.id
	if number == 1:
		art_path = "res://assets/neon_factory/factory_panorama.png"
	elif number == 2:
		art_path = "res://assets/machine_jungle/jungle_panorama.png"
	art.texture = load(art_path) as Texture2D
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	choice.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.43, 0.83, 1.0])
	gradient.colors = PackedColorArray([Color("13223522"), Color("101b2a20"), Color("0b1525ed"), Color("071222")])
	var shade_map := GradientTexture2D.new()
	shade_map.gradient = gradient
	shade_map.fill_from = Vector2.ZERO
	shade_map.fill_to = Vector2.DOWN
	var shade := TextureRect.new()
	shade.texture = shade_map
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := UI.label(choice, "%02d   %s" % [number, sector.title], 22, UI.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_left = 14
	title.offset_bottom = -29
	title.offset_top = -63
	var subtitle := UI.label(choice, state, 15, accent.lerp(Color.WHITE, 0.38))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left = 14
	subtitle.offset_bottom = -8
	subtitle.offset_top = -31
	var outline := Panel.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice.add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var refresh := func():
		var highlight := choice.is_hovered() or choice.has_focus()
		art.modulate = Color.WHITE if highlight else Color(0.71, 0.78, 0.88)
		title.modulate = UI.VIOLET if highlight else Color.WHITE
		outline.add_theme_stylebox_override("panel", UI.frame(Color.TRANSPARENT, Color("416178"), 1))
	choice.mouse_entered.connect(refresh)
	choice.mouse_exited.connect(refresh)
	choice.focus_entered.connect(refresh)
	choice.focus_exited.connect(refresh)
	refresh.call()
	return choice

func build_fabrication(columns: HBoxContainer) -> void:
	var slots := card(columns)
	var list := card(columns, 1.2)
	UI.label(slots, "RX-07 Equipment", 29, UI.CYAN)
	var body := EquipmentBody.new()
	slots.add_child(body)
	body.install(profile, inventory_slot, select_inventory_slot)
	UI.label(slots, "Equipped gear is lost when a run ends in death.", 16, UI.MUTED)
	UI.label(list, "Fabrication  /  " + String(Profile.GEAR_SLOTS[inventory_slot]), 33, UI.CYAN)
	UI.label(list, "PLAYER LV. %d" % profile.player_level(), 18, Color("ffd079"))
	UI.label(list, "Review a blueprint to check its materials.", 17, UI.MUTED)
	var items: Array[String] = []
	for id in Profile.GEAR:
		if profile.blueprints.has(id) and Profile.GEAR[id].slot == inventory_slot:
			items.append(id)
	build_item_grid(list, items, true, 8)
	if not inventory_status.is_empty():
		UI.label(list, inventory_status, 16, UI.VIOLET)

func build_item_grid(parent: VBoxContainer, items: Array[String], blueprints: bool, max_columns: int) -> void:
	if items.is_empty():
		UI.label(parent, "Storage is empty. Fabricated gear will appear here." if page == "Storage" else ("No blueprints discovered for this slot. Recover them during a deployment and extract." if blueprints else "Fabricate gear at the Workshop to fill your loadout."), 16, UI.MUTED)
		return

	var entries := scroll_entries(parent)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", UI.ITEM_GAP)
	grid.add_theme_constant_override("v_separation", UI.ITEM_GAP)
	entries.add_child(grid)

	var detail_card := UI.equipment_card(UI.CYAN)
	parent.add_child(detail_card)
	var details := UI.column(detail_card, 3)
	var title := UI.label(details, "", 18)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var state := UI.label(details, "", 14)
	var perk := UI.label(details, "", 15, UI.MUTED)
	var action := UI.button(details, "Inspect Blueprint" if blueprints else "Equip", func():
		if blueprints:
			inspect_shop_item(focused_item)
		else:
			inventory_status = profile.move_gear(focused_item)
			show_page(page)
	, false, 35)

	var reveal := func(id: String):
		focused_item = id
		var item: Dictionary = Profile.GEAR[id]
		var owned: String = profile.gear.get(id, "")
		var status := item_status(id, blueprints)
		title.text = item.name
		title.tooltip_text = item.name
		perk.text = item.perk
		state.text = "%s  /  %s  /  %s" % [Profile.RARITY_NAMES[item.rarity], Profile.GEAR_SLOTS[item.slot], status]
		state.add_theme_color_override("font_color", Profile.RARITY_COLORS[item.rarity])
		if blueprints:
			action.text = "Inspect Blueprint" if owned.is_empty() else "Owned"
		else:
			var equipped: String = profile.equipped_for(item.slot)
			action.text = "Stow" if owned == "equipped" else ("Equip" if equipped.is_empty() else "Replace " + String(Profile.GEAR[equipped].name))
		action.disabled = blueprints and not owned.is_empty()

	var initial := focused_item if focused_item in items else items[0]
	var tiles: Array[Button] = []
	for id in items:
		var item: Dictionary = Profile.GEAR[id]
		var tint: Color = Profile.RARITY_COLORS[item.rarity]
		var texture := EquipmentIcons.icon(id, item.slot)
		var tile := UI.item_tile(grid, texture, tint, item.rarity, item_tile_caption(id, blueprints), func():
			reveal.call(id)
			if not action.disabled:
				action.grab_focus()
		)
		tile.tooltip_text = "%s
%s" % [item.name, item.perk]
		tile.focus_entered.connect(reveal.bind(id))
		tiles.append(tile)
	var fit_columns := func():
		var width := entries.size.x
		var columns := clampi(floori((width + UI.ITEM_GAP) / (UI.ITEM_SIZE + UI.ITEM_GAP)), 1, max_columns)
		grid.columns = columns
		for index in tiles.size():
			var tile := tiles[index]
			tile.focus_neighbor_bottom = tile.get_path_to(action) if index + columns >= tiles.size() else NodePath()
	entries.resized.connect(fit_columns)
	fit_columns.call_deferred()
	for tile in tiles:
		tile.focus_entered.connect(func(): action.focus_neighbor_top = action.get_path_to(tile))
	action.focus_neighbor_top = action.get_path_to(tiles[items.find(initial)])
	reveal.call(initial)
	if page == "Storage":
		tiles[items.find(initial)].grab_focus()

func item_tile_caption(id: String, blueprints: bool) -> String:
	var status := item_status(id, blueprints)
	if status == "Blueprint" and Profile.GEAR[id].has("sector"):
		return "S%02d" % Profile.GEAR[id].sector
	return status

func item_status(id: String, blueprints: bool) -> String:
	var owned: String = profile.gear.get(id, "")
	match owned:
		"equipped": return "Equipped"
		"stored": return "Stowed"
		"carried": return "Carried"
	if blueprints:
		var required := Profile.recipe_level(id)
		return "Lv. %d" % required if profile.player_level() < required else "Blueprint"
	return ""

func scroll_entries(parent: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	parent.add_child(scroll)
	var entries := UI.column(scroll, 10)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return entries

func item_card(parent: VBoxContainer, id: String) -> VBoxContainer:
	var item: Dictionary = Profile.GEAR[id]
	var tint: Color = Profile.RARITY_COLORS[item.rarity]
	var panel := UI.equipment_card(tint)
	parent.add_child(panel)
	var stack := UI.column(panel, 6)
	var head := HBoxContainer.new()
	stack.add_child(head)
	head.add_theme_constant_override("separation", 9)
	var icon := TextureRect.new()
	icon.texture = EquipmentIcons.icon(id, item.slot)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var title := UI.label(head, item.name, 18, UI.WHITE)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tag := PanelContainer.new()
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", UI.frame(tint.darkened(0.81), tint.darkened(0.36), 1))
	head.add_child(tag)
	UI.label(tag, Profile.RARITY_NAMES[item.rarity], 14, tint).autowrap_mode = TextServer.AUTOWRAP_OFF
	UI.label(stack, item.perk, 16, UI.MUTED)
	return stack

func select_inventory_slot(slot: String) -> void:
	shop_item = ""
	focused_item = ""
	inventory_slot = slot
	show_page(page)

func inspect_shop_item(id: String) -> void:
	shop_item = id
	show_page("Craft Item")

func build_purchase(columns: HBoxContainer) -> void:
	var form := card(columns, 1.12)
	UI.label(form, "Review Blueprint", 32, UI.CYAN)
	item_card(form, shop_item)
	UI.label(form, "PLAYER LEVEL  %d / %d" % [profile.player_level(), Profile.recipe_level(shop_item)], 17, UI.CYAN)
	var bill: Dictionary = profile.recipe_materials(shop_item)
	for material in bill:
		var available := int(profile.materials.get(material, 0))
		UI.label(form, "%s  %d / %d" % [Materials.label(material), available, bill[material]], 17,
			UI.WHITE if available >= int(bill[material]) else UI.VIOLET)
	var restriction: String = profile.craft_limit(shop_item)
	if not restriction.is_empty():
		UI.label(form, restriction, 17, UI.VIOLET)
	UI.button(form, "Fabricate", confirm_gear_purchase if restriction.is_empty() else Callable(), true)
	UI.button(form, "Cancel", show_page.bind("Fabrication")).grab_focus()
	portrait(card(columns))

func confirm_gear_purchase() -> void:
	inventory_status = profile.craft(shop_item)
	show_page("Fabrication")

func build_storage(columns: HBoxContainer) -> void:
	var fitted := card(columns, 0.92)
	UI.label(fitted, "RX-07 Equipment", 28, UI.CYAN)
	var body := EquipmentBody.new()
	fitted.add_child(body)
	body.install(profile, storage_filter, func(slot: String):
		storage_filter = slot
		focused_item = profile.equipped_for(slot)
		open_equipment_view("Gear")
	)
	var actor := body.preview_actor
	EquipmentStats.apply(actor, profile)
	actor.gain_experience(saved_experience, false)
	add_stat_group(fitted, "DMG", "%.1f buster  /  %.1f blade" % [actor.buster_power(), actor.buster_power() * actor.melee_multiplier])
	add_stat_group(fitted, "DEF", "%.1f%% reduction" % (100.0 - actor.mitigate_damage(100.0)))
	add_stat_group(fitted, "ENG  /  HP", "%.0f energy  /  %.0f max health" % [actor.max_energy, actor.max_health])
	add_stat_group(fitted, "SPD", "%.1f run  /  %.1f dash" % [actor.move_speed, actor.dash_speed])

	var equipment := card(columns, 1.15)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	equipment.add_child(tabs)
	for section in ["Gear", "Boss Abilities"]:
		var tab := UI.button(tabs, section, open_equipment_view.bind(section), false, 35)
		if section == equipment_view:
			tab.add_theme_color_override("font_color", UI.CYAN)
			tab.grab_focus()
	match equipment_view:
		"Gear":
			build_storage_grid(equipment)
		"Boss Abilities":
			build_boss_abilities(equipment)

	if not inventory_status.is_empty():
		UI.label(equipment, inventory_status, 16, UI.VIOLET)

func storage_items() -> Dictionary:
	var items := {}
	for id in Profile.GEAR:
		var gear: Dictionary = Profile.GEAR[id]
		if profile.gear.has(id):
			items[id] = {"kind": "Equipment", "name": gear.name, "slot": gear.slot, "icon": EquipmentIcons.icon(id, gear.slot),
				"rarity": gear.rarity, "detail": gear.perk, "badge": item_status(id, false)}
		if profile.blueprint_items.has(id):
			items["blueprint/" + id] = {"kind": "Blueprints", "name": gear.name + " Blueprint", "slot": "", "icon": EquipmentIcons.icon(id, gear.slot),
				"rarity": gear.rarity, "detail": "Learn this blueprint to unlock its recipe in Crafting.", "badge": "Recipe", "id": id}
	for upgrade in profile.all_upgrades():
		var rank: int = profile.rank(upgrade.id)
		if rank == 0:
			continue
		var slot := String(upgrade.get("slot", Profile.UPGRADE_SLOTS.get(upgrade.id, "")))
		items[upgrade.id] = {"kind": "Augments", "name": upgrade.name, "slot": slot, "icon": EquipmentIcons.icon(slot, slot),
			"rarity": upgrade.get("rarity", 0), "detail": upgrade.effects[rank - 1], "badge": "Active"}
	for id in Profile.stock:
		var item: Dictionary = Profile.stock[id]
		var material: bool = item.has("material")
		var quantity := int(profile.materials.get(item.material, 0)) if material else int(profile.inventory.get(id, 0))
		if quantity > 0:
			items[id] = {"kind": "Materials" if material else "Supplies", "name": item.name, "slot": "", "icon": EquipmentIcons.icon(item.icon, item.icon),
				"rarity": item.rarity, "detail": "Used to fabricate equipment." if material else item.detail, "badge": "×%d" % quantity}
	return items

func build_storage_grid(parent: VBoxContainer) -> void:
	var toolbar := HBoxContainer.new()
	parent.add_child(toolbar)
	var filter := OptionButton.new()
	toolbar.add_child(filter)
	UI.style_button(filter)
	var categories := ["All", "Equipment", "Augments", "Supplies", "Blueprints", "Materials"]
	if Profile.GEAR_SLOTS.has(storage_filter):
		categories.append(storage_filter)
	for category in categories:
		filter.add_item(Profile.GEAR_SLOTS.get(category, category))
	filter.select(categories.find(storage_filter))
	filter.item_selected.connect(func(index: int):
		storage_filter = categories[index]
		focused_item = ""
		show_page("Storage")
	)
	var capacity := UI.label(toolbar, "%d / %d stowed" % [profile.stored_count(), profile.storage_capacity()], 17, Color("ffd079"))
	capacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capacity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var entries := scroll_entries(parent)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", UI.ITEM_GAP)
	grid.add_theme_constant_override("v_separation", UI.ITEM_GAP)
	entries.add_child(grid)
	var detail_card := UI.equipment_card(UI.CYAN)
	parent.add_child(detail_card)
	var detail := UI.column(detail_card, 4)
	var title := UI.label(detail, "Stored Items", 20, UI.CYAN)
	var description := UI.label(detail, "Select an item or choose a socket to filter gear.", 16, UI.MUTED)
	var action := UI.button(detail, "", func(): apply_storage_item(focused_item), false, 34)
	action.hide()
	var items := storage_items()
	var reveal := func(id: String):
		var item: Dictionary = items[id]
		focused_item = id
		title.text = "%s  ·  %s" % [item.name, Profile.RARITY_NAMES[item.rarity]]
		title.add_theme_color_override("font_color", Profile.RARITY_COLORS[item.rarity])
		description.text = item.detail
		action.visible = item.kind in ["Equipment", "Blueprints"]
		if item.kind == "Equipment":
			var current: String = profile.equipped_for(item.slot)
			action.text = "Stow" if id == current else ("Equip" if current.is_empty() else "Replace " + String(Profile.GEAR[current].name))
		elif item.kind == "Blueprints":
			action.text = "Learn Blueprint"
		elif item.kind == "Supplies":
			description.text += "  ·  Choose a direction below to assign one."
	var tiles := {}
	for id in items:
		var item: Dictionary = items[id]
		if storage_filter not in ["All", item.kind, item.slot]:
			continue
		var tile := UI.item_tile(grid, item.icon, Profile.RARITY_COLORS[item.rarity], item.rarity, item.badge, func():
			reveal.call(id)
			if action.visible:
				action.grab_focus()
		)
		tile.tooltip_text = item.name
		tile.focus_entered.connect(reveal.bind(id))
		tiles[id] = tile
	if tiles.is_empty():
		focused_item = ""
		UI.label(entries, "No items in this category.", 17, UI.MUTED)
	else:
		var id: String = focused_item if tiles.has(focused_item) else tiles.keys()[0]
		reveal.call(id)
		tiles[id].grab_focus()
		var fit := func():
			grid.columns = clampi(floori((entries.size.x + UI.ITEM_GAP) / (UI.ITEM_SIZE + UI.ITEM_GAP)), 1, 9)
		entries.resized.connect(fit)
		fit.call_deferred()
	build_quick_assignments(parent)

func apply_storage_item(id: String) -> void:
	if id.begins_with("blueprint/"):
		inventory_status = profile.learn_blueprint(id.trim_prefix("blueprint/"))
	elif profile.gear.has(id):
		inventory_status = profile.move_gear(id)
	show_page("Storage")

func build_quick_assignments(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.ITEM_GAP)
	parent.add_child(row)
	for index in 4:
		var stack: Dictionary = profile.quick_slots[index]
		var id: String = stack.get("id", "")
		var icon := EquipmentIcons.icon("utility", "utility") if id.is_empty() else EquipmentIcons.icon(profile.stock[id].icon, profile.stock[id].icon)
		var direction: String = ["↑", "←", "→", "↓"][index]
		var button := UI.item_tile(row, icon, UI.CYAN, 0, direction, func():
			if Profile.stock.has(focused_item) and not Profile.stock[focused_item].has("material"):
				inventory_status = profile.assign_quick(index, focused_item)
			else:
				inventory_status = "Select a supply to assign."
			show_page("Storage")
		)
		button.tooltip_text = "Assign supply to %s" % direction if id.is_empty() else "%s  ·  %s" % [direction, profile.stock[id].name]
	var clear := OptionButton.new()
	row.add_child(clear)
	clear.add_item("Clear quick slot")
	clear.set_item_disabled(0, true)
	for index in 4:
		clear.add_item(["Up", "Left", "Right", "Down"][index])
		clear.set_item_disabled(index + 1, int(profile.quick_slots[index].get("count", 0)) <= 0)
	clear.item_selected.connect(func(index: int):
		inventory_status = profile.clear_quick(index - 1)
		show_page("Storage")
	)

func add_stat_group(parent: VBoxContainer, category: String, values: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := UI.label(row, category, 16, UI.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reading := UI.label(row, values, 16, UI.WHITE)
	reading.autowrap_mode = TextServer.AUTOWRAP_OFF
	reading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func open_equipment_view(section: String) -> void:
	equipment_view = section
	show_page("Storage")

func build_boss_abilities(parent: VBoxContainer) -> void:
	var unlocked: Array = run_unlocks.filter(func(id): return not Catalog.weapon(String(id)).is_empty())
	if unlocked.is_empty():
		UI.label(parent, "Defeat sector bosses to unlock their abilities for this run.", 17, UI.MUTED)
		return
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", UI.ITEM_GAP)
	grid.add_theme_constant_override("v_separation", UI.ITEM_GAP)
	parent.add_child(grid)
	var panel := UI.equipment_card(UI.CYAN)
	parent.add_child(panel)
	var details := UI.column(panel, 8)
	var title := UI.label(details, "", 24, UI.CYAN)
	var origin := UI.label(details, "", 16, UI.MUTED)
	var description := UI.label(details, "", 18)
	var energy := UI.label(details, "", 16, UI.MUTED)
	UI.label(details, "Use LB / RB in a mission to switch between unlocked abilities.", 16, UI.MUTED)
	var reveal := func(id: String):
		var info := Catalog.weapon(id)
		title.text = info.reward_name
		title.add_theme_color_override("font_color", Color(info.color))
		origin.text = "Unlocked in " + String(info.title)
		description.text = Catalog.WEAPON_EFFECTS[id]
		energy.text = "Base energy cost   %d per shot  /  %d charged" % [8, 36] if id == "magma_breaker" else "Base energy cost   7 per shot  /  30 charged"
	for id in unlocked:
		var info := Catalog.weapon(id)
		var tile := UI.item_tile(grid, EquipmentIcons.icon("arm", "arm"), Color(info.color), 2, "S%02d" % (Catalog.SECTORS.find(info) + 1), reveal.bind(id))
		tile.tooltip_text = info.reward_name
		tile.focus_entered.connect(reveal.bind(id))
	reveal.call(unlocked[0])

func build_info(columns: HBoxContainer, title: String, description: String) -> void:
	var info := card(columns, 1.25)
	UI.label(info, title, 30, UI.CYAN)
	UI.label(info, description, 19)
	portrait(card(columns))

func deploy() -> void:
	start_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if station_panel and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var step := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		var tabs := station_tabs().keys()
		if not tabs.is_empty():
			get_viewport().set_input_as_handled()
			show_page(tabs[posmod(tabs.find(page) + step, tabs.size())])
			return
		if page == "Storage":
			var views := ["Gear", "Boss Abilities"]
			get_viewport().set_input_as_handled()
			open_equipment_view(views[posmod(views.find(equipment_view) + step, views.size())])
			return
	if event.is_action_pressed("ui_cancel") and page != "Title":
		RiftAudio.play_effect(&"menu_confirm")
		leave_page()
		get_viewport().set_input_as_handled()
