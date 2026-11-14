extends VBoxContainer

const UI := preload("res://scripts/rift_ui.gd")
const UpdateClient := preload("res://scripts/update_client.gd")

var pending_action := ""
var pending_device := ""
var controls: ScrollContainer
var note: Label
var cancel_capture: Button
var initial_focus: OptionButton
var slots: Dictionary = {}
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
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", UI.frame(Color("101e32"), Color("365d79"), 1))
	tabs.add_theme_stylebox_override("tab_selected", UI.frame(Color("34244f"), UI.VIOLET))
	tabs.add_theme_stylebox_override("tab_hovered", UI.frame(Color("34244f"), UI.VIOLET))
	tabs.add_theme_stylebox_override("tab_unselected", UI.frame(Color("12253d"), Color("3b6384")))
	add_child(tabs)
	var audio_video := VBoxContainer.new()
	audio_video.name = "Display & Audio"
	audio_video.add_theme_constant_override("separation", 12)
	tabs.add_child(audio_video)
	UI.label(audio_video, "Display", 24, UI.CYAN)
	var display := HBoxContainer.new()
	display.add_theme_constant_override("separation", 16)
	audio_video.add_child(display)
	UI.label(display, "Resolution", 17, UI.MUTED).custom_minimum_size.x = 120
	var mode := OptionButton.new()
	initial_focus = mode
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for resolution in RiftSettings.MODES:
		mode.add_item("%d × %d" % [resolution.x, resolution.y])
	mode.select(RiftSettings.resolution_index)
	display.add_child(mode)
	UI.style_button(mode)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = RiftSettings.fullscreen
	display.add_child(fullscreen)
	UI.style_button(fullscreen)
	mode.item_selected.connect(func(index: int): RiftSettings.set_display(index, fullscreen.button_pressed))
	fullscreen.toggled.connect(func(on: bool): RiftSettings.set_display(mode.selected, on))
	audio_video.add_child(HSeparator.new())
	UI.label(audio_video, "Audio", 24, UI.CYAN)
	for bus_name in ["Master", "Music", "SFX"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		audio_video.add_child(row)
		var value := Label.new()
		value.custom_minimum_size.x = 126
		row.add_child(value)
		var slider := HSlider.new()
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 28
		slider.value = RiftSettings.volumes[bus_name] * 100
		value.text = "%s  %d%%" % [bus_name, slider.value]
		row.add_child(slider)
		slider.value_changed.connect(func(level: float):
			value.text = "%s  %d%%" % [bus_name, level]
			RiftSettings.set_volume(bus_name, level / 100.0)
		)
	var tips := CheckButton.new()
	tips.text = "Show first-visit hub tips"
	tips.button_pressed = RiftSettings.show_hub_tips
	audio_video.add_child(tips)
	UI.style_button(tips)
	tips.toggled.connect(func(enabled: bool):
		RiftSettings.show_hub_tips = enabled
		RiftSettings.save()
	)
	var input_settings := VBoxContainer.new()
	input_settings.name = "Controls"
	input_settings.add_theme_constant_override("separation", 8)
	tabs.add_child(input_settings)
	note = UI.label(input_settings, "Select a binding to change it.", 16, UI.MUTED)
	cancel_capture = UI.button(input_settings, "Cancel Binding", cancel_remap, false, 34)
	cancel_capture.hide()
	controls = ScrollContainer.new()
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls.follow_focus = true
	input_settings.add_child(controls)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(grid)
	for caption in ["Action", "Keyboard / Mouse", "Controller"]:
		var item := Label.new()
		item.text = caption
		grid.add_child(item)
	for action in RiftSettings.ACTIONS:
		var caption := Label.new()
		caption.text = RiftSettings.ACTIONS[action]
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(caption)
		for device in ["key", "pad"]:
			var bind := Button.new()
			bind.custom_minimum_size = Vector2(130, 32)
			bind.text = RiftSettings.binding_label(action, device)
			grid.add_child(bind)
			UI.style_button(bind)
			slots[action + ":" + device] = bind
			bind.pressed.connect(begin_capture.bind(action, device))
	UI.button(input_settings, "Reset Bindings", func():
		RiftSettings.reset_bindings()
		end_capture()
		note.text = "Default controls restored."
	, false, 34)
	tabs.tab_changed.connect(func(_tab: int):
		if not pending_action.is_empty():
			cancel_remap()
	)
	build_updates(tabs)

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
	cancel_capture.show()
	refresh()
	note.text = "Press a key or mouse button. For left click, use an empty area. Esc cancels." if device == "key" else "Press a controller input  /  Esc to cancel"

func refresh() -> void:
	for action in RiftSettings.ACTIONS:
		for device in ["key", "pad"]:
			slots[action + ":" + device].text = "Listening…" if action == pending_action and device == pending_device else RiftSettings.binding_label(action, device)

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
