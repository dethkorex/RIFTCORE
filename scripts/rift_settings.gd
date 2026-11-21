extends Node

const MODES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(3840, 2160), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(3840, 1600), Vector2i(5120, 1440)]
const ACTIONS := {
	"move_left": "Move left", "move_right": "Move right", "jump": "Jump",
	"crouch": "Crouch", "climb_up": "Climb up", "climb_down": "Climb down",
	"dash": "Dash", "shoot": "Attack / charge", "suit_fire": "Suit Weapon", "melee": "Switch buster / saber", "guard": "Block with saber", "swap_weapon": "Next suit", "previous_suit": "Previous suit", "pause": "Pause",
	"field_interact": "Field interact", "push_to_talk": "Push-to-talk",
}
const QUICK_DEFAULTS := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]
const AXES := ["move_left", "move_right", "climb_up", "climb_down", "crouch"]
var path := "user://riftcore_settings.cfg"
signal hud_scale_changed
signal voice_settings_changed
const DISPLAY_MODES := ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen", "Extended Fullscreen (Ultrawide)"]
const EXTENDED_FULLSCREEN := 3
const VSYNC_CHOICES := ["Off", "On", "Adaptive", "Mailbox"]
const FRAME_LIMITS := [0, 30, 60, 90, 120, 144, 165, 240]
const CONTROLLER_STYLES := ["Xbox", "PlayStation"]
const PAD_BUTTONS := [0, 1, 2, 3, 9, 10, 7, 8, 4, 6, 11, 12, 13, 14]
const QUALITY_SCALES := [0.67, 0.85, 1.0]
var volumes := {"Master": 1.0, "Music": 0.85, "SFX": 1.0, "Voice": 1.0}
var voice_enabled := false
var voice_push_to_talk := true
var microphone_device := "Default"
var speaker_device := "Default"
var resolution_index := 2
var display_mode := 1
var vsync_mode := 1
var frame_limit := 0
var controller_style := 0
var graphics_quality := 2
var hud_scale := 1.0
var vibration := true
var show_hub_tips := true
var seen_hub_tips := PackedStringArray()
var seen_story_beats := PackedStringArray()
var last_operator_name := ""
var startup_mode := ""
var defaults: Dictionary = {}
var bindings: Dictionary = {}

func _ready() -> void:
	# Only physics-driven mission operators opt in. Network ghosts and camera tweens already update per frame.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	restore()
	apply_video.call_deferred()

func restore() -> void:
	var data := ConfigFile.new()
	last_operator_name = ""
	startup_mode = ""
	seen_story_beats = PackedStringArray()
	if data.load(path) == OK:
		for bus_name in volumes:
			volumes[bus_name] = clampf(float(data.get_value("audio", bus_name, volumes[bus_name])), 0.0, 1.0)
		voice_enabled = bool(data.get_value("audio", "voice_enabled", false))
		voice_push_to_talk = bool(data.get_value("audio", "voice_push_to_talk", true))
		microphone_device = str(data.get_value("audio", "microphone", "Default"))
		speaker_device = str(data.get_value("audio", "speakers", "Default"))
		resolution_index = clampi(int(data.get_value("video", "resolution", resolution_index)), 0, MODES.size() - 1)
		var previous_fullscreen := bool(data.get_value("video", "fullscreen", true))
		display_mode = clampi(int(data.get_value("video", "window_mode", int(previous_fullscreen))), 0, DISPLAY_MODES.size() - 1)
		vsync_mode = clampi(int(data.get_value("video", "vsync", 1)), 0, VSYNC_CHOICES.size() - 1)
		frame_limit = clampi(int(data.get_value("video", "frame_limit", 0)), 0, FRAME_LIMITS.size() - 1)
		controller_style = clampi(int(data.get_value("controller", "layout", 0)), 0, CONTROLLER_STYLES.size() - 1)
		graphics_quality = clampi(int(data.get_value("video", "quality", 2)), 0, QUALITY_SCALES.size() - 1)
		hud_scale = clampf(float(data.get_value("gameplay", "hud_scale", 1.0)), 0.80, 1.15)
		vibration = bool(data.get_value("controller", "vibration", true))
		last_operator_name = str(data.get_value("player", "last_operator_name", "")).left(20)
		startup_mode = String(data.get_value("player", "startup_mode", ""))
		show_hub_tips = bool(data.get_value("tutorial", "enabled", true))
		var seen: Variant = data.get_value("tutorial", "seen_stations", PackedStringArray())
		if seen is PackedStringArray:
			seen_hub_tips = seen
		var beats: Variant = data.get_value("tutorial", "seen_story_beats", PackedStringArray())
		if beats is PackedStringArray:
			seen_story_beats = beats
		var loaded = data.get_value("controls", "bindings", {})
		if loaded is Dictionary:
			bindings = loaded
	for bus_name in volumes:
		apply_volume(bus_name)
	apply_audio_devices()
	if not defaults.is_empty():
		apply_bindings()

