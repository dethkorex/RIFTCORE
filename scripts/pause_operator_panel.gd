extends PanelContainer

const UI := preload("res://scripts/rift_ui.gd")
const Profile := preload("res://scripts/rogue_profile.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")

var operator: Callable
var profile
var stats: Label
var gear: Label
var quick_slots: Label
var inventory: Label
var refresh_in := 0.0

func _ready() -> void:
	custom_minimum_size.x = 380
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := UI.column(self, 8)
	UI.label(content, "OPERATOR  /  " + profile.operator_name, 24, UI.CYAN)
	stats = UI.label(content, "", 17)
	content.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 228
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	content.add_child(scroll)
	var items := UI.column(scroll, 6)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(items, "EQUIPPED GEAR", 18, UI.CYAN)
	gear = UI.label(items, "", 16)
	UI.label(items, "QUICK SLOTS", 18, UI.CYAN)
	quick_slots = UI.label(items, "", 16)
	UI.label(items, "INVENTORY", 18, UI.CYAN)
	inventory = UI.label(items, "", 16)
	refresh()

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
	stats.text = "LV. %d   ·   XP %d / %d   ·   Lives %d\nHP %.0f / %.0f   ·   ENG %.0f / %.0f\nBuster DMG %.1f   ·   Saber DMG %.1f\nDEF %.1f%%   ·   SPD %.1f m/s" % [
		level, player.experience - xp_floor, xp_next - xp_floor, player.lives,
		player.health, player.max_health, player.energy, player.max_energy,
		player.buster_power(), player.buster_power() * player.melee_multiplier,
		player.defense_rating() * 100.0, player.move_speed * (1.0 + player.supply_bonus("speed")),
	]
	var equipped := PackedStringArray()
	for slot in Profile.GEAR_SLOTS:
		var id: String = profile.equipped_for(slot)
		equipped.append("%s   ·   %s" % [Profile.GEAR_SLOTS[slot], "Empty" if id.is_empty() else Profile.GEAR[id].name])
	gear.text = "\n".join(equipped)
	var slots := PackedStringArray()
	for index in profile.quick_slots.size():
		var stack: Dictionary = profile.quick_slots[index]
		var id := String(stack.get("id", ""))
		var count := int(stack.get("count", 0))
		var name := "Empty" if count <= 0 or not Profile.stock.has(id) else "%s  ×%d" % [Profile.stock[id].name, count]
		slots.append("Slot %d   ·   %s" % [index + 1, name])
	quick_slots.text = "\n".join(slots)
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
