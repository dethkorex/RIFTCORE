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
	check(hub.pads.size() == 9 and hub.prompt.visible and hub.current_station == 4, "Hub opens at the Deploy bay")
	check(hub.get_node("OperationsBanner/Geometry").get_child_count() > 4, "Modular signage builds")
	check(hub.get_node("TraderBay/Geometry").get_child_count() > hub.get_node("SettingsTerminal/Geometry").get_child_count(), "Trader bay has its own fitted props")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	Input.action_press("move_right")
	await frames(43)
	Input.action_release("move_right")
	await frames(8)
	check(hub.current_station == 5 and hub.pads[5].beam.visible and hub.station_notice.text.contains("STORAGE"), "Walking onto Storage lights the correct pad")
	hub.station_requested.emit("Storage")
	await frames(3)
	check(game.menu.page == "Storage" and hub.panel_open, "Storage remains accessible from its pad")
	game.menu.leave_page()
	check(not hub.panel_open and hub.current_station == 5, "Back returns the player to the same bay")
	quit(failures)
