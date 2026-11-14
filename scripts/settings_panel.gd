extends VBoxContainer

const UI := preload("res://scripts/rift_ui.gd")
const UpdateClient := preload("res://scripts/update_client.gd")
const ControllerOverlay := preload("res://scripts/controller_overlay.gd")
var tabs: TabContainer

var pending_action := ""
var pending_device := ""
var notes: Dictionary = {}
var cancel_buttons: Dictionary = {}
var note: Label
var cancel_capture: Button
var initial_focus: Control
var slots: Dictionary = {}
var pad_keys: Dictionary = {}
var assign_popup: PopupMenu
var assigning_button := -1
var controller_layout: OptionButton
var can_restart := false
var updater: Node
var current_version := ""
var manifest: Dictionary
var check_button: Button
var install_button: Button
var update_status: Label
var patch_notes: RichTextLabel
var progress: ProgressBar
var installing := false

func _ready() -> void:
	add_theme_constant_override("separation", 15)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.label(self, "LB / RB   Switch tab", 14, UI.MUTED)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", UI.frame(Color("101e32"), Color("365d79"), 1))
	tabs.add_theme_stylebox_override("tab_focus", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", UI.frame(Color("34244f"), UI.VIOLET))
	tabs.add_theme_stylebox_override("tab_hovered", UI.frame(Color("34244f"), UI.VIOLET))
	tabs.add_theme_stylebox_override("tab_unselected", UI.frame(Color("12253d"), Color("3b6384")))
	add_child(tabs)
	var audio := settings_tab("Audio", "Volume")
	for bus_name in RiftSettings.volumes:
		var key: String = bus_name
		add_slider(audio, key + " Volume", RiftSettings.volumes[key] * 100.0, 0, 100, 1,
			func(value: float): RiftSettings.set_volume(key, value / 100.0))
	var video := settings_tab("Video", "Display")
	var mode := add_selector(video, "Resolution", RiftSettings.MODES.map(func(size): return "%d × %d" % [size.x, size.y]), RiftSettings.resolution_index)
	var window_mode := add_selector(video, "Display Mode", RiftSettings.DISPLAY_MODES, RiftSettings.display_mode)
	window_mode.item_selected.connect(func(index: int): RiftSettings.set_display(RiftSettings.resolution_index, index))
	mode.item_selected.connect(func(index: int): RiftSettings.set_display(index, RiftSettings.display_mode))
	var vsync := add_selector(video, "V-Sync", RiftSettings.VSYNC_CHOICES, RiftSettings.vsync_mode)
	vsync.item_selected.connect(func(index: int):
		RiftSettings.vsync_mode = index
		RiftSettings.apply_video()
		RiftSettings.save()
	)
	var fps := add_selector(video, "Frame Limit", RiftSettings.FRAME_LIMITS.map(func(limit): return "%d FPS" % limit if limit > 0 else "Unlimited"), RiftSettings.frame_limit)
	fps.item_selected.connect(func(index: int):
		RiftSettings.frame_limit = index
		RiftSettings.apply_video()
		RiftSettings.save()
	)
	var quality := add_selector(video, "Graphics Quality", ["Performance", "Balanced", "High"], RiftSettings.graphics_quality)
	quality.item_selected.connect(func(index: int):
		RiftSettings.graphics_quality = index
		RiftSettings.apply_video()
		RiftSettings.save()
	)
	var gameplay := settings_tab("Gameplay", "Interface")
	add_slider(gameplay, "HUD Scale", RiftSettings.hud_scale * 100.0, 80, 115, 5, func(value: float): RiftSettings.set_hud_scale(value / 100.0))
	add_toggle(gameplay, "Show first-visit hub tips", RiftSettings.show_hub_tips, func(enabled: bool):
		RiftSettings.show_hub_tips = enabled
		RiftSettings.save()
	)
	build_bindings("Keyboard & Mouse", "key")
	build_bindings("Controller", "pad")
	tabs.tab_changed.connect(func(_tab: int):
		if not pending_action.is_empty():
			cancel_remap()
	)
	build_updates(tabs)
	tabs.tab_changed.connect(func(_tab: int):
		if is_visible_in_tree():
			var focused := get_viewport().gui_get_focus_owner()
			if focused == null or not focused.is_visible_in_tree():
				tabs.get_tab_bar().grab_focus()
	)

func settings_tab(title: String, heading: String) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = title
	panel.add_theme_constant_override("separation", 12)
	tabs.add_child(panel)
	UI.label(panel, heading, 25, UI.CYAN)
	return panel

func add_selector(panel: VBoxContainer, title: String, options: Array, index: int) -> OptionButton:
	var row := HBoxContainer.new()
	panel.add_child(row)
	UI.label(row, title, 17, UI.MUTED).custom_minimum_size.x = 150
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choice)
	UI.style_button(choice)
	for label in options:
		choice.add_item(label)
	choice.select(index)
	return choice

