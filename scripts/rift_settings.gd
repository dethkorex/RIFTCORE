extends Node

const MODES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const ACTIONS := {
	"move_left": "Move left", "move_right": "Move right", "jump": "Jump",
	"crouch": "Crouch", "climb_up": "Climb up", "climb_down": "Climb down",
	"dash": "Dash", "shoot": "Buster", "melee": "Sword", "swap_weapon": "Next suit", "previous_suit": "Previous suit", "pause": "Pause",
}
const QUICK_DEFAULTS := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]
const AXES := ["move_left", "move_right", "climb_up", "climb_down", "crouch"]
var path := "user://riftcore_settings.cfg"
var volumes := {"Master": 1.0, "Music": 0.85, "SFX": 1.0}
var resolution_index := 2
var fullscreen := true
var show_hub_tips := true
var seen_hub_tips := PackedStringArray()
var defaults: Dictionary = {}
var bindings: Dictionary = {}

func _ready() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	restore()
	apply_video.call_deferred()

func restore() -> void:
	var data := ConfigFile.new()
	if data.load(path) == OK:
		for bus_name in volumes:
			volumes[bus_name] = clampf(float(data.get_value("audio", bus_name, volumes[bus_name])), 0.0, 1.0)
		resolution_index = clampi(int(data.get_value("video", "resolution", resolution_index)), 0, MODES.size() - 1)
		fullscreen = bool(data.get_value("video", "fullscreen", fullscreen))
		show_hub_tips = bool(data.get_value("tutorial", "enabled", true))
		var seen: Variant = data.get_value("tutorial", "seen_stations", PackedStringArray())
		if seen is PackedStringArray:
			seen_hub_tips = seen
		var loaded = data.get_value("controls", "bindings", {})
		if loaded is Dictionary:
			bindings = loaded
	for bus_name in volumes:
		apply_volume(bus_name)
	if not defaults.is_empty():
		apply_bindings()

func save() -> Error:
	var data := ConfigFile.new()
	for bus_name in volumes:
		data.set_value("audio", bus_name, volumes[bus_name])
	data.set_value("video", "resolution", resolution_index)
	data.set_value("video", "fullscreen", fullscreen)
	data.set_value("controls", "bindings", bindings)
	data.set_value("tutorial", "enabled", show_hub_tips)
	data.set_value("tutorial", "seen_stations", seen_hub_tips)
	return data.save(path)

func apply_volume(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	var value: float = volumes[bus_name]
	if index >= 0:
		AudioServer.set_bus_mute(index, value < 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))

func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	apply_volume(bus_name)
	save()

func set_display(index: int, fill_screen: bool) -> void:
	resolution_index = clampi(index, 0, MODES.size() - 1)
	fullscreen = fill_screen
	apply_video()
	save()

func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var target: Vector2i = MODES[resolution_index]
	var screen := window.current_screen
	var available := DisplayServer.screen_get_usable_rect(screen)
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		var pixels := DisplayServer.screen_get_size(screen)
		window.scaling_3d_scale = clampf(float(target.x) / maxf(1.0, pixels.x), 0.25, 2.0)
	else:
		window.mode = Window.MODE_WINDOWED
		var visible_fit := Vector2i(available.size.x, maxi(540, available.size.y - 48))
		var fit := minf(1.0, minf(float(visible_fit.x) / target.x, float(visible_fit.y) / target.y))
		var fitted := Vector2i(Vector2(target) * fit)
		window.size = fitted
		window.position = available.position + (available.size - fitted) / 2
		window.scaling_3d_scale = 1.0

func configure_bindings() -> void:
	if defaults.is_empty():
		for action in ACTIONS.keys() + ["crouch_stick"]:
			defaults[action] = InputMap.action_get_events(action).duplicate()
	apply_bindings()

func device_of(event: InputEvent) -> String:
	return "key" if event is InputEventKey or event is InputEventMouseButton else "pad"

func to_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return {"type": "key", "code": code}
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		return {"type": "mouse", "code": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "button", "code": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "axis", "code": event.axis, "sign": signf(event.axis_value)}
	return {}

