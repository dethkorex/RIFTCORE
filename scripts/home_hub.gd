extends Node3D

signal station_requested(page: String)
signal title_requested

const UI := preload("res://scripts/rift_ui.gd")
const AVATAR := preload("res://scenes/actors/riftcore_player.tscn")
const WINDOW := preload("res://assets/campaign/orbital_array/panorama.png")
const DECK := preload("res://assets/campaign/orbital_array/terrain/deck.tscn")
const REACTOR := preload("res://assets/campaign/props/sci-reactor.glb")
const STATIONS := [
	{"x": -18.0, "name": "Save Game", "page": "Save Game", "color": Color("f18da9")},
	{"x": -13.5, "name": "Settings", "page": "Settings", "color": Color("a5a9ff")},
	{"x": -9.0, "name": "Item Shop", "page": "Item shop", "color": Color("f2ac85")},
	{"x": -4.5, "name": "Workshop", "page": "Upgrades", "color": Color("ffc971")},
	{"x": 0.0, "name": "Deploy", "page": "Sector select", "color": Color("5dffdc")},
	{"x": 4.5, "name": "Storage", "page": "Storage", "color": Color("86ecc8")},
	{"x": 9.0, "name": "Loadout", "page": "Loadout", "color": Color("72d1ff")},
	{"x": 13.5, "name": "Challenges", "page": "Challenges", "color": Color("d2a0ff")},
	{"x": 18.0, "name": "Field Guide", "page": "Collection", "color": Color("a3eca4")},
]

var avatar: RiftPlayer
var camera: Camera3D
var prompt: Label3D
var current_station := -1
var panel_open := false
var pads: Array[Dictionary] = []
var bank_label: Label
var hud_layer: CanvasLayer
var velocity_x := 0.0
var metal: StandardMaterial3D
var frame: StandardMaterial3D
var cyan: StandardMaterial3D

func _ready() -> void:
	metal = paint(Color("162538"), 0.0, 0.63)
	frame = paint(Color("273f56"), 0.0, 0.62)
	cyan = paint(Color("54d9fb"), 1.2)
	build_room()
	for station in STATIONS:
		build_pad(station)
	avatar = AVATAR.instantiate() as RiftPlayer
	add_child(avatar)
	avatar.position = Vector3(0, 0.89, 0)
	avatar.set_physics_process(false)
	avatar.collision_layer = 0
	avatar.collision_mask = 0
	avatar.model_root.rotation.y = 0.28
	avatar.play_character_animation("idle", true)
	prompt = label_in_space(avatar, "", Vector3(0, 1.58, 0.25), 46, Color.WHITE)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2.6, 8.5)
	camera.rotation_degrees.x = -4.0
	camera.fov = 68.0
	camera.make_current()
	build_hud()
	update_station()

func _physics_process(delta: float) -> void:
	if panel_open:
		return
	var input_axis := Input.get_axis("move_left", "move_right")
	if absf(input_axis) < 0.15:
		input_axis = Input.get_axis("ui_left", "ui_right")
	velocity_x = move_toward(velocity_x, input_axis * 6.6, delta * 38.0)
	var next_x := clampf(avatar.position.x + velocity_x * delta, -19.15, 19.15)
	var moving := absf(next_x - avatar.position.x) > 0.003
	avatar.position.x = next_x
	if moving:
		avatar.model_root.rotation.y = lerp_angle(avatar.model_root.rotation.y, signf(velocity_x) * PI * 0.5, 1.0 - exp(-18.0 * delta))
	avatar.play_character_animation("walk" if moving else "idle")
	camera.position.x = lerpf(camera.position.x, clampf(next_x * 0.88, -15.3, 15.3), 1.0 - exp(-6.5 * delta))
	update_station()

func _process(delta: float) -> void:
	for index in range(pads.size()):
		var pad := pads[index]
		var active := index == current_station
		var glow: StandardMaterial3D = pad.glow
		glow.emission_energy_multiplier = move_toward(glow.emission_energy_multiplier, 2.2 if active else 0.37, delta * 7.2)
		var beam: MeshInstance3D = pad.beam
		beam.visible = active
		if active:
			beam.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.08
		var lamp: OmniLight3D = pad.light
		lamp.light_energy = move_toward(lamp.light_energy, 1.75 if active else 0.0, delta * 7.0)

func update_station() -> void:
	var nearest := -1
	for index in range(STATIONS.size()):
		if absf(avatar.position.x - float(STATIONS[index].x)) <= 1.14:
			nearest = index
			break
	if nearest != current_station and nearest >= 0:
		RiftAudio.play_effect(&"menu_move")
	current_station = nearest
	prompt.visible = nearest >= 0 and not panel_open
	if nearest >= 0:
		prompt.text = "%s\nE / A  ·  Interact" % STATIONS[nearest].name
		prompt.modulate = STATIONS[nearest].color.lerp(Color.WHITE, 0.32)

func set_panel_open(open: bool) -> void:
	panel_open = open
	hud_layer.visible = not open
	velocity_x = 0.0
	avatar.play_character_animation("idle", true)
	update_station()

func set_bank(amount: int) -> void:
	bank_label.text = "%04d BOLTS" % amount

