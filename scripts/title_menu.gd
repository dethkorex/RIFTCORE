class_name RiftTitleMenu
extends Control

signal start_requested
signal load_requested
signal hub_requested
signal station_closed
signal sector_requested(number: int)
signal slot_requested(number: int, fresh: bool)
signal save_requested

var active_slot := 0
var developer_session := false
var replace_slot := 0
var slot_error := ""
var save_status: Label
var relay_status: Label
var relay_code: LineEdit
var relay_host: Button
var relay_join: Button
var relay_copy: Button
var relay_leave: Button

var can_load := false
var saved_sector := 1
var saved_act := 1
var saved_level := 1
var run_cleared_through := 0
var at_sector_start := false
var run_unlocks: Array = []
var profile
var shop_status := ""
var challenge_sector := 1
var inventory_slot := "frame"
var inventory_status := ""
var shop_item := ""
var station_panel := false
var deploy_error := ""

const CoopSetup := preload("res://scripts/coop_setup.gd")
const Story := preload("res://scripts/rift_story.gd")
const UI := preload("res://scripts/rift_ui.gd")
const PORTRAIT := preload("res://assets/ui/rx07_menu.png")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const ManualSave := preload("res://scripts/manual_save_session.gd")
const EquipmentBody := preload("res://scripts/equipment_body.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")

var layout: VBoxContainer
var page := "Title"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	RiftRelay.changed.connect(refresh_online_room)
	show_page("Title")

func show_page(next: String) -> void:
	if next == "Hub":
		hub_requested.emit()
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
		margins.add_theme_constant_override("margin_" + side, 36)
	layout = UI.column(margins, 18)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var logo := UI.label(header, "RIFTCORE", 42, UI.CYAN)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var section := UI.label(header, "RIFTCORE STATION  /  " + page.to_upper(), 18, UI.MUTED)
	section.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
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
			UI.button(form, "Start New Game", func(): slot_requested.emit(replace_slot, true))
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
		"Level select":
			build_level_select(columns)
		"New run":
			var confirmation := card(columns)
			UI.label(confirmation, "Start a new run?", 34, UI.CYAN)
			UI.label(confirmation, "Your current deployment, run XP and level unlocks will be reset.", 20, UI.MUTED)
			UI.button(confirmation, "Start in Neon Factory", deploy, true).grab_focus()
			UI.button(confirmation, "Keep current run", show_page.bind("Sector select"))
		"Loadout":
			build_loadout(columns)
		"Upgrades":
			build_workshop(columns)
		"Fabrication", "Storage":
			build_equipment_station(columns, next == "Fabrication")
		"Craft Item":
			build_purchase(columns)
		"Collection":
			build_archive(columns)
		"Challenges":
			build_challenges(columns)
		"Online Room":
			build_online_room(columns)
		"Co-op Setup Guide":
			CoopSetup.build(card(columns, 1.75), leave_page)
			portrait(card(columns))
		"Settings":
			var form := card(columns, 2.0)
			UI.label(form, "Audio and display", 28, UI.CYAN)
			UI.settings(form)
			UI.label(form, "Default keyboard  /  A–D move · S crouch · W/S ladder · Space jump · J fire · K slash · Shift dash\nDefault controller  /  Left stick move · Down crouch · Up/Down ladder · A jump · X fire · Y slash · B dash · Start pause\nHold fire to charge, then release. Charged shots use 30 energy.", 16, UI.MUTED)
			var art := card(columns)
			portrait(art)
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

func open_station(next: String) -> void:
	station_panel = true
	deploy_error = ""
	inventory_status = ""
	shop_item = ""
	show()
	show_page(next)

func leave_page() -> void:
	if page == "Co-op Setup Guide":
		show_page("Online Room")
		return
	if page == "Online Room":
		RiftRelay.leave()
	if station_panel:
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
	panel.add_theme_stylebox_override("panel", UI.frame(Color(0.043, 0.073, 0.14, 0.94), Color("426482"), 2))
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
	panel.add_theme_stylebox_override("panel", UI.frame(Color(0.026, 0.052, 0.115, 0.91), UI.CYAN, 3))
	add_child(panel)
	panel.anchor_left = 0.60
	panel.anchor_right = 0.96
	panel.anchor_top = 0.19
	var stack := UI.column(panel, 10)
	UI.label(stack, "RIFTCORE", 54, UI.CYAN)
	UI.label(stack, "ROGUE PROTOCOL   /   SECTOR 01", 14, UI.VIOLET)
	stack.add_child(HSeparator.new())
	var buttons: Array[Button] = []
	if active_slot > 0 or developer_session:
		var label := "Continue Station  /  Slot %d" % active_slot if active_slot > 0 else "Enter Station"
		buttons.append(UI.button(stack, label, func(): hub_requested.emit(), true))
	buttons.append(UI.button(stack, "New Game", open_slot_picker.bind("New Game"), buttons.is_empty()))
	buttons.append(UI.button(stack, "Load Game", open_slot_picker.bind("Load Game")))
	buttons.append(UI.button(stack, "Online Room", show_page.bind("Online Room")))
	buttons.append(UI.button(stack, "Settings", show_page.bind("Settings")))
	buttons.append(UI.button(stack, "Quit Game", get_tree().quit))
	for i in range(buttons.size()):
		var button := buttons[i]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 50
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

