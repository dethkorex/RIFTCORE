extends Node3D

signal station_requested(page: String)
signal title_requested

const UI := preload("res://scripts/rift_ui.gd")
const PauseMenu := preload("res://scripts/coop_pause_menu.gd")
const AVATAR := preload("res://scenes/actors/riftcore_player.tscn")
const WINDOW := preload("res://assets/hub/orbital_view.png")
const STATIONS := [
	{"x": -18.0, "name": "System", "page": "Save Game", "color": Color("9cbbff"), "prop": "settings_terminal"},
	{"x": -9.0, "name": "Crafting", "page": "Fabrication", "color": Color("ffc465"), "prop": "forge_bay"},
	{"x": -4.5, "name": "Shop", "page": "Shop", "color": Color("ffd076"), "prop": "storage_bay"},
	{"x": 0.0, "name": "Deploy", "page": "Sector select", "color": Color("52edff"), "prop": "deploy_pad"},
	{"x": 4.5, "name": "Equipment", "page": "Storage", "color": Color("5ffcec"), "prop": "storage_bay"},
	{"x": 9.0, "name": "Social", "page": "Social", "color": Color("b883ff"), "prop": "save_terminal"},
	{"x": 13.5, "name": "Challenges", "page": "Challenges", "color": Color("bd8cff"), "prop": "challenge_terminal"},
	{"x": 18.0, "name": "NOVA Archive", "page": "Collection", "color": Color("81ffe8"), "prop": "archive_terminal"},
]

const BlueprintOrb := preload("res://scripts/pickup_orb_visual.gd")
var profile: RefCounted
var persist_blueprint_trade: Callable
var blueprint_visuals: Dictionary = {}
var blueprint_requests: Dictionary = {}
var avatar: RiftPlayer
var partners: Dictionary = {}
var local_online_label: Label3D
var station_sync := 0.0
var camera: Camera3D
var prompt: Label3D
var current_station := -1
var panel_open := false
var pause_menu: PauseMenu
var reconstructing := false
var story: CanvasLayer
const NOVA := preload("res://assets/ui/nova_guide.svg")
const RX07 := preload("res://assets/ui/rx07_menu.png")
const ARRIVAL := [
	["NOVA", "RX-07, can you hear me? I am NOVA. You are on the Deploy pad at Operations Station."],
	["RX-07", "I can hear you. Why can't I remember getting here?"],
	["NOVA", "The Architect built you. After the Blackout, Dr. Mara Voss installed the Rogue Protocol so you could choose your own orders."],
	["RX-07", "Then tell me where you need me."],
	["NOVA", "The Architect seized ten facilities. Start in Neon Factory. Stop the Forge Titan and bring back its memory. We need those records to reach the Architect."],
	["RX-07", "Understood. Put Neon Factory on the deployment map."],
]
const RECONSTRUCTION := [
	["NOVA", "You're back, RX-07. When a frame is lost, I can recode you from the operator pattern."],
	["RX-07", "Then put me back where I fell."],
	["NOVA", "I can restore you here. The deployment is gone, so you'll start again in Neon Factory. Your banked bolts and permanent enhancements are still here."],
	["RX-07", "All right. Let's make this run count."],
]
var pads: Array[Dictionary] = []
var bank_label: Label
var bolts_label: Label
var shards_label: Label
var station_notice: Button
var hud_layer: CanvasLayer
const HUB_RUN_SPEED := 6.6
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
	avatar.position = Vector3(0, 1.11, 0)
	avatar.set_physics_process(false)
	avatar.collision_layer = 0
	avatar.collision_mask = 0
	avatar.model_root.rotation.y = 0.28
	avatar.play_character_animation("idle", true)
	prompt = label_in_space(avatar, "", Vector3(0, 1.52, 0.25), 36, Color.WHITE)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	local_online_label = label_in_space(avatar, "", Vector3(0, 1.21, 0), 27, Color("91edff"))
	local_online_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	local_online_label.hide()
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2.75, 10.6)
	camera.rotation_degrees.x = -5.2
	camera.fov = 59.0
	camera.make_current()
	build_hud()
	pause_menu = PauseMenu.new()
	pause_menu.dismissed.connect(set_panel_open.bind(false))
	pause_menu.leave_requested.connect(func():
		pause_menu.close()
		RiftRelay.leave()
	)
	add_child(pause_menu)
	RiftRelay.blueprint_drop_changed.connect(update_blueprint_drop)
	RiftRelay.blueprint_received.connect(receive_blueprint)
	for key in RiftRelay.blueprint_drops:
		var offer: Dictionary = RiftRelay.blueprint_drops[key]
		update_blueprint_drop(key, offer.id, offer.owner, offer.x)
	RiftRelay.partner_moved.connect(update_partner)
	RiftRelay.changed.connect(refresh_partner_room)
	refresh_partner_room()
	update_station()

