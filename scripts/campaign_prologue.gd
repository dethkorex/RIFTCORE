extends CanvasLayer

signal finished

const UI := preload("res://scripts/rift_ui.gd")
const Story := preload("res://scripts/rift_story.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const BODY_FONT := preload("res://addons/GD-Sync/UI/Fonts/Outfit-Regular.ttf")
const PORTRAITS := preload("res://assets/ui/story/rx07_expressions.png")
const CITY := preload("res://assets/neon_factory/factory_panorama.png")
const NEXUS := preload("res://assets/campaign/riftcore_nexus/panorama.png")
const ARCHITECT := preload("res://assets/ui/story/architect.jpg")
const LAB := preload("res://assets/ui/story/station.jpg")
const VOSS := preload("res://assets/ui/story/voss.png")
const SOREN := preload("res://assets/ui/story/soren.png")
const NOVA := preload("res://assets/ui/nova_portrait.png")
const WATER := preload("res://assets/campaign/abyssal_plant/panorama.png")
const MUSIC := preload("res://assets/audio/dfg_ambient.ogg")
const FRACTURE := preload("res://assets/ui/story/rift_fracture.gdshader")
const TITLES := [
	"THE FALL OF MERIDIAN", "TWO SCIENTISTS, ONE CHOICE", "THE GUARDIAN UPRISING",
	"A NEW HERO", "THE LOST MEMORY",
]
const NAMES := {"VOSS": "DR. MARA VOSS", "SOREN": "DIRECTOR SOREN"}
const COLORS := {"NOVA": Color("86eaff"), "VOSS": Color("d3dbff"),
	"SOREN": Color("ff8291"), "RX-07": Color("8ff7ff")}
const FULL := Rect2(.045, .092, .91, .749)

var scene_index := 0
var line_index := 0
var ended := false
var skipped := false
var tutorial_requested := false
var canvas: Control
var page: Control
var shade: ColorRect
var next: Button
var music: AudioStreamPlayer
var transition: Tween
var motion: Tween
var lettering: Tween
var subtitle: Label

func play() -> void:
	build_overlay()
	show_line()
	await finished

func build_overlay() -> void:
	layer = 60
	canvas = Control.new()
	canvas.theme = UI.theme()
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("060b15")
	canvas.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.add_theme_constant_override("separation", 10)
	canvas.add_child(controls)
	anchor(controls, Rect2(.05, .914, .90, .05))
	next = UI.button(controls, "Next", advance, true, 35)
	UI.button(controls, "Skip intro", skip, false, 35)
	if RiftSettings.show_hub_tips:
		UI.button(controls, "Start Nova tutorial", start_tutorial, false, 35)
	next.grab_focus()
	shade = ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color.a = 0.0

	music = AudioStreamPlayer.new()
	var bed := MUSIC.duplicate() as AudioStreamOggVorbis
	bed.loop = true
	music.stream = bed
	music.bus = &"Music"
	music.volume_db = -23.0
	add_child(music)
	music.play()

func advance() -> void:
	if ended:
		return
	if lettering and lettering.is_running():
		lettering.kill()
		subtitle.visible_characters = -1
		return
	line_index += 1
	if line_index >= Story.OPENING[scene_index].size():
		scene_index += 1
		line_index = 0
	if scene_index >= Story.OPENING.size():
		close()
	else:
		show_line()

func start_tutorial() -> void:
	tutorial_requested = true
	close()

func skip() -> void:
	skipped = true
	close()

func show_line() -> void:
	rebuild_page()
	var line: Array = Story.OPENING[scene_index][line_index]
	var tint: Color = COLORS[line[0]]
	match scene_index:
		0: show_city()
		1: show_control_room(line[0])
		2: show_guardians()
		3: show_lab(line[0])
		4: show_floodgate()
	var location: String = "MERIDIAN / EARTH / 2189" if scene_index == 0 else TITLES[scene_index]
	var heading := UI.label(page, location, 22, Color("d9ecff"))
	anchor(heading, Rect2(.057, .037, .85, .039))
	var speaker: String = NAMES.get(line[0], line[0])
	if (scene_index == 2 and line_index == 1) or (scene_index == 4 and line[0] == "VOSS"):
		speaker += "   /   RADIO"
	caption(speaker, line[1], tint)
	next.text = "Continue to Hub" if scene_index == 4 and line_index == 2 else "Next"

func rebuild_page() -> void:
	if motion and motion.is_running():
		motion.kill()
	if is_instance_valid(page):
		page.hide()
		page.queue_free()
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	canvas.move_child(page, 1)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion = create_tween().set_parallel()
	page.modulate.a = 0.65
	motion.tween_property(page, "modulate:a", 1.0, 0.19)

func show_city() -> void:
	var vista := art(CITY, FULL, Color("76d9ff"))
	if line_index == 0:
		art(NEXUS, Rect2(.65, .16, .26, .42), Color("8cddff"))
	else:
		motion.tween_property(vista, "modulate", Color("46516d"), 1.25)
		var core := art(NEXUS, Rect2(.65, .16, .26, .42), Color("ff7583"))
		var break_light := ColorRect.new()
		break_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		core.add_child(break_light)
		break_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var crack := ShaderMaterial.new()
		crack.shader = FRACTURE
		break_light.material = crack
		motion.tween_method(func(value: float): crack.set_shader_parameter("surge", value), 0.0, 1.0, 1.05)
		RiftAudio.play_effect(&"enemy_break")

func show_control_room(speaker: String) -> void:
	art(NEXUS, FULL, Color("3e6587")).modulate = Color("60738c")
	var voss := art(VOSS, Rect2(.076, .14, .27, .59), Color("7ceaff"))
	var soren := art(SOREN, Rect2(.654, .14, .27, .59), Color("f48a92"))
	voss.modulate = Color.WHITE if speaker == "VOSS" else Color("8894a9")
	soren.modulate = Color.WHITE if speaker == "SOREN" else Color("8894a9")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	anchor(grid, Rect2(.376, .33, .248, .265))
	for sector in 9:
		var district := PanelContainer.new()
		district.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		district.size_flags_vertical = Control.SIZE_EXPAND_FILL
		district.custom_minimum_size.y = 35
		var circuit := UI.frame(Color("123d55"), Color("77eaff"), 2)
		district.add_theme_stylebox_override("panel", circuit)
		grid.add_child(district)
		var number := UI.label(district, "%02d" % (sector + 1), 18, Color("80efff"))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line_index > 0:
			motion.tween_property(circuit, "bg_color", Color("171827"), .3).set_delay(sector * .1)
			motion.tween_property(circuit, "border_color", Color("814656"), .3).set_delay(sector * .1)
			motion.tween_property(number, "modulate", Color("aa7481"), .3).set_delay(sector * .1)

func show_guardians() -> void:
	if line_index == 0:
		art(still("guardian-10.jpg", ARCHITECT), FULL, Color("f7667f"))
		return
	for sector in 9:
		var column := sector % 3
		var row := floori(sector / 3.0)
		var x := .053 + column * .300
		var y := .096 + row * .202
		var shot := art(still("guardian-%02d.jpg" % (sector + 1), ARCHITECT), Rect2(x, y, .291, .189), Color("ed667d"))
		shot.modulate = Color("ff687c00")
		motion.tween_property(shot, "modulate", Color.WHITE, .30).set_delay(sector * .105)
		var title := UI.label(shot, Catalog.info(sector + 1).boss, 18, Color.WHITE)
		title.add_theme_color_override("font_outline_color", Color("110a13"))
		title.add_theme_constant_override("outline_size", 6)
		anchor(title, Rect2(.045, .77, .9, .18))
	RiftAudio.play_effect(&"armor_hit")

func show_lab(speaker: String) -> void:
	art(LAB, FULL, UI.CYAN).modulate = Color("748ea5")
	var engineer := art(VOSS, Rect2(.075, .15, .27, .56), Color("73dafa"))
	var hero := art(operator_portrait(), Rect2(.40, .18, .34, .53), Color("69f4ff"))
	var drone := art(NOVA, Rect2(.77, .39, .145, .25), Color("b58bfa"))
	engineer.modulate = Color.WHITE if speaker == "VOSS" else Color("889cb9")
	drone.modulate = Color.WHITE if speaker == "NOVA" else Color("8298b1")
	if line_index == 1:
		hero.modulate = Color("5b7b8a")
		motion.tween_property(hero, "modulate", Color.WHITE, .68)
		RiftAudio.play_effect(&"deploy_zap")

func show_floodgate() -> void:
	if line_index == 2:
		flash(Color("c3efff"), .58, .7)
		radio_break()
		return
	art(still("floodgate.jpg", WATER), FULL, Color("5dd9fa"))
	if line_index == 0:
		show_convoy()
		RiftAudio.play_effect(&"enemy_break")
	else:
		flash(Color("5ee6ff"), .28, .4)
		RiftAudio.play_effect(&"deploy_zap")

func show_convoy() -> void:
	var street := art(CITY, Rect2(.665, .148, .258, .32), Color("71e7f5"))
	var road := ColorRect.new()
	road.color = Color("1b2936")
	street.add_child(road)
	anchor(road, Rect2(0, .75, 1, .055))
	for index in 3:
		var carrier := Polygon2D.new()
		carrier.polygon = PackedVector2Array([Vector2(-21, -13), Vector2(4, -13),
			Vector2(4, -10), Vector2(12, -10), Vector2(20, -4), Vector2(20, 0), Vector2(-21, 0)])
		carrier.color = Color("354b5c")
		road.add_child(carrier)
		var tread := PackedVector2Array()
		for point in 8:
			tread.append(Vector2.from_angle(TAU * point / 8.0) * 3.2)
		for axle in [-14, -5, 12]:
			var wheel := Polygon2D.new()
			wheel.polygon = tread
			wheel.position = Vector2(axle, 0)
			wheel.color = Color("0d1622")
			carrier.add_child(wheel)
		var cab := Polygon2D.new()
		cab.polygon = PackedVector2Array([Vector2(6, -9), Vector2(11, -9), Vector2(16, -5), Vector2(6, -5)])
		cab.color = Color("ffde94")
		carrier.add_child(cab)
		var travel := create_tween()
		travel.tween_method(func(progress: float):
			carrier.position = Vector2(road.size.x * progress, -2)
		, 0.05 + index * 0.16, 0.58 + index * 0.16, 2.45)
		travel.bind_node(page)

func radio_break() -> void:
	var static_clip := AudioStreamWAV.new()
	static_clip.format = AudioStreamWAV.FORMAT_16_BITS
	static_clip.mix_rate = 22050
	var count := roundi(static_clip.mix_rate * .29)
	var waveform := PackedByteArray()
	waveform.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 2189
	var filter := 0.0
	for index in count:
		var sample := noise.randf_range(-1.0, 1.0)
		filter = lerpf(filter, sample, 0.35)
		var envelope := 1.0 - float(index) / count
		waveform.encode_s16(index * 2, roundi((sample - filter) * envelope * 4200.0))
	static_clip.data = waveform
	var transmission := AudioStreamPlayer.new()
	transmission.stream = static_clip
	transmission.bus = &"SFX"
	add_child(transmission)
	transmission.finished.connect(transmission.queue_free)
	transmission.play()

func still(name: String, fallback: Texture2D) -> Texture2D:
	var path := "res://assets/ui/story/opening/" + name
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else fallback

func operator_portrait() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAITS
	atlas.region = Rect2(0, PORTRAITS.get_height() * .5, PORTRAITS.get_width() * .5, PORTRAITS.get_height() * .5)
	atlas.filter_clip = true
	return atlas

func art(texture: Texture2D, bounds: Rect2, tint: Color) -> Panel:
	var frame := Panel.new()
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(frame)
	anchor(frame, bounds)
	var frame_style := UI.frame(Color("0a111e"), tint.darkened(.14), 2)
	frame.add_theme_stylebox_override("panel", frame_style)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = texture
	frame.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 3
	picture.offset_top = 3
	picture.offset_right = -3
	picture.offset_bottom = -3
	return frame

func caption(speaker: String, detail: String, tint: Color) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(panel)
	anchor(panel, Rect2(.061, .882, .878, 0))
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := UI.frame(Color("0c1729"), tint.darkened(.2), 5)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var copy := UI.column(panel, 4)
	UI.label(copy, speaker, 25, tint)
	subtitle = UI.label(copy, detail, 27, UI.WHITE)
	subtitle.add_theme_font_override("font", BODY_FONT)
	subtitle.add_theme_constant_override("line_spacing", 5)
	subtitle.visible_characters = 0
	lettering = create_tween()
	lettering.tween_property(subtitle, "visible_characters", detail.length(), float(detail.length()) / 48.0)
	lettering.tween_callback(func(): subtitle.visible_characters = -1)

func anchor(control: Control, bounds: Rect2) -> void:
	control.anchor_left = bounds.position.x
	control.anchor_top = bounds.position.y
	control.anchor_right = bounds.end.x
	control.anchor_bottom = bounds.end.y

func flash(color: Color, strength: float, duration: float) -> void:
	if transition and transition.is_running():
		transition.kill()
	shade.color = Color(color, strength)
	transition = create_tween()
	transition.tween_property(shade, "color:a", 0.0, duration)

func close() -> void:
	if ended:
		return
	ended = true
	if lettering and lettering.is_running():
		lettering.kill()
	if transition and transition.is_running():
		transition.kill()
	shade.color = Color(0.02, 0.03, 0.06, 0)
	var fade_out := create_tween().set_parallel()
	fade_out.tween_property(shade, "color:a", 1.0, 0.24)
	fade_out.tween_property(music, "volume_db", -55.0, 0.24)
	await fade_out.finished
	finished.emit()

func _input(event: InputEvent) -> void:
	if ended or not is_instance_valid(next):
		return
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		skip()
	elif event.is_action_pressed(&"ui_accept") and not event.is_echo():
		var focused := get_viewport().gui_get_focus_owner() as Button
		get_viewport().set_input_as_handled()
		if focused and is_ancestor_of(focused):
			focused.pressed.emit()
		else:
			advance()
