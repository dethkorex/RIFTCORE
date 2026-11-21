extends PanelContainer

const UI := preload("res://scripts/rift_ui.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const EquipmentBody := preload("res://scripts/equipment_body.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const MissionMap := preload("res://scripts/mission_map.gd")

signal quick_assigned(id: String)

var operator: Callable
var configure_map: Callable
var life_total: Callable
var profile
var progress: Label
var stat_values: Array[Label] = []
var buster: Label
var quick_labels: Array[Label] = []
var quick_icons: Array[TextureRect] = []
var quick_edited: Callable
var quick_origin := ""
var quick_cancel: Button
var inventory_grid: GridContainer
var inventory_tiles: Dictionary = {}
var inventory_snapshot: Dictionary = {}
var inventory_empty: Label
var selected_supply := ""
var supply_source := &"inventory"
var selected_slot := 0
var item_detail: Label
var item_feedback: Label
var equip_buttons: Array[Button] = []
var return_stack: Button
const QUICK_KEYS := ["↑", "←", "→", "↓"]
var sections: TabContainer
var refresh_in := 0.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var equipment := UI.column(layout, 8)
	equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(equipment, "RX-07 EQUIPMENT", 24, UI.CYAN)
	var body := EquipmentBody.new()
	equipment.add_child(body)
	body.install(profile, "", Callable())
	body.custom_minimum_size.y = 225
	var weapons := HBoxContainer.new()
	weapons.add_theme_constant_override("separation", 7)
	equipment.add_child(weapons)
	buster = weapon_slot(weapons, "BUSTER", "arm")
	weapon_slot(weapons, "SABER", "utility").text = "RX-07 Saber"
	var module_id: String = operator.call().run_module if operator.is_valid() else ""
	var modules := preload("res://scripts/foundry_run_module.gd").MODULES
	if modules.has(module_id):
		UI.label(equipment, "Run module · " + String(modules[module_id][0]), 16, UI.CYAN)
	var sidebar := UI.column(layout, 6)
	sidebar.custom_minimum_size.x = 341
	UI.label(sidebar, "LB / RB   Switch tab", 14, UI.MUTED)
	sections = TabContainer.new()
	sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sections.use_hidden_tabs_for_min_size = false
	sections.add_theme_stylebox_override("panel", UI.frame(Color("101e32"), Color("365d79"), 1))
	sections.add_theme_stylebox_override("tab_focus", StyleBoxEmpty.new())
	sections.add_theme_stylebox_override("tab_selected", UI.frame(Color("34244f"), UI.VIOLET))
	sections.add_theme_stylebox_override("tab_hovered", UI.frame(Color("34244f"), UI.VIOLET))
	sections.add_theme_stylebox_override("tab_unselected", UI.frame(Color("12253d"), Color("3b6384")))
	sidebar.add_child(sections)
	var content := VBoxContainer.new()
	content.name = "Stats"
	content.add_theme_constant_override("separation", 6)
	sections.add_child(content)
	UI.label(content, "OPERATOR  /  " + profile.operator_name, 23, UI.CYAN)
	progress = UI.label(content, "", 16, UI.MUTED)
	for name in ["HP", "ENG", "BUSTER DMG", "SABER DMG", "DEF", "SPD"]:
		var row := HBoxContainer.new()
		content.add_child(row)
		var title := UI.label(row, name, 16, UI.MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := UI.label(row, "", 17)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.custom_minimum_size.x = 72
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_values.append(value)
	content.add_child(HSeparator.new())
	UI.label(content, "QUICK SLOTS", 18, UI.CYAN)
	var quick_row := HBoxContainer.new()
	content.add_child(quick_row)
	for index in 4:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.frame(Color("0b1b32"), Color("346681"), 1))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_row.add_child(card)
		var slot := UI.column(card, 2)
		var key := UI.label(slot, QUICK_KEYS[index], 14, UI.CYAN)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quick_icons.append(item_icon(slot, 20))
		var count := UI.label(slot, "", 14)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quick_labels.append(count)
	build_inventory()
	var map_tab := -1
	if configure_map.is_valid():
		var map := MissionMap.new()
		map.name = "Map"
		map.expanded = true
		map.custom_minimum_size = Vector2(620, 330)
		configure_map.call(map)
		sections.add_child(map)
		map_tab = sections.get_tab_count() - 1
	sections.tab_changed.connect(func(tab: int):
		equipment.visible = tab != map_tab
		selected_supply = ""
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			sections.get_tab_bar().grab_focus()
	)
	refresh()

func build_inventory() -> void:
	var panel := VBoxContainer.new()
	panel.name = "Inventory"
	panel.add_theme_constant_override("separation", 5)
	sections.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 156
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var contents := UI.column(scroll, 4)
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_empty = UI.label(contents, "No items in inventory.", 16, UI.MUTED)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", UI.ITEM_GAP)
	inventory_grid.add_theme_constant_override("v_separation", UI.ITEM_GAP)
	contents.add_child(inventory_grid)
	item_detail = UI.label(panel, "Select a supply, then pick its D-pad slot.", 16, UI.MUTED)
	item_detail.custom_minimum_size.y = 36
	item_feedback = UI.label(panel, "", 14, UI.CYAN)
	UI.label(panel, "D-PAD QUICK SLOTS", 17, UI.CYAN)
	var slots := HBoxContainer.new()
	panel.add_child(slots)
	for index in 4:
		var button := UI.button(slots, QUICK_KEYS[index], edit_slot.bind(index), false, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 15)
		button.focus_entered.connect(func():
			selected_slot = index
			refresh_slot_details()
		)
		equip_buttons.append(button)
	return_stack = UI.button(panel, "Unequip Selected Slot", clear_slot, false, 30)
	return_stack.focus_neighbor_top = return_stack.get_path_to(equip_buttons[0])
	quick_cancel = UI.button(panel, "Cancel Assignment", cancel_quick_assignment, false, 30)
	quick_cancel.hide()

func select_inventory_item(key: String, equip := false) -> void:
	var item: Dictionary = inventory_snapshot[key]
	item_detail.text = "%s ×%d
%s" % [item.name, item.count, item.detail]
	if equip:
		selected_supply = String(item.get("supply", ""))
		supply_source = item.get("source", &"inventory")
	if equip and not selected_supply.is_empty():
		quick_origin = key
		quick_cancel.show()
		item_feedback.text = "Assign Quick Slot  ·  %s" % item.name
		equip_buttons[selected_slot].grab_focus()

func edit_slot(index: int) -> void:
	selected_slot = index
	if selected_supply.is_empty():
		refresh_slot_details()
		item_feedback.text = "Select a supply above to equip it."
		return
	var previous: Dictionary = profile.quick_slots[index].duplicate()
	var player := operator.call() as RiftPlayer
	item_feedback.text = profile.assign_quick(index, selected_supply, supply_source, player.recovered_supplies)
	if previous != profile.quick_slots[index]:
		if quick_edited.is_valid():
			quick_edited.call()
		quick_assigned.emit(selected_supply)
		cancel_quick_assignment(false)
	refresh()

func cancel_quick_assignment(clear_message := true) -> bool:
	if selected_supply.is_empty():
		return false
	var origin: Button = inventory_tiles.get(quick_origin)
	selected_supply = ""
	quick_origin = ""
	quick_cancel.hide()
	if clear_message:
		item_feedback.text = ""
	if is_instance_valid(origin):
		origin.grab_focus()
	return true

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and cancel_quick_assignment():
		get_viewport().set_input_as_handled()

func clear_slot() -> void:
	var previous: Dictionary = profile.quick_slots[selected_slot].duplicate()
	var player := operator.call() as RiftPlayer
	item_feedback.text = profile.clear_quick(selected_slot, player.recovered_supplies)
	if previous != profile.quick_slots[selected_slot] and quick_edited.is_valid():
		quick_edited.call()
	refresh()
	equip_buttons[selected_slot].grab_focus()

func refresh_slot_details() -> void:
	var stack: Dictionary = profile.quick_slots[selected_slot]
	return_stack.disabled = int(stack.get("count", 0)) <= 0
	for button in equip_buttons:
		button.focus_neighbor_bottom = NodePath() if return_stack.disabled else button.get_path_to(return_stack)
	return_stack.focus_neighbor_top = return_stack.get_path_to(equip_buttons[selected_slot])
	if selected_supply.is_empty() and not return_stack.disabled and equip_buttons[selected_slot].has_focus():
		var item: Dictionary = Profile.stock.get(stack.get("id", ""), {})
		item_detail.text = "%s ×%d
%s" % [item.get("name", "Supply"), stack.count, item.get("detail", "")]

func reload_inventory(contents: Dictionary) -> void:
	if contents == inventory_snapshot:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var previous_key: String = focused.get_meta("inventory_key", "") if focused else ""
	inventory_snapshot = contents
	for tile in inventory_tiles.values():
		inventory_grid.remove_child(tile)
		tile.queue_free()
	inventory_tiles.clear()
	inventory_empty.visible = contents.is_empty()
	for key: String in contents:
		var item: Dictionary = contents[key]
		var icon := EquipmentIcons.supply_icon(Profile.stock[item.supply]) if item.has("supply") else EquipmentIcons.icon(item.icon, item.get("slot", item.icon))
		var tile := UI.item_tile(inventory_grid, icon,
			Profile.RARITY_COLORS[item.rarity], item.rarity, "×%d" % item.count, select_inventory_item.bind(key, true))
		tile.set_meta("inventory_key", key)
		tile.tooltip_text = item.name
		tile.focus_entered.connect(select_inventory_item.bind(key))
		inventory_tiles[key] = tile
	var buttons := inventory_tiles.values()
	for index in buttons.size():
		var tile: Button = buttons[index]
		var columns := inventory_grid.columns
		if index + columns >= buttons.size():
			tile.focus_neighbor_bottom = tile.get_path_to(equip_buttons[mini(equip_buttons.size() - 1, (index % columns) * equip_buttons.size() / columns)])
	for index in equip_buttons.size():
		var button := equip_buttons[index]
		var top: Control = buttons[mini(index, buttons.size() - 1)] if not buttons.is_empty() else sections.get_tab_bar()
		button.focus_neighbor_top = button.get_path_to(top)
	if not previous_key.is_empty() and sections.get_current_tab_control().name == "Inventory":
		var target: Button = inventory_tiles.get(previous_key, equip_buttons[selected_slot])
		target.grab_focus()

func weapon_slot(parent: HBoxContainer, title: String, icon_kind: String) -> Label:
	var card := UI.equipment_card(UI.CYAN)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	item_icon(row, 24).texture = EquipmentIcons.icon(icon_kind, icon_kind)
	var content := UI.column(row, 1)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(content, title, 15, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
	var name := UI.label(content, "", 16)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return name

func item_icon(parent: Container, width: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(width, width)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)
	return icon

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	refresh_in -= delta
	if refresh_in <= 0.0:
		refresh_in = 0.15
		refresh()

func refresh() -> void:
	var player := operator.call() as RiftPlayer
	if not is_instance_valid(player):
		return
	var level := RiftPlayer.level_for_experience(player.experience)
	var xp_floor := RiftPlayer.experience_threshold(level)
	var xp_next := RiftPlayer.experience_threshold(level + 1)
	var lives: int = life_total.call(player) if life_total.is_valid() else player.lives
	progress.text = "LV. %d   ·   XP %d / %d   ·   Lives %d" % [level, player.experience - xp_floor, xp_next - xp_floor, lives]
	var values := [
		"%.0f / %.0f" % [player.health, player.max_health],
		"%.0f / %.0f" % [player.energy, player.max_energy],
		"%.1f" % player.buster_power(),
		"%.1f" % (player.buster_power() * player.melee_multiplier),
		"%.1f%%" % (player.defense_rating() * 100.0),
		"%.1f m/s" % (player.move_speed * (1.0 + player.supply_bonus("speed"))),
	]
	for index in stat_values.size():
		stat_values[index].text = values[index]
	buster.text = String(Catalog.weapon(player.equipped_suit()).get("reward_name", "Standard Buster"))
	for index in profile.quick_slots.size():
		var stack: Dictionary = profile.quick_slots[index]
		var id := String(stack.get("id", ""))
		var count := int(stack.get("count", 0))
		var item: Dictionary = Profile.stock.get(id, {}) if count > 0 else {}
		quick_icons[index].texture = EquipmentIcons.supply_icon(item) if not item.is_empty() else null
		quick_labels[index].text = "×%d" % count if not item.is_empty() else "—"
		quick_labels[index].tooltip_text = String(item.get("name", "Empty"))
	for index in profile.quick_slots.size():
		equip_buttons[index].text = "%s  %s" % [QUICK_KEYS[index], quick_labels[index].text]
		equip_buttons[index].tooltip_text = quick_labels[index].tooltip_text
		equip_buttons[index].icon = quick_icons[index].texture
	refresh_slot_details()
	var contents := {}
	add_supplies(contents, profile.inventory, &"inventory")
	add_supplies(contents, player.recovered_supplies, &"field")
	var material_sources := {"carried": profile.carried_materials, "recovered": player.salvage}
	for source in material_sources:
		for id in material_sources[source]:
			var amount := int(material_sources[source][id])
			if amount > 0:
				contents["%s:material:%s" % [source, id]] = {"name": Materials.label(id), "count": amount,
					"detail": "Goes to Storage on extraction." if source == "recovered" else "Stow this at Equipment to use it for crafting.",
					"icon": "core", "rarity": 0}
	for id in player.recovered_blueprints:
		if Profile.GEAR.has(id):
			var gear: Dictionary = Profile.GEAR[id]
			contents["blueprint:" + id] = {"name": gear.name + " Blueprint", "count": 1,
				"detail": "Learn this recipe at the station.", "icon": id, "slot": gear.slot, "rarity": gear.rarity}
	reload_inventory(contents)

func add_supplies(contents: Dictionary, supplies: Dictionary, source: StringName) -> void:
	for id in supplies:
		if Profile.stock.has(id) and int(supplies[id]) > 0:
			var supply: Dictionary = Profile.stock[id]
			var detail: String = supply.detail
			if source == &"field":
				detail += "  ·  Unused units go to Storage on extraction."
			contents["field:" + id if source == &"field" else id] = {"name": supply.name, "count": supplies[id], "detail": detail,
				"icon": supply.icon, "rarity": supply.rarity, "supply": id, "source": source}
