class_name RiftTitleMenu
extends Control

signal operator_deleted(slot: int)
signal blueprint_drop_requested(id: String)
signal start_requested
signal load_requested
signal hub_requested
signal station_closed
signal sector_requested(number: int, difficulty: int)
signal slot_requested(number: int, fresh: bool, operator_name: String)
signal save_requested
signal profile_reset_requested
signal cloud_save_requested
signal online_setup_finished
signal username_changed
signal finish_purchase_requested(id: String)

var active_slot := 0
var developer_session := false
var replace_slot := 0
var displayed_operator := 1
var delete_return_page := "New Game"
var slot_error := ""
var sign_in_email_hint := ""
var directory_return_page := ""
var checking_cloud_save := false
var save_status: Label
var relay_status: Label
var relay_code: LineEdit
var relay_host: Button
var relay_join: Button
var relay_rejoin: Button
var relay_paste: Button
var relay_deploy: Button
var relay_copy: Button
var relay_leave: Button

var can_load := false
var saved_sector := 1
var saved_act := 1
var saved_difficulty := 0
var saved_level := 1
var saved_experience := 0
var at_sector_start := false
var run_unlocks: Array = []
var profile
var shop_status := ""
var shop_category := "All Items"
var enhancement_focus := ""
const SHOP_FILTERS := {"All Items": "visor", "Supplies": "frame", "Buffs": "utility", "Materials": "core"}
var challenge_sector := 1
var selected_sector := 1
var selected_difficulty := 0
var archive_sector := 1
var archive_loot_mode := 0
var tutorial_topic := 0
var pending_blueprint := ""
var social_contact := ""
var social_filter := 0
var notifications_tab: Button
var inventory_slot := ""
var inventory_status := ""
var shop_item := ""
var focused_item := ""
var item_actions: Control
var item_origin: Button
var navigation_state := {}
var menu_body: Control
var station_panel := false
var deploy_error := ""