func _unhandled_input(event: InputEvent) -> void:
	if panel_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		title_requested.emit()
		return
	var use_key: bool = event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo
	if current_station >= 0 and (use_key or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		RiftAudio.play_effect(&"menu_confirm")
		var destination: String = STATIONS[current_station].page
		if destination == "Title":
			title_requested.emit()
		else:
			station_requested.emit(destination)

func build_room() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("071324")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b0cef7")
	world.environment.ambient_light_energy = 0.81
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -30, 0)
	key.light_energy = 1.12
	key.light_color = Color("cce8ff")
	add_child(key)
	var panorama := MeshInstance3D.new()
	var glass_view := QuadMesh.new()
	glass_view.size = Vector2(46, 9)
	panorama.mesh = glass_view
	var view_finish := StandardMaterial3D.new()
	view_finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view_finish.albedo_texture = WINDOW
	view_finish.albedo_color = Color("96b8e2")
	panorama.material_override = view_finish
	panorama.position = Vector3(0, 3.9, -5.3)
	add_child(panorama)
	for x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		var platform := DECK.instantiate() as Node3D
		add_child(platform)
		platform.position = Vector3(x, 0, 0)
		platform.scale.z = 2.4
	box(self, Vector3(0, -0.43, 0), Vector3(40, 0.42, 4.75), metal)
	box(self, Vector3(0, -0.28, 2.46), Vector3(39.9, 0.045, 0.055), cyan)
	box(self, Vector3(0, 0.28, -4.26), Vector3(41, 0.54, 0.65), metal)
	box(self, Vector3(0, 0.62, -4.07), Vector3(41, 0.065, 0.14), cyan)
	box(self, Vector3(0, 5.3, -2.30), Vector3(41, 0.63, 4.3), metal)
	box(self, Vector3(0, 4.95, -0.35), Vector3(40.6, 0.08, 0.11), cyan)
	box(self, Vector3(0, 4.78, -4.13), Vector3(40.6, 0.22, 0.35), frame)
	for x in [-20.8, -15.6, -10.4, -5.2, 0.0, 5.2, 10.4, 15.6, 20.8]:
		box(self, Vector3(x, 2.72, -4.19), Vector3(0.27, 4.18, 0.44), frame)
		box(self, Vector3(x, 3.96, -3.93), Vector3(0.08, 0.61, 0.064), cyan)
	for x in [-11.1, -6.65, -2.2, 2.2, 6.65, 11.1]:
		box(self, Vector3(x, 0.36, -2.83), Vector3(0.77, 0.72, 0.58), metal)
		var screen := box(self, Vector3(x, 0.77, -2.69), Vector3(0.71, 0.27, 0.055), frame)
		screen.rotation.x = -0.23
		for row in range(3):
			box(self, Vector3(x - 0.08, 0.69 + row * 0.066, -2.63), Vector3(0.38 - row * 0.072, 0.017, 0.022), cyan)
	for x in [-15.05, 15.05]:
		var reactor := REACTOR.instantiate() as Node3D
		add_child(reactor)
		reactor.position = Vector3(x, 0, -2.9)

func build_pad(station: Dictionary) -> void:
	var at := Node3D.new()
	add_child(at)
	at.position.x = station.x
	var tint: Color = station.color
	var glow := paint(tint, 0.37)
	var footing := CylinderMesh.new()
	footing.top_radius = 0.98
	footing.bottom_radius = 1.08
	footing.height = 0.15
	footing.radial_segments = 8
	part(at, footing, Vector3(0, 0.057, 0), frame)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.82
	plate.bottom_radius = 0.82
	plate.height = 0.035
	plate.radial_segments = 24
	part(at, plate, Vector3(0, 0.14, 0), metal)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.74
	ring.outer_radius = 0.85
	part(at, ring, Vector3(0, 0.157, 0), glow)
	for side in [-1.0, 1.0]:
		box(at, Vector3(side * 0.65, 0.125, 0.68), Vector3(0.29, 0.08, 0.11), glow)
	var beacon := CylinderMesh.new()
	beacon.top_radius = 0.97
	beacon.bottom_radius = 0.69
	beacon.height = 2.25
	beacon.radial_segments = 24
	var beam_finish := ShaderMaterial.new()
	beam_finish.shader = preload("res://assets/ui/hub_pad_light.gdshader")
	beam_finish.set_shader_parameter("tint", tint)
	var beam := part(at, beacon, Vector3(0, 1.23, 0), beam_finish)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.hide()
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 0.53, 0.58)
	lamp.light_color = tint
	lamp.light_energy = 0.0
	lamp.omni_range = 2.9
	at.add_child(lamp)
	label_in_space(at, String(station.name).to_upper(), Vector3(0, 0.38, 1.26), 37, tint.lerp(Color.WHITE, 0.24))
	pads.append({"glow": glow, "beam": beam, "light": lamp})

func build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var interface := Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(interface)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var info := VBoxContainer.new()
	info.position = Vector2(24, 20)
	info.custom_minimum_size.x = 380
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.add_child(info)
	UI.label(info, "RIFTCORE STATION", 29, UI.CYAN)
	UI.label(info, "Walk to a pad to access its station.", 15, UI.WHITE)
	bank_label = UI.label(info, "", 16, Color("ffcd76"))

func paint(tint: Color, emission: float, metallic := 0.0) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = tint
	finish.metallic = metallic
	finish.roughness = 0.34
	finish.emission_enabled = emission > 0.0
	finish.emission = tint
	finish.emission_energy_multiplier = emission
	return finish

func part(parent: Node3D, mesh: Mesh, at: Vector3, finish: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = finish
	piece.position = at
	parent.add_child(piece)
	return piece

func box(parent: Node3D, at: Vector3, dimensions: Vector3, finish: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return part(parent, mesh, at, finish)

func label_in_space(parent: Node3D, text: String, at: Vector3, pixels: int, tint: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = pixels
	label.pixel_size = 0.0048
	label.outline_size = 12
	label.modulate = tint
	label.position = at
	parent.add_child(label)
	return label
