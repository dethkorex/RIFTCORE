extends Node

const PauseOperator := preload("res://scripts/pause_operator_panel.gd")
const Story := preload("res://scripts/rift_story.gd")
const StoryDialogue := preload("res://scripts/story_dialogue.gd")
const UI := preload("res://scripts/rift_ui.gd")
const FactoryHUD := preload("res://scripts/factory_hud.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Difficulty := preload("res://scripts/mission_difficulty.gd")
const FoundryModule := preload("res://scripts/foundry_run_module.gd")
const BossCache := preload("res://scripts/boss_loot_cache.gd")
const Miniboss := preload("res://scripts/sector_miniboss.gd")
const ActLoadingScreen := preload("res://scripts/act_loading_screen.gd")
const SectorDetails := preload("res://scripts/sector_details.gd")
const COMBAT_VFX := preload("res://scripts/combat_vfx.gd")
const ManualSave := preload("res://scripts/manual_save_session.gd")
const SuitReveal := preload("res://scripts/suit_reveal.gd")
const CampaignDoor := preload("res://scripts/campaign_door.gd")
const GateRelays := preload("res://scripts/gate_relays.gd")
const WhisperOverlay := preload("res://scripts/whisper_overlay.gd")
const PlaytestReset := preload("res://scripts/playtest_reset.gd")
const PlayerAccount := preload("res://scripts/player_account.gd")
const HOME_HUB := preload("res://scenes/home_hub.tscn")
var sector_complete := false
var deploying := false
var remaining_enemies := 0
var factory_hud: Control
var boss: Combatant
var gate: Node3D
var gate_open := false
var arena_door: CampaignDoor
var gate_relays: GateRelays
var repair_hall: Node3D
var arena_sealed := false
var arena_intro := false
var suit_reveal_active := false
var boss_defeated := false
var respawning := false
const CHECKPOINT_STATIONS := {
	"canopy_lift": "TERRAIN/CanopyLiftCheckpoint",
	"midpoint": "TERRAIN/MidpointCheckpoint",
	"escape_shaft": "TERRAIN/EscapeShaftCheckpoint",
	"forge_hall": "TERRAIN/ForgeHallCheckpoint",
}
const CHECKPOINT_ORDER := ["canopy_lift", "midpoint", "escape_shaft", "forge_hall"]
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
var run_module := ""


var player: RiftPlayer
var camera_rig: SideCameraRig
var hud: CanvasLayer
var menu: Control
var game_root: Node3D
var pause_menu: Control
var recovery_menu: CanvasLayer
var recovery_label: Label
var recovery_button: Button
var invite_overlay: CanvasLayer
var chat: WhisperOverlay
var account: PlayerAccount
var progress_reset_error := OK
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
	chat = WhisperOverlay.new()
	chat.available = can_open_chat
	chat.toggled.connect(set_chat_open)
	add_child(chat)
	Input.joy_connection_changed.connect(on_joy_connection_changed)
	var pointer := preload("res://scripts/menu_pointer.gd").new()
	pointer.name = "MenuPointer"
	pointer.menu_open = func(): return (is_instance_valid(menu) and menu.is_visible_in_tree()
		or is_instance_valid(pause_menu) and pause_menu.is_visible_in_tree()
		or is_instance_valid(coop_mission) and coop_mission.is_pause_open()
		or is_instance_valid(home_hub) and (home_hub.is_pause_open() or home_hub.has_dialogue())
		or chat.is_open()
		or is_instance_valid(recovery_menu)
		or is_instance_valid(invite_overlay)
		or get_tree().has_group(&"interactive_dialogue"))
	add_child(pointer)
	RiftRelay.invite_received.connect(show_friend_invite)
	RiftRelay.directory.friend_request_received.connect(show_friend_request)
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
	account = PlayerAccount.new()
	account.restore()
	progress_reset_error = PlaytestReset.migrate_local(account)
	profile.player_xp = account.experience
	if get_tree().has_meta(&"restart_factory"):
		get_tree().remove_meta(&"restart_factory")
		start_game.call_deferred()
	elif get_tree().has_meta(&"load_factory"):
		get_tree().remove_meta(&"load_factory")
		load_game.call_deferred()
	else:
		show_main_menu()

func show_friend_request(sender: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 174
	add_child(layer)
	var panel := UI.equipment_card(UI.CYAN)
	panel.theme = UI.theme()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -350
	panel.offset_right = -20
	panel.offset_top = 105
	var content := UI.column(panel, 4)
	UI.label(content, "%s sent a friend request" % sender, 19, UI.CYAN)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var accept := UI.button(actions, "Accept Friend", func():
		var status: String = await RiftRelay.directory.friend_action(sender, "accept")
		if is_instance_valid(layer) and status == "Friend request accepted.":
			layer.queue_free()
	, true, 34)
	accept.focus_mode = Control.FOCUS_NONE
	UI.button(actions, "Later", layer.queue_free, false, 34).focus_mode = Control.FOCUS_NONE
	get_tree().create_timer(12.0).timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())

func show_friend_invite(display_name: String, code: String) -> void:
	RiftSocial.record_invite(display_name, code)
	if is_instance_valid(invite_overlay):
		invite_overlay.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 175
	invite_overlay = layer
	add_child(layer)
	var panel := UI.equipment_card(UI.VIOLET)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = UI.theme()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -344
	panel.offset_right = -22
	panel.offset_top = 82
	var content := UI.column(panel, 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.label(content, "%s invited you to a game" % display_name, 20, UI.CYAN)
	var can_enter_station: bool = is_instance_valid(menu) and not menu.checking_cloud_save \
		and not RiftRelay.directory.progress.conflict and not is_instance_valid(player) and menu.preferred_operator() > 0
	if RiftRelay.can_receive_invite() and (is_instance_valid(home_hub) or can_enter_station):
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		content.add_child(buttons)
		UI.button(buttons, "Join Game", func():
			if RiftRelay.can_receive_invite():
				if not is_instance_valid(home_hub) and can_enter_station:
					menu.play_local_save()
				if not is_instance_valid(home_hub):
					return
				RiftSocial.remove_invite(code)
				RiftRelay.join_room(code)
				layer.queue_free()
		, true, 35).focus_mode = Control.FOCUS_NONE
		UI.button(buttons, "Dismiss", func():
			RiftSocial.remove_invite(code)
			layer.queue_free()
		, false, 35).focus_mode = Control.FOCUS_NONE
	else:
		UI.label(content, "Open Social → Notifications to join", 16, UI.MUTED)
	RiftAudio.play_effect(&"menu_confirm")
	get_tree().create_timer(7.0).timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
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
	var wipe_test := arguments.has("wipe")
	if wipe_test:
		arguments = arguments.slice(0, arguments.size() - 1)
	var mission_test := arguments.has("mission")
	var smoke_sector := 2 if arguments.has("jungle") else 1
	if not arguments.is_empty() and arguments[-1].begins_with("sector="):
		smoke_sector = int(arguments[-1].trim_prefix("sector="))
		arguments = arguments.slice(0, arguments.size() - 1)
	elif smoke_sector == 2:
		arguments = arguments.slice(0, arguments.size() - 1)
	if mission_test:
		arguments = arguments.slice(0, arguments.size() - 1)
	var host := arguments == PackedStringArray(["host"])
	var guest := arguments.size() == 2 and arguments[0] == "join" and RiftRelay.valid_code(arguments[1])
	if (not host and not guest) or smoke_sector < 1 or smoke_sector > Catalog.SECTORS.size():
		print("RELAY CHECK FAIL. Use host or join ROOM_CODE, with optional mission sector=N.")
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
		checkpoint_path = "user://relay-check-%d.cfg" % OS.get_process_id()
		await verify_coop_mission(host, smoke_sector, wipe_test)
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

func verify_coop_mission(host: bool, smoke_sector: int, wipe_test := false) -> void:
	profile.unlocked_sector = smoke_sector
	RiftRelay.unlocked_sector = smoke_sector
	if host:
		menu.leave_page()
	else:
		await get_tree().create_timer(0.8).timeout
	var previous_credits: int = profile.credits
	var previous_xp: int = profile.player_xp
	var starting_operator_xp := 120 if host else 260
	var run := ConfigFile.new()
	run.set_value("checkpoint", "sector", smoke_sector)
	run.set_value("checkpoint", "experience", starting_operator_xp)
	if smoke_sector > 1 and not host:
		run.set_value("checkpoint", "weapons", [Catalog.info(smoke_sector - 1).reward])
		run.set_value("checkpoint", "equipped", Catalog.info(smoke_sector - 1).reward)
	write_checkpoint(run)
	var reward_blueprint := "bp_%02d_%02d" % [smoke_sector, int(not host)]
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
			print("Campaign check failed to see the guest move in the hub")
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
		RiftRelay.deploy(smoke_sector)
	if not await wait_for_relay(func(): return is_instance_valid(coop_mission), 15.0):
		print("Campaign check failed to deploy")
		finish_relay_check(false)
		return
	var mission = coop_mission
	var local_index := 0 if host else 1
	var local_operator: RiftPlayer = mission.operators[local_index]
	if not await wait_for_relay(func(): return is_instance_valid(coop_mission) and coop_mission.operators[local_index].experience >= starting_operator_xp, 5.0):
		print("Campaign check failed to carry Operator XP into deployment")
		finish_relay_check(false)
		return
	var spawn_x := local_operator.position.x
	if mission.camera.target != local_operator or not is_equal_approx(local_operator.damage_taken_scale, mission.difficulty) or not mission.personal_hud.coop or not mission.personal_hud.is_visible_in_tree():
		print("Campaign check failed local camera or HUD")
		finish_relay_check(false)
		return
	if not host and (not local_operator.local_prediction or not local_operator.is_physics_processing()):
		print("Campaign check failed guest input prediction")
		finish_relay_check(false)
		return
	if not await verify_coop_input_isolation(mission, local_index):
		print("Campaign check failed to isolate jump and movement inputs")
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
	if smoke_sector == 1 and not await verify_foundry_landing(local_operator):
		print("Campaign check failed at the Foundry intake landing")
		finish_relay_check(false)
		return
	if smoke_sector == 2 and not await verify_canopy_coop_crossing(local_operator, mission):
		print("Campaign check failed at the nursery swing")
		finish_relay_check(false)
		return
	if wipe_test:
		await verify_coop_wipe(host, mission)
		return
	if not host:
		RiftRelay.relay.lobby_set_data("coop_guest_moved", true)
		var entered_act_two := await wait_for_relay(func(): return is_instance_valid(coop_mission) and coop_mission.act == 2 and not coop_mission.changing_act, 24.0)
		if entered_act_two:
			var jungle_passed := true
			if smoke_sector == 2:
				jungle_passed = await verify_canopy_coop_crossing(mission.operators[local_index], mission)
			RiftRelay.relay.lobby_set_data("coop_guest_act_two", jungle_passed)
	else:
		if not await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_guest_moved", false), 10.0):
			finish_relay_check(false)
			return
		if not await clear_coop_test_boss(mission):
			finish_relay_check(false)
			return
		if not await wait_for_relay(func(): return is_instance_valid(mission) and mission.act == 2 and not mission.changing_act, 20.0):
			print("Campaign check failed to enter Act II")
			finish_relay_check(false)
			return
		if smoke_sector == 2 and not await verify_canopy_coop_crossing(mission.operators[local_index], mission):
			print("Campaign check failed at the Canopy Escape")
			finish_relay_check(false)
			return
		if not await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_guest_act_two", false), 20.0):
			print("Campaign check failed to confirm the guest entered Act II")
			finish_relay_check(false)
			return
		for index in mission.operators.size():
			mission.operators[index].credits += 19 + index * 11
			mission.operators[index].recovered_blueprints["bp_%02d_%02d" % [smoke_sector, index]] = true
		if not await clear_coop_test_boss(mission):
			finish_relay_check(false)
			return
	# The guest begins waiting before the host plays the guardian entrance,
	# suit reveal and extraction debrief. Each is part of the normal test path.
	var returned := await wait_for_relay(func(): return is_instance_valid(home_hub) and not RiftRelay.mission_active, 50.0)
	var continuation := read_checkpoint()
	var next_sector := mini(smoke_sector + 1, Catalog.SECTORS.size())
	var progressed: bool = (continuation != null
		and int(continuation.get_value("checkpoint", "sector", 0)) == next_sector
		and int(continuation.get_value("checkpoint", "experience", 0)) > starting_operator_xp
		and Catalog.info(smoke_sector).reward in continuation.get_value("checkpoint", "weapons", []))
	var rewards := (profile.player_xp > previous_xp and profile.credits > previous_credits
		and profile.blueprint_items.has(reward_blueprint) and profile.gear == saved_gear
		and profile.unlocked_sector >= next_sector and progressed)
	if not returned or not rewards:
		print("Campaign check failed at extraction: hub=", returned, " XP=", profile.player_xp > previous_xp,
			" bolts=", profile.credits > previous_credits, " blueprint=", profile.blueprint_items.has(reward_blueprint),
			" gear=", profile.gear == saved_gear, " sector=", profile.unlocked_sector, " continuation=", progressed)
	if not host and returned and rewards:
		RiftRelay.relay.lobby_set_data("coop_guest_returned", true)
		await get_tree().create_timer(1.5).timeout
	if host and returned and rewards:
		returned = await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_guest_returned", false), 8.0)
	finish_relay_check(returned and rewards)

func verify_coop_wipe(host: bool, mission: Node) -> void:
	var room := RiftRelay.connected_room
	var previous_xp: int = profile.player_xp
	profile.gear["pulse_lens"] = "equipped"
	profile.gear["impact_liner"] = "stored"
	profile.core_shards = 17
	profile.credits = 113
	profile.operator_level = 4
	var checkpoint := ConfigFile.new()
	checkpoint.set_value("checkpoint", "experience", 650)
	write_checkpoint(checkpoint)
	if host:
		if not await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_wipe_ready", false), 10.0):
			finish_relay_check(false)
			return
		for operator in mission.operators:
			operator.gain_experience(650, false)
			operator.lives = 1
			mission.respawn_operator(operator)
	else:
		RiftRelay.relay.lobby_set_data("coop_wipe_ready", true)
	var returned := await wait_for_relay(func(): return is_instance_valid(home_hub) and not RiftRelay.mission_active, 15.0)
	var reset := returned and RiftRelay.connected_room == room and RiftRelay.room_size == 2
	reset = reset and profile.operator_level == 1 and read_checkpoint() == null
	reset = reset and not profile.gear.has("pulse_lens") and profile.gear.get("impact_liner", "") == "stored"
	reset = reset and profile.core_shards == 17 and profile.credits == 113 and profile.player_xp == previous_xp
	if not host and reset:
		RiftRelay.relay.lobby_set_data("coop_wipe_returned", true)
		await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_wipe_confirmed", false), 8.0)
	elif host and reset:
		reset = await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_wipe_returned", false), 8.0)
		if reset:
			RiftRelay.relay.lobby_set_data("coop_wipe_confirmed", true)
			await get_tree().create_timer(1.3).timeout
	print("LIVE PARTY WIPE ", reset, " / same room, Lv. 1 and permanent progress")
	finish_relay_check(reset)

func verify_coop_input_isolation(mission: Node, local_index: int) -> bool:
	var operator: RiftPlayer = mission.operators[local_index]
	var teammate: RiftPlayer = mission.operators[1 - local_index]
	if not await wait_for_relay(func(): return operator.grounded(), 3.0):
		return false
	var lobby := RiftRelay.relay
	var local_start := operator.global_position
	lobby.lobby_set_data("coop_input_ready_%d" % local_index, local_start.x)
	if not await wait_for_relay(func(): return lobby.lobby_get_data("coop_input_ready_%d" % (1 - local_index), null) != null, 5.0):
		return false
	var remote_start := float(lobby.lobby_get_data("coop_input_ready_%d" % (1 - local_index), 0.0))
	for moving_index in 2:
		if local_index == moving_index:
			Input.action_press("move_right")
			Input.action_press("jump")
			var jumped := await wait_for_relay(func(): return operator.global_position.y > local_start.y + .45 and operator.global_position.x > local_start.x + .55, .6)
			Input.action_release("move_right")
			Input.action_release("jump")
			if not jumped:
				return false
			lobby.lobby_set_data("coop_input_jump_%d" % moving_index, true)
			if not await wait_for_relay(func(): return lobby.lobby_get_data("coop_input_observed_%d" % moving_index, false), 5.0):
				return false
		else:
			var idle_start := operator.global_position
			if not await wait_for_relay(func(): return lobby.lobby_get_data("coop_input_jump_%d" % moving_index, false) and teammate.global_position.x > remote_start + .4, 5.0):
				return false
			if operator.global_position.distance_to(idle_start) > .25:
				return false
			lobby.lobby_set_data("coop_input_observed_%d" % moving_index, true)
	if not await wait_for_relay(func(): return operator.grounded(), 3.0):
		return false
	print("CO-OP INPUT ISOLATION PASS ", "host" if local_index == 0 else "guest")
	return true

func verify_foundry_landing(operator: RiftPlayer) -> bool:
	var start_health := operator.health
	Input.action_press("move_right")
	var takeoff := await wait_for_jump_lip(operator, 14.0)
	var crossed := false
	if takeoff:
		Input.action_press("jump")
		for frame in 17:
			await get_tree().physics_frame
		Input.action_press("dash")
		crossed = await wait_for_relay(func(): return is_instance_valid(operator) and operator.global_position.x >= 22.25 and operator.is_on_floor(), 3.0)
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	return crossed and is_equal_approx(operator.health, start_health)

func verify_canopy_coop_crossing(operator: RiftPlayer, mission: Node) -> bool:
	var route := mission.stage.find_child("CanopyTraverse", true, false) as Node3D
	if not route:
		return false
	var start := route.global_position + Vector3(-2.0, 0.90, 0.0)
	var approach := "CanopyTraverse%d" % mission.act
	if mission.host:
		if not await wait_for_relay(func(): return RiftRelay.relay.lobby_get_data("coop_approach_ready", "") == approach, 10.0):
			return false
		for player in mission.operators:
			player.invulnerable_time = 12.0
			player.global_position = start
			player.velocity = Vector3.ZERO
			mission.mark_position_reset(player)
		mission.broadcast_state(true)
	else:
		RiftRelay.relay.lobby_set_data("coop_approach_ready", approach)
	if not await wait_for_relay(func(): return operator.global_position.distance_to(start) < 0.95 and operator.grounded(), 10.0):
		return false
	Input.action_press("move_right")
	Input.action_press("climb_up")
	var completed := true
	for vine in route.get_children():
		if not vine.is_in_group(&"jungle_swing"):
			continue
		if not await wait_for_relay(func(): return operator.jungle_vine == vine and operator.jungle_swing_time >= 0.89, 4.0):
			completed = false
			break
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("jump")
	Input.action_release("climb_up")
	var end := route.global_position + (Vector3(10.25, 4.28, 0.0) if mission.act == 1 else Vector3(33.7, 6.58, 0.0))
	for tick in 150:
		if operator.global_position.x >= end.x - 0.90:
			Input.action_release("move_right")
		if operator.global_position.distance_to(end) < 2.15 and operator.grounded():
			break
		await get_tree().physics_frame
	Input.action_release("move_right")
	var crossed := completed and operator.grounded() and operator.global_position.distance_to(end) < 2.15
	print("JUNGLE CANOPY CROSSING ACT ", mission.act, " ", crossed, " at ", operator.global_position)
	return crossed


func wait_for_jump_lip(operator: RiftPlayer, edge: float) -> bool:
	# Physics ticks keep the takeoff repeatable under load.
	for frame in 135:
		await get_tree().physics_frame
		if operator.health <= 0:
			return false
		if operator.global_position.x >= edge - 0.48:
			return operator.is_on_floor()
	return false


func clear_coop_test_boss(mission: Node) -> bool:
	var gate_position: Vector3 = mission.gate.global_position
	if mission.gate_relays.count() != 0:
		print("Campaign check failed: gate relays carried across acts")
		return false
	for index in mission.operators.size():
		mission.operators[index].global_position = gate_position + Vector3(-2.0 - index, 1.0, 0.0)
	mission.check_campaign_progress()
	if mission.entrance_open:
		print("Campaign check failed: arena door opened without gate relays")
		return false
	for index in mission.gate_relays.terminals.size():
		var operator: RiftPlayer = mission.operators[index]
		operator.global_position = mission.gate_relays.terminals[index].global_position + Vector3.UP * 0.9
		if not mission.interact_gate_relay(operator) or mission.gate_relays.count() != index + 1:
			print("Campaign check failed: gate relay did not register for operator ", index)
			return false
		if index == 0:
			operator.global_position = gate_position + Vector3(-2.0, 1.0, 0.0)
			mission.check_campaign_progress()
			if mission.entrance_open:
				print("Campaign check failed: arena door opened with only one gate relay")
				return false
	mission.operators[0].global_position = gate_position + Vector3(-2.0, 1.0, 0.0)
	mission.operators[1].global_position = gate_position + Vector3(-10.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if mission.entrance_open or mission.boss_started:
		print("Campaign check failed: arena door opened on a staggered arrival, act ", mission.act)
		return false
	mission.operators[1].global_position = gate_position + Vector3(-1.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if not mission.entrance_open or mission.boss_started:
		print("Campaign check failed: arena door did not open for both operators, act ", mission.act)
		return false
	if not await wait_for_relay(func(): return mission.arena_door.passable, 2.0):
		print("Campaign check failed: open arena door retains collision, act ", mission.act)
		return false
	mission.operators[0].global_position = gate_position + Vector3(3.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if mission.boss_started:
		print("Campaign check failed: arena sealed while an operator was outside, act ", mission.act)
		return false
	mission.operators[1].global_position = gate_position + Vector3(4.0, 1.0, 0.0)
	mission.check_campaign_progress()
	if not mission.boss_started or not await wait_for_relay(func(): return not mission.boss_intro_active, 17.0):
		print("Campaign check failed: boss intro did not complete, act ", mission.act)
		return false
	if mission.sector == 2:
		if not await clear_jungle_test_boss(mission):
			return false
	elif mission.boss.has_method("open_armor"):
		for phase in 3:
			mission.boss.open_armor()
			mission.boss.take_damage(100000.0)
	else:
		mission.boss.take_damage(100000.0)
	mission.operators[0].global_position = mission.exit_marker.global_position
	mission.check_campaign_progress()
	return mission.boss_defeated

func clear_jungle_test_boss(mission: Node) -> bool:
	var opponent: Combatant = mission.boss
	var operator: RiftPlayer = mission.operators[0]
	operator.invulnerable_time = 30.0
	var armor_hp := opponent.health
	opponent.take_damage(100000.0)
	if opponent.health != armor_hp:
		return false
	if mission.act == 1:
		for phase in 3:
			if not await wait_for_relay(func(): return not opponent.root_anchor.dormant, 3.0):
				return false
			var prime: Vector3 = opponent.root_anchor.global_position
			var side := -1.0 if opponent.global_position.x >= prime.x else 1.0
			for hit in opponent.root_anchor.durability:
				operator.global_position = prime + Vector3(side * 2.2, -.05, 0)
				operator.velocity = Vector3.ZERO
				operator.facing = -side
				operator.shoot(false)
				await get_tree().create_timer(.18).timeout
			if not await wait_for_relay(func(): return opponent.exposed, 2.0):
				return false
			opponent.take_damage(100000.0)
	else:
		operator.global_position = opponent.drains[0].global_position + Vector3.UP * .96
		operator.velocity = Vector3.ZERO
		if not await wait_for_relay(func(): return opponent.exposed, 11.0):
			return false
		opponent.take_damage(100000.0)
	return true

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
	if checkpoint_path.begins_with("user://relay-check-") and FileAccess.file_exists(checkpoint_path):
		DirAccess.remove_absolute(checkpoint_path)
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
	add_key_action("suit_fire", KEY_L)
	add_key_action("swap_weapon", KEY_Q)
	add_key_action("previous_suit", KEY_E)
	add_key_action("melee", KEY_K)
	add_key_action("restart", KEY_R)
	add_key_action("pause", KEY_ESCAPE)
	add_key_action("field_interact", KEY_F)
	add_key_action("push_to_talk", KEY_V)
	add_joy_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_joy_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	InputMap.action_set_deadzone("move_left", 0.18)
	InputMap.action_set_deadzone("move_right", 0.18)
	add_joy_button("jump", JOY_BUTTON_A)
	add_joy_button("dash", JOY_BUTTON_B)
	add_joy_button("shoot", JOY_BUTTON_X)
	add_joy_action("suit_fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	InputMap.action_set_deadzone("suit_fire", 0.55)
	add_joy_button("swap_weapon", JOY_BUTTON_RIGHT_SHOULDER)
	add_joy_button("previous_suit", JOY_BUTTON_LEFT_SHOULDER)
	add_joy_button("melee", JOY_BUTTON_Y)
	add_joy_action("crouch_stick", JOY_AXIS_LEFT_Y, 1.0)
	InputMap.action_set_deadzone("crouch_stick", 0.65)
	add_joy_button("pause", JOY_BUTTON_START)
	add_joy_button("field_interact", JOY_BUTTON_RIGHT_STICK)
	add_joy_button("push_to_talk", JOY_BUTTON_LEFT_STICK)
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
		RiftRelay.party_rejoin_offered.connect(show_party_rejoin)
		RiftRelay.recovery.changed.connect(update_recovery_menu)
	RiftAudio.play_music(false)
	menu = RiftTitleMenu.new()
	menu.account = account
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
	menu.profile_reset_requested.connect(reset_player_profile)
	menu.cloud_save_requested.connect(restore_cloud_and_play)
	menu.online_setup_finished.connect(complete_online_setup)
	menu.username_changed.connect(persist_username)
	menu.finish_purchase_requested.connect(purchase_finish)
	if progress_reset_error != OK:
		menu.show_page("Save Reset Error")
		return
	if account and not get_tree().has_meta(&"startup_choice_confirmed") and checkpoint_path == SAVE_PATH:
		menu.show_page("Set up Player Profile")
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
	var save := read_checkpoint()
	if save:
		coop_mission.starting_xp = clampi(int(save.get_value("checkpoint", "experience", 0)), 0, 1000000)
		var saved_weapons: Variant = save.get_value("checkpoint", "weapons", [])
		if saved_weapons is Array:
			coop_mission.starting_weapons = saved_weapons
		coop_mission.starting_suit = String(save.get_value("checkpoint", "equipped", ""))
	coop_mission.rewards_earned.connect(bank_coop_rewards)
	coop_mission.operator_wiped.connect(reset_defeated_run)
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
	var recovered: Dictionary = results.get("recovered", {}).duplicate()
	profile.apply_recovery_crew(number, recovered)
	profile.deposit_materials(recovered)
	var supplies: Dictionary = results.get("supplies", {}).duplicate()
	var packs := int(profile.apply_resupply_contract(supplies))
	profile.deposit_supplies(supplies)
	coop_mission.profile_xp_progress = award_profile_clear(number, RiftRelay.mission_mode, coop_mission.sector_seconds, int(results.get("kills", 0)), true)
	profile.credits += bolts
	var shards := int(profile.talent_bonus("shard_reclaimer"))
	profile.core_shards += shards
	coop_mission.extracted_results["talent_shards"] = shards
	coop_mission.extracted_results["talent_packs"] = packs
	profile.unlock_sector(mini(number + 1, Catalog.SECTORS.size()))
	if number <= Story.MEMORIES.size() and not profile.memories.has(number):
		profile.memories.append(number)
	if number == Catalog.SECTORS.size():
		var ending := "secret" if Story.has_all_memories(profile.memories) else "standard"
		if not profile.endings.has(ending):
			profile.endings.append(ending)
	for id in blueprints:
		profile.collect_blueprint(id)
	var operator_level := RiftPlayer.level_for_experience(xp)
	var hunt: String = profile.advance_blueprint_hunt(number, RiftRelay.mission_mode, operator_level)
	if not hunt.is_empty():
		coop_mission.extracted_results["hunt_award"] = profile.GEAR[hunt].name
	coop_mission.extracted_results["talent_blueprints"] = profile.award_archive_mastery(number, RiftRelay.mission_mode, operator_level)
	profile.operator_level = operator_level
	var save := read_checkpoint()
	if save == null:
		save = ConfigFile.new()
	var old_sector := int(save.get_value("checkpoint", "sector", 1))
	var cleared := maxi(number, int(save.get_value("checkpoint", "run_cleared_through", old_sector - 1)))
	if old_sector <= number:
		var module_id: String = save.get_value("checkpoint", "module", "")
		save = ConfigFile.new()
		save.set_value("checkpoint", "sector", mini(cleared + 1, Catalog.SECTORS.size()))
		save.set_value("checkpoint", "act", 2 if cleared >= Catalog.SECTORS.size() else 1)
		save.set_value("checkpoint", "difficulty", RiftRelay.mission_mode)
		save.set_value("checkpoint", "module", module_id)
		save.set_value("checkpoint", "at_start", true)
		save.set_value("checkpoint", "lives", 3)
	save.set_value("checkpoint", "run_cleared_through", cleared)
	save.set_value("checkpoint", "experience", xp)
	save.set_value("checkpoint", "weapons", results.get("weapons", []))
	save.set_value("checkpoint", "equipped", results.get("equipped", ""))
	var error := write_checkpoint(save)
	if error != OK:
		push_warning("Could not save the next co-op deployment: %s" % error_string(error))
	elif save_session and persist_operator_save() != OK:
		push_warning("Could not save the co-op extraction rewards to disk.")

func close_coop_mission(message: String) -> void:
	if not is_instance_valid(coop_mission):
		return
	profile.finish_field_supplies({}, false)
	if coop_mission.outcome.is_empty() and coop_mission.operators[coop_mission.local_index].lives <= 0:
		coop_mission.keep_recovered_blueprints(coop_mission.recovered_blueprint_ids(coop_mission.local_index))
		reset_defeated_run()
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

func show_party_rejoin() -> void:
	if is_instance_valid(home_hub) and is_instance_valid(menu):
		home_hub.station_requested.emit("Social")
		menu.show_page("Party")

func update_recovery_menu() -> void:
	var recovery := RiftRelay.recovery
	if not is_instance_valid(coop_mission) or not recovery.active():
		if is_instance_valid(recovery_menu):
			recovery_menu.hide()
			recovery_menu.queue_free()
			recovery_menu = null
			get_tree().paused = false
		return
	if not is_instance_valid(recovery_menu):
		if chat.is_open():
			chat.close()
		if is_instance_valid(coop_mission.pause_menu) and coop_mission.pause_menu.is_open():
			coop_mission.pause_menu.close()
		get_tree().paused = true
		recovery_menu = CanvasLayer.new()
		recovery_menu.layer = 195
		recovery_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(recovery_menu)
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.015, 0.035, 0.075, 0.78)
		recovery_menu.add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var center := CenterContainer.new()
		backdrop.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var panel := UI.equipment_card(UI.CYAN)
		panel.theme = UI.theme()
		panel.custom_minimum_size.x = 490
		center.add_child(panel)
		var content := UI.column(panel, 12)
		UI.label(content, "CONNECTION INTERRUPTED", 30, UI.CYAN)
		recovery_label = UI.label(content, "", 19)
		recovery_button = UI.button(content, "Rejoin Party", RiftRelay.rejoin_party, true)
		UI.button(content, "Return to Station", RiftRelay.leave.bind("You left the interrupted mission."))
		var clock := Timer.new()
		clock.wait_time = 0.25
		clock.timeout.connect(refresh_recovery_menu)
		recovery_menu.add_child(clock)
		clock.start()
		refresh_recovery_menu()
		if recovery_button.visible:
			recovery_button.grab_focus()
		else:
			(content.get_child(-1) as Button).grab_focus()
	refresh_recovery_menu()

func refresh_recovery_menu() -> void:
	var recovery := RiftRelay.recovery
	if not is_instance_valid(recovery_menu) or not recovery.active():
		return
	var disconnected := RiftRelay.connected_room.is_empty()
	recovery_button.visible = disconnected
	recovery_button.disabled = recovery.retrying
	var message := "Waiting for the party to reconnect."
	if disconnected:
		message = "Reconnecting to your party…" if recovery.retrying else "Rejoin to continue from where you disconnected."
	recovery_label.text = "%s\nMission paused · %d seconds remaining" % [message, recovery.remaining_seconds()]

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
	menu.at_sector_start = false
	menu.run_unlocks = []
	if save:
		menu.saved_sector = clampi(int(save.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
		profile.unlock_sector(menu.saved_sector)
		menu.saved_act = clampi(int(save.get_value("checkpoint", "act", 1)), 1, 2)
		menu.saved_difficulty = profile.available_difficulty(menu.saved_sector, int(save.get_value("checkpoint", "difficulty", Difficulty.NORMAL)))
		menu.saved_experience = clampi(int(save.get_value("checkpoint", "experience", 0)), 0, 1000000)
		menu.saved_level = RiftPlayer.level_for_experience(menu.saved_experience)
		menu.at_sector_start = bool(save.get_value("checkpoint", "at_start", false))
		menu.run_unlocks = save.get_value("checkpoint", "weapons", [])
	profile.operator_level = menu.saved_level

func complete_online_setup() -> void:
	if menu.checking_cloud_save:
		return
	var newly_signed_in := account.display_name.is_empty()
	if newly_signed_in and account.create(RiftRelay.directory.username) != OK:
		menu.show_page("Set up Player Profile")
		return
	RiftSettings.confirm_startup_choice("online")
	get_tree().set_meta(&"startup_choice_confirmed", true)
	menu.checking_cloud_save = true
	menu.open_slot_picker("Load Game")
	var cloud = RiftRelay.directory.progress
	await cloud.sync(false, true)
	if not is_instance_valid(menu):
		return
	if newly_signed_in and not cloud.remote.is_empty() and cloud.conflict:
		var result: Dictionary = await cloud.restore_cloud()
		if not is_instance_valid(menu):
			return
		if result.get("error") == OK:
			account.restore()
	menu.checking_cloud_save = false
	if cloud.conflict:
		menu.show_page("Saves")
		return
	menu.open_slot_picker("Load Game")

func purchase_finish(id: String) -> void:
	var catalog := preload("res://scripts/operator_skins.gd")
	if not save_session or not menu.station_panel or not catalog.STORE.has(id) or account.unlocked_skins.has(id):
		return
	var cost: int = catalog.STORE[id][3]
	if profile.credits < cost:
		return
	profile.credits -= cost
	if persist_operator_save() != OK:
		profile.credits += cost
		menu.inventory_status = "Could not save the purchase."
	else:
		account.unlocked_skins.append(id)
		if account.save() != OK:
			account.unlocked_skins.erase(id)
			profile.credits += cost
			var refund := persist_operator_save()
			menu.inventory_status = "Could not save the finish. Bolts refunded." if refund == OK else "Purchase interrupted. Save your operator to persist the refund."
		else:
			menu.inventory_status = "Unlocked %s for this profile." % catalog.label(id)
			if is_instance_valid(home_hub):
				home_hub.set_bank(profile.credits, profile.core_shards, profile.player_level())
	menu.show_page("Cosmetics")

func current_armor_finish() -> String:
	return account.display_skin(save_session.slot) if account and save_session else ""

func persist_username() -> void:
	RiftRelay.local_name = RiftRelay.directory.username
	if RiftRelay.directory.online() and not RiftRelay.connected_room.is_empty():
		RiftRelay.relay.player_set_data("operator_name", RiftRelay.local_name)

func restore_cloud_and_play() -> void:
	if is_instance_valid(home_hub) or is_instance_valid(coop_mission):
		return
	var result: Dictionary = await RiftRelay.directory.progress.restore_cloud()
	if result.get("error") != OK:
		return
	get_tree().remove_meta(&"riftcore_save_session")
	save_session = null
	account = PlayerAccount.new()
	account.restore()
	menu.account = account
	refresh_menu_save()
	menu.open_slot_picker("Load Game")

func select_save_slot(number: int, fresh: bool, operator_name := "") -> void:
	var selected := ManualSave.new(number)
	if progress_reset_error != OK:
		return
	if not fresh and not selected.load_slot():
		menu.show_slot_error()
		return
	if is_instance_valid(home_hub):
		if save_session and save_session.slot == number and not fresh:
			menu.hide()
			close_station_panel()
			return
		if save_session and write_manual_save() != OK:
			menu.slot_error = "Could not save your active operator before switching."
			menu.show_page("Operators")
			return
		remove_home_hub()
	save_session = selected
	profile = selected.profile
	if account:
		profile.player_xp = account.experience
	if account and not account.display_name.is_empty():
		profile.operator_name = account.display_name
	elif fresh:
		profile.operator_name = profile.clean_operator_name(operator_name)
	RiftSettings.remember_operator_name(profile.operator_name)
	get_tree().set_meta(&"riftcore_save_session", selected)
	var saved_exists := ManualSave.read_slot(number) != null
	if (not fresh or (not saved_exists and selected.save_slot() == OK)) and account:
		account.last_operator = number
		account.save()
	open_home_hub()
	if fresh:
		home_hub.materialize_operator("arrival")

func reset_player_profile() -> void:
	if not account or account.display_name.is_empty() or is_instance_valid(coop_mission):
		return
	if RiftRelay.directory.linked:
		if not RiftRelay.directory.online():
			menu.show_save_result("Sign in to reset the cloud copy along with the local profile.")
			return
		var result: int = await RiftRelay.directory.progress.reset_cloud_progress()
		if result != OK:
			menu.show_save_result("Could not reset the cloud save. Your account and progress were kept.")
			return
	var error := account.remove_local_progress([SAVE_PATH, profile.path])
	if error != OK:
		menu.show_save_result("Could not delete the profile. " + error_string(error))
		return
	RiftRelay.leave()
	RiftRelay.directory.progress.reset()
	RiftSettings.remember_operator_name("")
	get_tree().remove_meta(&"riftcore_save_session")
	remove_home_hub()
	save_session = null
	profile = ManualSave.Profile.new()
	profile.manual_only = true
	account = PlayerAccount.new()
	menu.account = account
	menu.station_panel = false
	refresh_menu_save()
	if RiftRelay.directory.online():
		if account.create(RiftRelay.directory.username) == OK:
			menu.open_slot_picker("Load Game")
			return
	menu.show_page("Set up Player Profile")

func clear_deleted_operator(slot: int) -> void:
	if save_session and save_session.slot == slot:
		save_session = null
		profile = ManualSave.Profile.new()
		profile.manual_only = true
		if account:
			profile.player_xp = account.experience
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
	return persist_operator_save()

func persist_operator_save() -> Error:
	if not save_session:
		return ERR_UNCONFIGURED
	var error := save_session.save_slot()
	if error == OK and account and account.last_operator != save_session.slot:
		account.last_operator = save_session.slot
		account.save()
	return error

func manual_save_status(error: Error) -> String:
	if error == OK:
		var location := "Saved locally. Cloud backup queued." if RiftRelay.directory.online() else "Saved on this device."
		return "Operator %02d · %s" % [save_session.slot, location]
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
	var checkpoint := read_checkpoint()
	if checkpoint and checkpoint.has_section_key("checkpoint", "recovered_supplies"):
		var supplies: Dictionary = profile.finish_field_supplies(checkpoint.get_value("checkpoint", "recovered_supplies").duplicate(), true)
		checkpoint.set_value("checkpoint", "recovered_supplies", supplies)
	RiftRelay.local_name = RiftRelay.directory.username if RiftRelay.directory.online() else profile.operator_name
	if account:
		if RiftSettings.startup_mode == "online":
			RiftRelay.directory.configure.call_deferred(account.display_name)
	RiftRelay.publish_armor_finish(current_armor_finish())
	RiftRelay.unlocked_sector = profile.unlocked_sector
	RiftRelay.set_difficulty_unlocks(profile.normal_clears.keys(), profile.nightmare_unlocked())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(home_hub):
		return
	RiftSocial.connect_steam.call_deferred()
	refresh_menu_save()
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	home_hub = HOME_HUB.instantiate() as Node3D
	home_hub.profile = profile
	home_hub.initial_finish = current_armor_finish()
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
		if save_session and persist_operator_save() != OK:
			home_hub.set_panel_open(true)
			menu.process_mode = Node.PROCESS_MODE_INHERIT
			menu.open_station("Save Game")
			menu.show_save_result("Could not save your operator before returning to the title.")
			return
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
	if is_instance_valid(home_hub):
		home_hub.avatar.set_armor_finish(current_armor_finish())
		RiftRelay.publish_armor_finish(current_armor_finish())
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(home_hub):
		if save_session and save_session.owns_slot and menu.page in ["Shop", "Gear", "Storage", "Fabrication", "Upgrades", "Craft Item", "Learn Blueprint", "Blueprint Details"]:
			if persist_operator_save() != OK:
				push_warning("Could not save the station inventory change.")
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
	if number < 1 or number > profile.unlocked_sector:
		return
	var mode := Difficulty.index(selected_difficulty)
	if profile.available_difficulty(number, mode) != mode:
		return
	if not RiftRelay.connected_room.is_empty():
		RiftRelay.deploy(number, mode)
		return
	var save := read_checkpoint()
	if save == null:
		mission_difficulty = mode
		start_game(true, number)
		return
	var current := int(save.get_value("checkpoint", "sector", 1))
	var cleared := clampi(int(save.get_value("checkpoint", "run_cleared_through", current - 1)), 0, Catalog.SECTORS.size())
	if number != current or (mode != int(save.get_value("checkpoint", "difficulty", 0)) and bool(save.get_value("checkpoint", "at_start", false))):
		if number != current:
			for key in ["salvage", "blueprints", "recovered_supplies"]:
				if save.has_section_key("checkpoint", key):
					save.erase_section_key("checkpoint", key)
		save.set_value("checkpoint", "sector", number)
		save.set_value("checkpoint", "difficulty", mode)
		save.set_value("checkpoint", "act", 1)
		save.set_value("checkpoint", "run_cleared_through", cleared)
		save.set_value("checkpoint", "at_start", true)
		save.set_value("checkpoint", "sector_deaths", 0)
		save.set_value("checkpoint", "life_taken", false)
		for key in ["manual_combat_snapshot", "health", "energy", "equipped", "factory_caches", "factory_bridge_lowered", "interior_relays", "gate_relays"]:
			if save.has_section_key("checkpoint", key):
				save.erase_section_key("checkpoint", key)
		if write_checkpoint(save) != OK:
			menu.show_deploy_error()
			return
	load_game()

func start_game(play_intro := true, first_sector := 1) -> void:
	if is_instance_valid(game_root):
		return
	if play_intro:
		profile.finish_field_supplies({}, false)
		sector = first_sector
		run_cleared_through = 0
		act = 1
		sector_deaths = 0
		run_weapons.clear()
		run_module = ""
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
	await play_deployment_briefing()
	factory_hud.announce("ACT 2" if act == 2 else "START", Color("71efff"))
	if act == 1:
		RiftAudio.play_effect(&"voice_start")
	player.invulnerable_time = 0.5
	player.set_physics_process(true)
	deploying = false

func play_deployment_briefing() -> void:
	if DisplayServer.get_name() == "headless" or not profile.claim_briefing(sector, act):
		return
	player.invulnerable_time = maxf(player.invulnerable_time, 0.5)
	await play_story_lines(Story.deployment(sector, act), "Begin Act")

func play_story_lines(lines: Array, finish_label: String) -> void:
	var dialogue := StoryDialogue.new()
	game_root.add_child(dialogue)
	await dialogue.play(lines, finish_label)
	dialogue.queue_free()

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
	sector = clampi(int(save.get_value("checkpoint", "sector", 1)), 1, Catalog.SECTORS.size())
	mission_difficulty = profile.available_difficulty(sector, int(save.get_value("checkpoint", "difficulty", Difficulty.NORMAL)))
	run_cleared_through = clampi(int(save.get_value("checkpoint", "run_cleared_through", sector - 1)), 0, Catalog.SECTORS.size())
	act = clampi(int(save.get_value("checkpoint", "act", 1)), 1, 2)
	var saved_lives := clampi(int(save.get_value("checkpoint", "lives", 3)), 1, 5)
	sector_deaths = maxi(0, int(save.get_value("checkpoint", "sector_deaths", 1 if saved_lives < 3 else 0)))
	if not ResourceLoader.exists(level_path(act)):
		push_warning("The saved sector scene is unavailable.")
		return
	profile.unlock_sector(sector)
	run_weapons.clear()
	var module_id := String(save.get_value("checkpoint", "module", ""))
	run_module = module_id if FoundryModule.MODULES.has(module_id) else ""
	var legacy_weapons: Array = []
	for prior in range(1, sector):
		legacy_weapons.append(Catalog.info(prior).reward)
	var weapons = save.get_value("checkpoint", "weapons", legacy_weapons)
	if weapons is Array:
		for weapon in weapons:
			if not Catalog.weapon(String(weapon)).is_empty():
				run_weapons[String(weapon)] = true
	start_game(false)
	gate_relays.set_active(int(save.get_value("checkpoint", "gate_relays", 0)))
	factory_hud.set_gate_relays(gate_relays.count())
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
	player.recovered_supplies = save.get_value("checkpoint", "recovered_supplies", {}).duplicate()
	player.phoenix_spent = bool(save.get_value("checkpoint", "phoenix_spent", false))
	var restored_relays: Array = save.get_value("checkpoint", "interior_relays", [])
	for relay in get_tree().get_nodes_in_group(&"factory_shot_relay"):
		if not game_root.is_ancestor_of(relay):
			continue
		var path := String(game_root.get_path_to(relay))
		var legacy_bridge := path == "TERRAIN/DropBridgeRelay" and bool(save.get_value("checkpoint", "factory_bridge_lowered", false))
		if path in restored_relays or legacy_bridge:
			relay.restore_bridge()
	player.set_meta("factory_caches", save.get_value("checkpoint", "factory_caches", []))
	for chest_name in player.get_meta("factory_caches"):
		var chest := game_root.get_node_or_null(NodePath("TERRAIN/" + String(chest_name)))
		if chest and chest.is_in_group(&"factory_salvage_chest"):
			chest.queue_free()
	mission_stats = {"seconds": 0.0, "kills": 0, "operator_xp": 0, "player_xp": 0, "shards": 0}
	mission_stats.merge(save.get_value("checkpoint", "mission_stats", {}), true)
	factory_hud.set_run_time(mission_stats.seconds)
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
	if not game_root.has_node(CHECKPOINT_STATIONS.get(checkpoint_station, "TERRAIN/UnknownCheckpoint")):
		checkpoint_station = "midpoint"
	var checkpoint = game_root.get_node(CHECKPOINT_STATIONS[checkpoint_station])
	for station in CHECKPOINT_ORDER.slice(0, CHECKPOINT_ORDER.find(checkpoint_station)):
		var previous := game_root.get_node_or_null(CHECKPOINT_STATIONS[station])
		if previous:
			previous.online = true
	checkpoint.online = true
	checkpoint_reached = true
	checkpoint_spawn = checkpoint.global_position + Vector3.UP * 0.95
	var saved_spawn = save.get_value("checkpoint", "spawn", checkpoint_spawn)
	if not game_root.has_meta("interior_layout") and saved_spawn is Vector3 and saved_spawn.distance_to(checkpoint_spawn) < 3.0:
		checkpoint_spawn = saved_spawn
	player.global_position = checkpoint_spawn
	camera_rig.global_position.x = checkpoint_spawn.x

func build_pause_menu() -> void:
	var stack := overlay()
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	stack.add_child(layout)
	stack = UI.column(layout, 8)
	stack.custom_minimum_size.x = 176
	var readout := PauseOperator.new()
	readout.operator = func(): return player
	readout.profile = profile
	layout.add_child(readout)
	pause_menu.sections = readout.sections
	UI.label(stack, "PAUSED", 36, UI.CYAN)
	UI.label(stack, "%s / Act %d" % [Catalog.info(sector).title, act], 17, UI.MUTED)
	if controller_disconnected:
		UI.label(stack, "Controller disconnected", 17, UI.VIOLET)
	pause_menu.first_focus = UI.button(stack, "Resume", toggle_pause, true)
	pause_menu.first_focus.grab_focus()
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
		panel.offset_left = 88
		panel.offset_right = -88
		panel.offset_top = 38
		panel.offset_bottom = -38
	return UI.column(panel, 9)

func show_pause_settings() -> void:
	var stack := overlay(false, true)
	pause_menu.back_action = build_pause_menu
	UI.label(stack, "SETTINGS", 32, UI.CYAN)
	var settings := UI.settings(stack)
	UI.button(stack, "Back to pause", build_pause_menu)
	pause_menu.first_focus = settings.initial_focus
	settings.initial_focus.grab_focus()

func build_level() -> void:
	var stage := load(level_path(act)) as PackedScene
	game_root = stage.instantiate()
	add_child(game_root)
	player = game_root.get_node("Actors/RiftcoreMecha") as RiftPlayer
	var actors_root := game_root.get_node("Actors")
	actors_root.set_meta("loot_scale", Difficulty.LOOT[mission_difficulty])
	var combat_scale := Difficulty.combat_scale(sector, mission_difficulty)
	actors_root.set_meta("opponent_health_scale", combat_scale)
	actors_root.set_meta("mission_difficulty", mission_difficulty)
	player.set_armor_finish(current_armor_finish())
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
		enemy.scale_for_sector(sector, act, combat_scale, mission_difficulty)
		enemy.operator_at_deploy = player
		enemy.died.connect(_enemy_defeated)
		remaining_enemies += 1
	camera_rig = game_root.get_node("CameraRig") as SideCameraRig
	camera_rig.target = player
	var bounds := game_root.get_node("MARKERS/CameraBounds")
	camera_rig.min_x = bounds.get_meta("min_x")
	camera_rig.max_x = bounds.get_meta("max_x")
	boss = game_root.get_node("Actors/" + Catalog.info(sector).boss_node) as Combatant
	gate = game_root.get_node("Gate") as Node3D
	arena_door = CampaignDoor.new(gate)
	arena_door.reset()
	gate_relays = GateRelays.new()
	gate_relays.install(game_root, Color(Catalog.info(sector).color), sector != 2)
	boss_spawn = boss.position
	if act == 1:
		var actors := boss.get_parent()
		actors.remove_child(boss)
		boss.queue_free()
		boss = create_miniboss()
		actors.add_child(boss)
	boss.apply_boss_scaling(sector, mission_difficulty, act)
	boss.hide()
	build_hud()
	for station in CHECKPOINT_STATIONS:
		var checkpoint := game_root.get_node_or_null(CHECKPOINT_STATIONS[station])
		if checkpoint:
			checkpoint.activated.connect(_on_checkpoint_activated.bind(station))
	repair_hall = game_root.get_node("ForgeHallDoor")
	repair_hall.operators = [player]
	repair_hall.motor.reset()
	bind_boss_signals()
	for chest in get_tree().get_nodes_in_group(&"factory_salvage_chest"):
		if game_root.is_ancestor_of(chest):
			chest.difficulty = mission_difficulty
	install_sector_pads()
	SectorDetails.new().install(game_root, player, sector, act)

func create_miniboss() -> Combatant:
	var info := Catalog.info(sector)
	var exit := game_root.get_node("ExitBarrier") as Node3D
	var guard := Miniboss.for_sector(sector, Color(info.color), info.weak, gate.global_position, exit.global_position.x)
	guard.name = "SectorMiniboss"
	guard.position = Vector3(boss_spawn.x, gate.position.y + guard.chassis_height, 0.0)
	return guard

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
	player.run_module = run_module
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
		var defeat_xp := (35 if act == 1 else 80) + sector * 8
		player.gain_experience(roundi(defeat_xp * player.xp_gain_multiplier))
		var shards := 1 + sector + (3 if act == 2 else 0)
		profile.core_shards += shards
		factory_hud.core_shards = profile.core_shards
		mission_stats.shards += shards
		var actors := game_root.get_node("Actors") as Node3D
		if act == 2:
			var cache := BossCache.new()
			cache.position = actors.to_local(Vector3(boss_spawn.x, gate.global_position.y + 0.52, 0.0))
			actors.add_child.call_deferred(cache)
			cache.opened.connect(func(): BossCache.spill(actors, cache.global_position, BossCache.roll_loot(sector, mission_difficulty, player.level_for_experience(player.experience))))
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
		factory_hud.exit_task = Story.objective(sector, act, true, Miniboss.TITLES[sector - 1])
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
	factory_hud.exit_task = Story.objective(sector, act, false, Miniboss.TITLES[sector - 1])
	factory_hud.set_gate_relays(gate_relays.count())
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
	player.bolts_picked_up.connect(func(amount: int): factory_hud.show_loot({}, "", "", amount))
	player.experience_changed.connect(factory_hud.set_experience)
	player.blueprint_found.connect(func(id: String): factory_hud.show_loot({}, id, ""))
	player.supply_found.connect(func(id: String): factory_hud.show_loot({}, "", id))
	player.salvage_collected.connect(func(drop: Dictionary): factory_hud.show_loot(drop, "", ""))
	player.experience_earned.connect(func(amount: int):
		mission_stats.operator_xp += amount
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
		factory_hud.show_loot({}, "", "", 0, true)
		if checkpoint_reached:
			save_checkpoint()
	)

func _on_checkpoint_activated(spawn: Vector3, station := "midpoint") -> void:
	if checkpoint_reached and CHECKPOINT_ORDER.find(station) < CHECKPOINT_ORDER.find(checkpoint_station):
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
	save.set_value("checkpoint", "module", run_module)
	save.set_value("checkpoint", "at_start", not checkpoint_reached)
	save.set_value("checkpoint", "spawn", checkpoint_spawn)
	save.set_value("checkpoint", "station", checkpoint_station)
	save.set_value("checkpoint", "experience", int(player.experience))
	save.set_value("checkpoint", "credits", player.credits)
	save.set_value("checkpoint", "salvage", player.salvage)
	save.set_value("checkpoint", "blueprints", player.recovered_blueprints)
	save.set_value("checkpoint", "recovered_supplies", player.recovered_supplies.duplicate())
	save.set_value("checkpoint", "mission_stats", mission_stats)
	save.set_value("checkpoint", "lives", player.lives)
	save.set_value("checkpoint", "sector_deaths", sector_deaths)
	save.set_value("checkpoint", "life_taken", life_taken)
	save.set_value("checkpoint", "phoenix_spent", player.phoenix_spent)
	save.set_value("checkpoint", "factory_caches", player.get_meta("factory_caches", []))
	var active_relays: Array[String] = []
	for relay in get_tree().get_nodes_in_group(&"factory_shot_relay"):
		if game_root.is_ancestor_of(relay) and relay.triggered and not relay.lift:
			active_relays.append(String(game_root.get_path_to(relay)))
	save.set_value("checkpoint", "interior_relays", active_relays)
	save.set_value("checkpoint", "gate_relays", gate_relays.active)
	if manual_combat_snapshot:
		save.set_value("checkpoint", "manual_combat_snapshot", true)
		save.set_value("checkpoint", "health", player.health)
		save.set_value("checkpoint", "energy", player.energy)
		save.set_value("checkpoint", "equipped", player.equipped_suit())
	var error := write_checkpoint(save)
	if error != OK:
		push_warning("Could not save Riftcore checkpoint: %s" % error_string(error))

func award_profile_clear(number: int, difficulty: int, seconds := 0.0, kills := 0, online := false) -> Dictionary:
	profile.survival_seconds += maxf(0.0, seconds)
	if account:
		var progress := account.award_clear(number, difficulty, {
			"seconds": seconds, "kills": kills, "online": online,
			"operator": profile.operator_name, "survival": profile.survival_seconds})
		profile.player_xp = account.experience
		return progress
	var before: int = profile.player_xp
	profile.award_player_xp(PlayerAccount.clear_reward(number, difficulty))
	return {"before": before, "after": profile.player_xp}

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
	for boulder in get_tree().get_nodes_in_group(&"foundry_boulder"):
		if game_root.is_ancestor_of(boulder):
			boulder.reset_runway()
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
	player.clear_boss_debuff()
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
	profile.finish_field_supplies(player.recovered_supplies, false)
	bank_run_credits()
	reset_defeated_run()

func reset_defeated_run() -> void:
	var elapsed: float = coop_mission.sector_seconds if is_instance_valid(coop_mission) else float(mission_stats.seconds)
	if account and account.track_survival(profile.survival_seconds + elapsed, profile.operator_name):
		if account.save() != OK:
			push_warning("Could not save the Operator survival record.")
	profile.survival_seconds = 0.0
	profile.operator_level = 1
	clear_checkpoint()
	if save_session:
		var error := save_session.invalidate_defeated_run()
		if error != OK:
			push_warning("Could not invalidate the defeated run on disk: %s" % error_string(error))
	else:
		profile.lose_equipped_gear()
	run_cleared_through = 0
	run_weapons.clear()
	run_module = ""

func reset_boss_room() -> void:
	RiftAudio.play_music(true, sector)
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
	boss.apply_boss_scaling(sector, mission_difficulty, act)
	boss.hide()
	bind_boss_signals()
	gate_open = false
	arena_sealed = false
	arena_door.reset()
	repair_hall.hold = 0.0
	repair_hall.motor.reset()
	factory_hud.boss_visible = false
	factory_hud.update_boss_mechanic(null)
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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(gate):
		return
	arena_door.step(delta, gate_open and (not arena_sealed or boss_defeated), [player])
	if deploying or advancing_act or arena_intro or suit_reveal_active or sector_complete or respawning:
		return
	if not gate_open and gate_relays.complete() and arena_door.near(player):
		open_factory_gate()
	if gate_open and arena_door.passable and not arena_sealed and not boss_defeated and is_instance_valid(boss):
		var exit := game_root.get_node("MARKERS/RoomExit") as Marker3D
		if arena_door.inside(player, exit.global_position.x):
			seal_arena()

func _process(delta: float) -> void:
	if deploying or advancing_act or arena_intro or suit_reveal_active or sector_complete or not is_instance_valid(player) or player.health <= 0.0:
		return
	mission_stats.seconds += delta
	factory_hud.set_run_time(mission_stats.seconds)
	gate_relays.update_prompt(player, arena_door.near(player))
	if factory_hud.boss_visible:
		factory_hud.update_boss_mechanic(boss)
	factory_hud.set_status_effects(player.supplies, player.boss_debuff, player.debuff_left)
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
	var profile_progress := award_profile_clear(sector, mission_difficulty, mission_stats.seconds, mission_stats.kills)
	mission_stats.player_xp = int(profile_progress.after) - int(profile_progress.before)
	mission_stats.profile_progress = profile_progress
	var replay := sector <= run_cleared_through
	run_cleared_through = maxi(run_cleared_through, sector)
	var bonus := 160 + 25 * (sector - 1)
	var hard_unlocked: bool = profile.record_sector_clear(sector, mission_difficulty)
	var recovered := player.salvage.duplicate()
	profile.apply_recovery_crew(sector, recovered)
	var recovered_blueprints: Array[String] = []
	for id in player.recovered_blueprints:
		if profile.collect_blueprint(id):
			recovered_blueprints.append(profile.GEAR[id].name)
	var hunt: String = profile.advance_blueprint_hunt(sector, mission_difficulty, RiftPlayer.level_for_experience(player.experience))
	if not hunt.is_empty():
		recovered_blueprints.append(profile.GEAR[hunt].name)
	recovered_blueprints.append_array(profile.award_archive_mastery(sector, mission_difficulty, RiftPlayer.level_for_experience(player.experience)))
	profile.deposit_materials(recovered)
	var recovered_supplies: Dictionary = profile.finish_field_supplies(player.recovered_supplies, true)
	profile.apply_resupply_contract(recovered_supplies)
	profile.deposit_supplies(recovered_supplies)
	player.salvage.clear()
	player.recovered_blueprints.clear()
	var shards := 4 + sector + int(profile.talent_bonus("shard_reclaimer"))
	profile.core_shards += shards
	mission_stats.shards += shards
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
		continuation.set_value("checkpoint", "module", run_module)
		continuation.set_value("checkpoint", "equipped", player.equipped_suit())
		continuation.set_value("checkpoint", "at_start", true)
		continuation.set_value("checkpoint", "experience", int(player.experience))
		continuation.set_value("checkpoint", "lives", player.lives if replay else 3)
		continuation.set_value("checkpoint", "sector_deaths", sector_deaths if final_sector else 0)
		var error := write_checkpoint(continuation)
		if error != OK:
			push_warning("Could not save the next sector deployment: %s" % error_string(error))
	var ending := ""
	var extraction_dialogue: Array = Story.hard_unlock(sector) if hard_unlocked else []
	if final_sector:
		var recovered_all := Story.has_all_memories(profile.memories)
		var ending_id := "secret" if recovered_all else "standard"
		if not profile.endings.has(ending_id):
			profile.endings.append(ending_id)
			profile.save()
		ending = Story.ending(recovered_all)
		extraction_dialogue.append_array(Story.ending_exchange(recovered_all))
	if save_session and persist_operator_save() != OK:
		push_warning("Could not save the extraction rewards to disk.")
	if not extraction_dialogue.is_empty() and DisplayServer.get_name() != "headless":
		player.invulnerable_time = maxf(player.invulnerable_time, 0.5)
		player.set_physics_process(false)
		await play_story_lines(extraction_dialogue, "View Results")
	get_tree().paused = true
	var stack := overlay()
	stack.get_parent().custom_minimum_size.x = 1050
	preload("res://scripts/mission_complete.gd").build(
		stack, Catalog.info(sector).title, mission_stats, recovered, recovered_blueprints, recovered_supplies,
		player.credits + bonus + int(reward.get("credits", 0)), int(reward.get("lives", 0)), sector_deaths,
		ending, return_to_command_deck
	)

func advance_to_act_two() -> void:
	player.cancel_charge()
	player.set_physics_process(false)
	if sector == 1 and run_module.is_empty():
		if DisplayServer.get_name() == "headless":
			run_module = "prism"
		else:
			var chooser := FoundryModule.new()
			add_child(chooser)
			chooser.choose()
			run_module = await chooser.selected
			chooser.queue_free()
		player.run_module = run_module
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
	save.set_value("checkpoint", "module", run_module)
	save.set_value("checkpoint", "experience", player.experience)
	save.set_value("checkpoint", "credits", player.credits)
	save.set_value("checkpoint", "salvage", player.salvage)
	save.set_value("checkpoint", "blueprints", player.recovered_blueprints)
	save.set_value("checkpoint", "recovered_supplies", player.recovered_supplies.duplicate())
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
	await play_deployment_briefing()
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

func seal_arena() -> void:
	arena_sealed = true
	arena_intro = true
	play_arena_intro()

func play_arena_intro() -> void:
	RiftAudio.play_boss_music()
	var intro_boss := boss
	var intro_player := player
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
	if player != intro_player or boss != intro_boss:
		return
	player.play_character_animation("idle", true)
	var cinematic := preload("res://scripts/boss_intro.gd").new()
	intro_boss.add_child(cinematic)
	await cinematic.play(camera_rig, boss, gate.global_position.y, factory_hud.boss_name, Color(Catalog.info(sector).color), sector, act, factory_hud)
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
	if chat.is_open():
		if event.is_action_pressed("ui_cancel") or (not event is InputEventMouseButton and event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			chat.close()
		return
	if event is InputEventKey and event.pressed and not event.echo and can_open_chat() and (
			event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
		get_viewport().set_input_as_handled()
		chat.open()

func can_open_chat() -> bool:
	if get_tree().paused or get_tree().has_group(&"interactive_dialogue") or (is_instance_valid(menu) and menu.is_visible_in_tree()):
		return false
	if is_instance_valid(coop_mission):
		return coop_mission.can_open_chat()
	if is_instance_valid(home_hub):
		return not home_hub.panel_open and not home_hub.reconstructing and not home_hub.has_dialogue()
	return is_instance_valid(player) and player.visible and not deploying and not advancing_act and not arena_intro and not suit_reveal_active and not sector_complete and not respawning

func set_chat_open(open: bool) -> void:
	if not open:
		for action in RiftSettings.ACTIONS.keys() + ["crouch_stick", "quick_0", "quick_1", "quick_2", "quick_3"]:
			if action != "push_to_talk":
				Input.action_release(action)
	if is_instance_valid(coop_mission):
		coop_mission.set_chat_open(open)
	elif is_instance_valid(home_hub):
		home_hub.set_chat_open(open)
	elif is_instance_valid(player):
		player.set_controls_suspended(open)

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
	if event.is_action_pressed("field_interact") and is_instance_valid(gate_relays) and can_open_chat() and not chat.is_open():
		var before := gate_relays.active
		if gate_relays.interact(player, arena_door.near(player)):
			if before != gate_relays.active:
				factory_hud.set_gate_relays(gate_relays.count())
				save_checkpoint()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") and game_root and not deploying and not sector_complete and not advancing_act and not arena_intro and not suit_reveal_active and player.visible:
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
	profile.finish_field_supplies(player.recovered_supplies, false)
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
	profile.finish_field_supplies(player.recovered_supplies, false)
	bank_run_credits()
	get_tree().paused = false
	get_tree().set_meta(&"open_command_deck", true)
	get_tree().reload_current_scene()
