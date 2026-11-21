extends CanvasLayer

const UI := preload("res://scripts/rift_ui.gd")
const Score := preload("res://scripts/gamer_score.gd")
const TROPHY := preload("res://assets/ui/riftcore_kit/icon_leaderboard.png")

var card: PanelContainer
var transition: Tween
var target: Node3D
var field_hud: Control
var lift := 0.0

func _ready() -> void:
	layer = 148
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func show_unlocks(ids: Array, points: int, operator: Node3D = null, hud: Control = null) -> void:
	if ids.is_empty():
		return
	# Extraction can open a dialogue in the same frame as the award.
	await get_tree().process_frame
	while get_tree().has_group(&"interactive_dialogue"):
		await get_tree().process_frame
	if is_instance_valid(card):
		transition.kill()
		card.queue_free()
	target = operator if is_instance_valid(operator) else null
	field_hud = hud if is_instance_valid(hud) else null
	lift = -7.0
	card = PanelContainer.new()
	card.name = "AchievementPopup"
	card.hide()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UI.hud_frame(UI.VIOLET, Vector2(13, 10), true))
	add_child(card)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var trophy := TextureRect.new()
	trophy.texture = TROPHY
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.custom_minimum_size = Vector2(32, 32)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trophy.modulate = Color("e3c1ff")
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trophy)
	var copy := UI.column(row, 3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(header)
	var title := "ACHIEVEMENT UNLOCKED" if ids.size() == 1 else "%d ACHIEVEMENTS UNLOCKED" % ids.size()
	var summary := UI.profile_label(header, title, 15, Color("e3c1ff"))
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if points > 0:
		UI.profile_label(header, "+%d G" % points, 16, UI.VIOLET)
	for id: String in ids.slice(0, 3):
		UI.profile_label(copy, Score.achievement_catalog[id][0], 23 if ids.size() == 1 else 19, UI.WHITE)
	if ids.size() > 3:
		UI.profile_label(copy, "+%d more in Profile  /  Achievements" % (ids.size() - 3), 14, UI.MUTED)
	card.modulate.a = 0.0
	transition = card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition.tween_property(card, "modulate:a", 1.0, 0.18)
	transition.parallel().tween_property(self, "lift", 2.0, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_interval(3.1 if ids.size() == 1 else 4.2)
	transition.tween_property(card, "modulate:a", 0.0, 0.23)
	transition.parallel().tween_property(self, "lift", 12.0, 0.23)
	transition.tween_callback(func():
		card.queue_free()
		target = null
		field_hud = null
		set_process(false)
	)
	set_process(true)
	RiftAudio.play_effect(&"achievement_unlocked")

func _process(_delta: float) -> void:
	card.size = card.get_combined_minimum_size()
	var pickup_clearance: float = field_hud.pickup_stack_height() if is_instance_valid(field_hud) else 0.0
	card.position = UI.operator_popup_position(card, target, pickup_clearance + lift)
	var can_show := not get_tree().has_group(&"interactive_dialogue")
	if card.visible != can_show:
		card.visible = can_show
		if can_show:
			transition.play()
		else:
			transition.pause()
