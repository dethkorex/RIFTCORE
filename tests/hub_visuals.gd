extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func check(passed: bool, message: String) -> void:
	print("PASS " if passed else "FAIL ", message)
	failures += int(not passed)

func run() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.open_home_hub()
	await frames(15)
	var hub = game.home_hub
	check(hub.pads.size() == 8 and hub.prompt.visible and hub.current_station == 3, "Hub opens at the Deploy bay")
	check(hub.get_node("OperationsBanner/Geometry").get_child_count() > 4, "Modular signage builds")
	check(hub.get_node("TraderBay/Geometry").get_child_count() > hub.get_node("SettingsTerminal/Geometry").get_child_count(), "Trader bay has its own fitted props")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	Input.action_press("move_right")
	for index in range(52):
		await frames(1)
		if hub.avatar.position.x >= 4.18:
			break
	Input.action_release("move_right")
	await frames(8)
	check(hub.current_station == 4 and hub.pads[4].beam.visible and hub.station_notice.text.contains("STORAGE"), "Walking onto Storage lights the correct pad")
	game.profile.gear["vital_weave"] = "stored"
	game.profile.gear["impact_liner"] = "stored"
	var interact := InputEventKey.new()
	interact.pressed = true
	interact.physical_keycode = KEY_E
	root.push_input(interact)
	await frames(3)
	check(game.menu.page == "Storage" and hub.panel_open, "Storage remains accessible from its pad")
	var grid := game.menu.find_children("*", "GridContainer", true, false)[0] as GridContainer
	check(grid.columns == 4 and grid.get_child_count() == 2, "Storage displays compact gear tiles")
	var indices := grid.get_children()
	indices[1].grab_focus()
	check(game.menu.focused_item == "vital_weave", "Focusing a tile selects its details")
	var action = game.menu.find_children("*", "Button", true, false).filter(func(button): return button.text == "Equip")[0]
	action.pressed.emit()
	await frames(2)
	check(game.profile.equipped_for("frame") == "vital_weave", "Storage equips selected gear")
	action = game.menu.find_children("*", "Button", true, false).filter(func(button): return button.text == "Stow")[0]
	action.pressed.emit()
	await frames(2)
	check(game.profile.gear.get("vital_weave") == "stored" and game.profile.stored_count() == 2, "Storage stows selected gear and updates capacity")
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().size() > 1:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	game.menu.leave_page()
	check(not hub.panel_open and hub.current_station == 4, "Back returns the player to the same bay")
	hub.station_requested.emit("Fabrication")
	await frames(2)
	check(game.menu.find_children("*", "Button", true, false).any(func(button): return button.text == "Core Enhancements"), "Workshop has its own enhancement tab")
	check(not game.menu.find_children("*", "Button", true, false).any(func(button): return button.text in ["Deploy", "Equipment", "Storage"]), "Other stations require their pads")
	var shoulder := InputEventJoypadButton.new()
	shoulder.pressed = true
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	root.push_input(shoulder)
	check(game.menu.page == "Upgrades", "RB switches Workshop to Core Enhancements")
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	root.push_input(shoulder)
	check(game.menu.page == "Fabrication", "LB switches Workshop back to Blueprints")
	game.menu.leave_page()
	hub.avatar.position.x = -12.0
	hub.update_station()
	root.push_input(interact)
	check(game.menu.page == "Save Game", "System pad opens Save Game")
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	root.push_input(shoulder)
	check(game.menu.page == "Settings", "System pad also opens Settings with RB")
	game.menu.leave_page()
	hub.avatar.position.x = 9.0
	hub.update_station()
	root.push_input(interact)
	check(game.menu.page == "Loadout", "Loadout still opens from its own pad")
	check(game.menu.find_children("*", "GridContainer", true, false).size() == 1, "Loadout uses the same gear tile grid")
	root.push_input(shoulder)
	check(game.menu.equipment_view == "Boss Abilities", "RB switches Loadout to Boss Abilities")
	root.push_input(shoulder)
	check(game.menu.equipment_view == "Presets", "RB switches Loadout to Presets")
	game.menu.leave_page()
	hub.avatar.position.x = -18.0
	hub.update_station()
	root.push_input(interact)
	check(game.menu.page == "Social", "Social opens from its own pad")
	check(game.menu.find_children("*", "Button", true, false).any(func(button): return button.text == "Open Steam Friends"), "Social links to Steam Friends")
	quit(failures)