func materialize_operator(sequence := "") -> void:
	reconstructing = true
	update_station()
	avatar.position = Vector3(0.0, 1.11, 0.0)
	avatar.model_root.rotation.y = 0.28
	avatar.play_character_animation("idle", true)
	var fade_meshes: Array[MeshInstance3D] = []
	var original_transparency := PackedFloat32Array()
	for child in avatar.model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.is_visible_in_tree():
			fade_meshes.append(mesh)
			original_transparency.append(mesh.transparency)
			mesh.transparency = 1.0
	var beam := preload("res://scripts/deploy_lightning.gd").new()
	add_child(beam)
	beam.global_position = Vector3(0, 0.18, 0)
	beam.strike()
	RiftAudio.play_effect(&"deploy_zap")
	var opening := camera.position
	var close := Vector3(0.0, 2.35, 8.1)
	var reveal := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var reveal_time := 1.85 if sequence == "arrival" else (1.30 if sequence == "reconstruction" else 0.45)
	reveal.tween_property(camera, "position", close, reveal_time)
	reveal.tween_method(func(weight: float):
		for index in fade_meshes.size():
			fade_meshes[index].transparency = lerpf(1.0, original_transparency[index], weight)
	, 0.0, 1.0, reveal_time)
	await reveal.finished
	avatar.play_character_animation("land", true)
	await get_tree().create_timer(0.26).timeout
	avatar.play_character_animation("idle", true)
	if not sequence.is_empty():
		await play_station_story(ARRIVAL if sequence == "arrival" else RECONSTRUCTION)
	await create_tween().tween_property(camera, "position", opening, 0.42).finished
	reconstructing = false
	update_station()

func has_dialogue() -> bool:
	return is_instance_valid(story) and story.visible and not story.is_queued_for_deletion()

func play_station_story(lines: Array) -> void:
	story = CanvasLayer.new()
	story.layer = 39
	add_child(story)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.frame(Color("0c182cf5"), UI.CYAN, 4))
	story.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -408
	box.offset_right = 408
	box.offset_top = -197
	box.offset_bottom = -23
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var frame_box := PanelContainer.new()
	frame_box.add_theme_stylebox_override("panel", UI.frame(Color("081222"), UI.CYAN, 2))
	row.add_child(frame_box)
	frame_box.add_child(portrait)
	var pane := VBoxContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pane)
	var speaker := UI.label(pane, "", 23, UI.CYAN)
	var speech := UI.label(pane, "", 22)
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var next := UI.button(pane, "Continue", func(): pass, true, 43)
	var pilot := AtlasTexture.new()
	pilot.atlas = RX07
	var source := RX07.get_size()
	pilot.region = Rect2(source.x * 0.35, source.y * 0.05, source.x * 0.31, source.y * 0.46)
	for index in lines.size():
		var line: Array = lines[index]
		speaker.text = line[0]
		speech.text = line[1]
		var guide: bool = line[0] == "NOVA"
		portrait.texture = NOVA if guide else pilot
		speaker.add_theme_color_override("font_color", UI.VIOLET if guide else UI.CYAN)
		next.text = "Continue" if index < lines.size() - 1 else "Back to Station"
		next.grab_focus()
		await next.pressed
	story.hide()
	story.queue_free()

