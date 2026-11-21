extends CanvasLayer

const UI := preload("res://scripts/rift_ui.gd")
var shade: ColorRect
var heading: Label
var progress: ProgressBar

func show_loading(sector_title: String, title := "LOADING ACT II") -> void:
	layer = 100
	shade = ColorRect.new()
	shade.color = Color("080f23")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.modulate.a = 0.0
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.hud_frame(UI.CYAN, Vector2(28, 22), true))
	center.add_child(panel)
	var column := UI.column(panel, 12)
	column.custom_minimum_size.x = 490.0
	var sector := UI.label(column, sector_title.to_upper(), 20, Color("9db5ce"))
	sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading = UI.label(column, title, 49, Color("86edff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.add_theme_stylebox_override("background", UI.profile_frame(Color("1c324a"), Color.TRANSPARENT, Vector2.ZERO))
	progress.add_theme_stylebox_override("fill", UI.profile_frame(UI.CYAN, Color.TRANSPARENT, Vector2.ZERO))
	column.add_child(progress)
	create_tween().tween_property(shade, "modulate:a", 1.0, 0.20)

func begin() -> void:
	progress.value = 1.0
	heading.text = "ACT II BEGIN"
	heading.modulate.a = 0.0
	create_tween().tween_property(heading, "modulate:a", 1.0, 0.18)

func fade_out() -> void:
	await create_tween().tween_property(shade, "modulate:a", 0.0, 0.22).finished
	queue_free()
