extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func check(passed: bool, message: String) -> bool:
	print("PASS " if passed else "FAIL ", message)
	failures += int(not passed)
	return passed

func control(parent: Node, caption: String) -> Button:
	for button in parent.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree():
			return button
	return null

func choose(parent: Node, caption: String) -> bool:
	var button := control(parent, caption)
	if not check(is_instance_valid(button), "%s is available" % caption):
		return false
	button.pressed.emit()
	await frames(2)
	return true

func open_station(hub, x: float) -> void:
	hub.avatar.position.x = x
	hub.update_station()
	hub.activate_station()
	await frames(2)

func run() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.profile.manual_only = true
	root.add_child(game)
	current_scene = game
	root.get_node("RiftSettings").show_hub_tips = false
	game.open_home_hub()
	await frames(15)
	var hub = game.home_hub
	var menu = game.menu
	check(hub.pads.size() == 8 and hub.prompt.visible and hub.current_station == 3, "Hub opens at the Deploy bay")
	check(hub.get_node("OperationsBanner/Geometry").get_child_count() > 4, "Modular signage builds")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	Input.action_press("move_right")
	for index in 70:
		await frames(1)
		if hub.avatar.position.x >= 4.18:
			break
	Input.action_release("move_right")
	await frames(5)
	check(hub.current_station == 4 and hub.pads[4].beam.visible and hub.station_notice.text.contains("OPERATOR"), "Walking onto Operator lights the correct pad")
	hub.activate_station()
	await frames(2)
	check(menu.page == "Gear" and hub.panel_open, "Operator opens Gear from its pad")
	game.profile.inventory["patch_kit"] = 2
	if await choose(menu, "Storage"):
		check(menu.page == "Storage" and menu.find_children("*", "GridContainer", true, false).size() >= 2, "Inventory and Storage each have a grid")
		var carried: Button
		for button in menu.find_children("*", "Button", true, false):
			if button.get_meta(&"return_focus", "") == "inventory/patch_kit":
				carried = button
		if check(is_instance_valid(carried), "Carried patch kits have an Inventory tile"):
			carried.pressed.emit()
			if await choose(menu, "Stow Stack"):
				check(not game.profile.inventory.has("patch_kit") and game.profile.stored_supplies.get("patch_kit") == 2, "Stow Stack transfers both items")
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().size() > 1:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	menu.leave_page()
	check(not hub.panel_open and hub.current_station == 4, "Back returns to the Operator bay")
	await open_station(hub, -4.5)
	check(menu.page == "Shop" and is_instance_valid(control(menu, "Crafting")) and is_instance_valid(control(menu, "Core Ascension")), "Workshop groups its three actions")
	var shoulder := InputEventJoypadButton.new()
	shoulder.pressed = true
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	root.push_input(shoulder)
	await frames(2)
	check(menu.page == "Fabrication", "RB advances from Buy to Crafting")
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	root.push_input(shoulder)
	await frames(2)
	check(menu.page == "Shop", "LB returns to Buy")
	menu.leave_page()
	await open_station(hub, -18.0)
	check(menu.page == "Save Game" and is_instance_valid(control(menu, "Settings")), "System exposes saves and settings")
	menu.leave_page()
	await open_station(hub, -13.5)
	check(menu.page == "Player Profile" and is_instance_valid(control(menu, "Cosmetics")), "Profile exposes cosmetics")
	menu.leave_page()
	await open_station(hub, 9.0)
	check(menu.page == "Social" and is_instance_valid(control(menu, "Notifications")), "Social groups friends and notifications")
	quit(failures)
