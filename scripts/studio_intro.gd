extends Control

const UI := preload("res://scripts/rift_ui.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const MIN_LOADING_TIME := 6.0
const INTRO_SOUND := preload("res://assets/audio/dfg_intro.ogg")
const AMBIENT := preload("res://assets/audio/dfg_ambient.ogg")
const LoadingScreen := preload("res://scripts/act_loading_screen.gd")

@onready var video: VideoStreamPlayer = $Video
var wordmark: Label
var loading_screen: CanvasLayer
var loading := false
var elapsed := 0.0
var displayed_progress := 0.0
var game: PackedScene
var scene_progress := 0.0
var switched := false
var impact_audio: AudioStreamPlayer
var ambiance: AudioStreamPlayer

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
	impact_audio = create_audio(INTRO_SOUND, &"SFX", -10.0)
	var bed := AMBIENT.duplicate() as AudioStreamOggVorbis
	bed.loop = true
	ambiance = create_audio(bed, &"Music", -37.0)
	ambiance.play()
	create_tween().tween_property(ambiance, "volume_db", -22.0, 1.3)
	if ResourceLoader.load_threaded_request(GAME_SCENE) != OK:
		begin_loading()
		return
	if not video.stream:
		begin_loading()
		return
	video.finished.connect(begin_loading)
	get_tree().create_timer(4.0).timeout.connect(begin_loading)
	video.play()
	impact_audio.play()

func create_audio(track: AudioStream, bus: StringName, level: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = track
	player.bus = bus
	player.volume_db = level
	add_child(player)
	return player

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or switched:
		return
	if not loading:
		wordmark.modulate.a = smoothstep(1.16, 1.59, video.stream_position) * (1.0 - smoothstep(2.60, 3.05, video.stream_position))
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
		loading_screen.percent.text = "Could not load the game."
		push_error("RIFTCORE could not load its main scene.")
		return
	var target := minf(elapsed / MIN_LOADING_TIME, 0.90 + scene_progress * 0.10 if game else 0.12 + scene_progress * 0.86)
	displayed_progress = move_toward(displayed_progress, target, delta * (0.22 if game else 0.19))
	loading_screen.progress.value = displayed_progress
	if game and elapsed >= MIN_LOADING_TIME and displayed_progress >= 0.999:
		switched = true
		loading_screen.progress.value = 1.0
		await create_tween().tween_property(ambiance, "volume_db", -50.0, 0.38).finished
		get_tree().change_scene_to_packed(game)

func _input(event: InputEvent) -> void:
	if not loading and is_instance_valid(wordmark) and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		begin_loading()

func begin_loading() -> void:
	if loading:
		return
	loading = true
	if is_instance_valid(impact_audio):
		impact_audio.stop()
	video.stop()
	video.hide()
	wordmark.hide()
	loading_screen = LoadingScreen.new()
	add_child(loading_screen)
	loading_screen.show_loading("", "LOADING GAME")