func build_online_room(columns: HBoxContainer) -> void:
	var form := card(columns, 1.35)
	UI.label(form, "Online Room Preview", 34, UI.CYAN)
	UI.label(form, "Share a room code to connect with a friend. Co-op deployment is still in development.", 18, UI.MUTED)
	relay_host = UI.button(form, "Create Room", RiftRelay.host_room, true)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	form.add_child(join_row)
	relay_code = LineEdit.new()
	relay_code.placeholder_text = "Friend’s room code"
	relay_code.max_length = 14
	relay_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relay_code.text_submitted.connect(RiftRelay.join_room)
	join_row.add_child(relay_code)
	relay_join = UI.button(join_row, "Join Room", func(): RiftRelay.join_room(relay_code.text))
	relay_status = UI.label(form, "", 18, UI.CYAN)
	relay_copy = UI.button(form, "Copy Room Code", func(): DisplayServer.clipboard_set(RiftRelay.connected_room))
	relay_leave = UI.button(form, "Leave Room", func(): RiftRelay.leave())
	UI.button(form, "Co-op Setup Guide", show_page.bind("Co-op Setup Guide"))
	portrait(card(columns))
	refresh_online_room()
	relay_host.grab_focus()

func refresh_online_room() -> void:
	if page != "Online Room" or not is_instance_valid(relay_status):
		return
	var joined := not RiftRelay.connected_room.is_empty()
	var requesting := not RiftRelay.pending.is_empty()
	relay_host.disabled = joined or requesting
	relay_join.disabled = joined or requesting
	relay_code.editable = not joined and not requesting
	relay_copy.visible = joined
	relay_leave.visible = joined or requesting
	relay_leave.text = "Leave Room" if joined else "Cancel Connection"
	relay_status.text = "%s   /   Code %s" % [RiftRelay.status, RiftRelay.connected_room] if joined else RiftRelay.status
	if joined:
		relay_copy.grab_focus()
	elif requesting or get_viewport().gui_get_focus_owner() == relay_leave:
		if requesting:
			relay_leave.grab_focus()
		else:
			relay_host.grab_focus()

func open_slot_picker(mode: String) -> void:
	slot_error = ""
	show_page(mode)

func build_save_slots(columns: HBoxContainer, fresh: bool) -> void:
	var slots := card(columns, 1.35)
	UI.label(slots, "Choose a Save Slot", 34, UI.CYAN)
	UI.label(slots, "Save manually at the station or from Pause." if fresh else "Choose a slot to return to its station.", 19, UI.MUTED)
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
		var occupied := data != null
		var button := UI.button(slots, "Slot %d   /   %s" % [number, description], choose_slot.bind(number, fresh, occupied))
		button.disabled = not fresh and not occupied
		if not button.disabled and not first:
			first = button
	if first:
		first.grab_focus()
	if not slot_error.is_empty():
		UI.label(slots, slot_error, 18, UI.CYAN)
	portrait(card(columns))

func choose_slot(number: int, fresh: bool, occupied: bool) -> void:
	if fresh and occupied:
		replace_slot = number
		show_page("Replace Slot")
	else:
		slot_requested.emit(number, fresh)

func show_slot_error() -> void:
	slot_error = "That save could not be opened."
	show_page("Load Game")

func show_save_result(result: String) -> void:
	save_status.text = result

