extends Node

const UI := preload("res://scripts/rift_ui.gd")
const FactoryHUD := preload("res://scripts/factory_hud.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
var sector_complete := false
var deploying := false
var remaining_enemies := 0
var factory_hud: Control
var boss: Combatant
var gate: Node3D
var gate_open := false
var arena_sealed := false
var boss_defeated := false
var respawning := false
const CHECKPOINT_STATIONS := {"midpoint": "TERRAIN/MidpointCheckpoint", "forge_hall": "TERRAIN/ForgeHallCheckpoint"}
var checkpoint_reached := false
var checkpoint_station := "midpoint"
var checkpoint_spawn := Vector3.ZERO
var player_collision_layer := 1

const SAVE_PATH := "user://riftcore_checkpoint.cfg"
var checkpoint_path := SAVE_PATH
var profile := preload("res://scripts/rogue_profile.gd").new()
var banked_run := false
var life_taken := false
var boss_spawn := Vector3.ZERO
var deployed_spawn := Vector3.ZERO
var sector := 1
var run_weapons: Dictionary = {}

const NEON_FACTORY_LEVEL := preload("res://scenes/levels/neon_factory_test.tscn")

var player: RiftPlayer
var camera_rig: SideCameraRig
var hud: CanvasLayer
var menu: Control
var game_root: Node3D
var pause_menu: Control
var editor_level: Node3D

func _ready() -> void:
	editor_level = get_node_or_null("NeonFactoryEditable") as Node3D
	if editor_level:
		editor_level.visible = false
	configure_input()
	RiftSettings.configure_bindings()
	profile.restore()
	if get_tree().has_meta(&"restart_factory"):
		get_tree().remove_meta(&"restart_factory")
		start_game.call_deferred()
	elif get_tree().has_meta(&"load_factory"):
		get_tree().remove_meta(&"load_factory")
		load_game.call_deferred()
	else:
		show_main_menu()

func configure_input() -> void:
	add_key_action("move_left", KEY_A)
	add_key_action("move_left", KEY_LEFT)
	add_key_action("move_right", KEY_D)
	add_key_action("move_right", KEY_RIGHT)
	add_key_action("crouch", KEY_S)
	add_key_action("crouch", KEY_DOWN)
	for key in [KEY_W, KEY_UP]:
		add_key_action("climb_up", key)
	for key in [KEY_S, KEY_DOWN]:
		add_key_action("climb_down", key)
	add_joy_button("climb_up", JOY_BUTTON_DPAD_UP)
	add_joy_button("climb_down", JOY_BUTTON_DPAD_DOWN)
	add_joy_action("climb_up", JOY_AXIS_LEFT_Y, -1.0)
	add_joy_action("climb_down", JOY_AXIS_LEFT_Y, 1.0)
	InputMap.action_set_deadzone("climb_up", 0.42)
	InputMap.action_set_deadzone("climb_down", 0.55)
	add_key_action("jump", KEY_SPACE)
	add_key_action("dash", KEY_SHIFT)
	add_key_action("shoot", KEY_J)
	add_key_action("swap_weapon", KEY_Q)
	add_key_action("melee", KEY_K)
	add_key_action("restart", KEY_R)
	add_key_action("pause", KEY_ESCAPE)
	add_joy_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_joy_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	add_joy_button("jump", JOY_BUTTON_A)
	add_joy_button("dash", JOY_BUTTON_B)
	add_joy_button("shoot", JOY_BUTTON_X)
	add_joy_button("swap_weapon", JOY_BUTTON_RIGHT_SHOULDER)
	add_joy_button("melee", JOY_BUTTON_Y)
	add_joy_button("crouch", JOY_BUTTON_DPAD_DOWN)
	add_joy_action("crouch_stick", JOY_AXIS_LEFT_Y, 1.0)
	InputMap.action_set_deadzone("crouch_stick", 0.65)
	add_joy_button("pause", JOY_BUTTON_START)
	add_joy_button("ui_accept", JOY_BUTTON_A)
	add_joy_button("ui_cancel", JOY_BUTTON_B)
	add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	add_joy_action("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	add_joy_action("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	add_joy_action("ui_left", JOY_AXIS_LEFT_X, -1.0)
	add_joy_action("ui_right", JOY_AXIS_LEFT_X, 1.0)

func add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func add_joy_action(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action, 0.18)
	InputMap.action_set_deadzone(action, 0.18)
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func add_joy_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func show_main_menu() -> void:
	RiftAudio.play_music(false)
	menu = RiftTitleMenu.new()
	menu.can_load = FileAccess.file_exists(checkpoint_path)
	var save := ConfigFile.new()
	if save.load(checkpoint_path) == OK:
		menu.saved_sector = int(save.get_value("checkpoint", "sector", 1))
		menu.at_sector_start = bool(save.get_value("checkpoint", "at_start", false))
		menu.run_unlocks = save.get_value("checkpoint", "weapons", [])
	menu.profile = profile
	add_child(menu)
	menu.start_requested.connect(start_game)
	menu.load_requested.connect(load_game)
	if get_tree().has_meta(&"open_command_deck"):
		get_tree().remove_meta(&"open_command_deck")
		menu.show_page("Hub")

func start_game(play_intro := true) -> void:
	if is_instance_valid(game_root):
		return
	if play_intro:
		sector = 1
		run_weapons.clear()
		clear_checkpoint()
	RiftAudio.play_music(true, sector)
	if menu: menu.queue_free()
	build_level()
	if play_intro:
		play_deploy_intro()

func play_deploy_intro() -> void:
	deploying = true
	player.hide()
	player.set_physics_process(false)
	await get_tree().physics_frame
	var floor_at := find_safe_spawn()
	deployed_spawn = floor_at
	player.global_position = floor_at
	var pad := game_root.get_node_or_null("MARKERS/PlayerSpawn/DeploymentPad")
	if pad:
		pad.global_position = floor_at - Vector3.UP * (player.standing_capsule.height * 0.5 + 0.055)
		pad.pulse()
	player.velocity = Vector3.ZERO
	camera_rig.global_position = Vector3(clampf(floor_at.x, camera_rig.min_x, camera_rig.max_x), maxf(0.85, floor_at.y + 0.35), 0)
	await get_tree().create_timer(0.27, false).timeout
	var beam := preload("res://scripts/deploy_lightning.gd").new()
	beam.name = "DeployLightning"
	game_root.add_child(beam)
	beam.global_position = player.global_position - Vector3.UP * (player.standing_capsule.height * 0.5 + 0.055)
	beam.strike()
	RiftAudio.play_effect(&"deploy_zap")
	await get_tree().create_timer(0.09, false).timeout
	player.show()
	player.play_character_animation("land", true)
	await get_tree().create_timer(0.25, false).timeout
	factory_hud.announce("START", Color("71efff"))
	RiftAudio.play_effect(&"voice_start")
	player.invulnerable_time = 0.5
	player.set_physics_process(true)
	deploying = false

func find_safe_spawn() -> Vector3:
	var from_editor := player.global_position
	var marker := game_root.get_node("MARKERS/PlayerSpawn") as Marker3D
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	for enemy in get_tree().get_nodes_in_group("level_enemies"):
		exclude.append(enemy.get_rid())
	for base in [from_editor, marker.global_position]:
		for x_offset in [0.0, 0.55, -0.55, 1.1, -1.1, 1.75, -1.75]:
			var x: float = float(base.x) + float(x_offset)
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x, base.y + 0.25, 0), Vector3(x, base.y - 4.0, 0))
			ray.exclude = exclude
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y < 0.67:
				continue
			var at: Vector3 = hit.position + Vector3.UP * (player.standing_capsule.height * 0.5 + 0.055)
			var clearance := PhysicsShapeQueryParameters3D.new()
			clearance.shape = player.standing_capsule
			clearance.transform = Transform3D(Basis.IDENTITY, at)
			clearance.exclude = [player.get_rid()]
			if space.intersect_shape(clearance, 1).is_empty():
				return at
	return Vector3(marker.global_position.x, marker.global_position.y, 0.0)

