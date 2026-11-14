extends Node3D

signal exit_requested

const PLAYER := preload("res://scenes/actors/riftcore_player.tscn")
const FLOOR := preload("res://assets/neon_factory/floor_panel_a.tscn")
const UI := preload("res://scripts/rift_ui.gd")
const INPUTS := [&"jump", &"dash", &"crouch", &"crouch_stick", &"shoot", &"melee", &"climb_down", &"swap_weapon", &"previous_suit"]
const ENEMY_POSITIONS := [10.0, 16.0, 23.0, 30.0, 36.0]
const TICK := 0.05

var host := false
var peer: Node
var operators: Array[RiftPlayer] = []
var enemies: Array[WalkerBot] = []
var room_status: Label
var stats: Label
var clock := 0.0
var guest_timeout := 0.0
var outcome := ""
var held: Dictionary = {}
var pressed: Dictionary = {}
var released: Dictionary = {}
var targets: Array = []
var enemy_targets: Array = []

func _ready() -> void:
	peer = RiftRelay.relay
	peer.expose_func(receive_input)
	peer.expose_func(receive_state)
	peer.expose_func(receive_shot)
	peer.expose_func(receive_outcome)
	build_arena()
	for index in 2:
		var operator := PLAYER.instantiate() as RiftPlayer
		operator.name = "Operator%d" % index
		operator.position = Vector3(1.0 + index * 1.4, 1.12, 0)
		operator.remote_input = host and index == 1
		add_child(operator)
		operator.set_physics_process(host)
		if not host:
			operator.set_process(false)
			operator.collision_layer = 0
			operator.collision_mask = 0
		else:
			operator.fell_into_pit.connect(operator.take_damage.bind(10000.0))
			operator.shot_fired.connect(send_shot)
			operator.died.connect(func():
				operator.hide()
				operator.set_deferred("collision_layer", 0)
			)
		operators.append(operator)
		targets.append([])
	for index in ENEMY_POSITIONS.size():
		var enemy := WalkerBot.new()
		enemy.name = "Security%d" % index
		enemy.variant = [WalkerBot.Variant.SCOUT, WalkerBot.Variant.TURRET, WalkerBot.Variant.HEAVY, WalkerBot.Variant.FLYER, WalkerBot.Variant.QUAD][index]
		enemy.position = Vector3(ENEMY_POSITIONS[index], 2.4 if index == 3 else 1.1, 0)
		enemy.mission_enemy = true
		if host:
			enemy.shot_fired.connect(send_shot)
		enemy.add_to_group(&"damageable_enemies")
		add_child(enemy)
		if not host:
			enemy.set_process(false)
			enemy.set_physics_process(false)
			enemy.collision_layer = 0
			enemy.collision_mask = 0
		enemies.append(enemy)
		enemy_targets.append([])
	var camera := SideCameraRig.new()
	camera.target = operators[0 if host else 1]
	camera.min_x = 0.0
	camera.max_x = 42.0
	add_child(camera)
	build_hud()

func build_arena() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("091527")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("91bde8")
	world.environment.ambient_light_energy = 0.9
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-31, -22, 0)
	light.light_energy = 1.1
	add_child(light)
	var panorama := Sprite3D.new()
	panorama.texture = preload("res://assets/neon_factory/factory_panorama.png")
	panorama.pixel_size = 0.038
	panorama.position = Vector3(20, 12, -13)
	add_child(panorama)
	for index in range(-2, 23):
		var floor_tile := FLOOR.instantiate() as Node3D
		floor_tile.position.x = index * 2.0
		add_child(floor_tile)
	for index in range(3):
		for column in range(2):
			var ledge := FLOOR.instantiate() as Node3D
			ledge.position = Vector3(9 + index * 10.0 + column * 2.0, 2.65 + (index % 2) * 0.65, 0)
			add_child(ledge)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UI.theme()
	panel.position = Vector2(22, 18)
	layer.add_child(panel)
	var content := UI.column(panel, 5)
	UI.label(content, "NEON FACTORY DEFENSE", 27, UI.CYAN)
	stats = UI.label(content, "", 16)
	room_status = UI.label(content, "Clear the security units with your partner.", 16, UI.MUTED)
	var leave := UI.button(content, "Return to Station", func(): exit_requested.emit(), false, 34)
	leave.focus_mode = Control.FOCUS_NONE

func get_player_axis() -> Vector2:
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("climb_down", "climb_up"))

func _physics_process(delta: float) -> void:
	if not outcome.is_empty() or not RiftRelay.mission_active:
		return
	if not host:
		for action in INPUTS:
			if Input.is_action_just_pressed(action):
				pressed[action] = true
			if Input.is_action_just_released(action):
				released[action] = true
	else:
		guest_timeout -= delta
		if guest_timeout <= 0.0:
			operators[1].remote_axis = Vector2.ZERO
			operators[1].remote_held.clear()
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.target = nearest_operator(enemy.global_position)
	clock += delta
	if clock < TICK:
		return
	clock = fmod(clock, TICK)
	if host:
		broadcast_state()
	else:
		send_input()