func build_workshop(columns: HBoxContainer) -> void:
	if inventory_slot in ["visor", "arm"]:
		inventory_slot = "frame"
	var fitting := card(columns, 1.05)
	UI.label(fitting, "RX-07 Upgrade Sockets", 26, UI.CYAN)
	var body := EquipmentBody.new()
	fitting.add_child(body)
	body.install(profile, inventory_slot, select_inventory_slot, true)
	var store := card(columns, 1.08)
	UI.label(store, "Core Enhancement", 32, UI.CYAN)
	UI.label(store, "%d CORE SHARDS   /   PLAYER LV. %d" % [profile.core_shards, profile.player_level()], 17, Color("ffd079"))
	if profile:
		for upgrade in profile.UPGRADES:
			if Profile.UPGRADE_SLOTS[upgrade.id] != inventory_slot:
				continue
			var installed: int = profile.rank(upgrade.id)
			var maxed := installed == 2
			var price: int = 0 if maxed else upgrade.prices[installed]
			var enabled: bool = not maxed and profile.core_shards >= price and profile.player_level() >= profile.enhancement_level(upgrade.id, installed)
			var next := "I" if installed == 0 else "II"
			var text := "%s %s   ·   %s" % [upgrade.name, next, "Installed" if maxed else "%d shards  /  Lv. %d" % [price, profile.enhancement_level(upgrade.id, installed)]]
			UI.label(store, String(upgrade.effects[mini(installed, 1)]), 15, UI.MUTED)
			var purchase := UI.button(store, text, purchase_upgrade.bind(upgrade.id) if enabled else Callable(), enabled)
			purchase.icon = EquipmentIcons.icon(inventory_slot, inventory_slot)
			purchase.expand_icon = true
			purchase.add_theme_constant_override("icon_max_width", 24)
	if not shop_status.is_empty():
		UI.label(store, shop_status, 15, UI.VIOLET)

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
	if can_load:
		UI.label(route, "RX-07  /  Level %d" % saved_level, 17, UI.MUTED)
		UI.button(route, "Continue run  ›" if at_sector_start else "Resume checkpoint  ›", func(): load_requested.emit(), true).grab_focus()
		if run_cleared_through > 0:
			UI.button(route, "Level Select", show_page.bind("Level select"))
		UI.button(route, "Start a new run", show_page.bind("New run"))
	else:
		UI.button(route, "Deploy to Neon Factory  ›", deploy, true).grab_focus()
	var equipment := card(columns)
	UI.label(equipment, "Starting loadout", 24, UI.CYAN)
	UI.label(equipment, "Buster Cannon\nEnergy Blade\nDash Module")
	portrait(equipment)

func build_level_select(columns: HBoxContainer) -> void:
	var panel := card(columns)
	UI.label(panel, "Level Select", 34, UI.CYAN)
	UI.label(panel, "Choose a sector unlocked in this run. Changing sectors starts at Act I with your current gear and remaining lives.", 18, UI.MUTED)
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
	for number in range(1, mini(run_cleared_through + 1, Catalog.SECTORS.size()) + 1):
		var state := "Current deployment" if number == saved_sector else ("Cleared" if number <= run_cleared_through else "Unlocked")
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
		var border := UI.frame(Color.TRANSPARENT, accent if highlight else Color("416178"), 3 if highlight else 1)
		border.set_border_width_all(3 if highlight else 1)
		outline.add_theme_stylebox_override("panel", border)
	choice.mouse_entered.connect(refresh)
	choice.mouse_exited.connect(refresh)
	choice.focus_entered.connect(refresh)
	choice.focus_exited.connect(refresh)
	refresh.call()
	return choice

func build_equipment_station(columns: HBoxContainer, shopping: bool) -> void:
	var list := card(columns, 1.20)
	if shopping:
		var slots := card(columns)
		UI.label(slots, "RX-07 Equipment", 29, UI.CYAN)
		var body := EquipmentBody.new()
		slots.add_child(body)
		body.install(profile, inventory_slot, select_inventory_slot)
		UI.label(slots, "Equipped gear is lost when a run ends in death.", 16, UI.MUTED)
		UI.label(list, "Fabrication  /  " + String(Profile.GEAR_SLOTS[inventory_slot]), 33, UI.CYAN)
		UI.label(list, "PLAYER LV. %d" % profile.player_level(), 18, Color("ffd079"))
		UI.label(list, "Review a blueprint to check its materials.", 17, UI.MUTED)
	else:
		UI.label(list, "Storage   %d / %d" % [profile.stored_count(), profile.storage_capacity()], 33, UI.CYAN)
		UI.label(list, "Stowed gear survives defeat. Equipping an item stows the previous one automatically.", 17, UI.MUTED)
		portrait(card(columns, 0.82))
	var entries := scroll_entries(list)
	var shown := 0
	for id in Profile.GEAR:
		var item: Dictionary = Profile.GEAR[id]
		var state: String = profile.gear.get(id, "")
		if (shopping and item.slot != inventory_slot) or (not shopping and state.is_empty()):
			continue
		shown += 1
		var row := item_card(entries, id)
		if shopping:
			var header := row.get_child(0) as HBoxContainer
			var action := UI.button(header, ("Blueprint  ›" if profile.player_level() >= Profile.recipe_level(id) else "Locked  /  Lv. %d" % Profile.recipe_level(id)) if state.is_empty() else "Owned", inspect_shop_item.bind(id) if state.is_empty() else Callable())
			action.custom_minimum_size.y = 34
			action.add_theme_font_size_override("font_size", 15)
			action.tooltip_text = "Inspect blueprint" if state.is_empty() else "Available in Storage"
			if id == shop_item and not action.disabled:
				action.grab_focus()
		else:
			var action := "Stow" if state == "equipped" else "Equip"
			UI.button(row, action, move_stored_gear.bind(id))
	if shown == 0:
		UI.label(entries, "No items in storage. Visit the Fabrication.", 17, UI.MUTED)
	if not inventory_status.is_empty():
		UI.label(list, inventory_status, 17, UI.VIOLET)

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
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.frame(Color("0d2032"), tint.darkened(0.47), 1))
	parent.add_child(panel)
	var stack := UI.column(panel, 6)
	var head := HBoxContainer.new()
	stack.add_child(head)
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
	inventory_slot = slot
	show_page(page)