func add_toggle(panel: VBoxContainer, title: String, state: bool, action: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = state
	panel.add_child(toggle)
	UI.style_button(toggle)
	toggle.toggled.connect(action)

func add_slider(panel: VBoxContainer, title: String, value: float, minimum: int, maximum: int, increment: int, action: Callable) -> void:
	var row := HBoxContainer.new()
	panel.add_child(row)
	UI.label(row, title, 17).custom_minimum_size.x = 150
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = value
	slider.custom_minimum_size.y = 28
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var caption := UI.label(row, "%d%%" % value, 17, UI.CYAN)
	caption.custom_minimum_size.x = 55
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(next: float):
		caption.text = "%d%%" % next
		action.call(next)
	)
	if initial_focus == null:
		initial_focus = slider

func build_bindings(title: String, device: String) -> void:
	var panel := settings_tab(title, "Bindings")
	if device == "pad":
		panel.get_child(0).text = "Controller Layout"
		controller_layout = add_selector(panel, "Button Layout", RiftSettings.CONTROLLER_STYLES, RiftSettings.controller_style)
		controller_layout.item_selected.connect(func(index: int):
			RiftSettings.controller_style = index
			RiftSettings.save()
			refresh()
		)
		add_toggle(panel, "Controller vibration", RiftSettings.vibration, func(enabled: bool):
			RiftSettings.vibration = enabled
			if not enabled:
				for id in Input.get_connected_joypads():
					Input.stop_joy_vibration(id)
			RiftSettings.save()
		)
	notes[device] = UI.label(panel, "Select an action to change its binding.", 16, UI.MUTED)
	var cancel := UI.button(panel, "Cancel Binding", cancel_remap, false, 34)
	cancel.hide()
	cancel_buttons[device] = cancel
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 170
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var sections := HBoxContainer.new()
	sections.add_theme_constant_override("separation", 22)
	sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(sections)
	if device == "pad":
		build_controller_buttons(sections)
	sections.add_child(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)
	for action in RiftSettings.ACTIONS:
		var caption := UI.label(grid, RiftSettings.ACTIONS[action], 17)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var button := UI.button(grid, RiftSettings.binding_label(action, device), begin_capture.bind(action, device), false, 34)
		button.custom_minimum_size.x = 190
		slots[action + ":" + device] = button
	UI.button(panel, "Reset " + title + " Bindings", func():
		RiftSettings.reset_bindings(device)
		refresh()
		notes[device].text = "Default bindings restored."
	, false, 34)

func build_controller_buttons(parent: HBoxContainer) -> void:
	var board := Panel.new()
	board.custom_minimum_size = Vector2(346, 244)
	board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	board.add_theme_stylebox_override("panel", UI.frame(Color("101d31"), Color("2d6588"), 1))
	parent.add_child(board)
	for button_index in RiftSettings.PAD_BUTTONS:
		var chip := UI.button(board, "", pick_controller_action.bind(button_index), false, 28)
		chip.custom_minimum_size = Vector2(44 if button_index in [0,1,2,3,11,12,13,14] else 68, 28)
		chip.size = chip.custom_minimum_size
		if button_index in RiftSettings.QUICK_DEFAULTS:
			chip.disabled = true
		pad_keys[button_index] = chip
	assign_popup = PopupMenu.new()
	add_child(assign_popup)
	assign_popup.id_pressed.connect(func(id: int):
		var input := InputEventJoypadButton.new()
		input.button_index = assigning_button
		notes["pad"].text = RiftSettings.assign_button(RiftSettings.ACTIONS.keys()[id], input)
		refresh()
	)
	refresh_controller_buttons()

func pick_controller_action(button_index: int) -> void:
	assigning_button = button_index
	assign_popup.clear()
	var assigned := RiftSettings.action_for_button(button_index)
	for action in RiftSettings.ACTIONS:
		assign_popup.add_item(RiftSettings.ACTIONS[action] + ("  ✓" if action == assigned else ""))
	var rect: Rect2 = pad_keys[button_index].get_global_rect()
	assign_popup.position = Vector2i(get_window().position + Vector2i(rect.end.x, rect.position.y)) if not get_window().gui_embed_subwindows else Vector2i(rect.end.x, rect.position.y)
	assign_popup.popup()

func refresh_controller_buttons() -> void:
	if is_instance_valid(controller_layout):
		controller_layout.select(RiftSettings.controller_style)
	var playstation := RiftSettings.controller_style == 1
	var left_cluster := Vector2(73, 110) if playstation else Vector2(96, 159)
	var right_cluster := Vector2(249, 110)
	var button_layout := {
		0: right_cluster + Vector2(0, 31), 1: right_cluster + Vector2(46, 0),
		2: right_cluster + Vector2(-46, 0), 3: right_cluster + Vector2(0, -31),
		9: Vector2(76,37), 10: Vector2(268,37), 4: Vector2(131,82), 6: Vector2(204,82),
		7: Vector2(124,200) if playstation else Vector2(62,90), 8: Vector2(205,200),
		11: left_cluster + Vector2(0,-30), 12: left_cluster + Vector2(0,30),
		13: left_cluster + Vector2(-43,0), 14: left_cluster + Vector2(43,0),
	}
	for index in pad_keys:
		var input := InputEventJoypadButton.new()
		input.button_index = index
		var name := RiftSettings.pad_label(input)
		var action := RiftSettings.action_for_button(index)
		var quick := RiftSettings.QUICK_DEFAULTS.find(index)
		var purpose: String = "Quick Slot %d" % (quick+1) if quick >= 0 else RiftSettings.ACTIONS.get(action, "Assign an action")
		var chip: Button = pad_keys[index]
		chip.text = name.trim_prefix("D-pad ") if quick >= 0 else name
		chip.tooltip_text = "%s  /  %s" % [name, purpose]
		chip.size = Vector2(maxf(chip.custom_minimum_size.x, chip.get_minimum_size().x),28)
		chip.position = button_layout[index] - chip.size * .5