func from_data(data: Dictionary) -> InputEvent:
	var code := int(data.get("code", -1))
	if code < 0:
		return null
	match String(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = code
			return key
		"mouse":
			if code not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
				return null
			var mouse := InputEventMouseButton.new()
			mouse.button_index = code
			mouse.device = -1
			return mouse
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = code
			button.device = -1
			return button
		"axis":
			var axis := InputEventJoypadMotion.new()
			axis.axis = code
			axis.axis_value = float(data.get("sign", 1))
			axis.device = -1
			return axis
	return null

func set_binding(action: String, event: InputEvent, device: String) -> String:
	if event is InputEventJoypadButton and event.button_index in QUICK_DEFAULTS:
		return "D-pad directions are reserved for quick items."
	if not ACTIONS.has(action) or device_of(event) != device:
		return "Choose a %s input." % ("keyboard" if device == "key" else "controller")
	if event is InputEventJoypadMotion and not action in AXES:
		return "Use a controller button for this action."
	var data := to_data(event)
	if data.is_empty():
		return "Choose a key, mouse button, or controller input."
	for other in ACTIONS:
		if other == action or (other in ["climb_down", "crouch"] and action in ["climb_down", "crouch"]):
			continue
		for mapped in InputMap.action_get_events(other):
			if to_data(mapped) == data:
				return "Already bound to %s." % ACTIONS[other]
	var slots: Dictionary = bindings.get(action, {})
	slots[device] = data
	bindings[action] = slots
	apply_bindings()
	return "Binding saved." if save() == OK else "Binding applied for this session."

func apply_bindings() -> void:
	for action in defaults:
		InputMap.action_erase_events(action)
		for event in defaults[action]:
			InputMap.action_add_event(action, event)
	for action in bindings:
		if not ACTIONS.has(action) or not bindings[action] is Dictionary:
			continue
		for device in bindings[action]:
			var data = bindings[action][device]
			if not data is Dictionary:
				continue
			var event := from_data(data)
			if not event or (event is InputEventJoypadButton and event.button_index in QUICK_DEFAULTS):
				continue
			for old in InputMap.action_get_events(action):
				if device_of(old) == device:
					InputMap.action_erase_event(action, old)
			if action == "crouch" and device == "pad":
				InputMap.action_erase_events("crouch_stick")
				if event is InputEventJoypadMotion:
					InputMap.action_add_event("crouch_stick", event)
					continue
			InputMap.action_add_event(action, event)

func reset_bindings() -> void:
	bindings.clear()
	apply_bindings()
	save()

func binding_label(action: String, device: String) -> String:
	var names: PackedStringArray = []
	var events := InputMap.action_get_events(action)
	if action == "crouch" and device == "pad":
		events = events + InputMap.action_get_events("crouch_stick")
	for event in events:
		if device_of(event) != device:
			continue
		if event is InputEventKey:
			names.append(OS.get_keycode_string(event.physical_keycode))
		elif event is InputEventMouseButton:
			var labels := {MOUSE_BUTTON_LEFT: "Left Mouse", MOUSE_BUTTON_RIGHT: "Right Mouse", MOUSE_BUTTON_MIDDLE: "Middle Mouse", MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}
			names.append(labels.get(event.button_index, "Mouse %d" % event.button_index))
		elif event is InputEventJoypadButton:
			var labels := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 6: "Start", 9: "LB", 10: "RB", 11: "D-pad up", 12: "D-pad down", 13: "D-pad left", 14: "D-pad right"}
			names.append(str(labels.get(event.button_index, "Button %d" % event.button_index)))
		elif event is InputEventJoypadMotion:
			var axis_names := ["LS X", "LS Y", "RS X", "RS Y", "LT", "RT"]
			var axis := event.axis as int
			names.append((axis_names[axis] if axis < axis_names.size() else "Axis %d" % axis) + ("+" if event.axis_value > 0 else "−"))
	return " / ".join(names) if not names.is_empty() else "Unbound"