const SocialPanel := preload("res://scripts/social_panel.gd")
const CoopSetup := preload("res://scripts/coop_setup.gd")
const Story := preload("res://scripts/rift_story.gd")
const FieldManual := preload("res://scripts/field_manual.gd")
const EquipmentDisplay := preload("res://scripts/equipment_display.gd")
const EquipmentStats := preload("res://scripts/equipment_stats.gd")
const UI := preload("res://scripts/rift_ui.gd")
const SkinKit := preload("res://scripts/operator_skins.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const MissionResults := preload("res://scripts/mission_complete.gd")
var account
const TalentTree := preload("res://scripts/talent_tree.gd")
const ManualSave := preload("res://scripts/manual_save_session.gd")
const EquipmentBody := preload("res://scripts/equipment_body.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")

var equipment_slot := ""
var party_from_deploy := false
var layout: VBoxContainer
var page := "Title"
var hub_tip: Control
var tip_focus: Control
var tip_station := ""
const HUB_TIPS := {
	"Sector select": ["Deploy", "Resume a run or start a mission. Use Start a Group to bring a friend."],
	"Shop": ["Shop", "Spend Bolts here. Recovery items restore health or energy, buffs briefly boost your stats, and materials are used to craft gear."],
	"Fabrication": ["Crafting", "Use materials to craft gear from learned blueprints. Spend Core Shards on permanent talents in Core Ascension."],
	"Upgrades": ["Core Ascension", "These upgrades survive reconstruction, RX-07. Spend Core Shards to install and rank up talents. Install one talent in each tier to reach the next, all the way to your branch's capstone."],
	"Save Game": ["System / Save", "Save your progress manually here. Settings is on the next tab."],
	"Gear": ["Operator", "Equip gear and check your operator's stats. In Storage, stow items, learn blueprints, and assign supplies to the D-pad."],
	"Player Profile": ["Profile", "Check your career progress, preview cosmetics, and manage your online account here."],
	"Social": ["Social", "Find friends by username, send private messages, and check requests and game invites in Notifications."],
	"Challenges": ["Challenges", "Each sector gets a fresh set of challenges at local midnight. Clear all five before the reset for bonus Core Shards."],
	"Collection": ["NOVA Archive", "Read the story fragments and endings you’ve unlocked, or check the field guide."],
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	RiftRelay.changed.connect(refresh_online_room)
	RiftSocial.invites_changed.connect(update_social_tabs)
	RiftRelay.directory.changed.connect(update_social_tabs)
	RiftSocial.whispers_changed.connect(func(_id): update_social_tabs.call_deferred())
	show_page("Title")

func show_page(next: String) -> void:
	remember_navigation()
	item_actions = null
	item_origin = null
	hub_tip = null
	tip_focus = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if next == "Hub":
		hub_requested.emit()
		return
	if next == "Replace Slot" and ManualSave.read_slot(replace_slot) == null:
		slot_requested.emit(replace_slot, true, "")
		return
	page = next
	notifications_tab = null
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
		margins.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 17)
	menu_body = margins
	layout = UI.column(margins, 9)
	var header := HBoxContainer.new()
	layout.add_child(header)
	if station_panel:
		build_station_header(header)
	else:
		var logo := UI.label(header, "RIFTCORE", 42, UI.CYAN)
		logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var section_title := "OPERATOR ROSTER" if page in ["New Game", "Load Game"] else "SAVE CONFLICT" if page == "Saves" else page.to_upper()
		var section := UI.label(header, section_title, 18, UI.MUTED)
		section.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout.add_child(HSeparator.new())
	var tabs := station_tabs()
	var selected_tab: Button
	if not tabs.is_empty():
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 8)
		layout.add_child(strip)
		for tab_page in tabs:
			var label: String = tabs[tab_page]
			var button := UI.button(strip, label, show_page.bind(tab_page), false, 35)
			if page == tab_page:
				button.add_theme_color_override("font_color", UI.CYAN)
				selected_tab = button
			if tab_page == "Notifications":
				notifications_tab = button
		update_social_tabs()
		var hint := UI.label(strip, "LB / RB   Switch tab", 14, UI.MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	match page:
		"Set up Player Profile":
			SocialPanel.build_startup_choices(self, columns)
		"Create Account", "Sign In":
			SocialPanel.build_directory_account(self, columns, page == "Create Account")
		"Offline Setup", "Player Profile":
			build_player_account(columns)
		"Save Reset Error":
			var reset := card(columns)
			UI.label(reset, "Save reset could not finish", 30, UI.CYAN)
			UI.label(reset, "Close other copies of RIFTCORE and reopen the game to retry.", 18, UI.MUTED)
			UI.button(reset, "Quit Game", RiftRelay.quit_game, true).grab_focus()
		"Delete Profile":
			var form := card(columns)
			UI.label(form, "Reset operator progress?", 32, UI.CYAN)
			UI.label(form, "This clears all three operators and saved progression for this profile. Your RIFTCORE account, username, and friends stay intact.", 20, UI.MUTED)
			UI.button(form, "Keep Progress", show_page.bind("Player Profile"), true).grab_focus()
			UI.button(form, "Reset Operator Progress", profile_reset_requested.emit)
			save_status = UI.label(form, "", 17, UI.VIOLET)
		"Saves":
			build_profile_saves(columns)
		"New Game", "Load Game", "Operators":
			build_save_slots(columns)
		"Delete Operator":
			var form := card(columns)
			var saved := ManualSave.read_slot(displayed_operator)
			if saved:
				UI.label(form, "Delete %s?" % operator_name(saved), 32, UI.CYAN)
				UI.label(form, "This permanently deletes Operator %02d and all progress saved in this slot." % displayed_operator, 19, UI.MUTED)
				UI.button(form, "Cancel", show_page.bind(delete_return_page), true).grab_focus()
				UI.button(form, "Delete Operator", delete_selected_operator)
		"Replace Slot":
			var form := card(columns)
			UI.label(form, "Replace Operator %02d?" % replace_slot, 32, UI.CYAN)
			UI.label(form, "Your next manual save will replace this operator’s saved progress.", 19, UI.MUTED)
			UI.button(form, "Keep Existing Operator", show_page.bind("New Game"), true).grab_focus()
			UI.button(form, "Start New Operator", func(): slot_requested.emit(replace_slot, true, ""))
		"Save Game":
			var form := card(columns, 1.35)
			UI.label(form, "Save Game", 34, UI.CYAN)
			UI.label(form, "Save your operator’s inventory, banked bolts, and current deployment.", 19, UI.MUTED)
			var save_button := UI.button(form, "Save Operator %02d" % active_slot, func(): save_requested.emit(), true)
			save_button.custom_minimum_size.x = 192
			save_button.disabled = active_slot == 0
			if not save_button.disabled:
				save_button.grab_focus()
			save_status = UI.label(form, RiftRelay.directory.progress.status, 19, UI.CYAN)
			var indicator := save_status
			SocialPanel.watch(form, RiftRelay.directory.progress.changed, func():
				indicator.text = RiftRelay.directory.progress.status)
			portrait(card(columns))
		"Sector select":
			build_sector(columns)
		"Sector Challenges":
			select_challenge_sector(selected_sector, scroll_entries(card(columns)))
		"Sector Loot":
			archive_sector = selected_sector
			var intel := card(columns)
			UI.label(intel, Catalog.info(selected_sector).title + "  /  Loot Intel", 29, UI.CYAN)
			show_sector_loot(scroll_entries(intel))
		"Level select", "Co-op Sectors":
			build_level_select(columns)
		"New run":
			var confirmation := card(columns)
			UI.label(confirmation, "Start a new run?", 34, UI.CYAN)
			UI.label(confirmation, "Start at Operator Lv. 1 with the standard frame. Previously opened sectors stay unlocked.", 20, UI.MUTED)
			UI.button(confirmation, "Start in Ember Foundry", deploy, true).grab_focus()
			UI.button(confirmation, "Keep current run", show_page.bind("Sector select"))
		"Upgrades":
			build_workshop(columns)
		"Fabrication":
			build_fabrication(columns)
		"Gear":
			build_gear(columns)
		"Storage":
			build_storage_transfer(columns)
		"Blueprint Details", "Learn Blueprint":
			build_blueprint_details(columns)
		"Shop":
			build_shop(columns)
		"Craft Item":
			build_purchase(columns)
		"Social":
			SocialPanel.build_friends(self, columns)
		"Directory Account", "Directory Registration":
			SocialPanel.build_directory_account(self, columns, page == "Directory Registration")
		"Account Settings":
			SocialPanel.build_account_settings(self, columns)
		"Cosmetics":
			build_cosmetics(columns)
		"Notifications":
			SocialPanel.build_notifications(self, columns)
		"Party":
			build_online_room(columns)
		"Collection":
			build_archive(columns)
		"Tutorials":
			build_tutorials(columns)
		"Challenges":
			build_challenges(columns)
		"Co-op Setup Guide":
			CoopSetup.build(card(columns, 1.75), leave_page)
			portrait(card(columns))
		"Settings":
			var settings := UI.settings(card(columns), not station_panel)
			settings.initial_focus.grab_focus()
	if not checking_cloud_save and page not in ["Title", "Co-op Setup Guide", "Set up Player Profile", "Save Reset Error"]:
		var back_title := "Back to Title"
		if page in ["Create Account", "Sign In", "Offline Setup"]:
			back_title = "Back to Welcome"
		if station_panel:
			back_title = "Back to Deployment" if page in ["Level select", "New run", "Sector Challenges", "Sector Loot"] else "Back to Station"
			if page in ["Operators", "Account Settings", "Delete Profile"]:
				back_title = "Back to Profile"
			elif page == "Craft Item":
				back_title = "Back to Crafting"
			elif page == "Blueprint Details":
				back_title = "Back to Storage"
			elif page == "Learn Blueprint":
				back_title = "Back to Storage"
		if page in ["Directory Account", "Directory Registration"] and not directory_return_page.is_empty():
			back_title = "Back to Account Settings"
		var back := UI.button(layout, back_title, leave_page)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if get_viewport().gui_get_focus_owner() == null:
			if selected_tab:
				selected_tab.grab_focus()
			else:
				back.grab_focus()
	if station_panel and page == "Upgrades" and RiftSettings.show_hub_tips and not RiftSettings.seen_hub_tips.has(page):
		show_station_tip(page)
	elif navigation_state.has(page):
		restore_navigation.call_deferred(page, margins)

func remember_navigation() -> void:
	if not is_instance_valid(menu_body):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if not focused or not menu_body.is_ancestor_of(focused):
		return
	var key: String = focused.get_meta(&"return_focus", "")
	if key.is_empty():
		return
	var offsets: Array[int] = []
	for scroll in menu_body.find_children("*", "ScrollContainer", true, false):
		offsets.append(scroll.scroll_vertical)
	navigation_state[page] = {"focus": key, "offsets": offsets}

func restore_navigation(destination: String, container: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(container) or page != destination or container != menu_body or not is_visible_in_tree():
		return
	var state: Dictionary = navigation_state.get(destination, {})
	if state.is_empty():
		return
	var offsets: Array = state.offsets
	var scrollers := container.find_children("*", "ScrollContainer", true, false)
	for index in mini(offsets.size(), scrollers.size()):
		scrollers[index].scroll_vertical = offsets[index]
	for button in container.find_children("*", "Button", true, false):
		if button.get_meta(&"return_focus", "") == state.focus and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return

func station_tabs() -> Dictionary:
	if not station_panel:
		return {}
	if page in ["Shop", "Fabrication", "Upgrades"]:
		return {"Shop": "Buy", "Fabrication": "Crafting", "Upgrades": "Core Ascension"}
	if page in ["Save Game", "Settings"]:
		return {"Save Game": "Save Game", "Settings": "Settings"}
	if page in ["Gear", "Storage"]:
		return {"Gear": "Gear", "Storage": "Storage"}
	if page in ["Player Profile", "Cosmetics"]:
		return {"Player Profile": "Profile", "Cosmetics": "Cosmetics"}
	if page in ["Collection", "Tutorials"]:
		return {"Collection": "NOVA Archive", "Tutorials": "Tutorials"}
	if page in ["Social", "Notifications"]:
		return {"Social": "Friends", "Notifications": "Notifications"}
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
	if page in ["Shop", "Fabrication", "Upgrades", "Craft Item"]:
		station_name = "WORKSHOP"
	elif page in ["Gear", "Storage", "Blueprint Details", "Learn Blueprint"]:
		station_name = "OPERATOR"
	elif page in ["Save Game", "Settings"]:
		station_name = "SYSTEM"
	elif page in ["Player Profile", "Delete Profile", "Operators", "Delete Operator", "Account Settings", "Cosmetics"]:
		station_name = "PROFILE"
	elif page in ["Collection", "Tutorials"]:
		station_name = "NOVA ARCHIVE"
	elif page in ["Social", "Whispers", "Party", "Notifications", "Directory Account", "Directory Registration"]:
		station_name = "SOCIAL"
	elif page in ["Sector Challenges", "Sector Loot"]:
		station_name = "DEPLOY"
	var heading := UI.label(header, station_name, 25, UI.CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if page == "Upgrades":
		TalentTree.add_chip(header, "%04d BOLTS" % profile.credits, TalentTree.BOLT, UI.CYAN.darkened(0.22), 16, 27)
		TalentTree.add_chip(header, "%04d CORE SHARDS" % profile.core_shards, TalentTree.SHARD, UI.VIOLET, 16, 27)
		return
	var wallet := UI.column(header, 2)
	UI.currency_row(wallet, "%04d BOLTS" % profile.credits)
	wallet.add_child(HSeparator.new())
	UI.currency_row(wallet, "%04d CORE SHARDS" % profile.core_shards, true)

func open_station(next: String) -> void:
	station_panel = true
	deploy_error = ""
	inventory_status = ""
	shop_item = ""
	focused_item = ""
	equipment_slot = ""
	shop_category = "All Items"
	party_from_deploy = false
	show()
	show_page(next)
	if not is_instance_valid(hub_tip) and RiftSettings.show_hub_tips and HUB_TIPS.has(next) and not RiftSettings.seen_hub_tips.has(next):
		show_station_tip(next)

func show_station_tip(station: String) -> void:
	tip_station = station
	tip_focus = get_viewport().gui_get_focus_owner()
	hub_tip = ColorRect.new()
	hub_tip.name = "HubTip"
	hub_tip.color = Color(0.02, 0.04, 0.08, 0.50)
	add_child(hub_tip)
	hub_tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.frame(Color("11223b"), UI.CYAN))
	hub_tip.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -210
	panel.offset_bottom = -42
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var robot := TextureRect.new()
	robot.texture = preload("res://assets/ui/nova_guide.svg")
	robot.custom_minimum_size = Vector2(84, 84)
	robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	robot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	robot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(robot)
	var text := UI.column(row, 6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content: Array = HUB_TIPS[station]
	UI.label(text, "NOVA  /  " + String(content[0]), 26, UI.CYAN)
	UI.label(text, content[1], 19)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	text.add_child(actions)
	var proceed := UI.button(actions, "Continue  ·  A / Enter", dismiss_station_tip.bind(false), true, 34)
	var disable := UI.button(actions, "Turn off tips", dismiss_station_tip.bind(true), false, 34)
	proceed.focus_neighbor_right = proceed.get_path_to(disable)
	proceed.focus_neighbor_left = proceed.get_path_to(disable)
	disable.focus_neighbor_left = disable.get_path_to(proceed)
	disable.focus_neighbor_right = disable.get_path_to(proceed)
	proceed.grab_focus()

func dismiss_station_tip(disable: bool) -> void:
	if not is_instance_valid(hub_tip):
		return
	RiftSettings.seen_hub_tips.append(tip_station)
	if disable:
		RiftSettings.show_hub_tips = false
	RiftSettings.save()
	remove_child(hub_tip)
	hub_tip.queue_free()
	hub_tip = null
	if is_instance_valid(tip_focus):
		tip_focus.grab_focus()
	tip_focus = null

func _input(event: InputEvent) -> void:
	var popup := get_node_or_null("FindFriendsPopup") as Control
	if popup and popup.is_visible_in_tree():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			popup.hide()
		elif event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(hub_tip) or not is_visible_in_tree() or event is InputEventMouse:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var selected := get_viewport().gui_get_focus_owner() as Button
		if selected and hub_tip.is_ancestor_of(selected):
			selected.pressed.emit()
		else:
			dismiss_station_tip(false)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss_station_tip(false)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		get_viewport().set_input_as_handled()

func leave_page() -> void:
	if checking_cloud_save:
		return
	if is_instance_valid(item_actions) and item_actions.visible:
		item_actions.hide()
		if is_instance_valid(item_origin):
			item_origin.grab_focus()
		return
	if page in ["Set up Player Profile", "Save Reset Error"]:
		return
	if page in ["Create Account", "Sign In", "Offline Setup"]:
		show_page("Set up Player Profile")
		return
	if page == "Account Settings" and not station_panel:
		show_page("Saves" if RiftRelay.directory.progress.conflict else "Title")
		return
	if page in ["Directory Account", "Directory Registration"] and not directory_return_page.is_empty():
		var destination := directory_return_page
		directory_return_page = ""
		show_page(destination)
		return
	if station_panel and page in ["Operators", "Account Settings", "Delete Profile"]:
		show_page("Player Profile")
		return
	if page == "Delete Operator" and delete_return_page == "Operators":
		show_page("Operators")
		return
	if page == "Settings" and find_children("RiftSettingsPanel", "", true, false).any(func(panel): return panel.installing):
		return
	if page in ["Co-op Setup Guide", "Directory Account", "Directory Registration"]:
		show_page("Social" if station_panel else "Title")
		return
	if page in ["Party", "Social", "Co-op Sectors"] and party_from_deploy:
		party_from_deploy = false
		show_page("Sector select")
		return
	if page == "Party" and not RiftRelay.pending.is_empty():
		RiftRelay.leave()
	if station_panel:
		if page == "Co-op Sectors":
			show_page("Party")
			return
		if page == "Craft Item":
			show_page("Fabrication")
			return
		if page in ["Learn Blueprint", "Blueprint Details"]:
			show_page("Storage")
			return
		if page in ["Level select", "New run", "Sector Challenges", "Sector Loot"]:
			show_page("Sector select")
			return
		station_panel = false
		hide()
		station_closed.emit()
		return
	if page == "Delete Operator":
		show_page(delete_return_page)
		return
	show_page("New Game" if page == "Replace Slot" else "Title")

func show_deploy_error() -> void:
	deploy_error = "Could not save the selected deployment."
	show_page("Level select")

func card(parent: Container, ratio := 1.0) -> VBoxContainer:
	return UI.card(parent, ratio)

func portrait(parent: VBoxContainer) -> void:
	var hero := preload("res://scripts/equipment_display.gd").new()
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
	var subtitle := UI.label(stack, "ROGUE PROTOCOL", 17, UI.VIOLET)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(HSeparator.new())
	var buttons: Array[Button] = []
	if preferred_operator() > 0 or developer_session:
		var label := "Enter Station" if developer_session else "Continue"
		buttons.append(UI.button(stack, label, play_local_save, true))
	buttons.append(UI.button(stack, "Operators", open_slot_picker.bind("Load Game"), buttons.is_empty()))
	buttons.append(UI.button(stack, "Tutorials", show_page.bind("Tutorials")))
	buttons.append(UI.button(stack, "Settings", show_page.bind("Settings")))
	buttons.append(UI.button(stack, "Quit Game", RiftRelay.quit_game))
	for i in range(buttons.size()):
		var button := buttons[i]
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(242, 43)
		button.add_theme_font_size_override("font_size", 21)
		button.focus_neighbor_top = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(i + 1) % buttons.size()])
	var status := UI.label(stack, "RX-07    //    SYSTEM READY", 13, UI.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons[0].grab_focus()

func preferred_operator() -> int:
	if account and ManualSave.read_slot(account.last_operator) != null:
		return account.last_operator
	for number in range(1, ManualSave.SLOT_COUNT + 1):
		if ManualSave.read_slot(number) != null:
			return number
	return 0

func open_after_startup() -> void:
	get_tree().set_meta(&"startup_choice_confirmed", true)
	if preferred_operator() > 0:
		show_page("Title")
	else:
		open_slot_picker("Load Game")

func play_local_save() -> void:
	var number := preferred_operator()
	if number > 0:
		slot_requested.emit(number, false, "")
	elif developer_session:
		hub_requested.emit()
	else:
		open_slot_picker("Load Game")

func build_profile_saves(columns: HBoxContainer) -> void:
	var directory = RiftRelay.directory
	var cloud = directory.progress
	var local := card(columns)
	var online := card(columns)
	UI.label(local, "LOCAL SAVE", 28, UI.CYAN)
	describe_profile_save(local, cloud.snapshot(), "On this device")
	UI.button(local, "Use Local Copy", func():
		if cloud.conflict:
			await cloud.sync(true)
			if not is_instance_valid(local) or cloud.conflict:
				return
		open_slot_picker("Load Game")
	, true)
	UI.label(online, "CLOUD SAVE", 28, UI.CYAN)
	var status := UI.label(online, cloud.status, 17, UI.MUTED)
	var details := UI.column(online, 8)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	online.add_child(actions)
	var last_displayed := {"revision": "", "conflict": false, "online": false}
	var refresh := func():
		var revision: String = cloud.remote.get("revision", "")
		var connected: bool = directory.online()
		status.text = cloud.status if connected else "Connect online to select a cloud save."
		var visible_state := {"revision": revision, "conflict": cloud.conflict, "online": connected}
		if visible_state == last_displayed and actions.get_child_count() > 0:
			return
		last_displayed.assign(visible_state)
		for container in [details, actions]:
			for item in container.get_children():
				container.remove_child(item)
				item.queue_free()
		if connected:
			if not revision.is_empty():
				describe_profile_save(details, cloud.remote.data, "%s UTC" % cloud.remote.get("saved_at", ""))
				UI.button(actions, "Use Cloud Copy", func(): cloud_save_requested.emit(), true, 36)
			else:
				UI.label(details, "Your profile and all three operator saves back up here.", 17, UI.MUTED)

		else:
			UI.button(actions, "Connect Online", show_page.bind("Directory Account"), true, 36)
	SocialPanel.watch(online, cloud.changed, refresh)
	SocialPanel.watch(online, directory.changed, refresh)
	refresh.call()
	if directory.online():
		cloud.sync.call_deferred()

func describe_profile_save(panel: VBoxContainer, data: Dictionary, source: String) -> void:
	var stored := ConfigFile.new()
	if data.is_empty() or stored.parse(String(data.get("profile", ""))) != OK:
		UI.label(panel, "No profile saved", 23)
		return
	var xp := int(stored.get_value("player", "xp", 0))
	var name := String(stored.get_value("player", "name", "RX-07"))
	UI.label(panel, name, 27)
	UI.label(panel, "Profile Lv. %d  ·  %s" % [RiftPlayer.level_for_experience(xp), source], 17, UI.MUTED)
	var ops: Dictionary = data.get("operators", {})
	var number := int(stored.get_value("player", "last_operator", 0))
	if not ops.has(str(number)):
		number = int(ops.keys()[0]) if not ops.is_empty() else 0
	if number <= 0:
		UI.label(panel, "No operators created", 17, UI.MUTED)
		return
	var active := ConfigFile.new()
	if active.parse(ops[str(number)]) == OK:
		var level := RiftPlayer.level_for_experience(int(active.get_value("checkpoint", "experience", 0)))
		UI.label(panel, "Operator %02d  ·  Lv. %d" % [number, level], 19, UI.CYAN)
		UI.label(panel, "%d / %d operator slots in use" % [ops.size(), ManualSave.SLOT_COUNT], 17, UI.MUTED)

func build_cosmetics(columns: HBoxContainer) -> void:
	var finish_model := preload("res://scripts/equipment_display.gd").new()
	card(columns).add_child(finish_model)
	var list := card(columns, 1.18)
	UI.label(list, "Operator Finish", 27, UI.CYAN)
	var choices: Array = [""] + account.unlocked_skins
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	list.add_child(row)
	var slot := OptionButton.new()
	var finish := OptionButton.new()
	for control in [slot, finish]:
		control.custom_minimum_size.y = 35
		UI.style_button(control)
		row.add_child(control)
	for number in range(1, ManualSave.SLOT_COUNT + 1):
		if number != active_slot and not ManualSave.read_slot(number):
			continue
		slot.add_item("Operator %02d" % number, number)
		if number == active_slot:
			slot.select(slot.item_count - 1)
	for choice in choices:
		finish.add_item(SkinKit.label(choice))
	if slot.item_count == 0:
		slot.add_item("No operator")
		slot.disabled = true
		finish.disabled = true
	var apply_preview := func():
		var choice: String = account.display_skin(slot.get_selected_id())
		finish.select(choices.find(choice))
		finish_model.set_appearance(choice)
	var finish_status := UI.label(list, "" if not slot.disabled else "Create an operator before assigning a finish.", 16, UI.MUTED)
	slot.item_selected.connect(func(_index): apply_preview.call())
	finish.item_selected.connect(func(index: int):
		if account.select_skin(slot.get_selected_id(), choices[index]) == OK:
			finish_status.text = "Finish selected."
		else:
			finish_status.text = "Could not save the finish."
		apply_preview.call()
	)
	if not slot.disabled:
		apply_preview.call()
	list.add_child(HSeparator.new())
	UI.label(list, "Station Finishes", 23, UI.CYAN)
	if not inventory_status.is_empty():
		UI.label(list, inventory_status, 17, UI.CYAN)
	var store := scroll_entries(list)
	for id in SkinKit.STORE:
		var item: Array = SkinKit.STORE[id]
		var item_row := HBoxContainer.new()
		store.add_child(item_row)
		var swatch := ColorRect.new()
		swatch.color = Color(item[2])
		swatch.custom_minimum_size = Vector2(20, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item_row.add_child(swatch)
		var preview := UI.button(item_row, item[0], finish_model.set_appearance.bind(id), false, 35)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var owned: bool = account.unlocked_skins.has(id)
		var purchase := UI.button(item_row, "Owned" if owned else "%s bolts" % item[3], finish_purchase_requested.emit.bind(id), true, 35)
		purchase.disabled = owned or profile.credits < item[3]
		preview.focus_entered.connect(finish_model.set_appearance.bind(id))

func build_player_account(columns: HBoxContainer) -> void:
	var form := card(columns)
	if not account.display_name.is_empty():
		UI.label(form, account.display_name, 38, UI.CYAN)
		MissionResults.profile_progress(form, {"before": account.experience, "after": account.experience})
		UI.label(form, "%s TOTAL XP" % str(account.experience), 16, UI.MUTED)
		form.add_child(HSeparator.new())
		UI.label(form, "Career", 26, UI.CYAN)
		UI.label(form, "Sectors extracted    %d" % account.total_clears, 20)
		UI.label(form, "Security defeats on clears    %d" % account.total_kills, 20)
		var record := "No record yet"
		if account.longest_run > 0.0:
			record = "%s   ·   %s" % [account.longest_operator, format_profile_time(account.longest_run)]
		UI.label(form, "Longest Operator run    %s" % record, 20)
		UI.label(form, "Survival time counts active deployment time across sectors until reconstruction.", 16, UI.MUTED)
		var profile_actions := HBoxContainer.new()
		form.add_child(profile_actions)
		if station_panel:
			UI.button(profile_actions, "Switch Operator", open_slot_picker.bind("Operators"))
		UI.button(profile_actions, "Account Settings", show_page.bind("Account Settings"))
		UI.button(form, "Reset Progress", show_page.bind("Delete Profile"))
		portrait(card(columns))
		return
	UI.label(form, "Create Offline Profile", 36, UI.CYAN)
	UI.label(form, "Choose one name for your three operators. This profile saves on this device. Sign in to use cloud saves and the live friends list.", 20, UI.MUTED)
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Player name"
	name_field.max_length = 20
	name_field.custom_minimum_size = Vector2(245, 40)
	name_field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	form.add_child(name_field)
	var status := UI.label(form, "", 16, UI.MUTED)
	var submit := func():
		if name_field.text.strip_edges().is_empty():
			status.text = "Enter a name for your profile."
			return
		if account.create(name_field.text) != OK:
			status.text = "Could not save the profile. Try again."
			return
		RiftSettings.confirm_startup_choice("offline")
		open_after_startup()
	name_field.text_submitted.connect(func(_value): submit.call())
	UI.button(form, "Create Profile", submit, true)
	UI.button(form, "Quit Game", RiftRelay.quit_game)
	name_field.grab_focus()

func format_profile_time(value: float) -> String:
	var seconds := floori(value)
	return "%02d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]

func build_tutorials(columns: HBoxContainer) -> void:
	var topics := card(columns, 0.58)
	UI.label(topics, "Tutorials", 28, UI.CYAN)
	var choices := scroll_entries(topics)
	var manual := card(columns, 1.42)
	var content := scroll_entries(manual)
	var heading := UI.label(content, "", 30, UI.CYAN)
	var guide := UI.label(content, "", 20)
	var details := UI.label(content, "", 18, UI.MUTED)
	var buttons: Array[Button] = []
	var select := func(index: int):
		tutorial_topic = index
		var entry: Array = FieldManual.TOPICS[index]
		heading.text = entry[0]
		guide.text = entry[1]
		details.text = entry[2]
		for i in buttons.size():
			buttons[i].add_theme_color_override("font_color", UI.CYAN if i == index else UI.WHITE)
	for index in FieldManual.TOPICS.size():
		var button := UI.button(choices, FieldManual.TOPICS[index][0], func(): buttons[index].grab_focus(), false, 33)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_entered.connect(select.bind(index))
		buttons.append(button)
	select.call(tutorial_topic)
	buttons[tutorial_topic].grab_focus()

func build_archive(columns: HBoxContainer) -> void:
	var archive := card(columns, 1.65)
	UI.label(archive, "NOVA Archive", 32, UI.CYAN)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.make_readable_scroll(scroll)
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

func show_sector_loot(entries: VBoxContainer) -> void:
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	if not profile.loot_clears.has(archive_sector):
		UI.label(entries, "Extract from this sector to unlock its drop tables.", 17, UI.MUTED)
		return
	var mode := OptionButton.new()
	for title in Difficulty.NAMES:
		mode.add_item(title)
	mode.select(archive_loot_mode)
	entries.add_child(mode)
	UI.style_button(mode)
	var loot_list := UI.column(entries, 6)
	var refresh := func(index: int):
		archive_loot_mode = index
		for child in loot_list.get_children():
			loot_list.remove_child(child)
			child.queue_free()
		UI.label(loot_list, "Boss cache guarantees one blueprint and materials.", 16, UI.CYAN)
		UI.label(loot_list, "Your operator level determines which of these recipes can drop.", 16, UI.MUTED)
		UI.label(loot_list, "Materials", 21, UI.CYAN)
		for id in Materials.pool(archive_sector):
			UI.label(loot_list, Materials.label(id), 16)
		for boss in [false, true]:
			UI.label(loot_list, "Boss Cache" if boss else "Salvage Chests", 21, UI.CYAN)
			for part in Blueprints.drop_pool(archive_sector, index, 100000, boss):
				var id := Blueprints.blueprint_id(archive_sector, part)
				var item: Dictionary = Profile.GEAR[id]
				UI.label(loot_list, "%s  ·  %s  ·  Lv. %d" % [item.name, Profile.RARITY_NAMES[item.rarity], item.level],
					16, Profile.RARITY_COLORS[item.rarity])
				if boss and profile.can_collect_blueprint(id):
					var pin := "Pin blueprint"
					if id == profile.pinned_blueprint:
						pin = "Unpin  ·  %d/%d eligible clears" % [profile.blueprint_hunts.get(id, 0), Profile.HUNT_CLEARS]
					UI.button(loot_list, pin, func():
						profile.pin_blueprint(id)
						refresh_archive_pin(entries, id)
					, false, 29).set_meta(&"blueprint_pin", id)
	mode.item_selected.connect(refresh)
	refresh.call(archive_loot_mode)

func refresh_archive_pin(entries: VBoxContainer, id: String) -> void:
	show_sector_loot(entries)
	for button in entries.find_children("*", "Button", true, false):
		if button.get_meta(&"blueprint_pin", "") == id:
			button.grab_focus()
			return

func update_social_tabs() -> void:
	if is_instance_valid(notifications_tab):
		var pending := RiftRelay.directory.request_count() + RiftSocial.invites.size()
		notifications_tab.text = "Notifications (%d)" % pending if pending > 0 else "Notifications"

func build_online_room(columns: HBoxContainer) -> void:
	var form := card(columns)
	UI.label(form, "Start or Join a Group", 32, UI.CYAN)
	UI.label(form, "Up to four players can join. The leader chooses a campaign sector.", 18, UI.MUTED)
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
	relay_rejoin = UI.button(form, "Rejoin Party", RiftRelay.rejoin_party, true)
	relay_status = UI.label(form, "", 18, UI.CYAN)
	relay_deploy = UI.button(form, "Choose Co-op Sector", show_page.bind("Co-op Sectors"), true)
	relay_copy = UI.button(form, "Copy Room Code", func(): DisplayServer.clipboard_set(RiftRelay.connected_room))
	relay_leave = UI.button(form, "Leave Room", func(): RiftRelay.leave())
	refresh_online_room()
	if relay_rejoin.visible:
		relay_rejoin.grab_focus()
	elif not relay_host.disabled:
		relay_host.grab_focus()

func refresh_online_room() -> void:
	if page in ["Sector select", "Level select", "Co-op Sectors"]:
		refresh_deployment.call_deferred()
		return
	if page != "Party" or not is_instance_valid(relay_status):
		return
	var joined := not RiftRelay.connected_room.is_empty()
	var requesting := not RiftRelay.pending.is_empty()
	relay_host.disabled = not RiftRelay.available or joined or requesting
	relay_join.disabled = relay_host.disabled
	relay_rejoin.visible = RiftRelay.can_rejoin_party()
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
	displayed_operator = maxi(active_slot if station_panel else preferred_operator(), 1)
	show_page(mode)

func build_save_slots(columns: HBoxContainer) -> void:
	if checking_cloud_save:
		var loading := card(columns)
		UI.label(loading, "Checking cloud saves…", 24, UI.CYAN)
		return
	var cards: Array[Button] = []
	var saves: Array[ConfigFile] = []
	for number in range(1, ManualSave.SLOT_COUNT + 1):
		var saved := ManualSave.read_slot(number)
		saves.append(saved)
		var operator_card := card(columns)
		var is_active := station_panel and number == active_slot
		var heading := "OPERATOR %02d" % number
		if number == active_slot:
			heading += "   /   ACTIVE" if is_active else "   /   LAST PLAYED"
		UI.label(operator_card, heading, 20, UI.CYAN)
		if saved:
			var model := EquipmentDisplay.new()
			model.compact = true
			model.skin = account.display_skin(number) if account else ""
			operator_card.add_child(model)
			UI.label(operator_card, operator_name(saved), 25)
			UI.label(operator_card, operator_facts(saved)[2], 17, UI.MUTED)
		else:
			UI.label(operator_card, "＋", 54, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI.label(operator_card, "Empty slot", 23)
		var space := Control.new()
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		operator_card.add_child(space)
		if is_active:
			UI.label(operator_card, "Active operator", 18, UI.CYAN)
			continue
		var caption := "Create Operator" if not saved else ("Switch Operator" if station_panel else "Play")
		var action := UI.button(operator_card, caption, choose_slot.bind(number, saved == null), true, 38)
		action.set_meta(&"operator_slot", number)
		action.custom_minimum_size.x = 142
		cards.append(action)
	var detail := card(columns, 1.2)
	var rendered := UI.column(detail, 6)
	var manage := MenuButton.new()
	manage.text = "Manage"
	manage.focus_mode = Control.FOCUS_ALL
	manage.custom_minimum_size.y = 35
	manage.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UI.style_button(manage)
	detail.add_child(manage)
	manage.get_popup().add_item("Delete Operator", 0)
	manage.get_popup().id_pressed.connect(func(_id):
		delete_return_page = page
		show_page("Delete Operator")
	)
	if not slot_error.is_empty():
		UI.label(detail, slot_error, 16, UI.VIOLET)
	var preview := func(number: int):
		displayed_operator = number
		for entry in rendered.get_children():
			rendered.remove_child(entry)
			entry.queue_free()
		var saved := saves[number - 1]
		UI.label(rendered, "OPERATOR %02d" % number, 23, UI.CYAN)
		if saved:
			var facts := operator_facts(saved)
			for index in [0, 1, 3, 4]:
				UI.label(rendered, facts[index], 16, UI.MUTED)
		else:
			UI.label(rendered, "Start a new run in this slot.", 17, UI.MUTED)
		manage.visible = saved != null and (not station_panel or number != active_slot)
	for index in cards.size():
		var action := cards[index]
		var number: int = action.get_meta(&"operator_slot")
		action.focus_entered.connect(preview.bind(number))
		if index > 0:
			action.focus_neighbor_left = action.get_path_to(cards[index - 1])
		if index + 1 < cards.size():
			action.focus_neighbor_right = action.get_path_to(cards[index + 1])
		action.focus_neighbor_top = action.get_path_to(manage)
		action.focus_entered.connect(func(): manage.focus_neighbor_bottom = manage.get_path_to(action))
	var target: Button
	for action in cards:
		if action.get_meta(&"operator_slot") == displayed_operator:
			target = action
			break
	preview.call(displayed_operator)
	if target:
		target.grab_focus()
	elif not cards.is_empty():
		cards[0].grab_focus()

func delete_selected_operator() -> void:
	var result := ManualSave.delete_slot(displayed_operator)
	if result == OK:
		operator_deleted.emit(displayed_operator)
		slot_error = ""
	else:
		slot_error = "Could not delete this operator. " + error_string(result)
	show_page(delete_return_page)

func operator_name(saved: ConfigFile) -> String:
	if account and not account.display_name.is_empty():
		return account.display_name
	return Profile.clean_operator_name(str(saved.get_value("profile", "operator_name", "RX-07")))

func operator_facts(saved: ConfigFile) -> PackedStringArray:
	var sector := clampi(int(saved.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
	var stored_profile := Profile.new()
	stored_profile.decode_from(saved)
	var material_count := 0
	for count in stored_profile.materials.values():
		material_count += int(count)
	var seconds := maxi(0, int(saved.get_value("slot", "play_seconds", 0)))
	var duration := "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return PackedStringArray([
		"Saved  ·  %s" % str(saved.get_value("slot", "saved_at", "Unknown")),
		"%s   /   Act %d" % [Catalog.info(sector).title, int(saved.get_value("checkpoint", "act", 1))],
		"Operator Lv. %d   /   Player Lv. %d" % [RiftPlayer.level_for_experience(int(saved.get_value("checkpoint", "experience", 0))), stored_profile.player_level()],
		"Materials  ·  %d" % material_count,
		"Playtime  ·  %s" % (duration if saved.has_section_key("slot", "play_seconds") else "Not tracked"),
	])

func choose_slot(number: int, fresh: bool) -> void:
	if fresh and ManualSave.read_slot(number) != null:
		replace_slot = number
		show_page("Replace Slot")
	else:
		slot_requested.emit(number, fresh, "")

func show_slot_error() -> void:
	slot_error = "That save could not be opened."
	show_page("Load Game")

func show_save_result(result: String) -> void:
	save_status.text = result

func build_workshop(columns: HBoxContainer) -> void:
	var tree := card(columns)
	var header := HBoxContainer.new()
	tree.add_child(header)
	var heading := UI.label(header, "Core Ascension", 30, UI.CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level := UI.label(header, "PLAYER LV. %d" % profile.player_level(), 17, Color("ffd079"))
	level.autowrap_mode = TextServer.AUTOWRAP_OFF
	UI.label(tree, "Install a talent in each earlier tier to unlock the next tier of that branch.", 16, UI.MUTED)
	var talent_tree := TalentTree.new()
	tree.add_child(talent_tree)
	talent_tree.build(profile, enhancement_focus, shop_status if not enhancement_focus.is_empty() else "", purchase_upgrade)
	enhancement_focus = ""

func shop_type(item: Dictionary) -> String:
	if item.has("material"):
		return "Material"
	if item.has("stat"):
		return "Buff"
	if item.get("hp", 0) == 0:
		return "Energy Cell"
	return "Supply"

func build_shop(columns: HBoxContainer) -> void:
	var operator_level: int = profile.operator_level
	var catalog := card(columns, 1.08)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 20)
	catalog.add_child(heading)
	UI.label(heading, "Station Shop", 31, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
	var subtitle := UI.label(heading, "Operator Lv. %d" % operator_level, 16, Color("ffd079"))
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	catalog.add_child(filters)
	var active_filter: Button
	for category in SHOP_FILTERS:
		var tab := UI.button(filters, category, func():
			shop_category = category
			show_page("Shop")
		, false, 34)
		if category == shop_category:
			tab.add_theme_color_override("font_color", UI.CYAN)
			active_filter = tab
		tab.icon = EquipmentIcons.icon(SHOP_FILTERS[category], SHOP_FILTERS[category])
		tab.expand_icon = true
		tab.add_theme_constant_override("icon_max_width", 16)

	var items: Array[String] = []
	for id in Profile.stock:
		var item: Dictionary = Profile.stock[id]
		if item.shop_level > operator_level or not Profile.sold_at_shop(id):
			continue
		var type := shop_type(item)
		if shop_category == "All Items" or (shop_category == "Supplies" and type in ["Supply", "Energy Cell"]) or (shop_category == "Materials" and type == "Material") or (shop_category == "Buffs" and type == "Buff"):
			items.append(id)
	items.sort_custom(func(left: String, right: String) -> bool:
		var a: Dictionary = Profile.stock[left]
		var b: Dictionary = Profile.stock[right]
		return a.name < b.name if a.shop_level == b.shop_level else a.shop_level < b.shop_level
	)
	var list_header := shop_columns(catalog, "ITEM (%d)" % items.size(), "TYPE", "PRICE", Color("a6c7df"))
	var gutter := Control.new()
	gutter.custom_minimum_size.x = 39
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_header.add_child(gutter)
	list_header.move_child(gutter, 0)
	var entries := scroll_entries(catalog)
	entries.add_theme_constant_override("separation", 4)

	var info := card(columns, 1.0)
	if items.is_empty():
		focused_item = ""
		UI.label(info, "No stock in this category at Operator Lv. %d." % operator_level, 20, UI.MUTED)
		active_filter.grab_focus()
		return
	var title := UI.label(info, "", 40, UI.CYAN)
	info.add_child(HSeparator.new())
	var rarity := UI.label(info, "", 20)
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 14)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(preview)
	var tile := UI.equipment_card(UI.CYAN)
	tile.custom_minimum_size = Vector2(122, 132)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.add_child(tile)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	var facts := UI.column(preview, 8)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var description := UI.label(facts, "", 20, UI.WHITE)
	var type_value := shop_fact(facts, "Type")
	var price_value := shop_fact(facts, "Price")
	var owned := shop_fact(facts, "In inventory")
	var order := UI.equipment_card(Color("3b7fa8"))
	info.add_child(order)
	var controls := UI.column(order, 4)
	shop_columns(controls, "Purchase Quantity", "", "Total Cost", UI.MUTED)
	var quantity_row := HBoxContainer.new()
	controls.add_child(quantity_row)
	var quantity := UI.label(quantity_row, "1", 23)
	quantity.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity.custom_minimum_size.x = 32
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var total := UI.label(quantity_row, "", 23, Color("ffd079"))
	total.autowrap_mode = TextServer.AUTOWRAP_OFF
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buy := UI.button(info, "Buy", func():
		inventory_status = profile.buy_supply(focused_item, int(quantity.text))
		show_page("Shop")
	, true, 51)
	buy.icon = EquipmentIcons.icon("core", "core")
	buy.expand_icon = true
	buy.add_theme_constant_override("icon_max_width", 24)
	buy.add_theme_font_size_override("font_size", 21)
	var message := UI.label(info, "Purchases go to Inventory. Stow them under Operator → Storage." if inventory_status.is_empty() else inventory_status, 15, UI.MUTED if inventory_status.is_empty() else UI.VIOLET)
	message.custom_minimum_size.y = 18

	var adjust := func(step: int):
		var limit: int = profile.supply_purchase_limit(focused_item)
		var count := clampi(int(quantity.text) + step, 1, maxi(1, limit))
		quantity.text = str(count)
		var cost: int = profile.supply_price(focused_item) * count
		total.text = "%d bolts" % cost
		buy.text = "BUY  /  %d BOLTS" % cost
		buy.disabled = limit == 0 or profile.credits < cost
		buy.tooltip_text = "Inventory stack is full" if limit == 0 else ("Not enough bolts" if buy.disabled else "Goes to Inventory.")
	var minus := UI.button(quantity_row, "‹", adjust.bind(-1), false, 34)
	quantity_row.move_child(minus, 0)
	var plus := UI.button(quantity_row, "›", adjust.bind(1), false, 34)
	quantity_row.move_child(plus, 2)
	var reveal := func(id: String):
		focused_item = id
		var item: Dictionary = Profile.stock[id]
		title.text = item.name
		rarity.text = Profile.RARITY_NAMES[item.rarity]
		rarity.add_theme_color_override("font_color", Profile.RARITY_COLORS[item.rarity])
		var symbol: String = {"Supply": "vital_weave", "Energy Cell": "charge_relay"}.get(shop_type(item), item.icon)
		icon.texture = EquipmentIcons.icon(symbol, item.icon)
		icon.modulate = Profile.RARITY_COLORS[item.rarity]
		description.text = item.detail
		type_value.text = shop_type(item)
		price_value.text = "%d bolts" % profile.supply_price(id)
		owned.text = str(profile.supply_owned(id))
		quantity.text = "1"
		adjust.call(0)
	var selected: String = focused_item if focused_item in items else items[0]
	for id in items:
		var item: Dictionary = Profile.stock[id]
		var record := UI.button(entries, "", func():
			reveal.call(id)
			if not buy.disabled:
				buy.grab_focus()
		, false, 39)
		record.tooltip_text = item.name
		var cells := shop_columns(record, item.name, shop_type(item), "%d" % profile.supply_price(id), Color("ffd079"))
		cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cells.offset_left = 10
		cells.offset_right = -10
		var entry_icon := TextureRect.new()
		entry_icon.texture = EquipmentIcons.icon(item.icon, item.icon)
		entry_icon.modulate = Profile.RARITY_COLORS[item.rarity]
		entry_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		entry_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry_icon.custom_minimum_size.x = 29
		entry_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cells.add_child(entry_icon)
		cells.move_child(entry_icon, 0)
		var name_label := cells.get_child(1) as Label
		cells.remove_child(name_label)
		var name_stack := VBoxContainer.new()
		name_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_stack.add_theme_constant_override("separation", -2)
		cells.add_child(name_stack)
		cells.move_child(name_stack, 1)
		name_stack.add_child(name_label)
		var tag_label := UI.label(name_stack, Profile.RARITY_NAMES[item.rarity], 14, Profile.RARITY_COLORS[item.rarity])
		tag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		record.focus_entered.connect(reveal.bind(id))
		record.focus_neighbor_right = record.get_path_to(plus)
		if id == selected:
			record.grab_focus()
	reveal.call(selected)

func shop_columns(parent: Control, item: String, type: String, price: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var item_label := UI.label(row, item, 18)
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var type_label := UI.label(row, type, 16, UI.MUTED)
	type_label.custom_minimum_size.x = 97
	var price_label := UI.label(row, price, 19, color)
	price_label.custom_minimum_size.x = 71
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label in [item_label, type_label, price_label]:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return row

func shop_fact(parent: VBoxContainer, caption: String) -> Label:
	parent.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := UI.label(row, caption, 17, UI.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value := UI.label(row, "", 18)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return value

func build_challenges(columns: HBoxContainer) -> void:
	var countdown := UI.label(layout, "", 32, UI.VIOLET)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout.move_child(countdown, columns.get_index())
	var sectors := card(columns, 0.8)
	UI.label(sectors, "Unlocked sectors", 25, UI.CYAN)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	sectors.add_child(scroll)
	var list := UI.column(scroll, 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := scroll_entries(card(columns, 1.65))
	UI.make_readable_scroll(details.get_parent() as ScrollContainer)
	var available: int = profile.unlocked_sector if profile else 1
	challenge_sector = clampi(challenge_sector, 1, available)
	var group := ButtonGroup.new()
	for number in range(1, available + 1):
		var label := "%02d   %s" % [number, Catalog.info(number).title]
		var option := UI.button(list, label, select_challenge_sector.bind(number, details))
		option.custom_minimum_size.x = 205
		option.toggle_mode = true
		option.button_group = group
		option.set_pressed_no_signal(number == challenge_sector)
		if number == challenge_sector:
			option.grab_focus()
	var displayed_day := [Profile.challenge_day()]
	select_challenge_sector(challenge_sector, details)
	var refresh := func():
		var clock := Time.get_datetime_dict_from_system()
		var today := Profile.challenge_day(clock)
		if today > displayed_day[0]:
			displayed_day[0] = today
			select_challenge_sector(challenge_sector, details)
		var left: int = Profile.challenge_seconds_left(clock)
		countdown.text = "Challenges Reset IN: %02dh %02dm %02ds" % [left / 3600, (left / 60) % 60, left % 60]
	var heartbeat := Timer.new()
	countdown.add_child(heartbeat)
	heartbeat.timeout.connect(refresh)
	heartbeat.start(1.0)
	refresh.call()

func select_challenge_sector(number: int, details: VBoxContainer) -> void:
	challenge_sector = number
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	UI.label(details, Catalog.info(number).title, 30, UI.CYAN)
	var cycle: Dictionary = profile.challenge_cycle(number)
	UI.label(details, "%d / 5 cleared  ·  +%d Core Shards for finishing the set" % [cycle.done.size(), Profile.challenge_set_shards(number)], 17, UI.MUTED)
	for tier in 5:
		var data: Array = Profile.CHALLENGE_SETS[cycle.set][tier]
		var done: bool = cycle.done.has(tier)
		details.add_child(HSeparator.new())
		var line := HBoxContainer.new()
		details.add_child(line)
		var title := UI.label(line, data[0], 20)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		var status := UI.label(line, "COMPLETE" if done else "OPEN", 17, Color("91f7a1") if done else UI.MUTED)
		status.autowrap_mode = TextServer.AUTOWRAP_OFF
		UI.label(details, data[1], 16, UI.MUTED)
		var amount := Profile.rotated_challenge_credits(number, tier)
		var shards: int = Profile.challenge_shards(number, tier)
		UI.label(details, "%s  %d bolts  ·  %d Core Shards  ·  1 reserve life" % ["Reward claimed" if done else "Reward", amount, shards], 17, Color("ffe28e"))
	var reserve: int = profile.reserve_lives if profile else 0
	details.add_child(HSeparator.new())
	UI.label(details, "Reserve lives: %d. Used automatically when you lose your last life." % reserve, 16, UI.MUTED)

func purchase_upgrade(id: String) -> void:
	shop_status = profile.buy(id)
	enhancement_focus = id
	show_page("Upgrades")

func build_sector(columns: HBoxContainer) -> void:
	build_level_select(columns)

func build_level_select(columns: HBoxContainer) -> void:
	var route := card(columns, 1.75)
	var connected := not RiftRelay.connected_room.is_empty()
	var cooperative := connected and RiftRelay.can_deploy()
	var last_sector: int = mini(Catalog.SECTORS.size(), profile.unlocked_sector if profile else 1)
	selected_sector = clampi(selected_sector, 1, last_sector)
	UI.label(route, "DEPLOYMENT MAP", 32, UI.CYAN)
	var actions := HBoxContainer.new()
	route.add_child(actions)
	if can_load and not connected:
		UI.button(actions, "Continue Run", func(): load_requested.emit(), true, 36)
		UI.button(actions, "New Run…", show_page.bind("New run"), false, 36)
	UI.button(actions, "Manage Group" if connected else "Start a Group", func():
		party_from_deploy = true
		show_page("Party")
	, false, 36)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	route.add_child(scroll)
	var entries := GridContainer.new()
	entries.columns = 3
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("h_separation", 8)
	entries.add_theme_constant_override("v_separation", 8)
	scroll.add_child(entries)
	var intel := card(columns)
	for number in range(1, last_sector + 1):
		var choice := sector_card(entries, number, "Normal  /  Lv. %d" % Difficulty.recommended_level(number, Difficulty.NORMAL))
		choice.set_meta(&"return_focus", "sector/%d" % number)
		choice.custom_minimum_size.y = 112
		choice.pressed.connect(func():
			selected_sector = number
			show_mission_intel(intel, connected, cooperative)
			var action := intel.get_node_or_null("Deploy") as Button
			if action and not action.disabled:
				action.grab_focus()
		)
		choice.focus_entered.connect(func():
			selected_sector = number
			show_mission_intel(intel, connected, cooperative)
		)
		if number == selected_sector:
			choice.grab_focus()
	show_mission_intel(intel, connected, cooperative)

func refresh_deployment() -> void:
	if is_visible_in_tree() and page in ["Sector select", "Level select", "Co-op Sectors"]:
		show_page(page)

func show_mission_intel(panel: VBoxContainer, connected: bool, can_deploy: bool) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var sector := Catalog.info(selected_sector)
	UI.label(panel, "MISSION INTEL", 22, UI.CYAN)
	UI.label(panel, sector.title, 31)
	add_stat_group(panel, "SECTOR", "%02d" % selected_sector)
	add_stat_group(panel, "ROUTE", "Act I → Act II")
	add_stat_group(panel, "BOSS", sector.boss)
	add_stat_group(panel, "ELEMENT", sector.element)
	add_stat_group(panel, "SUIT REWARD", sector.reward_name)
	UI.label(panel, Story.briefing(selected_sector), 16, UI.MUTED)
	var reference := HBoxContainer.new()
	reference.add_theme_constant_override("separation", 8)
	panel.add_child(reference)
	UI.button(reference, "Challenges", show_page.bind("Sector Challenges"), false, 32).set_meta(&"return_focus", "sector-challenges")
	var loot_unlocked: bool = profile.loot_clears.has(selected_sector)
	var loot := UI.button(reference, "Loot Intel", show_page.bind("Sector Loot"), false, 32)
	loot.set_meta(&"return_focus", "sector-loot")
	loot.disabled = not loot_unlocked
	loot.tooltip_text = "Extract from this sector to unlock its drop tables." if not loot_unlocked else ""
	if not deploy_error.is_empty():
		UI.label(panel, deploy_error, 17, Color("ff9e95"))
	var hunt: String = profile.pinned_blueprint
	if profile.can_collect_blueprint(hunt):
		var recipe: Dictionary = Profile.GEAR[hunt]
		var source: String = Catalog.info(recipe.sector).title
		var minimum: int = profile.blueprint_min_mode(hunt)
		if minimum >= 0:
			UI.label(panel, "Pinned  ·  %s\n%s, %s+  ·  Operator Lv. %d  ·  %d/%d clears" % [
				recipe.name, source, Difficulty.NAMES[minimum], recipe.level, profile.blueprint_hunts.get(hunt, 0), Profile.HUNT_CLEARS,
			], 15, UI.CYAN)
	if connected and not can_deploy:
		UI.label(panel, "The party leader chooses when to deploy.", 17, UI.MUTED)
		return
	if not connected and can_load and selected_sector == saved_sector and not at_sector_start:
		UI.label(panel, "Resume this checkpoint to continue on the difficulty shown below.", 16, UI.MUTED)
		add_stat_group(panel, "RECOMMENDED", "%s  /  Lv. %d" % [Difficulty.NAMES[saved_difficulty], Difficulty.recommended_level(selected_sector, saved_difficulty)])
		var resume := UI.button(panel, "Resume Checkpoint", func(): load_requested.emit(), true)
		resume.name = "Deploy"
		return
	var mode := OptionButton.new()
	var hard_available: bool = profile.hard_unlocked(selected_sector) and (not connected or RiftRelay.party_can_play_difficulty(selected_sector, Difficulty.HARD))
	var expert_available: bool = profile.nightmare_unlocked() and (not connected or RiftRelay.party_can_play_difficulty(selected_sector, Difficulty.NIGHTMARE))
	for index in Difficulty.NAMES.size():
		var locked := (index == Difficulty.HARD and not hard_available) or (index == Difficulty.NIGHTMARE and not expert_available)
		mode.add_item("%s  /  Lv. %d%s" % [Difficulty.NAMES[index], Difficulty.recommended_level(selected_sector, index), "  /  Locked" if locked else ""])
		mode.set_item_disabled(index, locked)
	if mode.is_item_disabled(selected_difficulty):
		selected_difficulty = Difficulty.HARD if hard_available else Difficulty.NORMAL
	mode.select(selected_difficulty)
	panel.add_child(mode)
	UI.style_button(mode)
	var difficulty_hint := UI.label(panel, "", 16, UI.MUTED)
	var refresh := func(index: int):
		selected_difficulty = index
		difficulty_hint.text = "Recommended Lv. %d  ·  %.2f× enemy HP and damage  ·  +%d%% enemy movement%s" % [
			Difficulty.recommended_level(selected_sector, index), Difficulty.combat_scale(selected_sector, index),
			roundi((Difficulty.enemy_speed_scale(selected_sector, index) - 1.0) * 100),
			"  ·  Better rare loot" if index > Difficulty.NORMAL else "",
		]
	refresh.call(selected_difficulty)
	mode.item_selected.connect(refresh)
	if not hard_available:
		UI.label(panel, "Everyone must clear this sector on Normal to unlock Hard." if connected else "Clear this sector on Normal to unlock Hard.", 15, UI.MUTED)
	if not expert_available:
		var unlock_text := "Everyone must clear all sectors on Hard to unlock Expert." if connected else "Clear all sectors on Hard to unlock Expert (%d / %d)." % [profile.hard_clear_count(), Catalog.SECTORS.size()]
		UI.label(panel, unlock_text, 15, UI.MUTED)
	var button := UI.button(panel, "Deploy", func(): sector_requested.emit(selected_sector, selected_difficulty), true)
	button.name = "Deploy"

func sector_card(entries: GridContainer, number: int, state: String) -> Button:
	var sector := Catalog.info(number)
	var accent := Color(sector.color)
	var choice := Button.new()
	entries.add_child(choice)
	UI.style_button(choice)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size.y = 166.0
	choice.clip_contents = true
	choice.tooltip_text = "%s · %s" % [sector.title, state]
	var art := TextureRect.new()
	var art_path := "res://assets/campaign/%s/panorama.png" % sector.id
	if number == 1:
		art_path = "res://assets/neon_factory/foundry/foundry_panorama.jpg"
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
	var list := card(columns, 1.25)
	var materials := card(columns, 0.75)
	UI.label(list, "Known Recipes", 30, UI.CYAN)
	UI.label(list, "OPERATOR LV. %d" % profile.operator_level, 18, Color("ffd079"))
	var filter := OptionButton.new()
	list.add_child(filter)
	UI.style_button(filter)
	var filters: Array = [""] + Profile.GEAR_SLOTS.keys()
	for slot in filters:
		filter.add_item(Profile.GEAR_SLOTS.get(slot, "All equipment"))
	filter.custom_minimum_size.x = 155
	filter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filter.select(maxi(0, filters.find(inventory_slot)))
	filter.item_selected.connect(func(index: int):
		inventory_slot = filters[index]
		show_page("Fabrication")
	)
	var items: Array[String] = []
	for id in Profile.GEAR:
		if profile.blueprints.has(id) and (inventory_slot.is_empty() or Profile.GEAR[id].slot == inventory_slot):
			items.append(id)
	build_item_grid(list, items, true, 8)
	UI.label(materials, "Materials in Storage", 26, UI.CYAN)
	var stock := scroll_entries(materials)
	for id in profile.materials:
		if int(profile.materials[id]) > 0:
			add_stat_group(stock, Materials.label(id), str(profile.materials[id]))
	if stock.get_child_count() == 0:
		UI.label(stock, "No materials yet. Extract with salvage or buy materials and stow them from Inventory.", 17, UI.MUTED)
	if not inventory_status.is_empty():
		UI.label(materials, inventory_status, 16, UI.VIOLET)

func build_item_grid(parent: VBoxContainer, items: Array[String], blueprints: bool, max_columns: int) -> void:
	if items.is_empty():
		UI.label(parent, "No recipes in this category. Learn recovered blueprints from Storage." if blueprints else "No gear available.", 16, UI.MUTED)
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
		var columns := UI.item_grid_columns(entries.get_parent(), max_columns)
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
		var required: int = profile.crafting_level(id)
		return "Lv. %d" % required if profile.operator_level < required else "Blueprint"
	return ""

func scroll_entries(parent: VBoxContainer) -> VBoxContainer:
	return UI.scroll_entries(parent)

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
	var state: Dictionary = navigation_state.get(page, {})
	if not state.is_empty():
		state.focus = "recipe/" + id
	show_page("Craft Item")

func build_purchase(columns: HBoxContainer) -> void:
	var form := card(columns, 1.12)
	UI.label(form, "Review Blueprint", 32, UI.CYAN)
	item_card(form, shop_item)
	UI.label(form, "OPERATOR LEVEL  %d / %d" % [profile.operator_level, profile.crafting_level(shop_item)], 17, UI.CYAN)
	var bill: Dictionary = profile.recipe_materials(shop_item)
	for material in bill:
		var available := int(profile.materials.get(material, 0))
		UI.label(form, "%s  %d / %d" % [Materials.label(material), available, bill[material]], 17,
			UI.WHITE if available >= int(bill[material]) else UI.VIOLET)
	var storage_limit: String = profile.craft_limit(shop_item)
	var equip_limit: String = profile.craft_limit(shop_item, true)
	var replaced: String = profile.equipped_for(Profile.GEAR[shop_item].slot)
	if not equip_limit.is_empty() and equip_limit == storage_limit:
		UI.label(form, equip_limit, 16, UI.VIOLET)
	elif not replaced.is_empty() and equip_limit.is_empty():
		UI.label(form, "Equipping sends %s to Storage." % Profile.GEAR[replaced].name, 16, UI.MUTED)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	form.add_child(choices)
	var equip := UI.button(choices, "Craft & Equip", confirm_gear_purchase.bind(true) if equip_limit.is_empty() else Callable(), true)
	var store := UI.button(choices, "Craft to Storage", confirm_gear_purchase.bind(false) if storage_limit.is_empty() else Callable())
	equip.tooltip_text = equip_limit
	store.tooltip_text = storage_limit
	if equip_limit != storage_limit:
		UI.label(form, equip_limit if not equip_limit.is_empty() else storage_limit, 16, UI.MUTED)
	UI.button(form, "Cancel", show_page.bind("Fabrication")).grab_focus()
	portrait(card(columns))

func confirm_gear_purchase(equip_now: bool) -> void:
	inventory_status = profile.craft(shop_item, equip_now)
	show_page("Fabrication")

func build_gear(columns: HBoxContainer) -> void:
	var fitted := card(columns, 0.93)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	fitted.add_child(heading)
	var title := UI.label(heading, "RX-07 Equipment", 28, UI.CYAN)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level := UI.label(heading, "Operator Lv. %02d" % profile.operator_level, 18, UI.WHITE)
	level.autowrap_mode = TextServer.AUTOWRAP_OFF
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var body := EquipmentBody.new()
	fitted.add_child(body)
	body.install(profile, equipment_slot, func(slot: String):
		equipment_slot = slot
		focused_item = profile.equipped_for(slot)
		show_page("Gear")
	)
	var actor: RiftPlayer = body.preview_actor
	EquipmentStats.apply(actor, profile)
	actor.gain_experience(saved_experience, false)
	add_stat_group(fitted, "DMG", "%.1f buster  /  %.1f blade" % [actor.buster_power(), actor.buster_power() * actor.melee_multiplier])
	add_stat_group(fitted, "DEF", "%.1f%% reduction" % (100.0 - actor.mitigate_damage(100.0)))
	add_stat_group(fitted, "ENG  /  HP", "%.0f energy  /  %.0f max health" % [actor.max_energy, actor.max_health])
	add_stat_group(fitted, "SPD", "%.1f run  /  %.1f dash" % [actor.move_speed, actor.dash_speed])

	var equipment := card(columns, 1.25)
	if not inventory_status.is_empty():
		UI.label(equipment, inventory_status, 16, UI.VIOLET)
	if equipment_slot.is_empty():
		UI.label(equipment, "SELECT AN EQUIPMENT SLOT", 24, UI.CYAN)
		UI.label(equipment, "Choose a socket to check equipped gear and see compatible items.", 17, UI.MUTED)
		body.buttons.visor.grab_focus()
		return

	UI.label(equipment, "%s socket" % Profile.GEAR_SLOTS[equipment_slot], 24, UI.CYAN)
	var first_item := build_storage_items(equipment, storage_items(), equipment_slot)
	if first_item:
		for socket in ["core", "arm"]:
			var button: Button = body.buttons[socket]
			button.focus_neighbor_right = button.get_path_to(first_item)
		first_item.focus_neighbor_left = first_item.get_path_to(body.buttons.core)
		first_item.grab_focus()
	else:
		body.buttons[equipment_slot].grab_focus()

func build_storage_transfer(columns: HBoxContainer) -> void:
	var inventory_panel := card(columns)
	var storage_panel := card(columns)
	UI.label(inventory_panel, "Inventory", 28, UI.CYAN)
	UI.label(inventory_panel, "Choose an item to stow it or assign it to a quick slot.", 17, UI.MUTED)
	UI.label(storage_panel, "Storage", 28, UI.CYAN)
	UI.label(storage_panel, "%d / %d gear stowed" % [profile.stored_count(), profile.storage_capacity()], 17, UI.MUTED)
	var carried := build_storage_items(inventory_panel, storage_items(true), "", true)
	var stored := build_storage_items(storage_panel, storage_items())
	if carried and stored:
		carried.focus_neighbor_right = carried.get_path_to(stored)
		stored.focus_neighbor_left = stored.get_path_to(carried)
	if carried:
		carried.grab_focus()
	elif stored:
		stored.grab_focus()
	if not inventory_status.is_empty():
		UI.label(inventory_panel, inventory_status, 16, UI.VIOLET)
	UI.label(storage_panel, "QUICK SLOTS", 16, UI.CYAN)
	build_quick_assignments(storage_panel)

func open_storage_item(parent: VBoxContainer, origin: Button, id: String, item: Dictionary, carried: bool) -> void:
	if is_instance_valid(item_actions):
		item_actions.get_parent().remove_child(item_actions)
		item_actions.queue_free()
	item_origin = origin
	item_actions = UI.column(parent, 4)
	var row := HBoxContainer.new()
	item_actions.add_child(row)
	var first: Button
	var reopen := func(action: Callable):
		origin.grab_focus()
		inventory_status = action.call()
		show_page("Storage")
	if carried:
		first = UI.button(row, "Stow Stack", reopen.bind(profile.stow_purchase.bind(id)), true, 33)
	if item.kind == "Blueprints":
		first = UI.button(row, "Learn Blueprint", func():
			origin.grab_focus()
			pending_blueprint = id.trim_prefix("blueprint/")
			show_page("Learn Blueprint")
		, true, 33)
	if item.kind == "Supplies":
		var slots := HBoxContainer.new()
		item_actions.add_child(slots)
		slots.hide()
		var source := &"inventory" if carried else &"storage"
		for index in 4:
			var direction: String = ["↑", "←", "→", "↓"][index]
			var target := UI.button(slots, direction, reopen.bind(profile.assign_quick.bind(index, id, source)), false, 33)
			target.tooltip_text = "Assign to D-pad " + ["Up", "Left", "Right", "Down"][index]
			if index == 0:
				var pick := UI.button(row, "Assign Quick Slot", func():
					slots.show()
					target.grab_focus()
				, first == null, 33)
				if not first:
					first = pick
	if not first:
		item_actions.queue_free()
		item_actions = null
		return
	UI.button(row, "Cancel", leave_page, false, 33)
	first.grab_focus()

func storage_items(carried := false) -> Dictionary:
	var items := {}
	for id in ([] if carried else Profile.GEAR.keys()):
		var gear: Dictionary = Profile.GEAR[id]
		if profile.gear.has(id):
			items[id] = {"kind": "Equipment", "name": gear.name, "slot": gear.slot, "icon": EquipmentIcons.icon(id, gear.slot),
				"rarity": gear.rarity, "detail": gear.perk, "badge": item_status(id, false)}
		if profile.blueprint_items.has(id):
			items["blueprint/" + id] = {"kind": "Blueprints", "name": gear.name + " Blueprint", "slot": "", "icon": EquipmentIcons.icon(id, gear.slot),
				"rarity": gear.rarity, "detail": "Learn this blueprint to unlock its recipe in Crafting.", "badge": "Recipe", "id": id}
	for id in Profile.stock:
		var item: Dictionary = Profile.stock[id]
		var material: bool = item.has("material")
		var quantity: int = profile.supply_owned(id) if carried else int(profile.materials.get(item.material, 0) if material else profile.stored_supplies.get(id, 0))
		if quantity > 0:
			items[id] = {"kind": "Materials" if material else "Supplies", "name": item.name, "slot": "", "icon": EquipmentIcons.icon(item.icon, item.icon),
				"rarity": item.rarity, "detail": "Used to fabricate equipment." if material else item.detail, "badge": "×%d" % quantity}
	return items

func build_storage_items(parent: VBoxContainer, items: Dictionary, slot := "", inventory_side := false) -> Button:
	var entries := scroll_entries(parent)
	var scroll := entries.get_parent() as ScrollContainer
	scroll.custom_minimum_size.y = UI.ITEM_SIZE + UI.ITEM_GAP
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UI.ITEM_GAP)
	grid.add_theme_constant_override("v_separation", UI.ITEM_GAP)
	entries.add_child(grid)

	var title := UI.label(parent, "", 20, UI.CYAN)
	var description := UI.label(parent, "", 16, UI.MUTED)
	var action: Button
	if not slot.is_empty():
		action = UI.button(parent, "", func(): apply_storage_item(focused_item), false, 34)
		action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var reveal := func(id: String):
		var item: Dictionary = items[id]
		if not inventory_side:
			focused_item = id
		title.text = item.name
		title.add_theme_color_override("font_color", Profile.RARITY_COLORS[item.rarity])
		description.text = item.detail
		if inventory_side:
			description.text = "%s  ·  %s" % [item.kind, item.badge]
		if action:
			var current: String = profile.equipped_for(item.slot)
			var required := Profile.recipe_level(id)
			action.disabled = id != current and profile.operator_level < required
			action.text = "Requires Operator Lv. %d" % required if action.disabled else (
				"Stow" if id == current else ("Equip" if current.is_empty() else "Replace " + String(Profile.GEAR[current].name)))

	var tiles := {}
	for id in items:
		var item: Dictionary = items[id]
		if not slot.is_empty() and item.slot != slot:
			continue
		var activate := func():
			reveal.call(id)
			if slot.is_empty():
				open_storage_item(parent, tiles[id], id, item, inventory_side)
			elif action and not action.disabled:
				action.grab_focus()
		var tile := UI.item_tile(grid, item.icon, Profile.RARITY_COLORS[item.rarity], item.rarity, item.badge, activate)
		tile.set_meta(&"return_focus", ("inventory/" if inventory_side else "stored/") + id)
		tile.tooltip_text = item.name
		tile.focus_entered.connect(reveal.bind(id))
		tile.mouse_entered.connect(func():
			if inventory_side:
				reveal.call(id)
		)
		tiles[id] = tile
	if tiles.is_empty():
		title.hide()
		description.hide()
		if action:
			action.hide()
		var empty := "No items in Inventory." if inventory_side else "Nothing in Storage."
		if not slot.is_empty():
			empty = "No compatible gear or installed augments for this socket."
		UI.label(entries, empty, 17, UI.MUTED)
		return null
	var selected := String(focused_item if not inventory_side and tiles.has(focused_item) else tiles.keys()[0])
	reveal.call(selected)
	var fit := func(): grid.columns = UI.item_grid_columns(scroll, 12)
	scroll.resized.connect(fit)
	fit.call_deferred()
	return tiles[selected] as Button

func apply_storage_item(id: String) -> void:
	if profile.gear.has(id):
		inventory_status = profile.move_gear(id)
	show_page(page)

func build_quick_assignments(parent: VBoxContainer) -> Array[Button]:
	var row := HBoxContainer.new()
	var buttons: Array[Button] = []
	row.add_theme_constant_override("separation", UI.ITEM_GAP)
	parent.add_child(row)
	for index in 4:
		var stack: Dictionary = profile.quick_slots[index]
		var id: String = stack.get("id", "")
		var icon := EquipmentIcons.icon("utility", "utility") if id.is_empty() else EquipmentIcons.icon(profile.stock[id].icon, profile.stock[id].icon)
		var direction: String = ["↑", "←", "→", "↓"][index]
		var button := UI.item_tile(row, icon, UI.CYAN, 0, "%s  %d/%d" % [direction, stack.get("count", 0), Profile.QUICK_MAX], Callable())
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.tooltip_text = "Select a supply to assign it to %s." % direction if id.is_empty() else "%s  ·  %s" % [direction, profile.stock[id].name]
		buttons.append(button)
	var clear := OptionButton.new()
	clear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clear.custom_minimum_size.y = 31
	row.add_child(clear)
	UI.style_button(clear)
	clear.add_item("Clear quick slot")
	clear.set_item_disabled(0, true)
	for index in 4:
		clear.add_item(["Up", "Left", "Right", "Down"][index])
		clear.set_item_disabled(index + 1, int(profile.quick_slots[index].get("count", 0)) <= 0)
	clear.select(0)
	clear.item_selected.connect(func(index: int):
		inventory_status = profile.clear_quick(index - 1)
		show_page("Storage")
	)
	return buttons

func add_stat_group(parent: VBoxContainer, category: String, values: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := UI.label(row, category, 16, UI.MUTED)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reading := UI.label(row, values, 16, UI.WHITE)
	reading.autowrap_mode = TextServer.AUTOWRAP_OFF
	reading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func build_blueprint_details(columns: HBoxContainer) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 494
	center.add_child(panel)
	var frame := panel.get_theme_stylebox("panel").duplicate() as StyleBox
	frame.content_margin_bottom = 23
	panel.add_theme_stylebox_override("panel", frame)
	var content := UI.column(panel, 10)
	var id := pending_blueprint
	if not Profile.GEAR.has(id) or not profile.blueprint_items.has(id):
		UI.label(content, "Blueprint unavailable", 27, UI.CYAN)
		return
	var known: bool = profile.blueprints.has(id)
	var required: int = profile.crafting_level(id)
	var may_learn: bool = not known and profile.operator_level >= required
	UI.label(content, "Unlock this recipe?" if page == "Learn Blueprint" else "Blueprint Details", 29, UI.CYAN)
	item_card(content, id)
	if page == "Learn Blueprint":
		UI.label(content, "Uses this blueprint to permanently unlock the recipe at the Workshop.", 17, UI.MUTED)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 9)
		content.add_child(actions)
		UI.button(actions, "Keep Blueprint", show_page.bind("Storage"), false, 34).grab_focus()
		var unlock := UI.button(actions, "Unlock Recipe", func():
			inventory_status = profile.learn_blueprint(id)
			show_page("Storage" if profile.blueprints.has(id) else "Blueprint Details")
		, true, 34)
		unlock.disabled = not may_learn
		return

	var label := "Recipe Already Unlocked" if known else ("Unlock Recipe" if may_learn else "Requires Operator Lv. %d" % required)
	var learn := UI.button(content, label, show_page.bind("Learn Blueprint") if may_learn else Callable(), true, 34)
	UI.label(content, "Unlock this item’s recipe at the Workshop.", 15, UI.MUTED)
	if not inventory_status.is_empty() and inventory_status.begins_with("Could not"):
		UI.label(content, inventory_status, 16, UI.VIOLET)
	if not learn.disabled:
		learn.grab_focus()

func build_info(columns: HBoxContainer, title: String, description: String) -> void:
	var info := card(columns, 1.25)
	UI.label(info, title, 30, UI.CYAN)
	UI.label(info, description, 19)
	portrait(card(columns))

func deploy() -> void:
	start_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(hub_tip):
		var selected := get_viewport().gui_get_focus_owner()
		if selected == null or not hub_tip.is_ancestor_of(selected):
			var buttons := hub_tip.find_children("*", "Button", true, false)
			buttons[0].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if station_panel and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var step := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		var tabs := station_tabs().keys()
		if not tabs.is_empty():
			get_viewport().set_input_as_handled()
			show_page(tabs[posmod(tabs.find(page) + step, tabs.size())])
			return
	if event.is_action_pressed("ui_cancel") and page != "Title":
		RiftAudio.play_effect(&"menu_confirm")
		leave_page()
		get_viewport().set_input_as_handled()
