extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for frame in count:
		await process_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failures += int(not ok)

func send_button(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	root.push_input(event)

func tap(code: JoyButton, hold_frames := 2) -> void:
	send_button(code, true)
	await frames(hold_frames)
	send_button(code, false)
	await frames(2)

func focused_label() -> String:
	var button := root.gui_get_focus_owner() as Button
	return button.text if button else ""

func run() -> void:
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await frames(4)
	var menu: Control = game.menu
	menu.developer_session = true
	menu.show_page("Title")
	await frames(5)
	check(focused_label() == "Enter Station", "Title begins at Enter Station")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(focused_label() == "Operators", "One Down tap moves one option")
	await tap(JOY_BUTTON_DPAD_DOWN, 32)
	check(focused_label() == "Tutorials", "Holding Down on the D-pad does not skip the Tutorials row")
	await tap(JOY_BUTTON_DPAD_UP, 32)
	check(focused_label() == "Operators", "Holding Up on the D-pad moves exactly one option")
	send_button(JOY_BUTTON_DPAD_DOWN, true)
	await frames(4)
	send_button(JOY_BUTTON_DPAD_DOWN, true)
	await frames(4)
	send_button(JOY_BUTTON_DPAD_DOWN, false)
	check(focused_label() == "Tutorials", "Duplicate Down events while held do not move twice")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(focused_label() == "Settings", "Settings is next after Tutorials")
	await tap(JOY_BUTTON_A)
	check(game.menu.page == "Settings", "The controller opens Settings")
	var settings = menu.find_child("RiftSettingsPanel", true, false)
	if not is_instance_valid(settings):
		quit(1)
		return
	var tab_bar: TabBar = settings.tabs.get_tab_bar()
	for title in ["Audio", "Video", "Gameplay"]:
		for index in settings.tabs.get_tab_count():
			if settings.tabs.get_tab_title(index) == title:
				settings.tabs.current_tab = index
				break
		await frames(5)
		tab_bar.grab_focus()
		var rows: Array[Control] = []
		for item: Control in settings.tabs.get_current_tab_control().find_children("*", "Control", true, false):
			if item.get_viewport() == root and item.is_visible_in_tree() and (item is BaseButton or item is HSlider) and item.focus_mode == Control.FOCUS_ALL:
				if not item is BaseButton or not item.disabled:
					rows.append(item)
		check(rows.size() >= 2, title + " has focusable controls")
		for row in rows:
			await tap(JOY_BUTTON_DPAD_DOWN)
			check(root.gui_get_focus_owner() == row, title + " Down follows menu order")
		for index in range(rows.size() - 2, -1, -1):
			await tap(JOY_BUTTON_DPAD_UP)
			check(root.gui_get_focus_owner() == rows[index], title + " Up follows menu order")
		await tap(JOY_BUTTON_DPAD_UP)
		check(root.gui_get_focus_owner() == tab_bar, title + " returns to the tab strip")
	await tap(JOY_BUTTON_B)
	check(game.menu.page == "Title", "Controller Back returns to the title")
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = 0.8
	root.push_input(motion)
	await frames(24)
	check(focused_label() != "Enter Station" and focused_label() != "Operators", "Holding the analog stick still repeats movement")
	quit(int(failures > 0))