func _physics_process(delta: float) -> void:
	if panel_open or reconstructing:
		return
	var input_axis := Input.get_axis("move_left", "move_right")
	if absf(input_axis) < 0.15:
		input_axis = Input.get_axis("ui_left", "ui_right")
	velocity_x = move_toward(velocity_x, RiftPlayer.locomotion_speed(input_axis, HUB_RUN_SPEED), delta * 38.0)
	var next_x := clampf(avatar.position.x + velocity_x * delta, -19.15, 19.15)
	var moving := absf(next_x - avatar.position.x) > 0.003
	avatar.position.x = next_x
	avatar.position.y = lerpf(avatar.position.y, 1.11 if absf(next_x) < 1.25 else 0.89, 1.0 - exp(-18.0 * delta))
	if moving:
		avatar.model_root.rotation.y = lerp_angle(avatar.model_root.rotation.y, signf(velocity_x) * PI * 0.5, 1.0 - exp(-18.0 * delta))
	avatar.play_ground_locomotion(input_axis, velocity_x if moving else 0.0, HUB_RUN_SPEED)
	camera.position.x = lerpf(camera.position.x, clampf(next_x * 0.88, -15.3, 15.3), 1.0 - exp(-6.5 * delta))
	update_station()

func _process(delta: float) -> void:
	for entry in partners.values():
		var partner: RiftPlayer = entry.actor
		partner.position.x = lerpf(partner.position.x, entry.x, 1.0 - exp(-16.0 * delta))
		partner.position.y = 1.11 if absf(partner.position.x) < 1.25 else 0.89
		partner.model_root.rotation.y = entry.facing
	station_sync += delta
	if station_sync >= 0.05:
		station_sync = 0.0
		var animation := avatar.current_animation if avatar.current_animation in ["idle", "walk", "run"] else "idle"
		RiftRelay.send_station_position(avatar.position.x, avatar.model_root.rotation.y, animation)
		check_blueprint_pickups()
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

func update_partner(id: int, x: float, facing: float, animation: String, display_name: String) -> void:
	if not partners.has(id):
		var partner := AVATAR.instantiate() as RiftPlayer
		add_child(partner)
		partner.position = Vector3(x, 1.11, -0.26 * (partners.size() + 1))
		partner.set_physics_process(false)
		partner.set_process(false)
		partner.collision_layer = 0
		partner.collision_mask = 0
		var partner_label := label_in_space(partner, "", Vector3(0, 1.54, 0), 29, Color("ca99ff"))
		partner_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		partners[id] = {"actor": partner, "label": partner_label}
	var entry: Dictionary = partners[id]
	entry.label.text = display_name
	entry.x = x
	entry.facing = facing
	entry.actor.play_character_animation(animation)

func refresh_partner_room() -> void:
	if RiftRelay.connected_room.is_empty() and is_pause_open():
		pause_menu.close()
	local_online_label.text = RiftRelay.local_name
	local_online_label.visible = not RiftRelay.connected_room.is_empty()
	var members: Array = [] if RiftRelay.connected_room.is_empty() else RiftRelay.relay.lobby_get_all_clients()
	for id in partners.keys():
		if not members.has(id):
			partners[id].actor.queue_free()
			partners.erase(id)

