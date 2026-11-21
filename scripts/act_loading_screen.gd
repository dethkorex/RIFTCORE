extends CanvasLayer

const UI := preload("res://scripts/rift_ui.gd")
const ART := preload("res://assets/ui/riftcore_title_art.png")
const OPERATOR_MODEL := "res://assets/models/mecha_main/RiftcoreMechaUAL.glb"

var shade: ColorRect
var loading_panel: CenterContainer
var operator_view: SubViewport
var heading: Label
var progress: ProgressBar
var percent: Label

func show_loading(sector_title: String, title := "LOADING ACT II") -> void:
	layer = 100
	shade = ColorRect.new()
	shade.color = Color("080f23")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.modulate.a = 0.0
	build_loading_panel(sector_title, title)
	build_loading_runner.call_deferred()
	create_tween().tween_property(shade, "modulate:a", 1.0, 0.20)

func begin(title := "ACT II BEGIN") -> void:
	progress.value = 1.0
	heading.text = title

func fade_out() -> void:
	await create_tween().tween_property(shade, "modulate:a", 0.0, 0.22).finished
	queue_free()

func build_loading_panel(sector_title: String, title: String) -> void:
	loading_panel = CenterContainer.new()
	loading_panel.name = "GameLoading"
	shade.add_child(loading_panel)
	loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.texture = ART
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.30, 0.39, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.move_child(backdrop, loading_panel.get_index())
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
	heading = UI.label(column, title, 24, UI.MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not sector_title.is_empty():
		UI.label(column, sector_title.to_upper(), 18, UI.WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.step = 0.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 16
	progress.add_theme_stylebox_override("background", UI.frame(Color("14233c"), Color("385b82"), 1))
	progress.add_theme_stylebox_override("fill", UI.frame(Color("5ae9ff"), Color("a3efff"), 1))
	column.add_child(progress)
	percent = UI.label(column, "0%", 22, UI.CYAN)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.value_changed.connect(func(value: float): percent.text = "%d%%" % floori(value * 100.0))

func build_loading_runner() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var model_scene := load(OPERATOR_MODEL) as PackedScene
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