func save() -> Error:
	var data := ConfigFile.new()
	for bus_name in volumes:
		data.set_value("audio", bus_name, volumes[bus_name])
	data.set_value("audio", "voice_enabled", voice_enabled)
	data.set_value("audio", "voice_push_to_talk", voice_push_to_talk)
	data.set_value("audio", "microphone", microphone_device)
	data.set_value("audio", "speakers", speaker_device)
	data.set_value("video", "resolution", resolution_index)
	data.set_value("video", "fullscreen", display_mode != 0)
	data.set_value("video", "window_mode", display_mode)
	data.set_value("video", "vsync", vsync_mode)
	data.set_value("video", "frame_limit", frame_limit)
	data.set_value("controller", "layout", controller_style)
	data.set_value("video", "quality", graphics_quality)
	data.set_value("gameplay", "hud_scale", hud_scale)
	data.set_value("controller", "vibration", vibration)
	data.set_value("controls", "bindings", bindings)
	data.set_value("tutorial", "enabled", show_hub_tips)
	data.set_value("tutorial", "seen_stations", seen_hub_tips)
	data.set_value("tutorial", "seen_story_beats", seen_story_beats)
	data.set_value("player", "last_operator_name", last_operator_name)
	data.set_value("player", "startup_mode", startup_mode)
	return data.save(path)

func claim_story_beat(key: String, previously_seen := false) -> bool:
	if seen_story_beats.has(key):
		return false
	seen_story_beats.append(key)
	var error := save()
	if error != OK:
		push_warning("Could not remember story dialogue (%s)." % error_string(error))
	return not previously_seen

func deployment_dialogue(profile: RefCounted, sector: int, act: int, allow_tutorial := true) -> Array:
	var story := preload("res://scripts/rift_story.gd")
	var tell_story := claim_story_beat("campaign_story_v3_%d_%d" % [sector, act])
	var teach := allow_tutorial and claim_deployment_briefing(profile, sector, act)
	return story.deployment(sector, act, tell_story, teach)

func claim_deployment_briefing(profile: RefCounted, sector: int, act: int) -> bool:
	if not show_hub_tips:
		return false
	# Keep legacy slot history, but save this visit even if the player loses the run before saving.
	var previously_seen: bool = not profile.claim_briefing(sector, act)
	return claim_story_beat("briefing_%d" % ((sector - 1) * 2 + act), previously_seen)

func confirm_startup_choice(mode: String) -> void:
	if startup_mode != mode:
		startup_mode = mode
		save()

func remember_operator_name(operator_name: String) -> void:
	if last_operator_name != operator_name:
		last_operator_name = operator_name
		var result := save()
		if result != OK:
			push_warning("Could not remember the player name (%s)." % error_string(result))

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

func audio_devices(microphone: bool) -> Array:
	var listed := AudioServer.get_input_device_list() if microphone else AudioServer.get_output_device_list()
	var devices := ["Default"]
	for device in listed:
		if device not in devices:
			devices.append(device)
	return devices

func apply_audio_devices() -> void:
	AudioServer.input_device = microphone_device if microphone_device in audio_devices(true) else "Default"
	AudioServer.output_device = speaker_device if speaker_device in audio_devices(false) else "Default"

func set_audio_device(microphone: bool, device: String) -> void:
	var selected := device if device in audio_devices(microphone) else "Default"
	voice_settings_changed.emit()
	if microphone:
		microphone_device = selected
		AudioServer.input_device = selected
	else:
		speaker_device = selected
		AudioServer.output_device = selected
	save()

func set_voice_mode(enabled: bool, push_to_talk: bool) -> void:
	voice_enabled = enabled
	voice_push_to_talk = push_to_talk
	voice_settings_changed.emit()
	save()

func set_video(resolution: int, mode: int, vsync: int, limit: int, quality: int) -> Error:
	var previous := [resolution_index, display_mode, vsync_mode, frame_limit, graphics_quality]
	resolution_index = clampi(resolution, 0, MODES.size() - 1)
	display_mode = clampi(mode, 0, DISPLAY_MODES.size() - 1)
	vsync_mode = clampi(vsync, 0, VSYNC_CHOICES.size() - 1)
	frame_limit = clampi(limit, 0, FRAME_LIMITS.size() - 1)
	graphics_quality = clampi(quality, 0, QUALITY_SCALES.size() - 1)
	var result := save()
	if result != OK:
		resolution_index = previous[0]
		display_mode = previous[1]
		vsync_mode = previous[2]
		frame_limit = previous[3]
		graphics_quality = previous[4]
		return result
	apply_video()
	return OK

