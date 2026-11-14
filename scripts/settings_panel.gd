extends VBoxContainer

const UI := preload("res://scripts/rift_ui.gd")

var pending_action := ""
var pending_device := ""
var controls: ScrollContainer
var note: Label
var slots: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var display := HBoxContainer.new()
	add_child(display)
	var mode := OptionButton.new()
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for resolution in RiftSettings.MODES:
		mode.add_item("%d × %d" % [resolution.x, resolution.y])
	mode.select(RiftSettings.resolution_index)
	display.add_child(mode)
	UI.style_button(mode, UI.CYAN)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = RiftSettings.fullscreen
	display.add_child(fullscreen)
	UI.style_button(fullscreen, UI.VIOLET)
	mode.item_selected.connect(func(index: int): RiftSettings.set_display(index, fullscreen.button_pressed))
	fullscreen.toggled.connect(func(on: bool): RiftSettings.set_display(mode.selected, on))
	for bus_name in ["Master", "Music", "SFX"]:
		var row := HBoxContainer.new()
		add_child(row)
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
	var toggle := Button.new()
	toggle.text = "Remap controls  ›"
	toggle.custom_minimum_size.y = 42
	add_child(toggle)
	UI.style_button(toggle, UI.VIOLET)
	note = Label.new()
	note.add_theme_font_size_override("font_size", 14)
	note.text = "Set display, audio, and controls."
	add_child(note)
	controls = ScrollContainer.new()
	controls.custom_minimum_size.y = 215
	controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls.follow_focus = true
	add_child(controls)
	controls.hide()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(grid)
	for caption in ["Action", "Keyboard", "Controller"]:
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
			bind.custom_minimum_size = Vector2(108, 35)
			bind.text = RiftSettings.binding_label(action, device)
			grid.add_child(bind)
			UI.style_button(bind, UI.CYAN if device == "key" else UI.VIOLET)
			slots[action + ":" + device] = bind
			bind.pressed.connect(begin_capture.bind(action, device))
	var restore := Button.new()
	restore.text = "Reset bindings"
	grid.add_child(restore)
	UI.style_button(restore, Color("f9c65a"))
	restore.pressed.connect(func():
		RiftSettings.reset_bindings()
		refresh()
		note.text = "Default controls restored."
	)
	toggle.pressed.connect(func():
		controls.visible = not controls.visible
		toggle.text = "Hide controls" if controls.visible else "Remap controls  ›"
		pending_action = ""
		refresh()
	)

func begin_capture(action: String, device: String) -> void:
	pending_action = action
	pending_device = device
	refresh()
	note.text = "Press a key  /  Esc to cancel" if device == "key" else "Press a controller input  /  Esc to cancel"

func refresh() -> void:
	for action in RiftSettings.ACTIONS:
		for device in ["key", "pad"]:
			slots[action + ":" + device].text = "Listening…" if action == pending_action and device == pending_device else RiftSettings.binding_label(action, device)

func _input(event: InputEvent) -> void:
	if pending_action.is_empty() or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		pending_action = ""
		refresh()
		note.text = "Binding canceled."
		return
	var usable: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.76)
	if not usable or RiftSettings.device_of(event) != pending_device:
		return
	get_viewport().set_input_as_handled()
	note.text = RiftSettings.set_binding(pending_action, event, pending_device)
	pending_action = ""
	refresh()
