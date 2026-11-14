extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var relay := root.get_node("RiftRelay")
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var failures := 0
	failures += int(not check(root.get_node_or_null("GDSync") == null, "Offline title does not initialize GD Sync"))
	failures += int(not check(not game.menu.find_children("*", "Button", true, false).any(func(button): return button.text == "Online Room"), "Title has no Online Room entry"))
	game.open_home_hub()
	game.home_hub.station_requested.emit("Social")
	failures += int(not check(game.menu.relay_host.visible, "Room controls are available at the Social pad"))
	game.menu.relay_code.text = "bad!"
	game.menu.relay_join.pressed.emit()
	failures += int(not check(relay.status.begins_with("Enter the ten-character"), "Invalid join code is rejected locally"))
	failures += int(not check(relay.valid_code("7ZX3BAK2QF") and not relay.valid_code("7ZX3BAK2OI"), "Codes accept the unambiguous alphabet"))
	var keys := preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
	if not keys.has_keys():
		game.menu.relay_host.pressed.emit()
		failures += int(not check(relay.status.begins_with("Online rooms are unavailable"), "Missing keys produce a clear status"))
		failures += int(not check(root.get_node_or_null("GDSync") == null, "Unconfigured preview leaves the relay stopped"))
	game.menu.show_page("Co-op Setup Guide")
	failures += int(not check(game.menu.page == "Co-op Setup Guide", "Co-op guide is available from Social"))
	game.menu.leave_page()
	failures += int(not check(game.menu.page == "Social", "Guide returns to Social"))
	game.menu.leave_page()
	failures += int(not check(not game.menu.visible and relay.pending.is_empty(), "Back returns to the hub"))
	game.start_game(false)
	game.toggle_pause()
	game.show_pause_coop_setup()
	failures += int(not check(paused and not game.pause_menu.find_children("*", "Label", true, false).filter(
		func(label): return label.text == "CO-OP SETUP GUIDE").is_empty(), "Setup guide opens from the pause menu"))
	game.pause_menu.back_action.call()
	failures += int(not check(paused and not game.pause_menu.find_children("*", "Label", true, false).filter(
		func(label): return label.text == "PAUSED").is_empty(), "Guide returns to Pause"))
	paused = false
	quit(failures)

func check(passed: bool, message: String) -> bool:
	print("PASS " if passed else "FAIL ", message)
	return passed
