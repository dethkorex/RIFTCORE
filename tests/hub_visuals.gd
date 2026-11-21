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
	hub.update_partner(17, hub.avatar.position.x, 0.0, "idle", "Partner")
	var partner_plate: Label3D = hub.partners[17].label
	check(hub.local_online_label.position == partner_plate.position and hub.local_online_label.font_size == partner_plate.font_size and hub.local_online_label.pixel_size == partner_plate.pixel_size, "Local and partner hub nameplates share head clearance and type size")
	hub.partners[17].actor.queue_free()
	hub.partners.erase(17)
	var menu = game.menu
	check(hub.pads.size() == 8 and hub.station_notice.visible and hub.current_station == 3, "Hub opens at the Deploy bay")
	for index in hub.pads.size():
		var pad: Dictionary = hub.pads[index]
		var ring := pad.beam.get_parent().get_node_or_null("StandingRing") as MeshInstance3D
		var occupied: bool = index == hub.current_station
		check(is_instance_valid(ring) and ring.mesh is TorusMesh and ring.is_visible_in_tree()
			and pad.beam.visible == occupied and pad.pulse.visible == occupied,
			"%s has a visible standing ring and the correct occupancy effects" % hub.STATIONS[index].name)
	var sign_model = hub.get_node("OperationsBanner/Geometry").find_child("Chassis", true, false)
	check(is_instance_valid(sign_model), "The wall sign uses its modeled housing")
	for station in hub.STATIONS:
		if station.prop != "service_kiosk":
			continue
		var kiosk: Node3D
		for child in hub.get_children():
			if child.scene_file_path == "res://assets/hub/service_kiosk.tscn" and is_equal_approx(child.position.x, station.x):
				kiosk = child
				break
		check(is_instance_valid(kiosk) and kiosk.caption == station.get("caption", station.name.to_upper())
				and kiosk.icon == station.icon and kiosk.accent == station.color
				and is_instance_valid(kiosk.find_child("LightGuides", true, false)),
				"%s shows its modeled kiosk, symbol and station color" % station.name)
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	hub.activate_station()
	await frames(2)
	check(menu.page == "Sector select" and hub.panel_open, "Deploy opens sector selection")
	menu.leave_page()
	await frames(2)
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
	menu.leave_page()
	await open_station(hub, 13.5)
	check(menu.page == "Challenges", "Challenges opens from the trophy kiosk")
	menu.leave_page()
	await open_station(hub, 18.0)
	check(menu.page == "Collection", "NOVA Archive opens the collection")
	menu.leave_page()
	game.queue_free()
	for voice in root.get_node("RiftAudio").find_children("*", "AudioStreamPlayer", true, false):
		voice.stop()
	await create_timer(0.4).timeout
	quit(failures)
