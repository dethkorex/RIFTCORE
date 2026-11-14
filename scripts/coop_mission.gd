extends Node3D

signal exit_requested
signal rewards_earned(xp: int, bolts: int, blueprints: Array)

const PLAYER := preload("res://scenes/actors/riftcore_player.tscn")
const FLOOR := preload("res://assets/neon_factory/floor_panel_a.tscn")
const UI := preload("res://scripts/rift_ui.gd")
const INPUTS := [&"jump", &"dash", &"crouch", &"crouch_stick", &"shoot", &"melee", &"climb_down", &"swap_weapon", &"previous_suit"]
const ENEMY_POSITIONS := [10.0, 16.0, 23.0, 30.0, 36.0]
const TICK := 0.05
const DIFFICULTY := 2.5
const XP_BONUS := 1.5
const Blueprints := preload("res://scripts/blueprint_catalog.gd")
const Profile := preload("res://scripts/rogue_profile.gd")

var host := false
var peer: Node
var operators: Array[RiftPlayer] = []
var enemies: Array[WalkerBot] = []
var room_status: Label
var partner_status: Label
var camera: SideCameraRig
var nameplates: Array[Label3D] = []
var return_button: Button
var rewards_status: Label
var stats: Label
var clock := 0.0
var guest_timeout := 0.0
var outcome := ""
var team_xp := 0
var team_bolts := 0
var team_blueprints: Array = []
var loot_rng := RandomNumberGenerator.new()
var rewards_delivered := false
var blueprint_count := 0
var held: Dictionary = {}
var pressed: Dictionary = {}
var released: Dictionary = {}
var targets: Array = []
var enemy_targets: Array = []

func _ready() -> void:
	peer = RiftRelay.relay
	loot_rng.randomize()
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
		var plate := Label3D.new()
		plate.position.y = 1.48
		plate.font = UI.BODY
		plate.font_size = 30
		plate.pixel_size = 0.0048
		plate.outline_size = 10
		plate.modulate = UI.CYAN if index == (0 if host else 1) else UI.VIOLET
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		operator.add_child(plate)
		nameplates.append(plate)
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
		enemy.scale_for_sector(1)
		enemy.max_health *= DIFFICULTY
		enemy.health = enemy.max_health
		enemy.sector_damage_scale *= DIFFICULTY
		enemy.health_changed.emit(enemy.health, enemy.max_health)
		if host:
			enemy.died.connect(earn_security_rewards.bind(enemy.variant))
		if not host:
			enemy.set_process(false)
			enemy.set_physics_process(false)
			enemy.collision_layer = 0
			enemy.collision_mask = 0
		enemies.append(enemy)
		enemy_targets.append([])
	camera = SideCameraRig.new()
	camera.target = operators[0 if host else 1]
	camera.min_x = 0.0
	camera.max_x = 42.0
	add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	partner_status = UI.label(content, "", 16, UI.CYAN)
	room_status = UI.label(content, "2.5× enemy health and damage  /  1.5× shared XP", 16, UI.MUTED)
	rewards_status = UI.label(content, "", 15, UI.CYAN)
	return_button = UI.button(content, "Leave Mission", func(): exit_requested.emit(), false, 34)
	return_button.focus_mode = Control.FOCUS_NONE

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

func earn_security_rewards(variant: int) -> void:
	if not outcome.is_empty():
		return
	var xp := roundi(WalkerBot.XP_REWARDS[variant] * XP_BONUS)
	team_xp += xp
	team_bolts += 12 + floori(WalkerBot.XP_REWARDS[variant] * 0.5)
	var blueprint := Blueprints.roll(1, "elite" if variant == WalkerBot.Variant.HEAVY else "enemy", loot_rng)
	if not blueprint.is_empty() and not team_blueprints.has(blueprint):
		team_blueprints.append(blueprint)
	for operator in operators:
		if operator.health > 0.0:
			operator.gain_experience(xp)

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
	peer.call_func_unreliable(receive_state, players, security, team_xp, team_bolts, team_blueprints.size())
	if active == 0 or nearest_operator(Vector3.ZERO) == null:
		var success := active == 0
		peer.call_func(receive_outcome, success, team_xp, team_bolts, team_blueprints)
		finish_mission(success, team_xp, team_bolts, team_blueprints)

