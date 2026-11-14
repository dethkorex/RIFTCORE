extends Node

const PauseOperator := preload("res://scripts/pause_operator_panel.gd")
const Materials := preload("res://scripts/fabrication_catalog.gd")
const Story := preload("res://scripts/rift_story.gd")
const Drop := preload("res://scripts/material_pickup.gd")
const UI := preload("res://scripts/rift_ui.gd")
const FactoryHUD := preload("res://scripts/factory_hud.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const BossCache := preload("res://scripts/boss_loot_cache.gd")
const Miniboss := preload("res://scripts/sector_miniboss.gd")
const ActLoadingScreen := preload("res://scripts/act_loading_screen.gd")
const SectorDetails := preload("res://scripts/sector_details.gd")
const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const ManualSave := preload("res://scripts/manual_save_session.gd")
const SuitReveal := preload("res://scripts/suit_reveal.gd")
const HOME_HUB := preload("res://scenes/home_hub.tscn")
var sector_complete := false
var deploying := false
var remaining_enemies := 0
var factory_hud: Control
var boss: Combatant
var gate: Node3D
var gate_open := false
var gate_motion: Tween
var arena_sealed := false
var arena_intro := false
var suit_reveal_active := false
var boss_defeated := false
var respawning := false
const CHECKPOINT_STATIONS := {"midpoint": "TERRAIN/MidpointCheckpoint", "forge_hall": "TERRAIN/ForgeHallCheckpoint"}
var checkpoint_reached := false
var checkpoint_station := "midpoint"
var checkpoint_spawn := Vector3.ZERO
var player_collision_layer := 1

const SAVE_PATH := "user://riftcore_checkpoint.cfg"
var checkpoint_path := SAVE_PATH
var save_session: ManualSave
var home_hub: Node3D
var run_cleared_through := 0
var profile := preload("res://scripts/rogue_profile.gd").new()
var banked_run := false
var life_taken := false
var boss_spawn := Vector3.ZERO
var deployed_spawn := Vector3.ZERO
var sector := 1
var mission_difficulty := 0
var act := 1
var advancing_act := false
var act_exit_retry := false
var sector_deaths := 0
var mission_stats := {"seconds": 0.0, "kills": 0, "operator_xp": 0, "player_xp": 0, "shards": 0}
var run_weapons: Dictionary = {}

const NEON_FACTORY_LEVEL := preload("res://scenes/levels/neon_factory_test.tscn")

var player: RiftPlayer
var camera_rig: SideCameraRig
var hud: CanvasLayer
var menu: Control
var game_root: Node3D
var pause_menu: Control
var invite_overlay: CanvasLayer
var editor_level: Node3D
var coop_mission: Node3D
var coop_join_loading: CanvasLayer
var active_controller := -1
var controller_disconnected := false

func _ready() -> void:
	if not OS.has_feature("editor") and DisplayServer.get_name() != "headless":
		var updater := preload("res://scripts/update_client.gd").new()
		var running := updater.configure_game()
		var latest := updater.newest_installed()
		var forwarded := latest != running and not latest.is_empty() and updater.compare_tags(latest, running)
		var started := forwarded and updater.start_version(latest)
		var install_root: String = updater.install_root
		updater.free()
		if started:
			get_tree().quit()
			return
		preload("res://scripts/steam_artwork.gd").apply.call_deferred(install_root)
	add_build_version()
	Input.joy_connection_changed.connect(on_joy_connection_changed)
	var pointer := preload("res://scripts/menu_pointer.gd").new()
	pointer.name = "MenuPointer"
	pointer.menu_open = func(): return (is_instance_valid(menu) and menu.is_visible_in_tree()
		or is_instance_valid(pause_menu) and pause_menu.is_visible_in_tree()
		or is_instance_valid(coop_mission) and coop_mission.is_pause_open()
		or is_instance_valid(home_hub) and (home_hub.is_pause_open() or home_hub.has_dialogue())
		or is_instance_valid(invite_overlay) and invite_overlay.visible)
	add_child(pointer)
	RiftRelay.invite_received.connect(show_friend_invite)
	var arguments := OS.get_cmdline_user_args()
	if "--verify-social" in arguments or "--verify-relay" in arguments:
		configure_input()
		profile.manual_only = true
		show_main_menu()
		var relay_check := arguments.find("--verify-relay")
		if relay_check >= 0:
			verify_live_relay.call_deferred(arguments.slice(relay_check + 1))
		else:
			verify_social.call_deferred()
		return
	editor_level = get_node_or_null("NeonFactoryEditable") as Node3D
	if editor_level:
		editor_level.visible = false
	configure_input()
	RiftSettings.configure_bindings()
	add_child(preload("res://scripts/menu_stick.gd").new())
	if get_tree().has_meta(&"riftcore_save_session"):
		save_session = get_tree().get_meta(&"riftcore_save_session")
	if save_session:
		profile = save_session.profile
	elif checkpoint_path != SAVE_PATH:
		profile.restore()
	else:
		profile.manual_only = true
	if get_tree().has_meta(&"restart_factory"):
		get_tree().remove_meta(&"restart_factory")
		start_game.call_deferred()
	elif get_tree().has_meta(&"load_factory"):
		get_tree().remove_meta(&"load_factory")
		load_game.call_deferred()
	else:
		show_main_menu()

func show_friend_invite(display_name: String, code: String) -> void:
	if not is_instance_valid(home_hub) or is_instance_valid(game_root) or not RiftRelay.can_receive_invite():
		return
	if is_instance_valid(invite_overlay):
		invite_overlay.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 175
	invite_overlay = layer
	add_child(layer)
	var overlay := preload("res://scripts/controller_overlay.gd").new()
	var dismiss := func():
		invite_overlay = null
		layer.hide()
		layer.queue_free()
	overlay.back_action = dismiss
	overlay.pause_action = dismiss
	overlay.theme = UI.theme()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.075, 0.52)
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 355
	center.add_child(panel)
	var content := UI.column(panel, 8)
	UI.label(content, "CO-OP INVITE", 27, UI.CYAN)
	UI.label(content, "%s invited you to their party." % display_name, 17)
	UI.button(content, "Join Party", func():
		dismiss.call()
		if RiftRelay.can_receive_invite():
			RiftRelay.join_room(code)
			home_hub.station_requested.emit("Social")
			menu.show_page("Party")
	, true).grab_focus()
	UI.button(content, "Dismiss", dismiss)
	get_tree().create_timer(25.0).timeout.connect(func():
		if is_instance_valid(layer) and invite_overlay == layer:
			dismiss.call()
	)

