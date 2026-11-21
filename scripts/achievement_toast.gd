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
	var spacing := StyleBoxEmpty.new()
	spacing.content_margin_left = 18.0
	spacing.content_margin_right = 32.0
	spacing.content_margin_top = 10.0
	spacing.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", spacing)
	card.custom_minimum_size = Vector2(446, 74)
	add_child(card)
	card.draw.connect(draw_banner.bind(card))
	card.resized.connect(card.queue_redraw)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	var trophy := TextureRect.new()
	trophy.texture = TROPHY
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.custom_minimum_size = Vector2(66, 42)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trophy)
	var copy := UI.column(row, 1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 7)
	copy.add_child(header)
	var slashes := Control.new()
	slashes.custom_minimum_size.x = 18.0
	slashes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(slashes)
	slashes.draw.connect(func(): draw_marks(slashes, Vector2(0, slashes.size.y * 0.5 - 5), UI.VIOLET))
	var title := "ACHIEVEMENT UNLOCKED" if ids.size() == 1 else "%d ACHIEVEMENTS UNLOCKED" % ids.size()
	UI.profile_label(header, title, 16, Color("f1dfff"))
	for index in mini(3, ids.size()):
		UI.profile_label(copy, Score.achievement_catalog[ids[index]][0], 29 if index == 0 else 16, UI.WHITE if index == 0 else UI.MUTED)
	if ids.size() > 3:
		UI.profile_label(copy, "+%d more in Profile  /  Achievements" % (ids.size() - 3), 14, UI.MUTED)
	if points > 0:
		var tally := HBoxContainer.new()
		tally.add_theme_constant_override("separation", 6)
		tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tally)
		UI.profile_label(tally, "+%d" % points, 27, UI.VIOLET)
		var badge := UI.profile_label(tally, "G", 17, UI.VIOLET)
		badge.custom_minimum_size = Vector2(22, 22)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.draw.connect(func(): badge.draw_arc(badge.size * 0.5, 10.5, 0.0, TAU, 28, UI.VIOLET, 1.6, true))
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

func draw_banner(canvas: Control) -> void:
	var width := canvas.size.x
	var bottom := canvas.size.y - 2.0
	var middle := bottom * 0.5
	var body := PackedVector2Array([
		Vector2(60, 4), Vector2(width - 19, 4), Vector2(width - 2, 16),
		Vector2(width - 34, bottom), Vector2(50, bottom), Vector2(23, middle),
	])
	var plate := PackedVector2Array([
		Vector2(35, 2), Vector2(82, 2), Vector2(105, middle - 6),
		Vector2(73, bottom), Vector2(24, bottom), Vector2(10, middle + 8),
	])
	canvas.draw_colored_polygon(body, Color("0a1725f5"))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(130, 5), Vector2(width - 20, 5), Vector2(width - 5, 17),
		Vector2(width - 32, bottom - 3), Vector2(width - 93, bottom - 3), Vector2(width - 49, 5),
	]), Color("17344c65"))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(23, middle - 24), Vector2(5, middle + 8), Vector2(20, bottom),
		Vector2(13, bottom), Vector2(1, middle + 8), Vector2(18, middle - 23),
	]), Color("a55aef"))
	outline(canvas, body, Color("36dfff"))
	canvas.draw_colored_polygon(plate, Color("0c2336"))
	outline(canvas, plate, Color("62efff"))
	canvas.draw_line(Vector2(106, 5), Vector2(186, 5), Color("b3fbff"), 2.2, true)
	canvas.draw_line(Vector2(138, bottom), Vector2(224, bottom), Color("54e8ff"), 2.2, true)
	canvas.draw_line(Vector2(226, bottom), Vector2(277, bottom), UI.VIOLET, 2.2, true)
	draw_marks(canvas, Vector2(width - 65, bottom - 17), Color("36dfff"))

func outline(canvas: Control, points: PackedVector2Array, tint: Color) -> void:
	points.append(points[0])
	canvas.draw_polyline(points, Color(tint, 0.12), 8.0, true)
	canvas.draw_polyline(points, Color(tint, 0.28), 4.0, true)
	canvas.draw_polyline(points, tint, 1.9, true)

func draw_marks(canvas: Control, start: Vector2, tint: Color) -> void:
	for index in 3:
		var point := start + Vector2(index * 6, 0)
		canvas.draw_line(point + Vector2(0, 10), point + Vector2(6, 0), tint, 2.6, true)

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
