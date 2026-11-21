class_name RiftTitleMenu
extends Control

signal operator_deleted(slot: int)
signal hub_drop_requested(key: String, amount: int)
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
var relay_join_form: Control
var relay_room: Label
var relay_roster: VBoxContainer
var relay_members: Label
var relay_roster_key := ""
var relay_access: OptionButton
var relay_host_form: Control
var relay_squad: Control
var relay_browser: Control
var relay_lobbies: VBoxContainer
var relay_refresh: Button
var relay_browse_note: Label
var relay_browser_key := ""

var can_load := false
var saved_sector := 1
var saved_act := 1
var saved_difficulty := 0
var saved_level := 1
var saved_experience := 0
var at_sector_start := false
var run_unlocks: Array = []
var profile
var persist_frame_purchase: Callable
var wallet_bolts: Label
var shop_status := ""
var shop_category := "All Items"
var enhancement_focus := ""
const SHOP_FILTERS := {"All Items": "visor", "Supplies": "frame", "Buffs": "utility", "Materials": "core"}
var claim_challenge_rewards: Callable
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
var station_tour_preview := false
const STATION_TAB_ICONS := {
	"Shop": "currency", "Fabrication": "craft", "Upgrades": "lightning", "Save Game": "save", "Settings": "gear",
	"Gear": "shield", "Storage": "storage", "Inventory": "storage", "Player Profile": "person", "Cosmetics": "gear", "Achievements": "leaderboard",
	"Collection": "archive", "Tutorials": "play", "Social": "person", "Party": "home", "Notifications": "warning",
}
var deploy_error := ""