func update_station() -> void:
	var nearest := -1
	for index in range(STATIONS.size()):
		if absf(avatar.position.x - float(STATIONS[index].x)) <= 1.14:
			nearest = index
			break
	if nearest != current_station and nearest >= 0:
		RiftAudio.play_effect(&"menu_move")
	current_station = nearest
	prompt.visible = nearest >= 0 and not panel_open and not reconstructing
	station_notice.visible = nearest >= 0 and not panel_open and not reconstructing
	if nearest >= 0:
		prompt.text = STATIONS[nearest].name.to_upper()
		prompt.modulate = STATIONS[nearest].color.lerp(Color.WHITE, 0.32)
		station_notice.text = "%s   /   %s INTERACT" % [STATIONS[nearest].name.to_upper(), "A" if not Input.get_connected_joypads().is_empty() else "E"]
		station_notice.add_theme_color_override("font_color", prompt.modulate)

func set_panel_open(open: bool) -> void:
	panel_open = open
	hud_layer.visible = not open
	velocity_x = 0.0
	avatar.play_character_animation("idle", true)
	update_station()

func set_bank(amount: int, shards: int, level: int) -> void:
	bank_label.text = "RX-07   /   PLAYER %02d" % level
	bolts_label.text = "%04d BOLTS" % amount
	shards_label.text = "%04d CORE SHARDS" % shards

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and not is_pause_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if panel_open or reconstructing:
		return
	if not RiftRelay.connected_room.is_empty() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		pause_menu.open()
		set_panel_open(true)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		title_requested.emit()
		return
	var use_key: bool = event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo
	if current_station >= 0 and (use_key or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		activate_station()

func is_pause_open() -> bool:
	return is_instance_valid(pause_menu) and pause_menu.is_open()

func activate_station() -> void:
	if panel_open or reconstructing or current_station < 0:
		return
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
	glass_view.size = Vector2(63, 21)
	panorama.mesh = glass_view
	var view_finish := StandardMaterial3D.new()
	view_finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view_finish.albedo_texture = WINDOW
	view_finish.albedo_color = Color("dcdeff")
	panorama.material_override = view_finish
	panorama.position = Vector3(1.0, 4.0, -12.0)
	add_child(panorama)
	var floor_finish := paint(Color("283954"), 0.0, 0.57)
	floor_finish.roughness = 0.29
	var inlay := paint(Color("41526d"), 0.0, 0.50)
	var purple := paint(Color("c356ed"), 1.20, 0.12)
	var strip := paint(Color("6ce7ff"), 1.38, 0.15)
	box(self, Vector3(0, -0.25, 4.38), Vector3(43.0, 0.48, 7.3), metal)
	box(self, Vector3(0, 5.66, 1.0), Vector3(43.5, 0.38, 12.2), metal)
	box(self, Vector3(0, 0.29, -3.34), Vector3(42.0, 0.62, 0.50), frame)
	box(self, Vector3(0, 0.59, -3.08), Vector3(41.5, 0.045, 0.058), purple)
	for side in [-1, 1]:
		box(self, Vector3(21.05 * side, 2.65, 1.10), Vector3(0.62, 5.45, 10.7), frame)
		box(self, Vector3(20.67 * side, 2.72, 4.66), Vector3(0.08, 3.6, 0.15), strip)
	for index in range(-4, 5):
		var x := index * 4.5
		for row in range(3):
			var z := 2.95 + row * 1.32
			box(self, Vector3(x - 1.07, -0.028, z), Vector3(2.06, 0.060, 1.27), floor_finish)
			box(self, Vector3(x + 1.07, -0.028, z), Vector3(2.06, 0.060, 1.27), floor_finish)
		box(self, Vector3(x, 0.009, 3.0), Vector3(3.85, 0.020, 0.040), inlay)
		box(self, Vector3(x, 0.012, 4.45), Vector3(2.76, 0.021, 0.051), strip if index % 2 == 0 else purple)
		box(self, Vector3(x + 2.21, 0.015, 4.66), Vector3(0.046, 0.012, 4.13), inlay)
		var ribs := box(self, Vector3(x, 5.14, 0.99), Vector3(0.34, 0.50, 8.45), frame)
		ribs.rotation_degrees.y = float(index % 2) * 7.0
		box(self, Vector3(x, 4.88, 3.22), Vector3(0.105, 0.038, 1.16), strip if index % 2 == 0 else purple)
		box(self, Vector3(x, 5.39, 3.0), Vector3(3.93, 0.12, 4.93), floor_finish)
		var illumination := OmniLight3D.new()
		illumination.position = Vector3(x, 3.35, 2.12)
		illumination.light_color = Color("7aaeff") if index % 2 == 0 else Color("b462ee")
		illumination.light_energy = 1.15
		illumination.omni_range = 4.8
		add_child(illumination)
	for index in range(-4, 5):
		var x := 4.5 * index
		place_asset("deck_section", Vector3(x, 0.0, 0.0))
		place_asset("window_frame", Vector3(x, 0.45, -3.28))
	for x in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		box(self, Vector3(x, 4.86, -1.85), Vector3(8.92, 0.39, 2.9), frame)
		box(self, Vector3(x, 5.15, -0.1), Vector3(8.90, 0.24, 1.5), metal)
		for side in [-1, 1]:
			var flange := box(self, Vector3(x + side * 3.06, 4.70, -0.11), Vector3(1.32, 0.18, 0.62), frame)
			flange.rotation.z = deg_to_rad(side * 13.0)
			box(self, Vector3(x + side * 2.50, 4.63, -0.06), Vector3(0.63, 0.035, 0.18), paint(Color("cb50f1"), 1.1))
		box(self, Vector3(x, -0.85, 1.61), Vector3(8.95, 0.93, 0.9), metal)
		box(self, Vector3(x, -0.69, 2.075), Vector3(7.76, 0.065, 0.034), cyan)
		box(self, Vector3(x, 4.73, -0.78), Vector3(7.7, 0.071, 0.075), cyan)
		box(self, Vector3(x, -0.10, -3.52), Vector3(8.96, 0.28, 0.35), metal)
	place_asset("operations_banner", Vector3(0, 4.36, -1.95))
	for x in [-10.8, 10.8]:
		var sash := paint(Color("40235b"), 0.11, 0.35)
		box(self, Vector3(x, 3.7, -2.28), Vector3(0.97, 1.61, 0.1), sash)
		box(self, Vector3(x, 4.50, -2.19), Vector3(1.25, 0.14, 0.22), frame)
		var band := box(self, Vector3(x, 3.35, -2.21), Vector3(0.91, 0.096, 0.034), paint(Color("8542ab"), 0.47))
		band.rotation.z = -0.30
		var crest := Sprite3D.new()
		crest.texture = preload("res://assets/ui/riftcore-icon.svg")
		crest.pixel_size = 0.63 / crest.texture.get_width()
		crest.position = Vector3(x, 3.76, -2.20)
		add_child(crest)

func place_asset(asset: String, position_on_deck: Vector3) -> Node3D:
	var scene := load("res://assets/hub/" + asset + ".tscn") as PackedScene
	var instance := scene.instantiate() as Node3D
	instance.position = position_on_deck
	add_child(instance)
	return instance

func build_pad(station: Dictionary) -> void:
	var at := Node3D.new()
	add_child(at)
	at.position.x = station.x
	var deployment: bool = station.page == "Sector select"
	var terminal := place_asset(station.prop, Vector3(station.x, 0, 0 if deployment else -1.84))
	if station.name == "System":
		terminal.set("caption", "SYSTEM / SAVE")
	elif station.name == "Shop":
		terminal.set("caption", "SHOP / SUPPLIES")
		terminal.set("accent", station.color)
	elif station.name == "Social":
		terminal.set("caption", "SOCIAL")
		terminal.set("icon", "icon_person")
		terminal.set("accent", station.color)
	var tint: Color = station.color
	var glow := paint(tint, 0.37)
	var footing := CylinderMesh.new()
	footing.top_radius = 0.98
	footing.bottom_radius = 1.08
	footing.height = 0.15
	footing.radial_segments = 8
	if not deployment:
		part(at, footing, Vector3(0, 0.057, 0), frame)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.82
	plate.bottom_radius = 0.82
	plate.height = 0.035
	plate.radial_segments = 24
	if not deployment:
		part(at, plate, Vector3(0, 0.14, 0), metal)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.74
	ring.outer_radius = 0.85
	part(at, ring, Vector3(0, 0.252 if deployment else 0.157, 0), glow)
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
	pads.append({"glow": glow, "beam": beam, "light": lamp})

func build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var interface := Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(interface)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.theme = UI.theme()
	var heading := PanelContainer.new()
	heading.position = Vector2(24, 21)
	heading.custom_minimum_size.x = 331
	interface.add_child(heading)
	UI.label(heading, "OPERATIONS HUB", 32, UI.CYAN)
	var wallet := PanelContainer.new()
	interface.add_child(wallet)
	var funds := UI.column(wallet, 3)
	bank_label = UI.label(funds, "", 16, UI.MUTED)
	bolts_label = UI.currency_row(funds, "")
	funds.add_child(HSeparator.new())
	shards_label = UI.currency_row(funds, "", true)
	wallet.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wallet.offset_left = -358
	wallet.offset_right = -24
	wallet.offset_top = 21
	station_notice = UI.button(interface, "", activate_station, false, 34, false)
	station_notice.focus_mode = Control.FOCUS_NONE
	station_notice.add_theme_font_size_override("font_size", 18)
	station_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	station_notice.offset_left = -190
	station_notice.offset_right = 190
	station_notice.offset_top = -77
	station_notice.offset_bottom = -22
	var idle := UI.texture_frame("panel_active_small", 31, Vector2(22, 12))
	var active := idle.duplicate() as StyleBoxTexture
	active.modulate_color = UI.VIOLET
	var down := active.duplicate() as StyleBoxTexture
	down.modulate_color = UI.VIOLET.darkened(0.22)
	UI.set_button_states(station_notice, idle, active, down)

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
	label.font = UI.DISPLAY
	label.font_size = pixels
	label.pixel_size = 0.0048
	label.outline_size = 12
	label.modulate = tint
	label.position = at
	parent.add_child(label)
	return label

func update_blueprint_drop(key: String, id: String, _owner: int, x: float) -> void:
	if blueprint_visuals.has(key):
		blueprint_visuals[key].queue_free()
		blueprint_visuals.erase(key)
	blueprint_requests.erase(key)
	if id.is_empty():
		return
	var orb := BlueprintOrb.new()
	orb.tint = Color("2abbff")
	orb.mark = BlueprintOrb.Mark.BLUEPRINT
	orb.position = Vector3(x, 0.54, 0.50)
	add_child(orb)
	blueprint_visuals[key] = orb
	var title := label_in_space(orb, "BLUEPRINT", Vector3(0, 0.57, 0), 22, Color("82eaff"))
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func check_blueprint_pickups() -> void:
	if not profile or panel_open or not RiftRelay.can_share_blueprints():
		return
	for key in RiftRelay.blueprint_drops.keys():
		var drop: Dictionary = RiftRelay.blueprint_drops[key]
		if absf(avatar.position.x - float(drop.x)) > 0.66 or drop.owner == RiftRelay.relay.get_client_id():
			continue
		var now := Time.get_ticks_msec()
		if profile.can_collect_blueprint(drop.id) and now >= int(blueprint_requests.get(key, 0)):
			blueprint_requests[key] = now + 1000
			RiftRelay.pick_up_blueprint(key)

func receive_blueprint(id: String) -> void:
	if profile and profile.collect_blueprint(id):
		if persist_blueprint_trade.is_valid():
			persist_blueprint_trade.call()
		RiftAudio.play_effect(&"pickup")
