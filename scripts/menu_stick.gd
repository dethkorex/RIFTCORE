extends Node

const ENGAGE := 0.28
const RELEASE := 0.18
const FIRST_REPEAT := 0.25
const REPEAT := 0.09

var stick := Vector2.ZERO
var direction := StringName()
var repeat_in := 0.0
var device := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		reset_stick()
	if not event is InputEventJoypadMotion or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		return
	var viewport := get_viewport()
	if not viewport.gui_get_focus_owner():
		reset_stick()
		return
	if device != event.device:
		reset_stick()
		device = event.device
	stick[event.axis] = event.axis_value
	get_tree().call_group(&"menu_pointer", &"observe_controller", event)
	viewport.set_input_as_handled()
	var next := stick_direction(RELEASE if not direction.is_empty() else ENGAGE)
	if next != direction:
		direction = next
		repeat_in = FIRST_REPEAT
		if not direction.is_empty():
			navigate.call_deferred(direction)

func _process(delta: float) -> void:
	if direction.is_empty():
		return
	if not get_viewport().gui_get_focus_owner():
		reset_stick()
		return
	repeat_in -= delta
	if repeat_in <= 0.0:
		repeat_in = REPEAT
		navigate(direction)

func stick_direction(threshold: float) -> StringName:
	if maxf(absf(stick.x), absf(stick.y)) < threshold:
		return &""
	if absf(stick.x) > absf(stick.y):
		return &"ui_left" if stick.x < 0.0 else &"ui_right"
	return &"ui_up" if stick.y < 0.0 else &"ui_down"

func navigate(action: StringName) -> void:
	var viewport := get_viewport()
	if not viewport.gui_get_focus_owner():
		return
	var step := InputEventAction.new()
	step.action = action
	step.pressed = true
	viewport.push_input(step)

func reset_stick() -> void:
	stick = Vector2.ZERO
	direction = &""
	device = -1
