class_name RiftTitleMenu
extends Control

signal start_requested
signal load_requested

var can_load := false
var profile
var shop_status := ""

const UI := preload("res://scripts/rift_ui.gd")
const PORTRAIT := preload("res://assets/ui/rx07_menu.png")

var layout: VBoxContainer
var page := "Title"
var return_page := "Title"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	show_page("Title")

func show_page(next: String) -> void:
	return_page = "Title" if next in ["Hub", "Load"] or page == "Title" else "Hub"
	page = next
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if page == "Title":
		build_start_screen()
		return
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
	var section := UI.label(header, "ROGUE PROTOCOL  /  " + ("COMMAND DECK" if page == "Hub" else page.to_upper()), 18, UI.MUTED)
	section.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	match page:
		"Hub":
			build_command_deck(columns)
		"Load":
			var saves := card(columns, 1.35)
			UI.label(saves, "Load game", 34, UI.CYAN)
			if can_load:
				UI.label(saves, "Sector 01  /  Last Neon Factory checkpoint")
				UI.button(saves, "Resume checkpoint", func(): load_requested.emit(), true).grab_focus()
			else:
				UI.label(saves, "No saved checkpoint yet. Reach the midpoint beacon in Neon Factory to unlock Load.", 19, UI.MUTED)
			portrait(card(columns))
		"Sector select":
			build_sector(columns)
		"Loadout":
			build_loadout(columns)
		"Upgrades":
			build_workshop(columns)
		"Collection":
			build_info(columns, "Field guide", "Neon Factory security includes scouts, quad walkers, heavy units, turrets, and flying drones.\n\nCollect purple XP orbs after defeating enemies. Green restores health, cyan restores energy, and gold adds credits. Shoot cargo carriers to release their crates.")
		"Challenges":
			build_info(columns, "Challenges", "There are no active challenges. You can play Neon Factory from Sector Select.")
		"Settings":
			var form := card(columns, 2.0)
			UI.label(form, "Audio and display", 28, UI.CYAN)
			UI.settings(form)
			UI.label(form, "Default keyboard  /  A–D move · S crouch · W/S ladder · Space jump · J fire · K slash · Shift dash\nDefault controller  /  Left stick move · Down crouch · Up/Down ladder · A jump · X fire · Y slash · B dash · Start pause\nHold fire to charge, then release. Charged shots use 30 energy.", 16, UI.MUTED)
			var art := card(columns)
			portrait(art)
	if page != "Title":
		var back := UI.button(layout, "Back to Title" if return_page == "Title" else "Back to Command Deck", show_page.bind(return_page))
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if get_viewport().gui_get_focus_owner() == null:
			back.grab_focus()

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
	buttons.append(UI.button(stack, "Start Game", show_page.bind("Hub"), true))
	buttons.append(UI.button(stack, "Load", func(): show_page("Load")))
	buttons.append(UI.button(stack, "Settings", func(): show_page("Settings")))
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

func build_command_deck(columns: HBoxContainer) -> void:
	var dossier := card(columns, 1.65)
	UI.label(dossier, "RX-07   //   RIFTCORE FRAME", 20, UI.CYAN)
	portrait(dossier)
	var nav := card(columns)
	UI.label(nav, "SECTOR 01", 15, UI.VIOLET)
	UI.label(nav, "Neon Factory", 34)
	UI.label(nav, "BANK  /  %04d CREDITS" % (profile.credits if profile else 0), 16, UI.MUTED)
	var launch := UI.button(nav, "Deploy  ›", show_page.bind("Sector select"), true)
	launch.custom_minimum_size.y = 55
	nav.add_child(HSeparator.new())
	for item in [["Loadout", "Loadout"], ["Field Guide", "Collection"], ["Upgrades", "Upgrades"], ["Challenges", "Challenges"], ["Settings", "Settings"]]:
		UI.button(nav, item[0], show_page.bind(item[1]))
	launch.grab_focus()

func build_workshop(columns: HBoxContainer) -> void:
	var store := card(columns, 2.0)
	UI.label(store, "Permanent Upgrades", 32, UI.CYAN)
	UI.label(store, "BANK  /  %04d CREDITS" % (profile.credits if profile else 0), 17, Color("ffd079"))
	if profile:
		for upgrade in profile.UPGRADES:
			var purchased: bool = profile.owned.has(upgrade.id)
			var enabled: bool = not purchased and profile.credits >= upgrade.cost
			var text := "%s   ·   %s" % [upgrade.name, "Installed" if purchased else "%d CR" % upgrade.cost]
			UI.label(store, upgrade.description, 15, UI.MUTED)
			UI.button(store, text, purchase_upgrade.bind(upgrade.id) if enabled else Callable(), enabled)
	if not shop_status.is_empty():
		UI.label(store, shop_status, 15, UI.VIOLET)
	var art := card(columns)
	portrait(art)

func purchase_upgrade(id: String) -> void:
	shop_status = profile.buy(id)
	show_page("Upgrades")

func build_sector(columns: HBoxContainer) -> void:
	var route := card(columns, 1.4)
	UI.label(route, "SECTOR 01", 15, UI.VIOLET)
	UI.label(route, "Neon Factory", 38, UI.CYAN)
	UI.label(route, "Clear the security units, defeat Forge Titan, and reach extraction.")
	route.add_child(HSeparator.new())
	UI.label(route, "Assembly line  ›  Reactor  ›  Smelter  ›  Forge Titan", 20)
	UI.label(route, "Expect patrol bots, moving platforms, and elevated catwalks.", 16, UI.MUTED)
	UI.button(route, "Deploy to Neon Factory  ›", deploy, true).grab_focus()
	var equipment := card(columns)
	UI.label(equipment, "Starting loadout", 24, UI.CYAN)
	UI.label(equipment, "Buster Cannon\nEnergy Blade\nDash Module")
	portrait(equipment)

func build_loadout(columns: HBoxContainer) -> void:
	var gear := card(columns)
	UI.label(gear, "Equipped gear", 27, UI.CYAN)
	for line in ["Buster Cannon\nSingle shot per press", "Energy Blade\nClose-range slash", "Dash Module\nUses 12 energy per dash"]:
		var row := PanelContainer.new()
		gear.add_child(row)
		UI.label(row, line)
	if profile and profile.weapons.has("magma_breaker"):
		UI.label(gear, "Magma Breaker unlocked · Q / RB during a run", 16, Color("ffad66"))
	var model := card(columns, 1.7)
	portrait(model)
	UI.label(model, "RX-07   /   STANDARD FRAME", 18, UI.VIOLET)

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
		show_page(return_page)
		get_viewport().set_input_as_handled()