func load_game() -> void:
	var save := ConfigFile.new()
	if save.load(checkpoint_path) != OK:
		if not is_instance_valid(menu):
			start_game()
		return
	sector = clampi(int(save.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
	if not ResourceLoader.exists(Catalog.info(sector).level):
		push_warning("The saved sector scene is unavailable.")
		return
	run_weapons.clear()
	var legacy_weapons: Array = []
	for prior in range(1, sector):
		legacy_weapons.append(Catalog.info(prior).reward)
	var weapons = save.get_value("checkpoint", "weapons", legacy_weapons)
	if weapons is Array:
		for weapon in weapons:
			if not Catalog.weapon(String(weapon)).is_empty():
				run_weapons[String(weapon)] = true
	start_game(false)
	var at_start := bool(save.get_value("checkpoint", "at_start", false))
	if not at_start:
		load_checkpoint_location(save)
	player.gain_experience(clampi(int(save.get_value("checkpoint", "experience", 0)), 0, 1000000))
	player.health = player.max_health
	player.restore_energy(player.max_energy)
	player.health_changed.emit(player.health, player.max_health)
	player.credits = maxi(int(save.get_value("checkpoint", "credits", 0)), 0)
	player.credits_changed.emit(player.credits)
	player.lives = clampi(int(save.get_value("checkpoint", "lives", 3)), 1, 5)
	player.lives_changed.emit(player.lives)
	life_taken = bool(save.get_value("checkpoint", "life_taken", false))
	if life_taken:
		var life := game_root.get_node_or_null("TERRAIN/InspectionExtraLife")
		if life:
			life.queue_free()
	if at_start:
		play_deploy_intro()

func load_checkpoint_location(save: ConfigFile) -> void:
	checkpoint_station = String(save.get_value("checkpoint", "station", "midpoint"))
	if not CHECKPOINT_STATIONS.has(checkpoint_station):
		checkpoint_station = "midpoint"
	var checkpoint = game_root.get_node(CHECKPOINT_STATIONS[checkpoint_station])
	if checkpoint_station == "forge_hall":
		var first = game_root.get_node(CHECKPOINT_STATIONS["midpoint"])
		first.online = true
		first.get_node("Status").text = "CHECKPOINT ACTIVE"
	checkpoint.online = true
	checkpoint.get_node("Status").text = "CHECKPOINT ACTIVE"
	checkpoint_reached = true
	checkpoint_spawn = checkpoint.global_position + Vector3.UP * 0.95
	var saved_spawn = save.get_value("checkpoint", "spawn", checkpoint_spawn)
	if saved_spawn is Vector3 and saved_spawn.distance_to(checkpoint_spawn) < 3.0:
		checkpoint_spawn = saved_spawn
	player.global_position = checkpoint_spawn
	camera_rig.global_position.x = checkpoint_spawn.x

func build_pause_menu() -> void:
	var stack := overlay()
	UI.label(stack, "PAUSED", 36, UI.CYAN)
	UI.label(stack, Catalog.info(sector).title, 17, UI.MUTED)
	UI.button(stack, "Resume", toggle_pause, true).grab_focus()
	UI.button(stack, "Restart sector", restart_run)
	UI.button(stack, "Settings", show_pause_settings)
	UI.button(stack, "Return to title", show_exit_confirmation)

func overlay() -> VBoxContainer:
	if is_instance_valid(pause_menu):
		pause_menu.get_parent().remove_child(pause_menu)
		pause_menu.queue_free()
	pause_menu = preload("res://scripts/controller_overlay.gd").new()
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if not sector_complete:
		pause_menu.back_action = toggle_pause
		pause_menu.pause_action = toggle_pause
	pause_menu.theme = UI.theme()
	hud.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.075, 0.8)
	pause_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	pause_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 460
	center.add_child(panel)
	return UI.column(panel, 12)

func show_pause_settings() -> void:
	var stack := overlay()
	pause_menu.back_action = build_pause_menu
	UI.label(stack, "SETTINGS", 32, UI.CYAN)
	UI.settings(stack)
	UI.button(stack, "Back to pause", build_pause_menu).grab_focus()

func build_level() -> void:
	if editor_level and sector == 1:
		game_root = editor_level
		game_root.visible = true
		game_root.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		var stage := NEON_FACTORY_LEVEL if sector == 1 else load(Catalog.info(sector).level) as PackedScene
		game_root = stage.instantiate()
		add_child(game_root)
	player = game_root.get_node("Actors/RiftcoreMecha") as RiftPlayer
	player.experience = 0
	player_collision_layer = player.collision_layer
	deployed_spawn = player.global_position
	apply_permanent_upgrades()
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.fell_into_pit.connect(_on_pit_fall)
	for enemy in get_tree().get_nodes_in_group("level_enemies"):
		if not game_root.is_ancestor_of(enemy):
			continue
		enemy.target = player
		enemy.scale_for_sector(sector)
		enemy.died.connect(_enemy_defeated)
		remaining_enemies += 1
	camera_rig = game_root.get_node("CameraRig") as SideCameraRig
	camera_rig.target = player
	var bounds := game_root.get_node("MARKERS/CameraBounds")
	camera_rig.min_x = bounds.get_meta("min_x")
	camera_rig.max_x = bounds.get_meta("max_x")
	boss = game_root.get_node("Actors/" + Catalog.info(sector).boss_node) as Combatant
	gate = game_root.get_node("Gate") as Node3D
	boss_spawn = boss.position
	build_hud()
	for station in CHECKPOINT_STATIONS:
		var checkpoint := game_root.get_node_or_null(CHECKPOINT_STATIONS[station])
		if checkpoint:
			checkpoint.activated.connect(_on_checkpoint_activated.bind(station))
	game_root.get_node("ForgeHallDoor").target = player
	bind_boss_signals()
	install_sector_pads()

func install_sector_pads() -> void:
	var spawn := game_root.get_node("MARKERS/PlayerSpawn") as Marker3D
	if not spawn.has_node("DeploymentPad"):
		spawn.add_child(preload("res://assets/neon_factory/deployment_pad.tscn").instantiate())
	var arrival := spawn.get_node("DeploymentPad") as Node3D
	arrival.global_position = player.global_position - Vector3.UP * player.standing_capsule.height * 0.5
	var exit := game_root.get_node("MARKERS/RoomExit") as Marker3D
	if not exit.has_node("ExtractionPad"):
		exit.add_child(preload("res://assets/neon_factory/extraction_pad.tscn").instantiate())
	exit.get_node("ExtractionPad").position.y = -player.standing_capsule.height * 0.5

func apply_permanent_upgrades() -> void:
	player.magma_unlocked = run_weapons.has("magma_breaker")
	player.thorn_unlocked = run_weapons.has("thorn_swarm")
	player.run_weapon_ids = run_weapons.keys()
	if profile.owned.has("armor"):
		player.max_health += 12.0
		player.health = player.max_health
	if profile.owned.has("capacitor"):
		player.max_energy += 15.0
		player.energy = player.max_energy
	if profile.owned.has("buster"):
		player.buster_damage_multiplier = 1.15
	if profile.owned.has("dash"):
		player.dash_speed *= 1.10
		player.dash_cooldown *= 0.85

func bind_boss_signals() -> void:
	boss.health_changed.connect(func(current: float, maximum: float):
		factory_hud.boss_health = current / maximum
		factory_hud.queue_redraw()
	)
	boss.died.connect(func():
		boss_defeated = true
		open_factory_gate()
		var info := Catalog.info(sector)
		var reward: String = info.reward
		var first_unlock := not run_weapons.has(reward)
		player.unlock_sector_weapon(reward)
		for minion in get_tree().get_nodes_in_group(&"arena_minions"):
			minion.queue_free()
		run_weapons[reward] = true
		if checkpoint_reached:
			save_checkpoint()
		var message: String = info.reward_name + " unlocked" if first_unlock else info.boss + " defeated"
		factory_hud.announce(message.to_upper(), Color(info.color))
		var barrier := game_root.get_node("ExitBarrier") as StaticBody3D
		barrier.get_node("CollisionShape3D").set_deferred("disabled", true)
		var release := barrier.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		release.tween_property(barrier.get_node("Seal"), "position:y", 4.2, 0.62)
		release.tween_callback(barrier.queue_free)
		factory_hud.boss_visible = false
		factory_hud.queue_redraw()
	)

func build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	factory_hud = FactoryHUD.new()
	factory_hud.exit_task = "REACH SECTOR EXTRACTION" if sector > 2 else ("REACH JUNGLE EXTRACTION" if sector == 2 else "REACH THE FACTORY EXIT")
	factory_hud.boss_name = String(Catalog.info(sector).boss).to_upper()
	factory_hud.boss_tint = Color(Catalog.info(sector).color)
	hud.add_child(factory_hud)
	factory_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	factory_hud.remaining = remaining_enemies
	factory_hud.lives = player.lives
	if not run_weapons.is_empty():
		factory_hud.weapon = "BUSTER CANNON"
	factory_hud.health_capacity = player.max_health
	factory_hud.energy_capacity = player.max_energy
	player.energy_changed.connect(func(current: float, maximum: float):
		factory_hud.energy = current / maximum
		factory_hud.energy_capacity = maximum
		factory_hud.queue_redraw()
	)
	player.credits_changed.connect(func(total: int):
		factory_hud.credits = total
		factory_hud.queue_redraw()
	)
	player.experience_changed.connect(factory_hud.set_experience)
	player.weapon_changed.connect(func(weapon: String):
		factory_hud.weapon = weapon
		factory_hud.queue_redraw()
	)

	player.lives_changed.connect(func(count: int):
		factory_hud.lives = count
		factory_hud.queue_redraw()
	)
	player.life_picked_up.connect(func():
		life_taken = true
		factory_hud.announce("EXTRA LIFE", Color("6dffdd"))
		if checkpoint_reached:
			save_checkpoint()
	)

func _on_checkpoint_activated(spawn: Vector3, station := "midpoint") -> void:
	if checkpoint_station == "forge_hall" and station == "midpoint":
		return
	checkpoint_station = station
	checkpoint_reached = true
	checkpoint_spawn = spawn
	save_checkpoint()
	RiftAudio.play_effect(&"checkpoint")
	factory_hud.announce("CHECKPOINT", Color("68efff"))

func save_checkpoint() -> void:
	var save := ConfigFile.new()
	save.set_value("checkpoint", "sector", sector)
	save.set_value("checkpoint", "weapons", run_weapons.keys())
	save.set_value("checkpoint", "at_start", not checkpoint_reached)
	save.set_value("checkpoint", "spawn", checkpoint_spawn)
	save.set_value("checkpoint", "station", checkpoint_station)
	save.set_value("checkpoint", "experience", int(player.experience))
	save.set_value("checkpoint", "credits", player.credits)
	save.set_value("checkpoint", "lives", player.lives)
	save.set_value("checkpoint", "life_taken", life_taken)
	var error := save.save(checkpoint_path)
	if error != OK:
		push_warning("Could not save Riftcore checkpoint: %s" % error_string(error))

func _enemy_defeated() -> void:
	remaining_enemies = maxi(0, remaining_enemies - 1)
	factory_hud.remaining = remaining_enemies
	factory_hud.queue_redraw()

func _on_pit_fall() -> void:
	if respawning:
		return
	respawning = true
	player.lives = maxi(0, player.lives - 1)
	player.lives_changed.emit(player.lives)
	factory_hud.failed = true
	factory_hud.queue_redraw()
	player.cancel_charge()
	player.set_physics_process(false)
	player.set_deferred("collision_layer", 0)
	player.hide()
	RiftAudio.play_effect(&"enemy_break")
	var burst := preload("res://scripts/pit_burst.gd").new()
	game_root.add_child(burst)
	burst.global_position = player.global_position
	burst.ignite()
	await get_tree().create_timer(0.45, false).timeout
	if player.lives <= 0:
		bank_run_credits()
		get_tree().set_meta(&"open_command_deck", true)
		get_tree().reload_current_scene()
		return
	if arena_sealed and not boss_defeated:
		reset_boss_room()
	burst.queue_free()
	player.global_position = checkpoint_spawn if checkpoint_reached else deployed_spawn
	player.velocity = Vector3.ZERO
	player.dash_left = 0.0
	player.dash_lock = 0.0
	player.jump_buffer = 0.0
	player.contact_recoil = 0.0
	player.ladder = null
	player.melee_lock = 0.0
	player.combo_queued = 0
	var blade := player.find_child("SwordPivot", true, false) as Node3D
	if blade:
		blade.hide()
	player.health = player.max_health
	player.restore_energy(player.max_energy)
	player.health_changed.emit(player.health, player.max_health)
	player.invulnerable_time = 1.5
	player.collision_layer = player_collision_layer
	player.show()
	player.set_physics_process(true)
	camera_rig.global_position.x = player.global_position.x
	factory_hud.failed = false
	factory_hud.queue_redraw()
	factory_hud.announce("%d LIVES LEFT" % player.lives, Color("8eeaff"))
	if checkpoint_reached or sector > 1:
		save_checkpoint()
	respawning = false

func reset_boss_room() -> void:
	if is_instance_valid(boss):
		boss.hide()
		boss.collision_layer = 0
		boss.queue_free()
	RiftAudio.stop_effect(&"titan_windup")
	for supply in get_tree().get_nodes_in_group(&"boss_supply"):
		supply.queue_free()
	for minion in get_tree().get_nodes_in_group(&"arena_minions"):
		minion.queue_free()
	for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
		if shot.owner_faction == "enemy" and shot.global_position.x > gate.global_position.x - 2.0:
			shot.queue_free()
	boss = (load(Catalog.info(sector).boss_scene) as PackedScene).instantiate() as Combatant
	boss.position = boss_spawn
	game_root.get_node("Actors").add_child(boss)
	bind_boss_signals()
	gate_open = false
	arena_sealed = false
	gate.get_node("Door").position.y = 0.0
	gate.get_node("Blocker/CollisionShape3D").set_deferred("disabled", false)
	factory_hud.boss_visible = false
	factory_hud.boss_health = 1.0

func clear_checkpoint() -> void:
	if FileAccess.file_exists(checkpoint_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checkpoint_path))