func apply_video() -> void:
	Engine.max_fps = FRAME_LIMITS[frame_limit]
	var window := get_window()
	var extended := display_mode == EXTENDED_FULLSCREEN
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if extended else Window.CONTENT_SCALE_ASPECT_KEEP
	if DisplayServer.get_name() == "headless":
		return
	var target: Vector2i = MODES[resolution_index]
	var screen := window.current_screen
	var available := DisplayServer.screen_get_usable_rect(screen)
	if display_mode != 0:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN if display_mode == 2 else Window.MODE_FULLSCREEN
		var pixels := DisplayServer.screen_get_size(screen)
		var display_height := float(pixels.y)
		if not extended and window.content_scale_size.x > 0:
			display_height = minf(display_height, float(pixels.x) * window.content_scale_size.y / window.content_scale_size.x)
		window.scaling_3d_scale = clampf(float(target.y) / maxf(1.0, display_height), 0.25, 2.0)
	else:
		window.mode = Window.MODE_WINDOWED
		var visible_fit := Vector2i(available.size.x, maxi(540, available.size.y - 48))
		var fit := minf(1.0, minf(float(visible_fit.x) / target.x, float(visible_fit.y) / target.y))
		var fitted := Vector2i(Vector2(target) * fit)
		window.size = fitted
		window.position = available.position + (available.size - fitted) / 2
		window.scaling_3d_scale = 1.0
	window.scaling_3d_scale *= QUALITY_SCALES[graphics_quality]
	DisplayServer.window_set_vsync_mode(vsync_mode as DisplayServer.VSyncMode)

func set_hud_scale(value: float) -> void:
	hud_scale = clampf(value, 0.80, 1.15)
	hud_scale_changed.emit()
	save()

func rumble() -> void:
	if vibration:
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.32, 0.18, 0.14)

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
	if event is InputEventJoypadMotion and not action in AXES and event.axis not in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		return "Use a controller button for this action."
	var data := to_data(event)
	if data.is_empty():
		return "Choose a key, mouse button, or controller input."
	if data.type == "key" and int(data.code) in [KEY_ENTER, KEY_KP_ENTER]:
		return "Enter opens chat during gameplay."
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

func assign_button(action: String, input: InputEventJoypadButton) -> String:
	var prior := action_for_button(input.button_index)
	if prior.is_empty() or prior == action:
		return set_binding(action, input, "pad")
	var previous: InputEventJoypadButton
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			previous = event
			break
	if not previous:
		return "Already assigned to %s. Rebind it from the action list first." % ACTIONS[prior]
	var prior_slots: Dictionary = bindings.get(prior, {})
	prior_slots["pad"] = to_data(previous)
	bindings[prior] = prior_slots
	var new_slots: Dictionary = bindings.get(action, {})
	new_slots["pad"] = to_data(input)
	bindings[action] = new_slots
	apply_bindings()
	return "Bindings swapped." if save() == OK else "Bindings swapped for this session."

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
			if not event or (event is InputEventJoypadButton and event.button_index in QUICK_DEFAULTS) or (event is InputEventKey and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
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

func reset_bindings(device := "") -> void:
	if device.is_empty():
		bindings.clear()
	else:
		for action in bindings.keys():
			if bindings[action] is Dictionary:
				bindings[action].erase(device)
	apply_bindings()
	save()

func pad_label(input: InputEvent) -> String:
	if input is InputEventJoypadButton:
		var xbox := {0:"A", 1:"B", 2:"X", 3:"Y", 4:"View", 6:"Menu", 7:"LS Click", 8:"RS Click", 9:"LB", 10:"RB"}
		var playstation := {0:"Cross", 1:"Circle", 2:"Square", 3:"Triangle", 4:"Share", 6:"Options", 7:"L3", 8:"R3", 9:"L1", 10:"R1"}
		var shared := {11:"D-pad ↑", 12:"D-pad ↓", 13:"D-pad ←", 14:"D-pad →"}
		var labels := playstation if controller_style == 1 else xbox
		return str(labels.get(input.button_index, shared.get(input.button_index, "Button %d" % input.button_index)))
	if input is InputEventJoypadMotion:
		var axis_names := ["Left Stick X", "Left Stick Y", "Right Stick X", "Right Stick Y", "L2" if controller_style == 1 else "LT", "R2" if controller_style == 1 else "RT"]
		var axis: int = input.axis
		return (axis_names[axis] if axis < axis_names.size() else "Axis %d" % axis) + ("+" if input.axis_value > 0 else "−")
	return ""

func action_for_button(button: int) -> String:
	for action in ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == button:
				return action
	return ""

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
		else:
			names.append(pad_label(event))
	return " / ".join(names) if not names.is_empty() else "Unbound"