func nearest_operator(at: Vector3) -> RiftPlayer:
	var best: RiftPlayer
	var distance := INF
	for operator in operators:
		var gap := operator.global_position.distance_squared_to(at)
		if operator.health > 0 and gap < distance:
			best = operator
			distance = gap
	return best

func send_input() -> void:
	var current := 0
	var down := 0
	var up := 0
	for index in INPUTS.size():
		var action: StringName = INPUTS[index]
		if Input.is_action_pressed(action):
			current |= 1 << index
		if pressed.has(action):
			down |= 1 << index
		if released.has(action):
			up |= 1 << index
	pressed.clear()
	released.clear()
	var axis := get_player_axis()
	if down != 0 or up != 0:
		peer.call_func_on(peer.get_host(), receive_input, axis, current, down, up)
	else:
		peer.call_func_on_unreliable(peer.get_host(), receive_input, axis, current, down, up)

func receive_input(axis: Vector2, current: int, down: int, up: int) -> void:
	if not host or not outcome.is_empty() or not axis.is_finite() or not peer.lobby_get_all_clients().has(peer.get_sender_id()) or peer.get_sender_id() == peer.get_client_id():
		return
	var operator := operators[1]
	guest_timeout = 0.45
	operator.remote_axis = axis.clamp(Vector2(-1, -1), Vector2(1, 1))
	operator.remote_held.clear()
	for index in INPUTS.size():
		var action: StringName = INPUTS[index]
		if current & (1 << index):
			operator.remote_held[action] = true
		if down & (1 << index):
			operator.remote_pressed[action] = true
		if up & (1 << index):
			operator.remote_released[action] = true
	clear_edges.call_deferred(operator)

func clear_edges(operator: RiftPlayer) -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	operator.remote_pressed.clear()
	operator.remote_released.clear()

func broadcast_state() -> void:
	var players := []
	var security := []
	var active := 0
	for operator in operators:
		players.append([operator.global_position, operator.model_root.rotation, operator.health, operator.energy, operator.current_animation, operator.facing])
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			security.append([enemy.global_position, enemy.robot.rotation, enemy.health])
			active += 1
		else:
			security.append([])
	peer.call_func_unreliable(receive_state, players, security)
	if active == 0 or nearest_operator(Vector3.ZERO) == null:
		var message := "Mission complete. All security units defeated." if active == 0 else "Mission failed. Both operators are down."
		peer.call_func(receive_outcome, message)
		set_outcome(message)

func receive_state(players: Array, security: Array) -> void:
	if host or peer.get_sender_id() != peer.get_host() or players.size() != 2 or security.size() != enemies.size():
		return
	targets = players
	enemy_targets = security

func _process(delta: float) -> void:
	if not host:
		var blend := 1.0 - exp(-19.0 * delta)
		for index in operators.size():
			var data: Array = targets[index]
			if data.is_empty():
				continue
			var operator := operators[index]
			operator.global_position = operator.global_position.lerp(data[0], blend)
			operator.model_root.rotation = data[1]
			operator.health = data[2]
			operator.energy = data[3]
			operator.play_character_animation(data[4])
			operator.facing = data[5]
			operator.visible = operator.health > 0
		for index in enemies.size():
			var enemy := enemies[index]
			var data: Array = enemy_targets[index]
			enemy.visible = not data.is_empty()
			if enemy.visible:
				enemy.global_position = enemy.global_position.lerp(data[0], blend)
				enemy.robot.rotation = data[1]
				enemy.health = data[2]
	stats.text = "HOST HP %d    PARTNER HP %d    SECURITY %d LEFT" % [operators[0].health, operators[1].health, enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.health > 0 and enemy.visible).size()]

func send_shot(shot: RiftProjectile) -> void:
	peer.call_func(receive_shot, shot.global_position, shot.direction, shot.speed, shot.palette, shot.is_charged, shot.is_magma, shot.owner_faction)

func receive_shot(at: Vector3, direction: Vector3, speed: float, tint: Color, charged: bool, magma: bool, faction: String) -> void:
	if host or peer.get_sender_id() != peer.get_host():
		return
	var shot := RiftProjectile.new()
	shot.collision_layer = 0
	shot.collision_mask = 0
	shot.speed = speed
	add_child(shot)
	shot.global_position = at
	shot.setup(direction, faction, tint, false, charged, magma)

func receive_outcome(message: String) -> void:
	if not host and peer.get_sender_id() == peer.get_host():
		set_outcome(message)

func set_outcome(message: String) -> void:
	outcome = message
	room_status.text = message
	for operator in operators:
		operator.set_physics_process(false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
