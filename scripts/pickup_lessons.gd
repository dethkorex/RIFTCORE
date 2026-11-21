extends Node

const UI := preload("res://scripts/rift_ui.gd")
const Inventory := preload("res://scripts/pause_operator_panel.gd")
const LESSON_TEXT := {
	"material": "That's salvage. Extract with it and the Workshop can use it to build gear.",
	"blueprint": "A blueprint! Check the recipe in the Workshop to see which materials you need.",
}

var game
var actor: RiftPlayer
var waiting := {}
var card: PanelContainer
var card_seconds := 0.0

func install(main, player: RiftPlayer) -> void:
	game = main
	actor = player
	player.salvage_collected.connect(func(drop: Dictionary):
		if not drop.is_empty():
			offer("material")
	)
	player.blueprint_found.connect(func(_id: String): offer("blueprint"))
	player.supply_found.connect(func(id: String): offer("supply", id))

func offer(category: String, item := "") -> void:
	if RiftSettings.show_hub_tips and not RiftSettings.seen_story_beats.has("pickup_lesson_" + category) and not waiting.has(category):
		waiting[category] = item

func _process(delta: float) -> void:
	if is_instance_valid(card):
		card_seconds -= delta
		if card_seconds <= 0.0 or not RiftSettings.show_hub_tips:
			dismiss()
		return
	if waiting.is_empty() or not game.can_open_chat() or not actor.is_on_floor() or actor.health <= 0:
		return
	if not RiftSettings.show_hub_tips:
		waiting.clear()
		return
	var category: String = waiting.keys()[0]
	var item: String = waiting[category]
	waiting.erase(category)
	if category == "supply" and int(actor.recovered_supplies.get(item, 0)) <= 0:
		return
	if not RiftSettings.claim_story_beat("pickup_lesson_" + category):
		return
	if category == "supply":
		game.toggle_pause()
		var inventory := game.pause_menu.find_child("OperatorInventory", true, false) as Inventory
		inventory.sections.current_tab = 1
		inventory.refresh()
		var tile: Button = inventory.inventory_tiles.get("field:" + item)
		if tile:
			tile.grab_focus()
			tile.modulate = Color("80f1ff")
		var panel: Control = inventory.sections.get_tab_control(1)
		var tip := UI.label(panel, "NOVA  /  Select the highlighted supply, then choose a D-pad slot to use it during your run.", 16, UI.CYAN)
		panel.move_child(tip, 0)
		var skip := UI.button(panel, "Skip tutorial", game.toggle_pause, false, 28)
		panel.move_child(skip, 1)
		inventory.quick_assigned.connect(func(id: String):
			if id == item and game.get_tree().paused:
				game.toggle_pause.call_deferred()
		)
	else:
		card = PanelContainer.new()
		card.name = "NovaPickupLesson"
		card.add_theme_stylebox_override("panel", UI.frame(Color("0b192c"), UI.CYAN))
		add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		card.offset_left = -215
		card.offset_right = 215
		card.offset_top = 24
		var stack := UI.column(card, 4)
		UI.label(stack, "NOVA  /  " + category.to_upper(), 17, UI.CYAN)
		UI.label(stack, LESSON_TEXT[category], 18)
		UI.button(stack, "Skip", dismiss, false, 25)
		card_seconds = 7.0

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(card) and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()

func dismiss() -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = null
