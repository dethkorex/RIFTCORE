extends PanelContainer

const UI := preload("res://scripts/rift_ui.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const EquipmentBody := preload("res://scripts/equipment_body.gd")
const EquipmentIcons := preload("res://scripts/equipment_icons.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")

var operator: Callable
var profile
var progress: Label
var stat_values: Array[Label] = []
var buster: Label
var quick_labels: Array[Label] = []
var quick_icons: Array[TextureRect] = []
var inventory: Label
var sections: TabContainer
var refresh_in := 0.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	add_child(layout)
	var equipment := UI.column(layout, 8)
	equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(equipment, "RX-07 EQUIPMENT", 24, UI.CYAN)
	var body := EquipmentBody.new()
	equipment.add_child(body)
	body.install(profile, "", Callable())
	body.custom_minimum_size.y = 276
	var weapons := HBoxContainer.new()
	weapons.add_theme_constant_override("separation", 7)
	equipment.add_child(weapons)
	buster = weapon_slot(weapons, "BUSTER", "arm")
	weapon_slot(weapons, "SABER", "utility").text = "RX-07 Saber"
	var sidebar := UI.column(layout, 6)
	sidebar.custom_minimum_size.x = 246
	UI.label(sidebar, "LB / RB   Switch tab", 14, UI.MUTED)
	sections = TabContainer.new()
	sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		var key := UI.label(slot, str(index + 1), 14, UI.CYAN)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quick_icons.append(item_icon(slot, 20))
		var count := UI.label(slot, "", 14)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quick_labels.append(count)
	var scroll := ScrollContainer.new()
	scroll.name = "Inventory"
	scroll.custom_minimum_size.y = 70
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	sections.add_child(scroll)
	inventory = UI.label(scroll, "", 16)
	inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.tab_changed.connect(func(_tab: int):
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			sections.get_tab_bar().grab_focus()
	)
	refresh()

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
	progress.text = "LV. %d   ·   XP %d / %d   ·   Lives %d" % [level, player.experience - xp_floor, xp_next - xp_floor, player.lives]
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
		quick_icons[index].texture = EquipmentIcons.icon(item.icon, item.icon) if not item.is_empty() else null
		quick_labels[index].text = "×%d" % count if not item.is_empty() else "—"
		quick_labels[index].tooltip_text = String(item.get("name", "Empty"))
	var contents := PackedStringArray()
	for id in profile.inventory:
		if Profile.stock.has(id) and int(profile.inventory[id]) > 0:
			contents.append("%s  ×%d" % [Profile.stock[id].name, profile.inventory[id]])
	var materials: Dictionary = profile.materials.duplicate()
	for id in player.salvage:
		materials[id] = int(materials.get(id, 0)) + int(player.salvage[id])
	for id in materials:
		if int(materials[id]) > 0:
			contents.append("%s  ×%d" % [Materials.label(id), materials[id]])
	var blueprints: Dictionary = profile.blueprint_items.duplicate()
	blueprints.merge(player.recovered_blueprints)
	for id in blueprints:
		if Profile.GEAR.has(id):
			contents.append("%s Blueprint" % Profile.GEAR[id].name)
	inventory.text = "Empty" if contents.is_empty() else "\n".join(contents)
