extends CanvasLayer

const UI := preload("res://scripts/rift_ui.gd")
var shade: ColorRect
var heading: Label
var progress: ProgressBar

func show_loading(sector_title: String) -> void:
	layer = 100
	shade = ColorRect.new()
	shade.color = Color("080f23")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.modulate.a = 0.0
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := UI.column(center, 16)
	column.custom_minimum_size.x = 490.0
	var sector := UI.label(column, sector_title.to_upper(), 20, Color("9db5ce"))
	sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading = UI.label(column, "LOADING ACT II", 49, Color("86edff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.add_theme_stylebox_override("background", UI.frame(Color("182842"), Color("284765"), 1))
	progress.add_theme_stylebox_override("fill", UI.frame(Color("68d9ef"), Color("acf2ff"), 1))
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
