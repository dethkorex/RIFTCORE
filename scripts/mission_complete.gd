extends RefCounted

const UI := preload("res://scripts/rift_ui.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")

static func build(stack: VBoxContainer, sector_name: String, stats: Dictionary, materials: Dictionary,
		blueprints: Array[String], bolts: int, lives: int, deaths: int, ending: String, exit: Callable) -> void:
	UI.label(stack, "DEPLOYMENT COMPLETE", 43, UI.CYAN)
	UI.label(stack, sector_name + "  /  EXTRACTION SUMMARY", 21, UI.WHITE)
	var body := HBoxContainer.new()
	body.custom_minimum_size.y = 355
	body.add_theme_constant_override("separation", 20)
	stack.add_child(body)
	var display := preload("res://scripts/equipment_display.gd").new()
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.size_flags_stretch_ratio = 0.55
	body.add_child(display)
	var results := UI.column(body, 10)
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var numbers := UI.equipment_card(UI.CYAN)
	results.add_child(numbers)
	var rows := GridContainer.new()
	rows.columns = 4
	rows.add_theme_constant_override("h_separation", 15)
	rows.add_theme_constant_override("v_separation", 8)
	numbers.add_child(rows)
	var time := int(stats.seconds)
	var material_count := 0
	for quantity in materials.values():
		material_count += int(quantity)
	for entry in [
		["Time", "%02d:%02d" % [time / 60, time % 60]], ["Enemies defeated", str(stats.kills)],
		["Boss defeated", "Yes"], ["Lives lost", str(deaths)],
		["Operator XP gained", "+%d" % stats.operator_xp], ["Player XP gained", "+%d" % stats.player_xp],
		["Materials recovered", str(material_count)], ["Core Shards earned", "+%d" % stats.shards],
		["Blueprints recovered", str(blueprints.size())], ["Bolts banked", "+%d" % bolts],
	]:
		var caption := UI.label(rows, entry[0], 15, UI.MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		UI.label(rows, entry[1], 16, UI.CYAN).autowrap_mode = TextServer.AUTOWRAP_OFF
	UI.label(results, "EXTRACTION REWARDS", 24, UI.CYAN)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 117
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	results.add_child(scroll)
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 8)
	scroll.add_child(rewards)
	for name in blueprints:
		reward(rewards, name, "Blueprint", UI.VIOLET)
	for id in materials:
		reward(rewards, Materials.label(id), "×%d" % materials[id], UI.CYAN)
	if lives > 0:
		reward(rewards, "Challenge reward", "+%d reserve lives" % lives, Color("ffd079"))
	if rewards.get_child_count() == 0:
		UI.label(rewards, "No salvage recovered.", 16, UI.MUTED)
	if not ending.is_empty():
		UI.label(stack, ending, 15, UI.MUTED)
	UI.button(stack, "Return to Station", exit, true).grab_focus()

static func reward(parent: HBoxContainer, caption: String, text: String, tint: Color) -> void:
	var tile := UI.equipment_card(tint)
	tile.custom_minimum_size.x = 125
	parent.add_child(tile)
	var content := UI.column(tile, 4)
	UI.label(content, text, 16, tint)
	UI.label(content, caption, 15)
