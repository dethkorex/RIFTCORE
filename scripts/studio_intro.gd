extends Control

const UI := preload("res://scripts/rift_ui.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const MIN_LOADING_TIME := 6.0
const INTRO_SOUND := preload("res://assets/audio/dfg_intro.ogg")
const AMBIENT := preload("res://assets/audio/dfg_ambient.ogg")
const ART := preload("res://assets/ui/riftcore_title_art.png")
const OPERATOR_MODEL := "res://assets/models/mecha_main/RiftcoreMechaUAL.glb"

@onready var video: VideoStreamPlayer = $Video
var wordmark: Label
var loading_panel: CenterContainer
var bar: ProgressBar
var percent: Label
var operator_view: SubViewport
var runner_ready := false
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
	build_loading_panel()
	ResourceLoader.load_threaded_request(OPERATOR_MODEL, "PackedScene")
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

func build_loading_panel() -> void:
	loading_panel = CenterContainer.new()
	loading_panel.name = "GameLoading"
	add_child(loading_panel)
	loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.texture = ART
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.30, 0.39, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(backdrop, loading_panel.get_index())
	backdrop.hide()
	loading_panel.visibility_changed.connect(func(): backdrop.visible = loading_panel.visible)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.texture_frame("panel_base_large", 40, Vector2(26, 23)))
	loading_panel.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var portrait_panel := PanelContainer.new()
	portrait_panel.add_theme_stylebox_override("panel", UI.frame(Color("071d30"), UI.CYAN, 2))
	row.add_child(portrait_panel)
	var runner := SubViewportContainer.new()
	runner.custom_minimum_size = Vector2(310, 285)
	runner.stretch = true
	runner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(runner)
	operator_view = SubViewport.new()
	operator_view.own_world_3d = true
	operator_view.transparent_bg = true
	operator_view.msaa_3d = Viewport.MSAA_4X
	operator_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	runner.add_child(operator_view)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 455
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)
	var brand := UI.label(column, "RIFTCORE", 78, UI.CYAN)
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
		wordmark.modulate.a = smoothstep(1.16, 1.59, video.stream_position) * (1.0 - smoothstep(2.60, 3.05, video.stream_position))
		return
	elapsed += delta
	if not runner_ready and ResourceLoader.load_threaded_get_status(OPERATOR_MODEL) == ResourceLoader.THREAD_LOAD_LOADED:
		build_loading_runner()
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
		await create_tween().tween_property(ambiance, "volume_db", -50.0, 0.38).finished
		get_tree().change_scene_to_packed(game)

func build_loading_runner() -> void:
	runner_ready = true
	var model_scene := ResourceLoader.load_threaded_get(OPERATOR_MODEL) as PackedScene
	if not model_scene:
		return
	var model := model_scene.instantiate() as Node3D
	operator_view.add_child(model)
	model.rotation.y = deg_to_rad(73.0)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.13
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	operator_view.add_child(camera)
	camera.position = Vector3(-0.10, 1.13, 4.1)
	camera.look_at(Vector3(-0.10, 0.94, 0.0))
	camera.make_current()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("aecbfa")
	world.environment.ambient_light_energy = 0.85
	operator_view.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, -25.0, 0.0)
	light.light_energy = 1.6
	operator_view.add_child(light)
	var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animator or not animator.has_animation(&"run"):
		return
	var run := animator.get_animation(&"run").duplicate() as Animation
	run.loop_mode = Animation.LOOP_LINEAR
	var idle := animator.get_animation(&"idle")
	for index in run.get_track_count():
		var path := run.track_get_path(index)
		if run.track_get_type(index) != Animation.TYPE_POSITION_3D or not String(path).ends_with(":mixamorig_Hips"):
			continue
		var idle_track := idle.find_track(path, Animation.TYPE_POSITION_3D)
		if idle_track < 0:
			continue
		var neutral: Vector3 = idle.track_get_key_value(idle_track, 0)
		for key in run.track_get_key_count(index):
			var pose: Vector3 = run.track_get_key_value(index, key)
			run.track_set_key_value(index, key, Vector3(neutral.x, pose.y, neutral.z))
	var library := AnimationLibrary.new()
	library.add_animation(&"run", run)
	animator.add_animation_library(&"loading", library)
	animator.play(&"loading/run")

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
	loading_panel.show()
