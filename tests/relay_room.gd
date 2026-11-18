extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func button(parent: Node, caption: String) -> Button:
	for control in parent.find_children("*", "Button", true, false):
		if control.text == caption and control.is_visible_in_tree():
			return control
	return null

func run() -> void:
	var relay := root.get_node("RiftRelay")
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var failures := 0
	failures += int(not check(root.get_node_or_null("GDSync") == null, "Offline title does not initialize GD Sync"))
	failures += int(not check(button(game.menu, "Online Room") == null, "Title has no Online Room entry"))
	root.get_node("RiftSettings").show_hub_tips = false
	game.open_home_hub()
	game.home_hub.activate_station()
	var group := button(game.menu, "Start a Group")
	failures += int(not check(is_instance_valid(group), "Deploy offers party management"))
	if not group:
		quit(failures)
		return
	group.pressed.emit()
	failures += int(not check(game.menu.page == "Party" and game.menu.relay_host.visible, "Party screen offers room controls"))
	relay.join_room("bad!")
	failures += int(not check(relay.status.begins_with("Enter the ten-character"), "Invalid join code is rejected locally"))
	failures += int(not check(relay.valid_code("7ZX3BAK2QF") and not relay.valid_code("7ZX3BAK2OI"), "Codes accept the unambiguous alphabet"))
	var keys := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
	if not keys.has_keys():
		failures += int(not check(game.menu.relay_host.disabled and game.menu.relay_join.disabled, "Missing keys disable room creation and joining"))
		relay.host_room()
		failures += int(not check(relay.status == relay.RELAY_UNAVAILABLE, "Missing keys produce a clear status"))
		failures += int(not check(root.get_node_or_null("GDSync") == null, "Unconfigured preview leaves the relay stopped"))
	game.menu.leave_page()
	failures += int(not check(game.menu.page == "Sector select", "Back returns from Party to Deploy"))
	game.menu.leave_page()
	failures += int(not check(not game.menu.visible and relay.pending.is_empty(), "Back returns to the hub"))
	game.start_game(false)
	game.toggle_pause()
	var settings := button(game.pause_menu, "Settings")
	failures += int(not check(paused and is_instance_valid(settings), "Pause offers Settings"))
	if settings:
		settings.pressed.emit()
		failures += int(not check(paused and is_instance_valid(game.pause_menu), "Settings keeps the game paused"))
		game.pause_menu.back_action.call()
		failures += int(not check(paused and button(game.pause_menu, "Settings") != null, "Settings returns to Pause"))
	paused = false
	quit(failures)

func check(passed: bool, message: String) -> bool:
	print("PASS " if passed else "FAIL ", message)
	return passed