func add_build_version() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 190
	add_child(layer)
	var version := String(ProjectSettings.get_setting("application/config/version"))
	var metadata := "res://assets/update_channel.json"
	if FileAccess.file_exists(metadata):
		var release: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata))
		if release is Dictionary:
			version = String(release.get("tag", version)).trim_prefix("v").trim_suffix("-preview")
	var label := UI.label(layer, "Alpha %s" % (version.trim_suffix(".0") if version.ends_with(".0") else version), 15, UI.MUTED)
	label.add_theme_color_override("font_shadow_color", Color("050a16"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -105
	label.offset_right = -12
	label.offset_top = -23
	label.offset_bottom = -7
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func verify_social() -> void:
	var valid := Engine.has_singleton("Steam")
	valid = valid and not menu.find_children("*", "Button", true, false).any(
		func(button): return button.text == "Online Room")
	open_home_hub()
	home_hub.station_requested.emit("Social")
	valid = valid and menu.page == "Social"
	menu.show_page("Party")
	valid = valid and is_instance_valid(menu.relay_host)
	if not valid:
		print("SOCIAL SMOKE FAIL")
		get_tree().quit(1)
		return
	if "--require-relay" in OS.get_cmdline_user_args():
		valid = (valid and RiftRelay.available
			and not menu.relay_host.disabled and not menu.relay_join.disabled
			and not menu.relay_paste.disabled and menu.relay_code.editable
			and FileAccess.file_exists("res://addons/GD-Sync/keys.cfg"))
	if not RiftRelay.available:
		valid = valid and menu.relay_host.disabled and menu.relay_join.disabled and not menu.relay_code.editable
		valid = valid and menu.relay_status.text == RiftRelay.RELAY_UNAVAILABLE
	RiftRelay.join_room("invalid!")
	valid = valid and RiftRelay.status.begins_with("Enter the ten-character")
	valid = valid and RiftRelay.valid_code("7ZX3BAK2QF")
	if not RiftRelay.available:
		RiftRelay.host_room()
		valid = valid and RiftRelay.status == RiftRelay.RELAY_UNAVAILABLE
		valid = valid and get_node_or_null("/root/GDSync") == null
	RiftRelay.leave()
	print("SOCIAL SMOKE PASS" if valid else "SOCIAL SMOKE FAIL")
	get_tree().quit(0 if valid else 1)

func verify_live_relay(arguments: PackedStringArray) -> void:
	var mission_test := arguments.has("mission")
	if mission_test:
		arguments = arguments.slice(0, arguments.size() - 1)
	var host := arguments == PackedStringArray(["host"])
	var guest := arguments.size() == 2 and arguments[0] == "join" and RiftRelay.valid_code(arguments[1])
	if not host and not guest:
		print("RELAY CHECK FAIL. Use host or join ROOM_CODE.")
		get_tree().quit(1)
		return
	if not RiftRelay.available:
		print("RELAY CHECK FAIL. ", RiftRelay.RELAY_UNAVAILABLE)
		get_tree().quit(1)
		return

	profile.operator_name = "Leader RX" if host else "Guest RX"
	open_home_hub()
	home_hub.station_requested.emit("Social")
	menu.show_page("Party")
	if host:
		menu.relay_host.pressed.emit()
	else:
		menu.relay_code.text = arguments[1]
		menu.relay_join.pressed.emit()
	if not await wait_for_relay(func(): return not RiftRelay.connected_room.is_empty(), 35.0):
		finish_relay_check(false)
		return
	if host:
		printerr("RELAY ROOM CODE ", RiftRelay.connected_room)
	var peer := RiftRelay.relay
	if not await wait_for_relay(func(): return RiftRelay.room_size == 2, 75.0):
		finish_relay_check(false)
		return

	if mission_test:
		await verify_coop_mission(host)
		return

	# Exchange lobby data to verify both clients share more than a room name.
	var platform := OS.get_name()
	if host:
		peer.lobby_set_data("rift_check_host", platform)
		var joined := await wait_for_relay(func(): return peer.lobby_has_data("rift_check_guest"), 15.0)
		if joined:
			print("RELAY PEER ", peer.lobby_get_data("rift_check_guest"))
			peer.lobby_set_data("rift_check_ack", true)
			joined = await wait_for_relay(func(): return peer.lobby_get_data("rift_check_ack", false), 15.0)
			if joined:
				await get_tree().create_timer(3.0).timeout
		finish_relay_check(joined)
	else:
		if not await wait_for_relay(func(): return peer.lobby_has_data("rift_check_host"), 15.0):
			finish_relay_check(false)
			return
		print("RELAY PEER ", peer.lobby_get_data("rift_check_host"))
		peer.lobby_set_data("rift_check_guest", platform)
		finish_relay_check(await wait_for_relay(func(): return peer.lobby_get_data("rift_check_ack", false), 15.0))

func verify_coop_mission(host: bool) -> void:
	if host:
		menu.leave_page()
	else:
		await get_tree().create_timer(0.8).timeout
	var previous_credits: int = profile.credits
	var previous_xp: int = profile.player_xp
	profile.gear["impact_liner" if host else "pulse_lens"] = "stored"
	var saved_gear: Dictionary = profile.gear.duplicate(true)
	if not host:
		Input.action_press("move_right")
		await get_tree().create_timer(0.8).timeout
		Input.action_release("move_right")
		RiftRelay.relay.lobby_set_data("coop_guest_in_hub", not RiftRelay.can_deploy())
		if not await wait_for_relay(func(): return profile.blueprint_items.has("bp_01_02"), 10.0):
			print("Campaign check failed blueprint pickup")
			finish_relay_check(false)
			return
		RiftRelay.relay.lobby_set_data("coop_blueprint_received", true)
	else:
		var together := await wait_for_relay(func(): return home_hub.partners.values().any(func(entry): return entry.actor.position.x > 2.0) and RiftRelay.relay.lobby_get_data("coop_guest_in_hub", false), 8.0)
		if not together:
			finish_relay_check(false)
			return
		home_hub.avatar.position.x = home_hub.partners.values()[0].x
		profile.collect_blueprint("bp_01_02")
		profile.move_blueprint_to_pouch("bp_01_02")
		drop_hub_blueprint("bp_01_02")
		if profile.blueprint_pouch.has("bp_01_02") or not await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_blueprint_received", false), 10.0):
			print("Campaign check failed blueprint handoff")
			finish_relay_check(false)
			return
		RiftRelay.deploy()
	if not await wait_for_relay(func(): return is_instance_valid(coop_mission), 15.0):
		finish_relay_check(false)
		return
	var mission = coop_mission
	var local_index := 0 if host else 1
	var local_operator: RiftPlayer = mission.operators[local_index]
	var spawn_x := local_operator.position.x
	if mission.camera.target != local_operator or not is_equal_approx(local_operator.damage_taken_scale, 1.25) or not mission.personal_hud.coop or not mission.personal_hud.is_visible_in_tree():
		print("Campaign check failed local camera or HUD")
		finish_relay_check(false)
		return
	if not host and (not local_operator.local_prediction or not local_operator.is_physics_processing()):
		print("Campaign check failed guest input prediction")
		finish_relay_check(false)
		return
	Input.action_press("move_right")
	await get_tree().create_timer(0.4).timeout
	Input.action_release("move_right")
	var moved := await wait_for_relay(func(): return is_instance_valid(local_operator) and local_operator.position.x > spawn_x + 0.5, 6.0)
	if not moved:
		print("Campaign check failed to move operator ", local_index)
		finish_relay_check(false)
		return
	if not host:
		RiftRelay.relay.lobby_set_data("coop_guest_moved", true)
		var entered_act_two := await wait_for_relay(func(): return is_instance_valid(coop_mission) and coop_mission.act == 2 and not coop_mission.changing_act, 24.0)
		if entered_act_two:
			RiftRelay.relay.lobby_set_data("coop_guest_act_two", true)
	else:
		if not await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_guest_moved", false), 10.0):
			finish_relay_check(false)
			return
		if not await clear_coop_test_boss(mission):
			finish_relay_check(false)
			return
		if not await wait_for_relay(func(): return is_instance_valid(mission) and mission.act == 2 and not mission.changing_act and RiftRelay.relay.lobby_get_data("coop_guest_act_two", false), 15.0):
			print("Campaign check failed to enter Act II")
			finish_relay_check(false)
			return
		mission.team_blueprints.append("bp_01_00")
		if not await clear_coop_test_boss(mission):
			finish_relay_check(false)
			return
	var returned := await wait_for_relay(func(): return is_instance_valid(home_hub) and not RiftRelay.mission_active, 24.0)
	var rewards := (profile.player_xp > previous_xp and profile.credits > previous_credits
		and profile.blueprint_items.has("bp_01_00") and profile.gear == saved_gear
		and profile.unlocked_sector >= 2)
	if not host and returned and rewards:
		RiftRelay.relay.lobby_set_data("coop_guest_returned", true)
		await get_tree().create_timer(1.5).timeout
	if host and returned and rewards:
		returned = await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_guest_returned", false), 8.0)
	finish_relay_check(returned and rewards)

func clear_coop_test_boss(mission: Node) -> bool:
	var gate_position: Vector3 = mission.gate.global_position
	mission.operators[0].global_position = gate_position + Vector3(-2.0, 1.0, 0.0)
	mission.operators[1].global_position = gate_position + Vector3(-10.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if mission.entrance_open or mission.boss_started:
		return false
	mission.operators[1].global_position = gate_position + Vector3(-1.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if not mission.entrance_open or mission.boss_started:
		return false
	mission.operators[0].global_position = gate_position + Vector3(3.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if mission.boss_started:
		return false
	mission.operators[1].global_position = gate_position + Vector3(4.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if not mission.boss_started or not await wait_for_relay(func(): return not mission.boss_intro_active, 14.0):
		return false
	mission.boss.take_damage(100000.0)
	mission.operators[0].global_position = mission.exit_marker.global_position
	mission.check_campaign_progress()
	return mission.boss_defeated

func wait_for_relay(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		if RiftRelay.pending.is_empty() and RiftRelay.connected_room.is_empty():
			return false
		await get_tree().create_timer(0.1).timeout
	return false

func finish_relay_check(passed: bool) -> void:
	if passed:
		print("RELAY CHECK PASS ", OS.get_name())
	else:
		print("RELAY CHECK FAIL. ", RiftRelay.status)
	RiftRelay.leave()
	get_tree().quit(0 if passed else 1)

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
	add_joy_action("climb_up", JOY_AXIS_LEFT_Y, -1.0)
	add_joy_action("climb_down", JOY_AXIS_LEFT_Y, 1.0)
	InputMap.action_set_deadzone("climb_up", 0.42)
	InputMap.action_set_deadzone("climb_down", 0.55)
	add_key_action("jump", KEY_SPACE)
	add_key_action("dash", KEY_SHIFT)
	add_key_action("shoot", KEY_J)
	add_key_action("swap_weapon", KEY_Q)
	add_key_action("previous_suit", KEY_E)
	add_key_action("melee", KEY_K)
	add_key_action("restart", KEY_R)
	add_key_action("pause", KEY_ESCAPE)
	add_joy_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_joy_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	InputMap.action_set_deadzone("move_left", 0.18)
	InputMap.action_set_deadzone("move_right", 0.18)
	add_joy_button("jump", JOY_BUTTON_A)
	add_joy_button("dash", JOY_BUTTON_B)
	add_joy_button("shoot", JOY_BUTTON_X)
	add_joy_button("swap_weapon", JOY_BUTTON_RIGHT_SHOULDER)
	add_joy_button("previous_suit", JOY_BUTTON_LEFT_SHOULDER)
	add_joy_button("melee", JOY_BUTTON_Y)
	add_joy_action("crouch_stick", JOY_AXIS_LEFT_Y, 1.0)
	InputMap.action_set_deadzone("crouch_stick", 0.65)
	add_joy_button("pause", JOY_BUTTON_START)
	add_joy_button("ui_accept", JOY_BUTTON_A)
	add_joy_button("ui_cancel", JOY_BUTTON_B)
	add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	for index in 4:
		add_key_action("quick_%d" % index, [KEY_1, KEY_2, KEY_3, KEY_4][index])
		add_joy_button("quick_%d" % index, [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN][index])

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
	if not RiftRelay.deploy_requested.is_connected(start_coop_mission):
		RiftRelay.deploy_requested.connect(start_coop_mission)
		RiftRelay.guest_joined.connect(enter_leader_hub)
		RiftRelay.mission_disconnected.connect(close_coop_mission)
		RiftRelay.mission_returned.connect(close_coop_mission.bind("Back at Operations Station."))
	RiftAudio.play_music(false)
	menu = RiftTitleMenu.new()
	refresh_menu_save()
	add_child(menu)
	menu.start_requested.connect(start_game)
	menu.load_requested.connect(load_game)
	menu.hub_requested.connect(open_home_hub)
	menu.blueprint_drop_requested.connect(drop_hub_blueprint)
	menu.station_closed.connect(close_station_panel)
	menu.sector_requested.connect(deploy_selected_sector)
	menu.slot_requested.connect(select_save_slot)
	menu.operator_deleted.connect(clear_deleted_operator)
	menu.save_requested.connect(save_at_station)
	if get_tree().has_meta(&"open_command_deck"):
		get_tree().remove_meta(&"open_command_deck")
		open_home_hub()
		if get_tree().has_meta(&"reconstruct_operator"):
			get_tree().remove_meta(&"reconstruct_operator")
			reconstruct_in_hub()

func enter_leader_hub() -> void:
	if not is_instance_valid(home_hub) or is_instance_valid(coop_mission):
		return
	coop_join_loading = ActLoadingScreen.new()
	var loading = coop_join_loading
	add_child(loading)
	loading.show_loading("ONLINE PARTY", "JOINING LEADER’S STATION")
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	home_hub.set_panel_open(true)
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(home_hub) and not RiftRelay.mission_active:
		home_hub.set_panel_open(false)
	if is_instance_valid(loading):
		loading.fade_out()

func start_coop_mission(is_host: bool, number: int) -> void:
	if is_instance_valid(coop_mission) or is_instance_valid(game_root):
		return
	if is_instance_valid(coop_join_loading):
		coop_join_loading.queue_free()
		coop_join_loading = null
	if is_instance_valid(home_hub):
		remove_home_hub()
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	coop_mission = preload("res://scripts/coop_mission.gd").new()
	coop_mission.name = "CoopMission"
	coop_mission.host = is_host
	coop_mission.sector = number
	coop_mission.local_profile = profile
	coop_mission.relay_owner = RiftRelay
	coop_mission.roster = RiftRelay.mission_roster.duplicate()
	coop_mission.mode = RiftRelay.mission_mode
	coop_mission.rewards_earned.connect(bank_coop_rewards)
	coop_mission.exit_requested.connect(func():
		if is_host and not coop_mission.outcome.is_empty():
			RiftRelay.return_to_station()
		else:
			RiftRelay.leave("You left the mission.")
	)
	add_child(coop_mission)
	RiftAudio.play_music(true, number)

func bank_coop_rewards(xp: int, bolts: int, blueprints: Array, number: int) -> void:
	profile.record_sector_clear(number, RiftRelay.mission_mode)
	var results: Dictionary = coop_mission.challenge_results()
	profile.record_challenges(number, results)
	profile.deposit_materials(results.get("recovered", {}))
	profile.award_player_xp(xp)
	profile.credits += bolts
	profile.unlock_sector(mini(number + 1, Catalog.SECTORS.size()))
	if not profile.memories.has(number):
		profile.memories.append(number)
	if number == Catalog.SECTORS.size():
		var ending := "secret" if profile.memories.size() == Story.MEMORIES.size() else "standard"
		if not profile.endings.has(ending):
			profile.endings.append(ending)
	for id in blueprints:
		profile.collect_blueprint(id)

func close_coop_mission(message: String) -> void:
	if not is_instance_valid(coop_mission):
		return
	remove_child(coop_mission)
	coop_mission.queue_free()
	coop_mission = null
	for shot in get_tree().get_nodes_in_group(&"rift_projectile"):
		shot.queue_free()
	open_home_hub()
	RiftAudio.play_music(false)
	if RiftRelay.connected_room.is_empty():
		home_hub.station_requested.emit("Social")
		menu.show_page("Party")
		menu.relay_status.text = message

func refresh_menu_save() -> void:
	menu.profile = profile
	menu.active_slot = save_session.slot if save_session else 0
	menu.developer_session = checkpoint_path != SAVE_PATH
	var save := read_checkpoint()
	menu.can_load = save != null
	menu.saved_sector = 1
	menu.saved_act = 1
	menu.saved_difficulty = Difficulty.NORMAL
	menu.saved_level = 1
	menu.saved_experience = 0
	menu.run_cleared_through = 0
	menu.at_sector_start = false
	menu.run_unlocks = []
	if save:
		menu.saved_sector = clampi(int(save.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
		menu.run_cleared_through = clampi(int(save.get_value("checkpoint", "run_cleared_through", menu.saved_sector - 1)), 0, Catalog.SECTORS.size())
		profile.unlock_sector(menu.saved_sector)
		menu.saved_act = clampi(int(save.get_value("checkpoint", "act", 1)), 1, 2)
		menu.saved_difficulty = Difficulty.index(int(save.get_value("checkpoint", "difficulty", 0)))
		menu.saved_experience = clampi(int(save.get_value("checkpoint", "experience", 0)), 0, 1000000)
		menu.saved_level = RiftPlayer.level_for_experience(menu.saved_experience)
		menu.at_sector_start = bool(save.get_value("checkpoint", "at_start", false))
		menu.run_unlocks = save.get_value("checkpoint", "weapons", [])

func select_save_slot(number: int, fresh: bool, operator_name := "") -> void:
	var selected := ManualSave.new(number)
	if not fresh and not selected.load_slot():
		menu.show_slot_error()
		return
	save_session = selected
	profile = selected.profile
	if fresh:
		profile.operator_name = profile.clean_operator_name(operator_name)
	RiftSettings.remember_operator_name(profile.operator_name)
	get_tree().set_meta(&"riftcore_save_session", selected)
	open_home_hub()
	if fresh:
		home_hub.materialize_operator("arrival")

func clear_deleted_operator(slot: int) -> void:
	if save_session and save_session.slot == slot:
		save_session = null
		profile = ManualSave.Profile.new()
		profile.manual_only = true
		get_tree().remove_meta(&"riftcore_save_session")
		refresh_menu_save()

func reconstruct_in_hub() -> void:
	var first: bool = not profile.reconstruction_seen
	await home_hub.materialize_operator("reconstruction" if first else "")
	if first:
		profile.reconstruction_seen = true
		if save_session:
			save_session.persist_reconstruction_seen()
		else:
			profile.save()

func save_at_station() -> void:
	menu.show_save_result(manual_save_status(write_manual_save()))

func write_manual_save() -> Error:
	if not save_session:
		return ERR_UNCONFIGURED
	if is_instance_valid(player) and not sector_complete:
		if respawning or player.health <= 0.0:
			return ERR_BUSY
		save_checkpoint(true)
	return save_session.save_slot()

func manual_save_status(error: Error) -> String:
	if error == OK:
		return "Operator %02d saved." % save_session.slot
	if error == ERR_UNCONFIGURED:
		return "Select a save slot from the title screen first."
	if error == ERR_BUSY:
		return "Wait for RX-07 to respawn before saving."
	return "Save failed. %s" % error_string(error)

func read_checkpoint() -> ConfigFile:
	if save_session:
		return save_session.run if save_session.run.has_section("checkpoint") else null
	var data := ConfigFile.new()
	if checkpoint_path != SAVE_PATH and data.load(checkpoint_path) == OK:
		return data
	return null

func write_checkpoint(data: ConfigFile) -> Error:
	if save_session:
		save_session.run = data
		return OK
	if checkpoint_path != SAVE_PATH:
		return data.save(checkpoint_path)
	return OK

func open_home_hub() -> void:
	RiftRelay.local_name = profile.operator_name
	RiftRelay.unlocked_sector = profile.unlocked_sector
	RiftRelay.set_nightmare_unlocked(profile.nightmare_unlocked())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(home_hub):
		return
	RiftSocial.connect_steam.call_deferred()
	refresh_menu_save()
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	home_hub = HOME_HUB.instantiate() as Node3D
	home_hub.profile = profile
	home_hub.persist_blueprint_trade = persist_blueprint_trade
	add_child(home_hub)
	home_hub.set_bank(profile.credits, profile.core_shards, profile.player_level())
	home_hub.station_requested.connect(func(page: String):
		home_hub.set_panel_open(true)
		menu.process_mode = Node.PROCESS_MODE_INHERIT
		menu.open_station(page)
	)
	home_hub.title_requested.connect(func():
		if not RiftRelay.connected_room.is_empty() or not RiftRelay.pending.is_empty():
			RiftRelay.leave()
		remove_home_hub()
		menu.process_mode = Node.PROCESS_MODE_INHERIT
		menu.show()
		menu.show_page("Title")
	)

func drop_hub_blueprint(id: String) -> void:
	if not is_instance_valid(home_hub) or not profile.blueprint_pouch.has(id) or not RiftRelay.can_share_blueprints():
		return
	var slot := profile.blueprint_pouch.find(id)
	profile.blueprint_pouch.remove_at(slot)
	RiftRelay.send_station_position(home_hub.avatar.position.x, home_hub.avatar.model_root.rotation.y, "idle")
	if persist_blueprint_trade() != OK or not RiftRelay.drop_blueprint(id, home_hub.avatar.position.x):
		profile.blueprint_pouch.insert(slot, id)
		persist_blueprint_trade()
		menu.inventory_status = "Could not drop the blueprint."
		menu.show_page("Storage")
		return
	menu.hide()
	close_station_panel()

func persist_blueprint_trade() -> Error:
	return save_session.persist_blueprint_trade() if save_session else profile.save()

func close_station_panel() -> void:
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(home_hub):
		home_hub.set_bank(profile.credits, profile.core_shards, profile.player_level())
		home_hub.set_panel_open(false)

func remove_home_hub() -> void:
	if is_instance_valid(invite_overlay):
		invite_overlay.hide()
		invite_overlay.queue_free()
		invite_overlay = null
	if is_instance_valid(home_hub):
		remove_child(home_hub)
		home_hub.queue_free()
		home_hub = null

func deploy_selected_sector(number: int, selected_difficulty := 0) -> void:
	var mode := Difficulty.index(selected_difficulty)
	if mode == Difficulty.NIGHTMARE and not profile.nightmare_unlocked():
		return
	if not RiftRelay.connected_room.is_empty():
		RiftRelay.deploy(number, mode)
		return
	var save := read_checkpoint()
	if save == null:
		if number == 1:
			mission_difficulty = mode
			start_game()
		return
	var current := int(save.get_value("checkpoint", "sector", 1))
	var cleared := clampi(int(save.get_value("checkpoint", "run_cleared_through", current - 1)), 0, Catalog.SECTORS.size())
	if number < 1 or number > mini(cleared + 1, Catalog.SECTORS.size()):
		return
	if number != current or (mode != int(save.get_value("checkpoint", "difficulty", 0)) and bool(save.get_value("checkpoint", "at_start", false))):
		save.set_value("checkpoint", "sector", number)
		save.set_value("checkpoint", "difficulty", mode)
		save.set_value("checkpoint", "act", 1)
		save.set_value("checkpoint", "run_cleared_through", cleared)
		save.set_value("checkpoint", "at_start", true)
		save.set_value("checkpoint", "sector_deaths", 0)
		save.set_value("checkpoint", "life_taken", false)
		for key in ["manual_combat_snapshot", "health", "energy", "equipped"]:
			if save.has_section_key("checkpoint", key):
				save.erase_section_key("checkpoint", key)
		if write_checkpoint(save) != OK:
			menu.show_deploy_error()
			return
	load_game()

func start_game(play_intro := true) -> void:
	if is_instance_valid(game_root):
		return
	if play_intro:
		sector = 1
		run_cleared_through = 0
		act = 1
		sector_deaths = 0
		run_weapons.clear()
		clear_checkpoint()
	RiftAudio.play_music(true, sector)
	remove_home_hub()
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
	factory_hud.announce("ACT 2" if act == 2 else "START", Color("71efff"))
	if act == 1:
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

func load_game(show_deployment := true) -> void:
	var save := read_checkpoint()
	if not save:
		if not is_instance_valid(menu):
			start_game()
		return
	mission_difficulty = Difficulty.index(int(save.get_value("checkpoint", "difficulty", 0)))
	if mission_difficulty == Difficulty.NIGHTMARE and not profile.nightmare_unlocked():
		mission_difficulty = Difficulty.HARD
	sector = clampi(int(save.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
	run_cleared_through = clampi(int(save.get_value("checkpoint", "run_cleared_through", sector - 1)), 0, Catalog.SECTORS.size())
	act = clampi(int(save.get_value("checkpoint", "act", 1)), 1, 2)
	var saved_lives := clampi(int(save.get_value("checkpoint", "lives", 3)), 1, 5)
	sector_deaths = maxi(0, int(save.get_value("checkpoint", "sector_deaths", 1 if saved_lives < 3 else 0)))
	if not ResourceLoader.exists(level_path(act)):
		push_warning("The saved sector scene is unavailable.")
		return
	profile.unlock_sector(sector)
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
	player.gain_experience(clampi(int(save.get_value("checkpoint", "experience", 0)), 0, 1000000), false)
	player.health = player.max_health
	player.restore_energy(player.max_energy)
	player.health_changed.emit(player.health, player.max_health)
	player.credits = maxi(int(save.get_value("checkpoint", "credits", 0)), 0)
	player.salvage = save.get_value("checkpoint", "salvage", {})
	player.recovered_blueprints = save.get_value("checkpoint", "blueprints", {})
	mission_stats = {"seconds": 0.0, "kills": 0, "operator_xp": 0, "player_xp": 0, "shards": 0}
	mission_stats.merge(save.get_value("checkpoint", "mission_stats", {}), true)
	player.credits_changed.emit(player.credits)
	player.lives = saved_lives
	player.lives_changed.emit(player.lives)
	if bool(save.get_value("checkpoint", "manual_combat_snapshot", false)) or (at_start and act == 2):
		player.health = clampf(float(save.get_value("checkpoint", "health", player.max_health)), 1.0, player.max_health)
		player.health_changed.emit(player.health, player.max_health)
		player.energy = clampf(float(save.get_value("checkpoint", "energy", player.max_energy)), 0.0, player.max_energy)
		player.energy_changed.emit(player.energy, player.max_energy)
	if save.has_section_key("checkpoint", "equipped"):
		player.equip_sector_weapon(String(save.get_value("checkpoint", "equipped", "")))
	life_taken = bool(save.get_value("checkpoint", "life_taken", false))
	if life_taken:
		var life := game_root.get_node_or_null("TERRAIN/InspectionExtraLife")
		if life:
			life.queue_free()
	if at_start and show_deployment:
		play_deploy_intro()

func level_path(target_act: int) -> String:
	var original: String = Catalog.info(sector).level
	return "res://scenes/levels/%s_act_2.tscn" % Catalog.info(sector).id if target_act == 2 else original

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
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	stack.add_child(layout)
	stack = UI.column(layout, 10)
	stack.custom_minimum_size.x = 198
	var readout := PauseOperator.new()
	readout.operator = func(): return player
	readout.profile = profile
	layout.add_child(readout)
	pause_menu.sections = readout.sections
	UI.label(stack, "PAUSED", 36, UI.CYAN)
	UI.label(stack, "%s / Act %d" % [Catalog.info(sector).title, act], 17, UI.MUTED)
	if controller_disconnected:
		UI.label(stack, "Controller disconnected", 17, UI.VIOLET)
		pause_menu.pause_action = Callable()
		pause_menu.back_action = Callable()
	UI.button(stack, "Resume", toggle_pause, true).grab_focus()
	if save_session:
		UI.button(stack, "Save Game", show_pause_save)
	UI.button(stack, "Restart run", restart_run)
	UI.button(stack, "Settings", show_pause_settings)
	UI.button(stack, "Return to title", show_exit_confirmation)

func show_pause_save() -> void:
	var stack := overlay()
	pause_menu.back_action = build_pause_menu
	UI.label(stack, "SAVE OPERATOR %02d" % save_session.slot, 28, UI.CYAN)
	UI.label(stack, "Resume from the latest checkpoint or the start of this act.", 17, UI.MUTED)
	var status := UI.label(stack, "", 17, UI.CYAN)
	UI.button(stack, "Save Operator", func():
		status.text = manual_save_status(write_manual_save())
	, true).grab_focus()
	UI.button(stack, "Back to Pause", build_pause_menu)

func overlay(sidebar := false, wide := false) -> VBoxContainer:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	shade.color = Color(0.015, 0.035, 0.075, 0.48 if sidebar else 0.8)
	pause_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	pause_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sidebar:
		center.anchor_right = 0.33
		center.offset_left = 22
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 348 if sidebar else 460
	center.add_child(panel)
	if wide:
		center.remove_child(panel)
		pause_menu.add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 155
		panel.offset_right = -155
		panel.offset_top = 55
		panel.offset_bottom = -55
	return UI.column(panel, 12)

func show_pause_settings() -> void:
	var stack := overlay(false, true)
	pause_menu.back_action = build_pause_menu
	UI.label(stack, "SETTINGS", 32, UI.CYAN)
	var settings := UI.settings(stack)
	UI.button(stack, "Back to pause", build_pause_menu)
	settings.initial_focus.grab_focus()

func build_level() -> void:
	if editor_level and sector == 1 and act == 1:
		game_root = editor_level
		game_root.visible = true
		game_root.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		var stage := NEON_FACTORY_LEVEL if sector == 1 and act == 1 else load(level_path(act)) as PackedScene
		game_root = stage.instantiate()
		add_child(game_root)
	player = game_root.get_node("Actors/RiftcoreMecha") as RiftPlayer
	game_root.get_node("Actors").set_meta("loot_scale", Difficulty.LOOT[mission_difficulty])
	var combat_scale := Difficulty.combat_scale(sector, mission_difficulty)
	player.damage_taken_scale = combat_scale
	player.experience = 0
	player.quick_profile = profile
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
		enemy.scale_for_sector(sector, act)
		enemy.max_health *= combat_scale
		enemy.health = enemy.max_health
		enemy.health_changed.emit(enemy.health, enemy.max_health)
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
	if act == 1:
		var actors := boss.get_parent()
		actors.remove_child(boss)
		boss.queue_free()
		boss = create_miniboss()
		actors.add_child(boss)
		decorate_miniboss_room()
	boss.max_health *= combat_scale
	boss.health = boss.max_health
	boss.hide()
	build_hud()
	for station in CHECKPOINT_STATIONS:
		var checkpoint := game_root.get_node_or_null(CHECKPOINT_STATIONS[station])
		if checkpoint:
			checkpoint.activated.connect(_on_checkpoint_activated.bind(station))
	game_root.get_node("ForgeHallDoor").target = player
	bind_boss_signals()
	install_sector_pads()
	SectorDetails.new().install(game_root, player, sector, act)

func create_miniboss() -> Combatant:
	var guard := Miniboss.new()
	var info := Catalog.info(sector)
	guard.name = "SectorMiniboss"
	var exit := game_root.get_node("ExitBarrier") as Node3D
	guard.configure(sector, Color(info.color), info.weak, gate.global_position, exit.global_position.x)
	guard.position = Vector3(boss_spawn.x, gate.position.y + guard.chassis_height, 0.0)
	return guard

func decorate_miniboss_room() -> void:
	var title: String = Miniboss.TITLES[sector - 1].to_upper()
	var decor := game_root.get_node("DECOR")
	for child in decor.get_children():
		if child is Label3D and child.name in [&"ArenaName", &"BossSign", &"GroveCounterplayHint"]:
			child.hide()
	var signpost := Label3D.new()
	signpost.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	signpost.text = "ACT 1  /  " + title
	signpost.modulate = Color(Catalog.info(sector).color)
	signpost.font_size = 54
	signpost.pixel_size = 0.0055
	decor.add_child(signpost)
	signpost.global_position = Vector3(gate.global_position.x + 8.0, gate.global_position.y + 4.35, -1.8)
	var exit_sign := Label3D.new()
	exit_sign.font = preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	exit_sign.text = "ACT 2"
	exit_sign.font_size = 48
	exit_sign.pixel_size = 0.006
	decor.add_child(exit_sign)
	var exit := game_root.get_node("MARKERS/RoomExit") as Node3D
	exit_sign.global_position = exit.global_position + Vector3(0.0, 2.5, -1.25)

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
	preload("res://scripts/equipment_stats.gd").apply(player, profile)

func bind_boss_signals() -> void:
	boss.health_changed.connect(func(current: float, maximum: float):
		factory_hud.boss_health = current
		factory_hud.boss_max_health = maximum
		factory_hud.queue_redraw()
	)
	boss.died.connect(func():
		boss_defeated = true
		RiftAudio.play_music(true, sector)
		award_mission_xp((35 if act == 1 else 80) + sector * 8)
		var shards := 1 + sector + (3 if act == 2 else 0)
		profile.core_shards += shards
		factory_hud.core_shards = profile.core_shards
		mission_stats.shards += shards
		var actors := game_root.get_node("Actors") as Node3D
		if act == 2:
			var cache := BossCache.new()
			cache.position = actors.to_local(Vector3(boss_spawn.x, gate.global_position.y + 0.52, 0.0))
			actors.add_child.call_deferred(cache)
			cache.opened.connect(func(): BossCache.spill(actors, cache.global_position, BossCache.roll_loot(sector, mission_difficulty)))
		else:
			Drop.roll_at(actors, boss.global_position + Vector3.UP * 0.25, sector, "miniboss")
		open_factory_gate()
		var info := Catalog.info(sector)
		for minion in get_tree().get_nodes_in_group(&"arena_minions"):
			minion.queue_free()
		var message := "MINIBOSS DOWN  /  ACT 2 OPEN"
		var reveal := false
		if act == 2:
			if sector <= Story.MEMORIES.size() and not profile.memories.has(sector):
				profile.memories.append(sector)
			var reward: String = info.reward
			var first_unlock := not run_weapons.has(reward)
			reveal = first_unlock
			player.unlock_sector_weapon(reward)
			run_weapons[reward] = true
			if checkpoint_reached:
				save_checkpoint()
			message = info.reward_name + " unlocked" if first_unlock else info.boss + " defeated"
		if reveal:
			suit_reveal_active = true
			reveal_suit.call_deferred(info)
		else:
			factory_hud.announce(message.to_upper(), Color(info.color))
		if act == 1:
			factory_hud.exit_task = "ENTER THE ACT 2 GATE"
		var barrier := game_root.get_node("ExitBarrier") as StaticBody3D
		barrier.get_node("CollisionShape3D").set_deferred("disabled", true)
		var release := barrier.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		release.tween_property(barrier.get_node("Seal"), "position:y", 4.2, 0.62)
		release.tween_callback(barrier.queue_free)
		factory_hud.boss_visible = false
		factory_hud.queue_redraw()
	)

func reveal_suit(info: Dictionary) -> void:
	if not is_instance_valid(player) or player.health <= 0 or respawning:
		suit_reveal_active = false
		return
	player.cancel_charge()
	player.velocity = Vector3.ZERO
	player.invulnerable_time = maxf(player.invulnerable_time, 1.0)
	player.set_physics_process(false)
	camera_rig.set_process(false)
	var point := player.global_position
	var ray := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 6.0, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	var floor_point: Vector3 = hit.get("position", point - Vector3.UP * player.standing_capsule.height * 0.5)
	var reveal := SuitReveal.new()
	game_root.add_child(reveal)
	await reveal.play(player, camera_rig, hud, info, floor_point)
	reveal.queue_free()
	camera_rig.set_process(true)
	player.resume_input_guard = 0.12
	player.invulnerable_time = 0.65
	player.set_physics_process(true)
	suit_reveal_active = false

func build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	factory_hud = FactoryHUD.new()
	factory_hud.exit_task = "DEFEAT THE MINIBOSS" if act == 1 else "REACH SECTOR EXTRACTION"
	factory_hud.boss_name = String(Miniboss.TITLES[sector - 1] if act == 1 else Catalog.info(sector).boss).to_upper()
	factory_hud.boss_health = boss.health
	factory_hud.boss_max_health = boss.max_health
	factory_hud.act = act
	factory_hud.boss_tint = Color(Catalog.info(sector).color)
	hud.add_child(factory_hud)
	factory_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	factory_hud.show_quick_slots(profile)
	factory_hud.remaining = remaining_enemies
	factory_hud.lives = player.lives
	factory_hud.core_shards = profile.core_shards
	factory_hud.reserve_lives = profile.reserve_lives
	factory_hud.weapon = "STANDARD FRAME"
	factory_hud.health_capacity = player.max_health
	factory_hud.energy_capacity = player.max_energy
	factory_hud.health = player.health / player.max_health
	factory_hud.energy = player.energy / player.max_energy
	factory_hud.displayed_health_capacity = player.max_health
	factory_hud.displayed_energy_capacity = player.max_energy
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
	player.blueprint_found.connect(func(id: String):
		if not profile.blueprints.has(id) and profile.GEAR.has(id):
			factory_hud.announce("BLUEPRINT RECOVERED  /  " + profile.GEAR[id].name, Color("ffda83"), 27)
	)
	player.salvage_collected.connect(func(drop: Dictionary):
		var recovered: Array[String] = []
		for id in drop:
			recovered.append("%s +%d" % [Materials.label(id), drop[id]])
		factory_hud.announce("SALVAGE  /  " + "  ·  ".join(recovered), Color("ff8ada"), 27)
	)
	player.experience_earned.connect(func(amount: int):
		mission_stats.operator_xp += amount
		award_mission_xp(maxi(1, amount / 3))
		factory_hud.queue_redraw()
	)
	player.weapon_changed.connect(func(weapon: String):
		var id := player.equipped_suit()
		var data := Catalog.weapon(id)
		factory_hud.weapon = weapon if not id.is_empty() else "STANDARD FRAME"
		factory_hud.suit_tint = Color(data.color) if not data.is_empty() else UI.CYAN
		factory_hud.queue_redraw()
	)

	player.lives_changed.connect(func(count: int):
		factory_hud.lives = count
		factory_hud.queue_redraw()
	)
	player.life_picked_up.connect(func():
		life_taken = true
		factory_hud.announce("EXTRA LIFE", Color("6dffdd"), 27)
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

func save_checkpoint(manual_combat_snapshot := false) -> void:
	var save := ConfigFile.new()
	save.set_value("checkpoint", "sector", sector)
	save.set_value("checkpoint", "difficulty", mission_difficulty)
	save.set_value("checkpoint", "run_cleared_through", run_cleared_through)
	save.set_value("checkpoint", "act", act)
	save.set_value("checkpoint", "weapons", run_weapons.keys())
	save.set_value("checkpoint", "at_start", not checkpoint_reached)
	save.set_value("checkpoint", "spawn", checkpoint_spawn)
	save.set_value("checkpoint", "station", checkpoint_station)
	save.set_value("checkpoint", "experience", int(player.experience))
	save.set_value("checkpoint", "credits", player.credits)
	save.set_value("checkpoint", "salvage", player.salvage)
	save.set_value("checkpoint", "blueprints", player.recovered_blueprints)
	save.set_value("checkpoint", "mission_stats", mission_stats)
	save.set_value("checkpoint", "lives", player.lives)
	save.set_value("checkpoint", "sector_deaths", sector_deaths)
	save.set_value("checkpoint", "life_taken", life_taken)
	if manual_combat_snapshot:
		save.set_value("checkpoint", "manual_combat_snapshot", true)
		save.set_value("checkpoint", "health", player.health)
		save.set_value("checkpoint", "energy", player.energy)
		save.set_value("checkpoint", "equipped", player.equipped_suit())
	var error := write_checkpoint(save)
	if error != OK:
		push_warning("Could not save Riftcore checkpoint: %s" % error_string(error))

func award_mission_xp(amount: int) -> void:
	var before: int = profile.player_xp
	profile.award_player_xp(amount)
	mission_stats.player_xp += profile.player_xp - before

func _enemy_defeated() -> void:
	mission_stats.kills += 1
	remaining_enemies = maxi(0, remaining_enemies - 1)
	factory_hud.remaining = remaining_enemies
	factory_hud.queue_redraw()

func _on_pit_fall() -> void:
	if respawning:
		return
	respawning = true
	sector_deaths += 1
	player.lives = maxi(0, player.lives - 1)
	var rescued := player.lives == 0 and profile.use_reserve_life()
	if rescued:
		player.lives = 1
		factory_hud.reserve_lives = profile.reserve_lives
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
		expire_run_on_death()
		show_reconstruction_notice()
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
	player.clear_ladder_support()
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
	factory_hud.announce("RESERVE LIFE USED" if rescued else "%d LIVES LEFT" % player.lives, Color("8eeaff"))
	if checkpoint_reached or sector > 1 or act == 2 or rescued:
		save_checkpoint()
	respawning = false

func show_reconstruction_notice() -> void:
	get_tree().paused = true
	var stack := overlay()
	stack.get_parent().custom_minimum_size.x = 500
	pause_menu.pause_action = Callable()
	pause_menu.back_action = Callable()
	UI.label(stack, "OPERATOR LOST", 30, UI.VIOLET)
	UI.label(stack, "RX-07 is out of lives. NOVA is ready to reconstruct you on the Deploy pad at Operations Station.", 19)
	UI.button(stack, "OK  ·  Return to Station", confirm_reconstruction, true).grab_focus()

func confirm_reconstruction() -> void:
	get_tree().set_meta(&"reconstruct_operator", true)
	return_to_command_deck()

func expire_run_on_death() -> void:
	bank_run_credits()
	profile.unlocked_sector = 1
	clear_checkpoint()
	if save_session:
		var error := save_session.invalidate_defeated_run()
		if error != OK:
			push_warning("Could not invalidate the defeated run on disk: %s" % error_string(error))
	profile.lose_equipped_gear()
	run_cleared_through = 0
	run_weapons.clear()

func reset_boss_room() -> void:
	RiftAudio.play_music(true, sector)
	if gate_motion and gate_motion.is_valid():
		gate_motion.kill()
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
	if act == 1:
		boss = create_miniboss()
	else:
		boss = (load(Catalog.info(sector).boss_scene) as PackedScene).instantiate() as Combatant
		boss.position = boss_spawn
	game_root.get_node("Actors").add_child(boss)
	boss.max_health *= Difficulty.combat_scale(sector, mission_difficulty)
	boss.health = boss.max_health
	boss.hide()
	bind_boss_signals()
	gate_open = false
	arena_sealed = false
	gate.get_node("Door").position.y = 0.0
	gate.get_node("Blocker/CollisionShape3D").set_deferred("disabled", false)
	factory_hud.boss_visible = false
	factory_hud.boss_health = boss.health
	factory_hud.boss_max_health = boss.max_health

func clear_checkpoint() -> void:
	if save_session:
		save_session.run = ConfigFile.new()
	elif checkpoint_path != SAVE_PATH and FileAccess.file_exists(checkpoint_path):
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
	UI.label(stack, "RETURN TO TITLE?", 30, UI.VIOLET)
	UI.label(stack, "Resume this run from the station. Save to keep your progress after closing the game.", 17, UI.MUTED)
	UI.button(stack, "Stay in sector", build_pause_menu).grab_focus()
	if save_session:
		var status := UI.label(stack, "", 16, UI.CYAN)
		UI.button(stack, "Save and return to title", func():
			var error := write_manual_save()
			if error == OK:
				return_to_title()
			else:
				status.text = manual_save_status(error)
		, true)
	UI.button(stack, "Return to title", return_to_title)

func _process(delta: float) -> void:
	if deploying or advancing_act or arena_intro or suit_reveal_active or sector_complete or not is_instance_valid(player) or player.health <= 0.0:
		return
	mission_stats.seconds += delta
	if not gate_open and absf(player.global_position.x - gate.global_position.x) < 4.0:
		open_factory_gate()
	if gate_open and not arena_sealed and not boss_defeated and is_instance_valid(boss) and player.global_position.x >= gate.global_position.x + 1.35:
		seal_arena()
	var exit := game_root.get_node("MARKERS/RoomExit") as Marker3D
	var at_exit := player.global_position.distance_to(exit.global_position) <= 1.45
	if not at_exit:
		act_exit_retry = false
	if at_exit and boss_defeated and not factory_hud.reached_exit:
		factory_hud.reached_exit = true
		game_root.get_node("MARKERS/RoomExit/ExtractionPad").pulse()
		factory_hud.queue_redraw()
	if not at_exit or not boss_defeated:
		return
	if act == 1:
		if not act_exit_retry:
			advancing_act = true
			advance_to_act_two.call_deferred()
		return
	sector_complete = true
	RiftSocial.record_clear(sector, mission_stats.seconds)
	award_mission_xp(65 + sector * 12)
	var replay := sector <= run_cleared_through
	run_cleared_through = maxi(run_cleared_through, sector)
	var bonus := 160 + 25 * (sector - 1)
	profile.record_sector_clear(sector, mission_difficulty)
	var recovered := player.salvage.duplicate()
	var recovered_blueprints: Array[String] = []
	for id in player.recovered_blueprints:
		if profile.collect_blueprint(id):
			recovered_blueprints.append(profile.GEAR[id].name)
	profile.deposit_materials(recovered)
	player.salvage.clear()
	player.recovered_blueprints.clear()
	profile.core_shards += 4 + sector
	mission_stats.shards += 4 + sector
	bank_run_credits(bonus)
	var final_sector := sector >= Catalog.SECTORS.size()
	var material_count := 0
	for quantity in recovered.values():
		material_count += int(quantity)
	var reward: Dictionary = profile.record_challenges(sector, {
		"clear": 1, "clean": int(sector_deaths == 0), "kills": mission_stats.kills,
		"materials": material_count, "bolts": player.credits, "time": mission_stats.seconds,
		"health": player.health / player.max_health * 100.0,
		"energy": player.energy / player.max_energy * 100.0,
	})
	mission_stats.shards += int(reward.get("shards", 0))
	if not final_sector:
		profile.unlock_sector(sector + 1)
	if banked_run and ResourceLoader.exists(Catalog.info(sector + 1).level):
		var continuation := ConfigFile.new()
		continuation.set_value("checkpoint", "sector", mini(run_cleared_through + 1, Catalog.SECTORS.size()))
		continuation.set_value("checkpoint", "run_cleared_through", run_cleared_through)
		continuation.set_value("checkpoint", "act", 2 if run_cleared_through >= Catalog.SECTORS.size() else 1)
		continuation.set_value("checkpoint", "difficulty", mission_difficulty)
		continuation.set_value("checkpoint", "weapons", run_weapons.keys())
		continuation.set_value("checkpoint", "equipped", player.equipped_suit())
		continuation.set_value("checkpoint", "at_start", true)
		continuation.set_value("checkpoint", "experience", int(player.experience))
		continuation.set_value("checkpoint", "lives", player.lives if replay else 3)
		continuation.set_value("checkpoint", "sector_deaths", sector_deaths if final_sector else 0)
		var error := write_checkpoint(continuation)
		if error != OK:
			push_warning("Could not save the next sector deployment: %s" % error_string(error))
	get_tree().paused = true
	var ending := ""
	if final_sector:
		var recovered_all := profile.memories.size() == Story.MEMORIES.size()
		var ending_id := "secret" if recovered_all else "standard"
		if not profile.endings.has(ending_id):
			profile.endings.append(ending_id)
			profile.save()
		ending = Story.ending(recovered_all)
	var stack := overlay()
	stack.get_parent().custom_minimum_size.x = 1050
	preload("res://scripts/mission_complete.gd").build(
		stack, Catalog.info(sector).title, mission_stats, recovered, recovered_blueprints,
		player.credits + bonus + int(reward.get("credits", 0)), int(reward.get("lives", 0)), sector_deaths,
		ending, return_to_command_deck
	)

func advance_to_act_two() -> void:
	var loading := ActLoadingScreen.new()
	add_child(loading)
	loading.show_loading(Catalog.info(sector).title)
	player.cancel_charge()
	player.set_physics_process(false)
	var path := level_path(2)
	var status := ResourceLoader.THREAD_LOAD_FAILED
	var progress: Array = []
	if ResourceLoader.load_threaded_request(path, "PackedScene") == OK:
		status = ResourceLoader.load_threaded_get_status(path, progress)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				loading.progress.value = progress[0]
			await get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(path, progress)
	var next_stage: PackedScene
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		next_stage = ResourceLoader.load_threaded_get(path) as PackedScene
	if not next_stage:
		await cancel_act_transition(loading, "LOAD FAILED  /  RE-ENTER THE GATE")
		return
	await get_tree().create_timer(0.42, false).timeout
	var save := ConfigFile.new()
	save.set_value("checkpoint", "sector", sector)
	save.set_value("checkpoint", "run_cleared_through", run_cleared_through)
	save.set_value("checkpoint", "act", 2)
	save.set_value("checkpoint", "at_start", true)
	save.set_value("checkpoint", "weapons", run_weapons.keys())
	save.set_value("checkpoint", "experience", player.experience)
	save.set_value("checkpoint", "credits", player.credits)
	save.set_value("checkpoint", "salvage", player.salvage)
	save.set_value("checkpoint", "blueprints", player.recovered_blueprints)
	save.set_value("checkpoint", "mission_stats", mission_stats)
	save.set_value("checkpoint", "lives", player.lives)
	save.set_value("checkpoint", "sector_deaths", sector_deaths)
	save.set_value("checkpoint", "difficulty", mission_difficulty)
	save.set_value("checkpoint", "health", player.health)
	save.set_value("checkpoint", "energy", player.energy)
	save.set_value("checkpoint", "equipped", player.equipped_suit())
	if write_checkpoint(save) != OK:
		await cancel_act_transition(loading, "SAVE FAILED  /  RE-ENTER THE GATE")
		return
	var act_reward: Dictionary = profile.record_challenges(sector, {"act": 1})
	mission_stats.shards += int(act_reward.get("shards", 0))
	save.set_value("checkpoint", "mission_stats", mission_stats)
	write_checkpoint(save)
	var previous := game_root
	remove_child(previous)
	previous.queue_free()
	remove_child(hud)
	hud.queue_free()
	game_root = null
	remaining_enemies = 0
	gate_open = false
	arena_sealed = false
	boss_defeated = false
	checkpoint_reached = false
	checkpoint_station = "midpoint"
	checkpoint_spawn = Vector3.ZERO
	life_taken = false
	load_game(false)
	player.set_physics_process(false)
	var spawn := player.global_position
	camera_rig.global_position = Vector3(clampf(spawn.x, camera_rig.min_x, camera_rig.max_x), maxf(0.85, spawn.y + 0.35), 0)
	loading.begin()
	await get_tree().create_timer(0.70, false).timeout
	await loading.fade_out()
	player.invulnerable_time = 0.5
	player.set_physics_process(true)
	advancing_act = false
	if not act_reward.is_empty():
		factory_hud.announce("CHALLENGE CLEAR  /  +%d BOLTS  +1 LIFE" % act_reward.credits, Color("ffe28e"))

func cancel_act_transition(loading: CanvasLayer, message: String) -> void:
	await loading.fade_out()
	player.set_physics_process(true)
	advancing_act = false
	act_exit_retry = true
	factory_hud.announce(message, Color.ORANGE_RED)

func open_factory_gate() -> void:
	gate_open = true
	var door := gate.get_node("Door") as Node3D
	var blocker := gate.get_node("Blocker/CollisionShape3D") as CollisionShape3D
	if gate_motion and gate_motion.is_valid():
		gate_motion.kill()
	gate_motion = gate.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	gate_motion.tween_property(door, "position:y", 4.2, 0.8)
	gate_motion.tween_callback(blocker.set_deferred.bind("disabled", true))

func seal_arena() -> void:
	arena_sealed = true
	arena_intro = true
	var door := gate.get_node("Door") as Node3D
	var blocker := gate.get_node("Blocker/CollisionShape3D") as CollisionShape3D
	blocker.set_deferred("disabled", false)
	if gate_motion and gate_motion.is_valid():
		gate_motion.kill()
	gate_motion = gate.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	gate_motion.tween_property(door, "position:y", 0.0, 0.48)
	play_arena_intro()

func play_arena_intro() -> void:
	RiftAudio.play_boss_music()
	player.cancel_charge()
	player.velocity = Vector3.ZERO
	player.facing = 1.0
	player.invulnerable_time = maxf(player.invulnerable_time, 0.35)
	player.set_physics_process(false)
	player.model_root.rotation.y = PI * 0.5
	var destination := player.global_position + Vector3.RIGHT * 1.75
	destination.x = minf(destination.x, boss.global_position.x - 3.1)
	destination.y = gate.global_position.y + player.standing_capsule.height * 0.5 + 0.02
	player.play_character_animation("walk", true)
	await player.create_tween().tween_property(player, "global_position", destination, 0.46).finished
	player.play_character_animation("idle", true)
	var cinematic := preload("res://scripts/boss_intro.gd").new()
	game_root.add_child(cinematic)
	await cinematic.play(camera_rig, boss, gate.global_position.y, factory_hud.boss_name, Color(Catalog.info(sector).color), sector, act)
	cinematic.queue_free()
	player.invulnerable_time = 0.35
	player.set_physics_process(true)
	boss.target = player
	boss.active = true
	factory_hud.boss_visible = true
	factory_hud.queue_redraw()
	arena_intro = false

func _on_health_changed(current: float, maximum: float) -> void:
	factory_hud.health = current / maximum
	factory_hud.health_capacity = maximum
	factory_hud.queue_redraw()

func _on_player_died() -> void:
	_on_pit_fall()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		active_controller = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
		active_controller = event.device
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		active_controller = -1

func on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or device != active_controller:
		return
	active_controller = -1
	if not is_instance_valid(game_root) or not is_instance_valid(player) or not is_instance_valid(hud):
		return
	if get_tree().paused or RiftRelay.mission_active or is_instance_valid(coop_mission) or sector_complete:
		return
	controller_disconnected = true
	toggle_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game_root and not sector_complete and not advancing_act and not arena_intro and not suit_reveal_active and player.visible:
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
		controller_disconnected = false
		player.resume_input_guard = 0.12
		for action in RiftSettings.ACTIONS.keys() + ["crouch_stick"]:
			Input.action_release(action)
		pause_menu.queue_free()
		pause_menu = null

func restart_run() -> void:
	bank_run_credits()
	get_tree().paused = false
	get_tree().set_meta(&"restart_factory", true)
	get_tree().reload_current_scene()

func return_to_title() -> void:
	if is_instance_valid(player) and player.health > 0.0 and not sector_complete:
		save_checkpoint(true)
	get_tree().paused = false
	get_tree().reload_current_scene()


func return_to_command_deck() -> void:
	bank_run_credits()
	get_tree().paused = false
	get_tree().set_meta(&"open_command_deck", true)
	get_tree().reload_current_scene()
