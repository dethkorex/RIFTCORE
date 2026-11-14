extends Control

const UI := preload("res://scripts/rift_ui.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const MIN_LOADING_TIME := 6.0

@onready var video: VideoStreamPlayer = $Video
var wordmark: Label
var loading_panel: CenterContainer
var bar: ProgressBar
var percent: Label
var loading := false
var elapsed := 0.0
var displayed_progress := 0.0
var game: PackedScene
var scene_progress := 0.0
var switched := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		return
	wordmark = UI.label(self, "DESTRUCTIVE FORCE GAMING", 51, UI.WHITE)
	wordmark.name = "StudioWordmark"
	wordmark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	wordmark.offset_top = -159
	wordmark.offset_bottom = -60
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wordmark.add_theme_color_override("font_outline_color", Color("040d19"))
	wordmark.add_theme_constant_override("outline_size", 13)
	wordmark.modulate.a = 0.0
	build_loading_panel()
	if ResourceLoader.load_threaded_request(GAME_SCENE) != OK:
		begin_loading()
		return
	if not video.stream:
		begin_loading()
		return
	video.finished.connect(begin_loading)
	get_tree().create_timer(4.0).timeout.connect(begin_loading)
	video.play()

func build_loading_panel() -> void:
	loading_panel = CenterContainer.new()
	loading_panel.name = "GameLoading"
	add_child(loading_panel)
	loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 475
	column.add_theme_constant_override("separation", 15)
	loading_panel.add_child(column)
	var brand := UI.label(column, "RIFTCORE", 94, UI.CYAN)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var message := UI.label(column, "LOADING GAME", 24, UI.MUTED)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16
	bar.add_theme_stylebox_override("background", UI.frame(Color("14233c"), Color("385b82"), 1))
	bar.add_theme_stylebox_override("fill", UI.frame(Color("5ae9ff"), Color("a3efff"), 1))
	column.add_child(bar)
	percent = UI.label(column, "0%", 22, UI.CYAN)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_panel.hide()

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or switched:
		return
	if not loading:
		wordmark.modulate.a = smoothstep(0.88, 1.35, video.stream_position) * (1.0 - smoothstep(2.60, 3.05, video.stream_position))
		return
	elapsed += delta
	if not game:
		var stage: Array = []
		var state := ResourceLoader.load_threaded_get_status(GAME_SCENE, stage)
		match state:
			ResourceLoader.THREAD_LOAD_LOADED:
				game = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
				scene_progress = 1.0
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not stage.is_empty():
					scene_progress = maxf(scene_progress, float(stage[0]))
			_:
				game = load(GAME_SCENE) as PackedScene
				scene_progress = 1.0
	if not game and scene_progress >= 1.0:
		switched = true
		percent.text = "Could not load the game."
		push_error("RIFTCORE could not load its main scene.")
		return
	var target := minf(elapsed / MIN_LOADING_TIME, 0.90 + scene_progress * 0.10 if game else 0.12 + scene_progress * 0.86)
	displayed_progress = move_toward(displayed_progress, target, delta * (0.22 if game else 0.19))
	bar.value = displayed_progress
	percent.text = "%d%%" % floori(displayed_progress * 100.0)
	if game and elapsed >= MIN_LOADING_TIME and displayed_progress >= 0.999:
		switched = true
		bar.value = 1.0
		percent.text = "100%"
		await get_tree().create_timer(0.2).timeout
		get_tree().change_scene_to_packed(game)

func _input(event: InputEvent) -> void:
	if not loading and is_instance_valid(wordmark) and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		begin_loading()

func begin_loading() -> void:
	if loading:
		return
	loading = true
	video.stop()
	video.hide()
	wordmark.hide()
	loading_panel.show()