func _unhandled_input(event: InputEvent) -> void:
	var step := ControllerOverlay.shoulder_step(event)
	if step != 0 and is_visible_in_tree() and pending_action.is_empty():
		get_viewport().set_input_as_handled()
		ControllerOverlay.cycle_tabs(tabs, step)

func build_updates(tabs: TabContainer) -> void:
	var panel := VBoxContainer.new()
	panel.name = "Update Game"
	panel.add_theme_constant_override("separation", 10)
	tabs.add_child(panel)
	updater = UpdateClient.new()
	add_child(updater)
	current_version = updater.configure_game()
	UI.label(panel, "Running %s" % current_version, 23, UI.CYAN)
	update_status = UI.label(panel, "Check for new releases and read the patch notes.", 17, UI.MUTED)
	progress = ProgressBar.new()
	panel.add_child(progress)
	progress.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	panel.add_child(actions)
	check_button = UI.button(actions, "Check for Updates", check_updates, true, 36)
	install_button = UI.button(actions, "Install and Restart", install_update, false, 36)
	install_button.disabled = true
	patch_notes = RichTextLabel.new()
	patch_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	patch_notes.focus_mode = Control.FOCUS_ALL
	patch_notes.selection_enabled = true
	panel.add_child(patch_notes)
	if OS.has_feature("editor"):
		check_button.disabled = true
		update_status.text = "Updates are available in exported Windows and Linux builds."

func _process(_delta: float) -> void:
	if installing:
		progress.value = updater.download_progress()

func check_updates() -> void:
	check_button.disabled = true
	install_button.disabled = true
	update_status.text = "Checking for updates…"
	var release: Variant = await updater.fetch_manifest()
	check_button.disabled = false
	if updater.package_entry(release).is_empty():
		update_status.text = "Could not check the update channel. Try again later."
		return
	manifest = release
	var tag: String = manifest.tag
	patch_notes.text = String(manifest.get("notes", "No patch notes published."))
	if not updater.compare_tags(tag, current_version):
		update_status.text = "This build is up to date."
		return
	if not can_restart:
		update_status.text = "%s is available. Save your progress and return to Title → Settings to install." % tag
		return
	update_status.text = "%s is available. Installing restarts the game." % tag
	install_button.disabled = false

func install_update() -> void:
	if installing or not can_restart or manifest.is_empty():
		return
	installing = true
	install_button.disabled = true
	check_button.disabled = true
	progress.value = 0
	progress.show()
	update_status.text = "Downloading and verifying %s…" % manifest.tag
	var error: String = await updater.install(manifest)
	if error.is_empty():
		if updater.start_version(manifest.tag):
			get_tree().quit()
			return
		error = "The update was installed, but it could not restart. Reopen RIFTCORE."
	installing = false
	progress.hide()
	update_status.text = error
	check_button.disabled = false
	install_button.disabled = false

func begin_capture(action: String, device: String) -> void:
	pending_action = action
	pending_device = device
	note = notes[device]
	cancel_capture = cancel_buttons[device]
	cancel_capture.show()
	refresh()
	note.text = "Press a key or mouse button. For left click, use an empty area. Esc cancels." if device == "key" else "Press a controller input  /  Esc to cancel"

func refresh() -> void:
	for action in RiftSettings.ACTIONS:
		for device in ["key", "pad"]:
			slots[action + ":" + device].text = "Listening…" if action == pending_action and device == pending_device else RiftSettings.binding_label(action, device)
	refresh_controller_buttons()

func _input(event: InputEvent) -> void:
	if pending_action.is_empty() or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		cancel_remap()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		for control in [cancel_capture, get_viewport().gui_get_hovered_control()]:
			if control == null or not control.get_global_rect().has_point(event.position):
				continue
			if control is BaseButton or control is Slider or control is ScrollBar:
				return
	var mouse_button: bool = event is InputEventMouseButton and event.pressed and not RiftSettings.to_data(event).is_empty()
	var usable: bool = mouse_button or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.76)
	if not usable or RiftSettings.device_of(event) != pending_device:
		return
	get_viewport().set_input_as_handled()
	note.text = RiftSettings.set_binding(pending_action, event, pending_device)
	end_capture()

func cancel_remap() -> void:
	note.text = "Binding canceled."
	end_capture()

func end_capture() -> void:
	pending_action = ""
	cancel_capture.hide()
	refresh()