func bank_run_credits(bonus := 0) -> void:
	if banked_run or not is_instance_valid(player):
		return
	if profile.deposit(player.credits + bonus) != OK:
		push_warning("Could not write the Riftcore credit bank.")
		return
	banked_run = true
	clear_checkpoint()

func show_exit_confirmation() -> void:
	var stack := overlay()
	pause_menu.back_action = build_pause_menu
	UI.label(stack, "LEAVE SECTOR?", 30, UI.VIOLET)
	UI.label(stack, "This run ends and your earned credits go to the bank.")
	UI.button(stack, "Stay in sector", build_pause_menu).grab_focus()
	UI.button(stack, "Return to title", return_to_title, true)

func _process(_delta: float) -> void:
	if deploying or sector_complete or not is_instance_valid(player) or player.health <= 0.0:
		return
	if not gate_open and absf(player.global_position.x - gate.global_position.x) < 4.0:
		open_factory_gate()
	if gate_open and not arena_sealed and player.global_position.x >= gate.global_position.x + 1.35:
		seal_arena()
	var exit := game_root.get_node("MARKERS/RoomExit") as Marker3D
	var at_exit := player.global_position.distance_to(exit.global_position) <= 1.45
	if at_exit and not factory_hud.reached_exit:
		factory_hud.reached_exit = true
		game_root.get_node("MARKERS/RoomExit/ExtractionPad").pulse()
		factory_hud.queue_redraw()
	if not at_exit or not boss_defeated:
		return
	sector_complete = true
	var bonus := 160 + 25 * (sector - 1)
	bank_run_credits(bonus)
	var final_sector := sector >= Catalog.SECTORS.size()
	if banked_run and ResourceLoader.exists(Catalog.info(sector + 1).level):
		var continuation := ConfigFile.new()
		continuation.set_value("checkpoint", "sector", mini(sector + 1, Catalog.SECTORS.size()))
		continuation.set_value("checkpoint", "weapons", run_weapons.keys())
		continuation.set_value("checkpoint", "at_start", true)
		continuation.set_value("checkpoint", "experience", int(player.experience))
		continuation.set_value("checkpoint", "lives", 3)
		var error := continuation.save(checkpoint_path)
		if error != OK:
			push_warning("Could not save the next sector deployment: %s" % error_string(error))
	get_tree().paused = true
	var stack := overlay()
	UI.label(stack, "CAMPAIGN COMPLETE" if final_sector else "SECTOR COMPLETE", 36, UI.CYAN)
	UI.label(stack, Catalog.info(sector).title, 20)
	UI.label(stack, "Credits earned  %d + %d clear bonus" % [player.credits, bonus], 17, Color("ffcd61"))
	UI.label(stack, "XP collected  %d" % player.experience, 17, Color("ab72ff"))
	UI.button(stack, "Continue to Command Deck", return_to_command_deck, true).grab_focus()