func receive_state(players: Array, security: Array, xp: int, bolts: int, blueprints_found: int) -> void:
	if host or not outcome.is_empty() or peer.get_sender_id() != peer.get_host() or players.size() != 2 or security.size() != enemies.size():
		return
	team_xp = xp
	team_bolts = bolts
	blueprint_count = blueprints_found
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
			operator.experience = team_xp
		for index in enemies.size():
			var enemy := enemies[index]
			var data: Array = enemy_targets[index]
			enemy.visible = not data.is_empty()
			if enemy.visible:
				enemy.global_position = enemy.global_position.lerp(data[0], blend)
				enemy.robot.rotation = data[1]
				if enemy.health != data[2]:
					enemy.health = data[2]
					enemy.health_changed.emit(enemy.health, enemy.max_health)
	var partner_index := 1 if host else 0
	var partner := operators[partner_index]
	var leader: int = peer.get_host()
	var companion: int = leader
	for id in peer.lobby_get_all_clients():
		if id != leader:
			companion = id
	for index in nameplates.size():
		var id := leader if index == 0 else companion
		nameplates[index].text = Profile.clean_operator_name(str(peer.player_get_data(id, "operator_name", "RX-07")))
	var partner_name := nameplates[partner_index].text
	var local := camera.target
	var offset := partner.global_position.x - local.global_position.x
	var view := camera.get_node("Camera3D") as Camera3D
	var on_screen := get_viewport().get_visible_rect().has_point(view.unproject_position(partner.global_position))
	if partner.health <= 0.0:
		partner_status.text = "%s is down" % partner_name
	elif on_screen:
		partner_status.text = "%s is nearby" % partner_name
	else:
		partner_status.text = "%s  %s  %.0f m" % ["←" if offset < 0.0 else "→", partner_name, absf(offset)]
	stats.text = "HOST HP %d    PARTNER HP %d    SECURITY %d LEFT\nSHARED  %d XP  /  %d BOLTS  /  %d BLUEPRINTS" % [operators[0].health, operators[1].health, enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.health > 0 and enemy.visible).size(), team_xp, team_bolts, team_blueprints.size() if host else blueprint_count]

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

func receive_outcome(success: bool, xp: int, bolts: int, blueprints: Array) -> void:
	if not host and peer.get_sender_id() == peer.get_host():
		finish_mission(success, xp, bolts, blueprints)

func finish_mission(success: bool, xp: int, bolts: int, blueprints: Array) -> void:
	if not outcome.is_empty():
		return
	var message := "Mission failed. Both operators are down."
	if success:
		var unlocked: Array[String] = []
		for id in blueprints:
			if id is String and Profile.GEAR.has(id) and Profile.GEAR[id].get("sector", 0) == 1 and not unlocked.has(id):
				unlocked.append(id)
		xp = clampi(xp, 0, 250)
		bolts = clampi(bolts, 0, 250)
		team_xp = xp
		team_bolts = bolts
		blueprint_count = unlocked.size()
		message = "Mission complete. Each player earned %d XP, %d bolts and %d blueprints." % [xp, bolts, unlocked.size()]
		if not rewards_delivered:
			rewards_delivered = true
			rewards_earned.emit(xp, bolts, unlocked)
	outcome = message
	room_status.text = message
	if success:
		rewards_status.text = "Save at the System pad to keep your rewards."
	return_button.text = "Return Together" if host else "Leave Mission"
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.grab_focus()
	for operator in operators:
		operator.set_physics_process(false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("pause") and not event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		exit_requested.emit()