const SocialPanel := preload("res://scripts/social_panel.gd")
const CoopSetup := preload("res://scripts/coop_setup.gd")
const Story := preload("res://scripts/rift_story.gd")
const FieldManual := preload("res://scripts/field_manual.gd")
const EquipmentDisplay := preload("res://scripts/equipment_display.gd")
const WardrobeStage := preload("res://scripts/wardrobe_stage.gd")
const EquipmentStats := preload("res://scripts/equipment_stats.gd")
const UI := preload("res://scripts/rift_ui.gd")
const SkinKit := preload("res://scripts/operator_skins.gd")
const Frames := preload("res://scripts/operator_frames.gd")
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
var layout: VBoxContainer
var page := "Title"
const StoryDialogue := preload("res://scripts/story_dialogue.gd")
var hub_tip: StoryDialogue
const HUB_TIPS := {
	"Sector select": ["Deploy", "Pick a sector and difficulty, or resume your last mission. Activate both Gate Relays in each act to open its boss room."],
	"Shop": ["Marketplace", "Spend Bolts on repair supplies, energy cells, buffs and materials. Better stock unlocks as your Operator Level rises."],
	"Fabrication": ["Crafting", "Learn a blueprint in Storage first. Then bring its materials here. Pick Craft & Equip to wear it now, or Craft to Storage to save it for later."],
	"Upgrades": ["Core Ascension", "Spend Core Shards to install talents. Take at least one talent in each earlier tier to unlock the next tier in that branch. Installed talents survive reconstruction."],
	"Save Game": ["Save", "Save here to keep this operator's progress. Use the Settings tab to change controls, audio or video."],
	"Gear": ["Operator", "Pick a gear socket to see what fits. In Storage, move items out of your carried inventory, learn blueprints, or assign supplies to your quick slots."],
	"Player Profile": ["Profile", "See your career stats, change your armor finish or manage your account. Finish a sector and extract to earn Profile XP."],
	"Social": ["Social", "Use Find Friends to look up an account username. Select a friend to message or invite them. Requests and invitations appear in Notifications."],
	"Challenges": ["Challenges", "Complete all five challenges for a sector for bonus Core Shards. Check the countdown before starting. The list resets at local midnight."],
	"Collection": ["NOVA Archive", "Open a sector to read the records you've recovered and see the loot you've discovered. Use Tutorials to look up a mechanic again."],
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme(true)
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
			var button := UI.button(strip, label, show_page.bind(tab_page), page == tab_page, 36)
			var icon: String = STATION_TAB_ICONS[tab_page]
			button.icon = load(UI.KIT + "icon_" + icon + ".png")
			button.add_theme_constant_override("icon_max_width", 18)
			button.custom_minimum_size.x = 104
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
			UI.label(form, "This clears all three operators, levels, shared storage, blueprints, and talents. It keeps your RIFTCORE account, username, and friends.", 20, UI.MUTED)
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
		"Inventory":
			build_hub_inventory(columns)
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
		"Achievements":
			build_achievements(columns)
		"Notifications":
			SocialPanel.build_notifications(self, columns)
		"Party":
			build_online_room(columns)
		"Collection":
			build_archive(columns)
		"Tutorials":
			build_tutorials(columns)
		"Challenges":
			build_challenges(columns, header)
		"Co-op Setup Guide":
			CoopSetup.build(card(columns, 1.75), leave_page)
			portrait(card(columns))
		"Settings":
			var settings := UI.settings(card(columns), not station_panel)
			if station_tour_preview:
				for index in settings.tabs.get_tab_count():
					if settings.tabs.get_tab_title(index) == "Gameplay":
						settings.tabs.current_tab = index
						break
			else:
				settings.initial_focus.grab_focus()
	if not checking_cloud_save and page not in ["Title", "Co-op Setup Guide", "Set up Player Profile", "Save Reset Error"]:
		var back_title := "Back to Title"
		if page in ["Create Account", "Sign In", "Offline Setup"]:
			back_title = "Back to Welcome"
		if station_panel:
			back_title = "Back to Deployment" if page in ["Level select", "New run", "Sector Loot"] else "Back to Station"
			if page == "Co-op Sectors":
				back_title = "Back to Party"
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
		back.icon = preload("res://assets/ui/riftcore_kit/icon_back.png")
		back.add_theme_constant_override("icon_max_width", 17)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if get_viewport().gui_get_focus_owner() == null:
			if selected_tab:
				selected_tab.grab_focus()
			else:
				back.grab_focus()
	if station_panel and not station_tour_preview and page == "Upgrades" and RiftSettings.show_hub_tips and not RiftSettings.seen_hub_tips.has(page):
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
		return {"Shop": "Marketplace", "Fabrication": "Crafting", "Upgrades": "Core Ascension"}
	if page in ["Save Game", "Settings"]:
		return {"Save Game": "Save Game", "Settings": "Settings"}
	if page in ["Gear", "Inventory", "Storage"]:
		return {"Gear": "Gear", "Inventory": "Inventory", "Storage": "Storage"}
	if page in ["Player Profile", "Cosmetics", "Achievements"]:
		return {"Player Profile": "Profile", "Cosmetics": "Cosmetics", "Achievements": "Achievements"}
	if page in ["Collection", "Tutorials"]:
		return {"Collection": "NOVA Archive", "Tutorials": "Tutorials"}
	if page in ["Social", "Party", "Notifications"]:
		return {"Social": "Friends", "Party": "Party", "Notifications": "Notifications"}
	return {}

func build_station_header(header: HBoxContainer) -> void:
	header.add_theme_constant_override("separation", 16)
	var wordmark := TextureRect.new()
	wordmark.texture = preload("res://assets/ui/riftcore-wordmark.svg")
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wordmark.custom_minimum_size = Vector2(178, 44)
	header.add_child(wordmark)
	var station_name := page.to_upper()
	if page in ["Shop", "Fabrication", "Upgrades", "Craft Item"]:
		station_name = "WORKSHOP"
	elif page in ["Gear", "Inventory", "Storage", "Blueprint Details", "Learn Blueprint"]:
		station_name = "OPERATOR"
	elif page in ["Save Game", "Settings"]:
		station_name = "SYSTEM"
	elif page in ["Player Profile", "Delete Profile", "Operators", "Delete Operator", "Account Settings", "Cosmetics", "Achievements"]:
		station_name = "PROFILE"
	elif page in ["Collection", "Tutorials"]:
		station_name = "NOVA ARCHIVE"
	elif page in ["Social", "Whispers", "Party", "Notifications", "Directory Account", "Directory Registration"]:
		station_name = "SOCIAL"
	elif page in ["Sector select", "Level select", "Co-op Sectors", "New run", "Sector Loot"]:
		station_name = "DEPLOY"
	var heading := UI.profile_label(header, station_name, 28, UI.CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if page == "Challenges":
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var wallet := PanelContainer.new()
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet.add_theme_stylebox_override("panel", UI.hud_frame(UI.CYAN, Vector2(12, 5)))
	header.add_child(wallet)
	var funds := HBoxContainer.new()
	funds.add_theme_constant_override("separation", 12)
	wallet.add_child(funds)
	wallet_bolts = UI.currency_row(funds, "%04d BOLTS" % profile.credits)
	funds.add_child(VSeparator.new())
	UI.currency_row(funds, "%s CORE SHARDS" % UI.shard_amount(profile.core_shards, 4), true)

func open_station(next: String, tour_preview := false) -> void:
	station_panel = true
	station_tour_preview = tour_preview
	deploy_error = ""
	inventory_status = ""
	shop_item = ""
	focused_item = ""
	equipment_slot = ""
	shop_category = "All Items"
	show()
	show_page(next)
	if not station_tour_preview and RiftRelay.connected_room.is_empty() and not is_instance_valid(hub_tip) and RiftSettings.show_hub_tips and HUB_TIPS.has(next) and not RiftSettings.seen_hub_tips.has(next):
		show_station_tip(next)

func close_tour_preview() -> void:
	station_tour_preview = false
	station_panel = false
	hide()

func show_station_tip(station: String) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var content: Array = HUB_TIPS[station]
	RiftSettings.seen_hub_tips.append(station)
	RiftSettings.save()
	var dialogue := StoryDialogue.new()
	dialogue.name = "HubTip"
	dialogue.tutorial_title = content[0]
	dialogue.disable_tips = func():
		RiftSettings.show_hub_tips = false
		RiftSettings.save()
	hub_tip = dialogue
	add_child(dialogue)
	await dialogue.play([[Story.GUIDE, content[1]]], "Got it")
	dialogue.queue_free()
	if hub_tip == dialogue:
		hub_tip = null
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	var popup := get_node_or_null("FindFriendsPopup") as Control
	if popup and popup.is_visible_in_tree():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			popup.hide()
		elif event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			get_viewport().set_input_as_handled()
		return

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
		if page in ["Level select", "New run", "Sector Loot"]:
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
	return UI.profile_panel(parent, ratio)

func portrait(parent: VBoxContainer) -> void:
	var hero := EquipmentDisplay.new()
	if account and active_slot > 0:
		hero.frame = account.display_frame(active_slot)
		hero.skin = account.display_skin(active_slot)
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
	panel.add_theme_stylebox_override("panel", UI.hud_frame(UI.CYAN, Vector2(28, 20), true))
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
	var left := UI.profile_panel(columns)
	var stage_heading := UI.profile_label(left, "", 23, UI.CYAN)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(225, 270)
	stage.clip_contents = true
	left.add_child(stage)
	var backdrop := WardrobeStage.new()
	stage.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var finish_model := EquipmentDisplay.new()
	finish_model.neutral_lighting = true
	finish_model.allow_zoom = true
	stage.add_child(finish_model)
	finish_model.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var wardrobe := UI.profile_panel(columns, 1.21)
	var heading := wardrobe_section(wardrobe, "OPERATOR APPEARANCE")
	UI.profile_label(heading, "Choose a frame and preview its finishes.", 15, UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	wardrobe.add_child(row)
	var slot := wardrobe_picker(row, "Operator")
	for number in range(1, ManualSave.SLOT_COUNT + 1):
		if number != active_slot and not ManualSave.read_slot(number):
			continue
		slot.add_item("Operator %02d" % number, number)
		if number == active_slot:
			slot.select(slot.item_count - 1)
	if slot.item_count == 0:
		slot.add_item("No operator")
		slot.disabled = true
	var frame_picker := wardrobe_picker(row, "Frame")
	var frames: Array[String] = []
	for id: String in Frames.NAMES:
		if Frames.available(id):
			frames.append(id)
			frame_picker.add_item(Frames.label(id))
	frame_picker.select(maxi(0, frames.find(account.display_frame(slot.get_selected_id()))))

	var loadout := PanelContainer.new()
	loadout.add_theme_stylebox_override("panel", UI.profile_frame(Color("10283c"), Color("345f7a"), Vector2(9, 3)))
	wardrobe.add_child(loadout)
	var info := HBoxContainer.new()
	loadout.add_child(info)
	var equipped := UI.profile_label(info, "", 15, UI.WHITE)
	equipped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_access := UI.profile_label(info, "", 15, UI.CYAN)
	var shortcuts := VBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 6)
	stage.add_child(shortcuts)
	shortcuts.position = Vector2(9, 32)
	shortcuts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var appearance := UI.button(shortcuts, "Appearance", frame_picker.grab_focus, false, 34, false)
	UI.profile_button(appearance, true)
	var options := scroll_entries(wardrobe)
	options.add_theme_constant_override("separation", 5)
	var scroll := options.get_parent() as ScrollContainer
	UI.make_readable_scroll(scroll)
	var scrollbar := scroll.get_v_scroll_bar()
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(style, UI.profile_frame(Color("659fbb") if style == "grabber" else UI.CYAN, Color.TRANSPARENT, Vector2(3, 0)))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	wardrobe.add_child(actions)
	var status := UI.profile_label(wardrobe, "", 15, UI.MUTED)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var previewed := {"id": "", "compare": false}
	var entries: Dictionary = {}
	var equip := UI.button(actions, "Equip Appearance", Callable(), true, 38)
	var purchase := UI.button(actions, "", Callable(), true, 38)
	var compare := UI.button(actions, "View Equipped", Callable(), false, 38)
	var reset := UI.button(actions, "Default Finish", Callable(), false, 38)
	for action: Button in [equip, purchase, compare, reset]:
		action.focus_mode = Control.FOCUS_ALL
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.profile_button(action, action == equip or action == purchase)

	var refresh := func():
		var selected_slot := slot.get_selected_id()
		var selected_frame := frames[frame_picker.selected]
		var id: String = previewed.id
		var current_frame: String = account.display_frame(selected_slot)
		var current_finish: String = account.display_skin(selected_slot)
		var same_appearance: bool = id == current_finish and selected_frame == current_frame
		finish_model.frame = current_frame if previewed.compare else selected_frame
		finish_model.set_appearance(current_finish if previewed.compare else id)
		stage_heading.text = "//  %s" % slot.get_item_text(slot.selected).to_upper()
		equipped.text = "Equipped  /  %s · %s" % [Frames.label(current_frame), finish_label(current_finish)] if not slot.disabled else "No operator created"
		var save := ManualSave.read_slot(selected_slot)
		var owns_frame := Frames.owned(selected_frame, save)
		var owned_count := 0
		for available_frame: String in frames:
			owned_count += int(Frames.owned(available_frame, save))
		var price := int(Frames.PRICES.get(selected_frame, 0))
		var can_purchase := selected_slot == active_slot and profile != null and persist_frame_purchase.is_valid()
		var owns_finish: bool = id.is_empty() or account.unlocked_skins.has(id)
		purchase.visible = not slot.disabled and not owns_frame
		purchase.text = "Unlock for %d Bolts" % price
		purchase.disabled = not can_purchase or int(profile.credits) < price
		equip.visible = owns_frame
		equip.disabled = slot.disabled or not owns_finish or same_appearance
		frame_access.text = "Frames owned  %d / %d" % [owned_count, frames.size()]
		compare.text = "Preview Selection" if previewed.compare else "View Equipped"
		compare.disabled = slot.disabled or same_appearance
		reset.disabled = id.is_empty() and not previewed.compare
		status.text = "Viewing equipped appearance" if previewed.compare else "Preview  /  %s · %s" % [Frames.label(selected_frame), finish_label(id)]
		if not owns_frame and not can_purchase:
			status.text = "Load this operator to purchase the frame."
		for finish: String in entries:
			var entry: Button = entries[finish]
			var badge := entry.get_node("Badge") as Label
			var is_equipped := not slot.disabled and current_frame == selected_frame and finish == current_finish
			var is_selected: bool = finish == id and not previewed.compare
			var is_owned: bool = finish.is_empty() or account.unlocked_skins.has(finish)
			badge.text = "EQUIPPED" if is_equipped else ("OWNED" if is_owned else "LOCKED")
			badge.add_theme_color_override("font_color", UI.CYAN if is_equipped else (UI.WHITE if is_owned else UI.MUTED))
			entry.button_pressed = is_selected

	var preview := func(id: String):
		previewed.id = id
		previewed.compare = false
		refresh.call()
	compare.pressed.connect(func():
		previewed.compare = not previewed.compare
		refresh.call()
	)
	reset.pressed.connect(func():
		preview.call("")
		scroll.scroll_vertical = 0
	)
	purchase.pressed.connect(func():
		if purchase.disabled:
			return
		var message: String = profile.buy_frame(frames[frame_picker.selected], persist_frame_purchase)
		if is_instance_valid(wallet_bolts):
			wallet_bolts.text = "%04d BOLTS" % profile.credits
		preview.call(previewed.id)
		status.text = message
	)
	equip.pressed.connect(func():
		var id: String = previewed.id
		if account.select_appearance(slot.get_selected_id(), frames[frame_picker.selected], id) == OK:
			preview.call(id)
			status.text = "Appearance saved."
		else:
			status.text = "Could not save the appearance."
	)
	frame_picker.item_selected.connect(func(_index): preview.call(previewed.id))
	slot.item_selected.connect(func(_index):
		frame_picker.select(maxi(0, frames.find(account.display_frame(slot.get_selected_id()))))
		preview.call(account.display_skin(slot.get_selected_id()))
	)
	var group := ButtonGroup.new()
	var add_finish := func(id: String, requirement: String):
		entries[id] = add_finish_entry(options, group, id, requirement, preview)

	var milestone := wardrobe_section(options, "MILESTONE FINISHES")
	add_finish.call("", "Standard operator finish.")
	for number in range(1, SkinKit.FIELD_VARIANTS.size() + 1):
		var id := SkinKit.field_finish(number)
		add_finish.call(id, SkinKit.palette(id)[5])
	var expert := wardrobe_section(options, "EXPERT FINISHES")
	for number in range(1, Catalog.SECTORS.size() + 1):
		var id := SkinKit.expert_finish(number)
		add_finish.call(id, SkinKit.expert_requirement(number))
	var suits: Array[String] = []
	var legacy: Array[String] = []
	for id: String in account.unlocked_skins:
		if SkinKit.LEGACY_FINISHES.has(id):
			legacy.append(id)
		elif not Catalog.weapon(id).is_empty():
			suits.append(id)
	if not suits.is_empty():
		wardrobe_section(options, "BOSS APPEARANCES")
		for id in suits:
			add_finish.call(id, "Extract from its sector twice on Hard or Expert.")
	if not legacy.is_empty():
		wardrobe_section(options, "PREVIOUSLY OWNED FINISHES")
		for id in legacy:
			add_finish.call(id, "Previously unlocked.")
	for section: VBoxContainer in [milestone, expert]:
		var jump := UI.button(shortcuts, "Milestone" if section == milestone else "Expert", func(): scroll.ensure_control_visible(section), false, 34, false)
		jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.profile_button(jump)
	preview.call(account.display_skin(slot.get_selected_id()))
	if not slot.disabled:
		slot.grab_focus()

func wardrobe_picker(parent: HBoxContainer, caption: String) -> OptionButton:
	var field := UI.column(parent, 3)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.profile_label(field, caption, 16, UI.MUTED)
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 34
	UI.profile_button(picker)
	field.add_child(picker)
	return picker

func wardrobe_section(parent: VBoxContainer, caption: String) -> VBoxContainer:
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", UI.profile_frame(Color("102740"), Color("2c789b"), Vector2(8, 4)))
	parent.add_child(ribbon)
	var content := UI.column(ribbon, 2)
	UI.profile_label(content, "//  " + caption, 22, UI.WHITE)
	return content

func finish_label(id: String) -> String:
	return "Default Finish" if id.is_empty() else SkinKit.label(id)

func add_finish_entry(parent: VBoxContainer, group: ButtonGroup, id: String, requirement: String, preview: Callable) -> Button:
	var pick := UI.button(parent, finish_label(id), preview.bind(id), false, 48, false)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.tooltip_text = requirement
	pick.toggle_mode = true
	pick.button_group = group
	pick.add_theme_font_size_override("font_size", 18)
	var idle := UI.profile_frame(Color("0b1b2c"), Color("385a79"), Vector2(66, 3))
	var hover := UI.profile_frame(Color("0e2538"), Color("6eabc9"), Vector2(66, 3))
	var selected := UI.profile_frame(Color("10344a"), UI.CYAN, Vector2(66, 3), true)
	for style in [idle, hover, selected]:
		style.content_margin_bottom = 18
	UI.set_button_states(pick, idle, hover, selected)
	pick.add_theme_stylebox_override("hover_pressed", selected)
	pick.focus_entered.connect(preview.bind(id))

	var swatch := Panel.new()
	var colors := SkinKit.palette(id)
	var primary := Color(colors[1]) if not colors.is_empty() else Color("c8d9ec")
	var trim := Color(colors[2]) if not colors.is_empty() else Color("304970")
	swatch.add_theme_stylebox_override("panel", UI.profile_frame(primary.lightened(0.12), Color("6888a5"), Vector2.ZERO))
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick.add_child(swatch)
	swatch.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	swatch.offset_left = 12
	swatch.offset_right = 54
	swatch.offset_top = -14
	swatch.offset_bottom = 14
	swatch.draw.connect(func():
		var rect := Rect2(Vector2(2, 2), swatch.size - Vector2(4, 4))
		var start := rect.position + Vector2(rect.size.x * 0.7, 0)
		draw_swatch_trim(swatch, rect, start, trim)
	)
	var detail := UI.profile_label(pick, requirement, 14, UI.MUTED)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	detail.offset_left = 66
	detail.offset_right = -105
	detail.offset_top = -21
	detail.offset_bottom = -4
	var badge := UI.profile_label(pick, "", 15, UI.MUTED)
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	badge.offset_left = -101
	badge.offset_right = -13
	badge.offset_top = -12
	badge.offset_bottom = 12
	return pick

func draw_swatch_trim(swatch: Control, rect: Rect2, start: Vector2, trim: Color) -> void:
	var points := PackedVector2Array([start, Vector2(rect.end.x - 3, rect.position.y), Vector2(rect.end.x, rect.position.y + 3), Vector2(rect.end.x, rect.end.y - 3), Vector2(rect.end.x - 3, rect.end.y), Vector2(rect.position.x + rect.size.x * 0.42, rect.end.y)])
	swatch.draw_colored_polygon(points, trim)

func build_achievements(columns: HBoxContainer) -> void:
	var ledger = RiftRelay.directory.gamer_score
	var pane := UI.profile_panel(columns)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	pane.add_child(header)
	var heading := UI.column(header, 1)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.profile_label(heading, "//  ACHIEVEMENTS", 29, UI.CYAN)
	var progress := UI.profile_label(heading, "", 17, UI.MUTED)
	var score_panel := PanelContainer.new()
	score_panel.add_theme_stylebox_override("panel", UI.profile_frame(Color("221a36"), UI.VIOLET.darkened(0.27), Vector2(14, 6)))
	header.add_child(score_panel)
	var score_copy := UI.column(score_panel, 0)
	var score_caption := UI.profile_label(score_copy, "GAMER SCORE", 13, UI.MUTED)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var score := UI.profile_label(score_copy, "", 22, UI.VIOLET)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pane.add_child(HSeparator.new())
	var rows := scroll_entries(pane)
	rows.add_theme_constant_override("separation", 6)
	var scroll := rows.get_parent() as ScrollContainer
	UI.make_readable_scroll(scroll)
	var displayed := {"state": []}
	var rebuild := func():
		var online := RiftRelay.directory.online()
		var local_finishes: Array = account.unlocked_skins if account != null else []
		var state: Array = [online, ledger.earned.duplicate() if online else [], local_finishes.duplicate()]
		if displayed.state == state:
			return
		displayed.state = state
		var previous_offset := scroll.scroll_vertical
		var focused := get_viewport().gui_get_focus_owner()
		var focused_id: String = focused.get_meta(&"achievement_id", "") if focused else ""
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		score_panel.visible = online
		score.text = "%d / %d G" % [ledger.score(), ledger.score_limit] if online else ""
		score.tooltip_text = "Gamer Score"
		var total_earned := 0
		for id in ledger.achievement_catalog:
			var record: Array = ledger.achievement_catalog[id]
			var earned: bool = (online and ledger.earned.has(id)) or local_finishes.has(id)
			total_earned += int(earned)
			var tile := PanelContainer.new()
			var accent := UI.CYAN if earned else Color("365978")
			var fill := Color("102b3b") if earned else Color("0c1d30")
			var style := UI.profile_frame(fill, accent, Vector2(12, 7))
			var highlighted := UI.profile_frame(fill.lightened(0.06), UI.CYAN, Vector2(12, 7), true)
			tile.add_theme_stylebox_override("panel", style)
			tile.focus_mode = Control.FOCUS_ALL
			tile.set_meta(&"achievement_id", id)
			tile.focus_entered.connect(func(): tile.add_theme_stylebox_override("panel", highlighted))
			tile.focus_exited.connect(func(): tile.add_theme_stylebox_override("panel", style))
			rows.add_child(tile)
			if focused_id == id:
				tile.grab_focus.call_deferred()
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			tile.add_child(row)
			var icon := TextureRect.new()
			icon.texture = preload("res://assets/ui/riftcore_kit/icon_leaderboard.png")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(33, 33)
			icon.modulate = UI.CYAN if earned else UI.MUTED
			row.add_child(icon)
			var copy := UI.column(row, 1)
			copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UI.profile_label(copy, record[0], 21)
			UI.label(copy, record[2], 16, UI.MUTED)
			var badge := UI.profile_label(row, "%d G  /  %s" % [record[1], "EARNED" if earned else "LOCKED"], 16, UI.CYAN if earned else UI.MUTED)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress.text = "%d / %d earned" % [total_earned, ledger.achievement_catalog.size()]
		if not online:
			progress.text += "  ·  Sign in to earn Gamer Score"
		scroll.set_deferred("scroll_vertical", previous_offset)
	SocialPanel.watch(pane, RiftRelay.directory.changed, rebuild)
	rebuild.call()

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
	var form := card(columns,0.9)
	UI.label(form, "PARTY", 30, UI.CYAN).autowrap_mode=TextServer.AUTOWRAP_OFF
	relay_status = UI.label(form, "", 18, UI.CYAN)
	relay_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	form.add_child(HSeparator.new())
	relay_host_form = UI.column(form, 8)
	UI.label(relay_host_form, "HOST A LOBBY", 17, UI.MUTED)
	relay_access = OptionButton.new()
	relay_host_form.add_child(relay_access)
	UI.style_button(relay_access)
	for access: String in RiftRelay.PARTY_ACCESS:
		relay_access.add_item(RiftRelay.PARTY_ACCESS[access])
		relay_access.set_item_metadata(relay_access.item_count - 1, access)
	relay_access.select(0)
	relay_host = UI.button(relay_host_form, "Host Lobby", func():
		RiftRelay.host_room(String(relay_access.get_selected_metadata()))
	, true)
	relay_rejoin = UI.button(form, "Rejoin Party", RiftRelay.rejoin_party, true)
	relay_join_form=UI.column(form,8)
	UI.label(relay_join_form,"JOIN WITH A CODE",16,UI.MUTED).autowrap_mode=TextServer.AUTOWRAP_OFF
	relay_code = LineEdit.new()
	relay_code.placeholder_text = "Enter your friend's room code"
	relay_code.max_length = 14
	relay_code.custom_minimum_size.y=38
	relay_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relay_code.text_submitted.connect(RiftRelay.join_room)
	relay_join_form.add_child(relay_code)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	relay_join_form.add_child(join_row)
	relay_paste = UI.button(join_row, "Paste Code", func():
		relay_code.text = DisplayServer.clipboard_get().strip_edges().left(relay_code.max_length)
		relay_code.grab_focus()
		relay_code.caret_column = relay_code.text.length()
	)
	relay_join = UI.button(join_row, "Join Lobby", func(): RiftRelay.join_room(relay_code.text))
	relay_room=UI.label(form,"",24,UI.WHITE)
	relay_room.autowrap_mode=TextServer.AUTOWRAP_OFF
	relay_deploy = UI.button(form, "Choose Co-op Sector", show_page.bind("Co-op Sectors"), true)
	relay_deploy.set_meta(&"return_focus", "choose-coop-sector")
	relay_copy = UI.button(form, "Copy Room Code", func(): DisplayServer.clipboard_set(RiftRelay.connected_room))
	UI.button(form, "Friends", show_page.bind("Social"), false, 36)
	var space:=Control.new()
	space.size_flags_vertical=Control.SIZE_EXPAND_FILL
	form.add_child(space)
	relay_leave = UI.button(form, "Leave Party", func(): RiftRelay.leave())
	var right := card(columns, 1.1)
	relay_browser = UI.column(right, 9)
	relay_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var browser_header := HBoxContainer.new()
	relay_browser.add_child(browser_header)
	var heading := UI.label(browser_header, "OPEN LOBBIES", 26, UI.CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relay_refresh = UI.button(browser_header, "Refresh", RiftRelay.browse_rooms, false, 34)
	relay_browse_note = UI.label(relay_browser, "", 16, UI.MUTED)
	relay_lobbies = scroll_entries(relay_browser)
	relay_browser_key = "!"
	var squad := UI.column(right, 8)
	relay_squad = squad
	relay_squad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	relay_members=UI.label(squad,"SQUAD  /  0 OF 4",26,UI.CYAN)
	relay_members.autowrap_mode=TextServer.AUTOWRAP_OFF
	UI.label(squad,"The party leader selects the sector. Everyone keeps their own operator.",16,UI.MUTED)
	relay_roster=scroll_entries(squad)
	relay_roster_key=""
	refresh_online_room()
	if RiftRelay.connected_room.is_empty():
		RiftRelay.browse_rooms()
	var browser_timer := Timer.new()
	right.add_child(browser_timer)
	browser_timer.timeout.connect(func():
		if RiftRelay.connected_room.is_empty() and RiftRelay.pending.is_empty():
			RiftRelay.browse_rooms()
	)
	browser_timer.start(12.0)
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
	relay_host_form.visible = not joined and not requesting
	relay_host.visible = relay_host_form.visible
	relay_browser.visible = not joined
	relay_squad.visible = joined
	relay_refresh.disabled = not RiftRelay.available or RiftRelay.browsing_rooms or requesting
	relay_browse_note.text = RiftRelay.lobby_browse_status if RiftRelay.available else RiftRelay.RELAY_UNAVAILABLE
	refresh_lobby_list(requesting)
	relay_join_form.visible=not joined
	relay_host.disabled = not RiftRelay.available or joined or requesting
	relay_join.disabled = relay_host.disabled
	relay_rejoin.visible = RiftRelay.can_rejoin_party()
	relay_paste.disabled = relay_join.disabled
	relay_code.editable = not joined and not requesting
	relay_deploy.visible = RiftRelay.can_deploy()
	relay_copy.visible = joined and RiftRelay.room_password.is_empty()
	relay_room.visible = joined
	var access: String = RiftRelay.PARTY_ACCESS.get(RiftRelay.room_access, "Room Code")
	relay_room.text = access.to_upper() if not RiftRelay.room_password.is_empty() else "%s  /  %s" % [access.to_upper(), RiftRelay.connected_room]
	relay_leave.visible = joined or requesting
	relay_leave.text = "Leave Party" if joined else "Cancel Connection"
	relay_status.text = RiftRelay.status
	refresh_party_members()
	var focused:=get_viewport().gui_get_focus_owner()
	# Presence updates must not pull focus away while a user types a room code.
	if focused and focused.is_visible_in_tree() and (not focused is BaseButton or not focused.disabled): return
	if relay_deploy.visible: relay_deploy.grab_focus()
	elif joined and relay_copy.visible: relay_copy.grab_focus()
	elif joined: relay_leave.grab_focus()
	elif requesting: relay_leave.grab_focus()
	elif relay_rejoin.visible: relay_rejoin.grab_focus()
	elif not relay_host.disabled: relay_host.grab_focus()

func refresh_lobby_list(requesting: bool) -> void:
	var key := str([RiftRelay.public_rooms, requesting])
	if key == relay_browser_key:
		return
	relay_browser_key = key
	var focused := get_viewport().gui_get_focus_owner()
	var restore_focus := focused != null and relay_lobbies.is_ancestor_of(focused)
	for child in relay_lobbies.get_children():
		relay_lobbies.remove_child(child)
		child.queue_free()
	var first: Button
	for room in RiftRelay.public_rooms:
		var row := HBoxContainer.new()
		relay_lobbies.add_child(row)
		var host := UI.label(row, "%s  ·  %d/%d" % [room.host, room.players, room.limit], 20, UI.WHITE)
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var join := UI.button(row, "Join", RiftRelay.join_room.bind(room.code), true, 34)
		join.disabled = requesting
		if not first:
			first = join
	if restore_focus:
		if first and not first.disabled:
			first.grab_focus()
		elif not relay_refresh.disabled:
			relay_refresh.grab_focus()

func refresh_party_members() -> void:
	var members: Array=[]
	if not RiftRelay.connected_room.is_empty() and is_instance_valid(RiftRelay.relay):
		var local_id: int=RiftRelay.relay.get_client_id()
		var leader: int=RiftRelay.relay.get_host()
		for id in RiftRelay.relay.lobby_get_all_clients():
			var username:=RiftRelay.local_name if id==local_id else String(RiftRelay.relay.player_get_data(id,"operator_name","Connecting…"))
			members.append({"name":Profile.clean_operator_name(username),"leader":id==leader,"local":id==local_id})
		members.sort_custom(func(a,b): return a.leader and not b.leader)
	var key:=str(members)
	if key==relay_roster_key: return
	relay_roster_key=key
	relay_members.text="SQUAD  /  %d OF 4"%members.size()
	for child in relay_roster.get_children():
		relay_roster.remove_child(child)
		child.queue_free()
	for index in 4:
		var occupied:=index<members.size()
		var plate:=UI.equipment_card(UI.PARTY_COLORS[index] if occupied else UI.MUTED.darkened(.5))
		relay_roster.add_child(plate)
		plate.custom_minimum_size.y=62
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		plate.add_child(row)
		var slot:=UI.label(row,"%02d"%(index+1),24,UI.PARTY_COLORS[index] if occupied else UI.MUTED)
		slot.autowrap_mode=TextServer.AUTOWRAP_OFF
		var copy:=UI.column(row,1)
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var username:=UI.label(copy,members[index].name if occupied else "Open slot",21,UI.WHITE if occupied else UI.MUTED)
		username.autowrap_mode=TextServer.AUTOWRAP_OFF
		username.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		UI.label(copy,("Party leader" if members[index].leader else "Party member") if occupied else "Invite a friend to join",14,UI.MUTED).autowrap_mode=TextServer.AUTOWRAP_OFF
		if occupied and members[index].local:
			UI.label(row,"YOU",14,UI.CYAN).autowrap_mode=TextServer.AUTOWRAP_OFF

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
			model.frame = account.display_frame(number) if account else ""
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
	UI.label(heading, "Marketplace", 31, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
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
		, category == shop_category, 34)
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

func build_challenges(columns: HBoxContainer, header: HBoxContainer) -> void:
	var clock_panel := PanelContainer.new()
	clock_panel.custom_minimum_size.x = 196
	clock_panel.add_theme_stylebox_override("panel", UI.hud_frame(UI.VIOLET, Vector2(13, 7), true))
	header.add_child(clock_panel)
	var clock_text := UI.column(clock_panel, 1)
	UI.label(clock_text, "CHALLENGES RESET IN:", 15, UI.VIOLET).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var countdown := UI.label(clock_text, "", 29, UI.WHITE)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.autowrap_mode = TextServer.AUTOWRAP_OFF

	var sectors := card(columns, .48)
	UI.label(sectors, "UNLOCKED SECTORS", 25, UI.CYAN)
	var list := scroll_entries(sectors)
	UI.make_readable_scroll(list.get_parent() as ScrollContainer)
	var details := card(columns, 1.52)
	var available: int = clampi(profile.unlocked_sector, 1, Catalog.SECTORS.size())
	challenge_sector = clampi(challenge_sector, 1, available)
	var group := ButtonGroup.new()
	for number in range(1, available + 1):
		var sector := Catalog.info(number)
		var option := UI.button(list, "%02d   %s" % [number, sector.title],
			select_challenge_sector.bind(number, details, group), false, 36)
		option.custom_minimum_size.y = 52
		option.icon = sector_panorama(number)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.expand_icon = true
		option.add_theme_constant_override("icon_max_width", 61)
		option.add_theme_font_size_override("font_size", 17)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		option.toggle_mode = true
		option.button_group = group
		option.set_pressed_no_signal(number == challenge_sector)
		if number == challenge_sector:
			option.grab_focus()
	var displayed_day := [Profile.challenge_day()]
	select_challenge_sector(challenge_sector, details, group)
	var refresh := func():
		var clock := Time.get_datetime_dict_from_system()
		var today := Profile.challenge_day(clock)
		if today > displayed_day[0]:
			displayed_day[0] = today
			select_challenge_sector(challenge_sector, details, group)
		var left: int = Profile.challenge_seconds_left(clock)
		countdown.text = "%02dh %02dm %02ds" % [left / 3600, (left / 60) % 60, left % 60]
	var heartbeat := Timer.new()
	countdown.add_child(heartbeat)
	heartbeat.timeout.connect(refresh)
	heartbeat.start(1.0)
	refresh.call()

func select_challenge_sector(number: int, details: VBoxContainer, group: ButtonGroup) -> void:
	challenge_sector = number
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	var sector := Catalog.info(number)
	var banner := Control.new()
	banner.custom_minimum_size.y = 76
	details.add_child(banner)
	var art := TextureRect.new()
	art.texture = sector_panorama(number)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cover := GradientTexture2D.new()
	cover.gradient = Gradient.new()
	cover.gradient.colors = PackedColorArray([Color("081826"), Color("07132127")])
	cover.fill_to = Vector2.RIGHT
	var shade := TextureRect.new()
	shade.texture = cover
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var banner_title := UI.column(banner, 1)
	banner_title.position = Vector2(16, 7)
	UI.label(banner_title, sector.title.to_upper(), 31, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
	UI.label(banner_title, "SECTOR %02d" % number, 16, UI.WHITE).autowrap_mode = TextServer.AUTOWRAP_OFF

	var cycle: Dictionary = profile.challenge_cycle(number)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 12)
	details.add_child(progress)
	UI.label(progress, "%d / 5 CLEARED" % cycle.done.size(), 19, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
	var segments := HBoxContainer.new()
	segments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.add_child(segments)
	for index in 5:
		var segment := Panel.new()
		segment.custom_minimum_size.y = 10
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		segment.add_theme_stylebox_override("panel", UI.frame(UI.CYAN.darkened(.30) if index < cycle.done.size() else Color("101e32"), Color("5396ba"), 1))
		segments.add_child(segment)
	UI.label(progress, "SET BONUS  ·  %s CORE SHARDS" % UI.shard_amount(Profile.challenge_set_shards(number)), 17, UI.VIOLET).autowrap_mode = TextServer.AUTOWRAP_OFF
	var tasks := scroll_entries(details)
	tasks.add_theme_constant_override("separation", 6)
	UI.make_readable_scroll(tasks.get_parent() as ScrollContainer)
	for index in 5:
		add_challenge_row(tasks, number, index, cycle)
	for button in group.get_buttons():
		button.focus_neighbor_right = NodePath()
	var rewards: Dictionary = profile.challenge_rewards(number, cycle)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	details.add_child(footer)
	var status := UI.label(footer, "Banked bonus lives  ·  %d" % profile.reserve_lives, 16, UI.MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if rewards.credits == 0 and rewards.shards == 0 and rewards.lives == 0:
		return
	status.text = "Ready to claim  ·  %d Bolts  ·  %s Core Shards" % [rewards.credits, UI.shard_amount(rewards.shards)]
	if rewards.lives > 0:
		status.text += "  ·  +%d %s" % [rewards.lives, "Life" if rewards.lives == 1 else "Lives"]
	var claim := UI.button(footer, "Claim Rewards", func():
		var error: int = claim_challenge_rewards.call(number) if claim_challenge_rewards.is_valid() else ERR_UNCONFIGURED
		if error == OK:
			show_page("Challenges")
		else:
			status.text = "Could not claim your rewards. Try again."
	, true, 36)
	var sector_button := group.get_pressed_button()
	if sector_button:
		claim.focus_neighbor_left = claim.get_path_to(sector_button)
		sector_button.focus_neighbor_right = sector_button.get_path_to(claim)

func add_challenge_row(parent: VBoxContainer, sector: int, index: int, cycle: Dictionary) -> void:
	var task: Array = Profile.CHALLENGE_SETS[cycle.set][index]
	var cleared: bool = cycle.done.has(index)
	var claimed: bool = cycle.claimed.has(index)
	var tile := UI.equipment_card(UI.CYAN if not cleared else Color("7fe4a9"))
	var padding := tile.get_theme_stylebox("panel").duplicate() as StyleBox
	padding.content_margin_top = 4
	padding.content_margin_bottom = 4
	tile.add_theme_stylebox_override("panel", padding)
	parent.add_child(tile)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tile.add_child(row)
	var icons := ["icon_deploy", "icon_save", "icon_shield", "icon_buster", "icon_storage"]
	var badge := TextureRect.new()
	badge.texture = load(UI.KIT + icons[index] + ".png") as Texture2D
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(35, 35)
	row.add_child(badge)
	var content := UI.column(row, 1)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(content, task[0], 21)
	UI.label(content, task[1], 16, UI.MUTED)
	var tally := HBoxContainer.new()
	content.add_child(tally)
	var completion := ProgressBar.new()
	completion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	completion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	completion.custom_minimum_size.y = 5
	completion.show_percentage = false
	completion.max_value = 1
	completion.value = float(cleared)
	var track := UI.frame(Color("101d31"), Color("477c9c"), 1)
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UI.CYAN
	completion.add_theme_stylebox_override("background", track)
	completion.add_theme_stylebox_override("fill", fill)
	tally.add_child(completion)
	var target: int = int(task[3]) if task[2] in ["kills", "materials", "bolts"] else 1
	UI.label(tally, "%d / %d" % [target if cleared else 0, target], 15, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(VSeparator.new())
	var payout := HBoxContainer.new()
	payout.add_theme_constant_override("separation", 11)
	row.add_child(payout)
	payout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.currency_row(payout, "%d Bolts" % Profile.rotated_challenge_credits(sector, index))
	UI.currency_row(payout, "%s Core Shards" % UI.shard_amount(Profile.challenge_shards(sector, index)), true)
	if Profile.challenge_life(index) > 0:
		UI.label(payout, "+1 Life", 16, Color("8ff6ac")).autowrap_mode = TextServer.AUTOWRAP_OFF
	var state := UI.label(row, "CLAIMED" if claimed else ("REWARD READY" if cleared else "OPEN"), 16,
		Color("9defb1") if cleared else UI.CYAN)
	state.custom_minimum_size.x = 78
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func purchase_upgrade(id: String) -> void:
	shop_status = profile.buy(id)
	enhancement_focus = id
	show_page("Upgrades")

func build_sector(columns: HBoxContainer) -> void:
	build_level_select(columns)

func build_level_select(columns: HBoxContainer) -> void:
	var connected := not RiftRelay.connected_room.is_empty()
	var cooperative := connected and RiftRelay.can_deploy()
	var last_sector: int = mini(Catalog.SECTORS.size(), profile.unlocked_sector if profile else 1)
	var first_deployment := last_sector == 1
	var route := card(columns, 1.15 if first_deployment else 1.75)
	selected_sector = clampi(selected_sector, 1, last_sector)
	UI.label(route, "DEPLOYMENT MAP", 32, UI.CYAN)
	if can_load and not connected:
		var actions := HBoxContainer.new()
		route.add_child(actions)
		UI.button(actions, "Continue Run", func(): load_requested.emit(), true, 36)
		UI.button(actions, "New Run…", show_page.bind("New run"), false, 36)
	if first_deployment:
		UI.label(route, "Clear both acts to unlock Machine Jungle.", 17, UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	route.add_child(scroll)
	var entries := GridContainer.new()
	entries.columns = clampi(last_sector, 1, 3)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("h_separation", 8)
	entries.add_theme_constant_override("v_separation", 8)
	scroll.add_child(entries)
	var intel := card(columns)
	for number in range(1, last_sector + 1):
		var choice := sector_card(entries, number, "Normal  /  Lv. %d" % Difficulty.recommended_level(number, Difficulty.NORMAL))
		choice.set_meta(&"return_focus", "sector/%d" % number)
		choice.custom_minimum_size.y = 255 if first_deployment else 112
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
	var loot_unlocked: bool = profile.loot_clears.has(selected_sector)
	var loot := UI.button(panel, "Loot Intel", show_page.bind("Sector Loot"), false, 32)
	loot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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

func sector_panorama(number: int) -> Texture2D:
	match number:
		1: return preload("res://assets/neon_factory/foundry/foundry_panorama.jpg")
		2: return preload("res://assets/machine_jungle/jungle_panorama.png")
	return load("res://assets/campaign/%s/panorama.png" % Catalog.info(number).id) as Texture2D

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
	art.texture = sector_panorama(number)
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

func build_hub_inventory(columns: HBoxContainer) -> void:
	var carried := card(columns)
	UI.label(carried, "Inventory", 28, UI.CYAN)
	var hint := "Drop a carried item for your party. They can walk over its icon to pick it up. Use Field Interact near your own drop to take it back."
	UI.label(carried, hint if RiftRelay.can_share_hub_items() else "Join a party to share carried items.", 17, UI.MUTED)
	var first := build_storage_items(carried, storage_items(true), "", true)
	if first:
		first.grab_focus()
	if not inventory_status.is_empty():
		UI.label(carried, inventory_status, 16, UI.VIOLET)
	var quick := card(columns, 0.7)
	UI.label(quick, "QUICK SLOTS", 24, UI.CYAN)
	build_quick_assignments(quick)

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
		show_page(page)
	if carried and page == "Inventory" and RiftRelay.can_share_hub_items():
		var amount: int = profile.hub_item_count(id)
		first = UI.button(row, "Drop for Party" if amount == 1 else "Drop 1", func(): hub_drop_requested.emit(id, 1), true, 33)
		if amount > 1:
			UI.button(row, "Drop Stack (%d)" % amount, func(): hub_drop_requested.emit(id, amount), false, 33)
	if carried:
		var stow: Callable = profile.stow_pouch_blueprint.bind(id.trim_prefix("blueprint/")) if item.kind == "Blueprints" else profile.stow_purchase.bind(id)
		var button := UI.button(row, "Stow Stack", reopen.bind(stow), first == null, 33)
		if not first:
			first = button
	elif item.kind != "Equipment":
		first = UI.button(row, "Move to Inventory", reopen.bind(profile.withdraw_inventory.bind(id)), true, 33)
	if item.kind == "Blueprints" and not carried:
		UI.button(row, "Learn Blueprint", func():
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
	for id in Profile.GEAR:
		var gear: Dictionary = Profile.GEAR[id]
		if not carried and profile.gear.has(id):
			items[id] = {"kind": "Equipment", "name": gear.name, "slot": gear.slot, "icon": EquipmentIcons.icon(id, gear.slot),
				"rarity": gear.rarity, "detail": gear.perk, "badge": item_status(id, false)}
		if profile.blueprint_pouch.has(id) if carried else profile.blueprint_items.has(id):
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

func build_quick_assignments(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.ITEM_GAP)
	parent.add_child(row)
	for index in 4:
		var stack: Dictionary = profile.quick_slots[index]
		var id: String = stack.get("id", "")
		var item: Dictionary = profile.stock.get(id, {})
		var icon := EquipmentIcons.supply_icon(item) if not item.is_empty() else null
		var direction: String = ["↑", "←", "→", "↓"][index]
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(56, 56)
		tile.add_theme_stylebox_override("panel", UI.hud_frame(UI.CYAN, Vector2.ZERO, icon != null))
		row.add_child(tile)
		var surface := Control.new()
		surface.tooltip_text = "Select a supply to assign it to %s." % direction if item.is_empty() else "%s  ·  %s" % [direction, item.name]
		tile.add_child(surface)
		var picture := TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		picture.offset_left = -14
		picture.offset_right = 14
		picture.offset_top = -14
		picture.offset_bottom = 14
		var key := UI.profile_label(surface, direction, 17, UI.CYAN)
		key.position = Vector2(6, 1)
		var count := UI.profile_label(surface, "%d/%d" % [stack.get("count", 0), Profile.QUICK_MAX], 13, UI.MUTED)
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -30
		count.offset_right = -5
		count.offset_top = -17
		count.offset_bottom = -3
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
		show_page(page)
	)

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
	if station_tour_preview:
		get_viewport().set_input_as_handled()
		return
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