func move_stored_gear(id: String) -> void:
	inventory_status = profile.move_gear(id)
	show_page("Storage")

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

func build_loadout(columns: HBoxContainer) -> void:
	var equipped := card(columns, 1.10)
	UI.label(equipped, "RX-07 Loadout", 31, UI.CYAN)
	var body := EquipmentBody.new()
	equipped.add_child(body)
	body.install(profile, inventory_slot, select_inventory_slot)
	var equipped_id: String = profile.equipped_for(inventory_slot)
	if not equipped_id.is_empty():
		item_card(equipped, equipped_id)
	if not run_unlocks.is_empty():
		var rewards := PackedStringArray()
		for id in run_unlocks:
			var info := Catalog.weapon(String(id))
			if not info.is_empty():
				rewards.append(String(info.reward_name))
		UI.label(equipped, "Run weapons   /   Q/E or RB/LB to cycle\n" + ", ".join(rewards), 15, UI.CYAN)
	var presets := card(columns)
	UI.label(presets, "Equipment Presets", 30, UI.CYAN)
	UI.label(presets, "Record your equipped gear, then re-equip it here. Use Save Game to keep presets across launches.", 16, UI.MUTED)
	var entries := scroll_entries(presets)
	for number in range(1, Profile.PRESET_COUNT + 1):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.frame(Color("0d2032"), Color("35566b"), 1))
		entries.add_child(panel)
		var row := UI.column(panel, 7)
		UI.label(row, "Preset %02d" % number, 19, UI.CYAN)
		var preset: Dictionary = profile.loadouts.get(number, {})
		if preset.is_empty():
			UI.label(row, "No gear recorded", 15, UI.MUTED)
		var fitted := GridContainer.new()
		fitted.columns = 2
		row.add_child(fitted)
		for slot in Profile.GEAR_SLOTS:
			if not preset.has(slot):
				continue
			var id: String = preset[slot]
			var entry := HBoxContainer.new()
			fitted.add_child(entry)
			var icon := TextureRect.new()
			icon.texture = EquipmentIcons.icon(id, slot)
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			entry.add_child(icon)
			var item_name: String = Profile.GEAR[id].name
			UI.label(entry, item_name if profile.gear.has(id) else item_name + "  /  Missing", 14, UI.WHITE).autowrap_mode = TextServer.AUTOWRAP_OFF
		var actions := HBoxContainer.new()
		row.add_child(actions)
		var record := UI.button(actions, "Record Equipped", preset_action.bind(number, true))
		record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var apply := UI.button(actions, "Equip Preset", preset_action.bind(number, false))
		apply.disabled = not profile.loadouts.has(number)
		apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not inventory_status.is_empty():
		UI.label(presets, inventory_status, 16, UI.VIOLET)

func preset_action(number: int, record: bool) -> void:
	inventory_status = profile.record_loadout(number) if record else profile.apply_loadout(number)
	show_page("Loadout")

func build_info(columns: HBoxContainer, title: String, description: String) -> void:
	var info := card(columns, 1.25)
	UI.label(info, title, 30, UI.CYAN)
	UI.label(info, description, 19)
	portrait(card(columns))

func deploy() -> void:
	start_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and page != "Title":
		RiftAudio.play_effect(&"menu_confirm")
		leave_page()
		get_viewport().set_input_as_handled()