func open_factory_gate() -> void:
	gate_open = true
	var door := gate.get_node("Door") as Node3D
	var blocker := gate.get_node("Blocker/CollisionShape3D") as CollisionShape3D
	var opening := gate.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	opening.tween_property(door, "position:y", 4.2, 0.8)
	opening.tween_callback(blocker.set_deferred.bind("disabled", true))

func seal_arena() -> void:
	arena_sealed = true
	var door := gate.get_node("Door") as Node3D
	var blocker := gate.get_node("Blocker/CollisionShape3D") as CollisionShape3D
	blocker.set_deferred("disabled", false)
	var closing := gate.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	closing.tween_property(door, "position:y", 0.0, 0.48)
	closing.tween_callback(func():
		if not is_instance_valid(boss) or player.health <= 0.0:
			return
		boss.target = player
		boss.active = true
		factory_hud.boss_visible = true
		factory_hud.queue_redraw()
	)

func _on_health_changed(current: float, maximum: float) -> void:
	factory_hud.health = current / maximum
	factory_hud.health_capacity = maximum
	factory_hud.queue_redraw()

func _on_player_died() -> void:
	_on_pit_fall()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game_root and not sector_complete and player.visible:
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if not game_root: return
	var paused := not get_tree().paused
	get_tree().paused = paused
	if paused:
		player.cancel_charge()
		RiftAudio.play_effect(&"menu_confirm")
		build_pause_menu()
	elif pause_menu:
		player.resume_input_guard = 0.12
		Input.action_release("dash")
		Input.action_release("jump")
		pause_menu.queue_free()
		pause_menu = null

func restart_run() -> void:
	bank_run_credits()
	get_tree().paused = false
	get_tree().set_meta(&"restart_factory", true)
	get_tree().reload_current_scene()

func return_to_title() -> void:
	bank_run_credits()
	get_tree().paused = false
	get_tree().reload_current_scene()


func return_to_command_deck() -> void:
	bank_run_credits()
	get_tree().paused = false
	get_tree().set_meta(&"open_command_deck", true)
	get_tree().reload_current_scene()
