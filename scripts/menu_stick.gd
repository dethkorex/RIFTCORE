extends Node

const ENGAGE := 0.28
const RELEASE := 0.18
const FIRST_REPEAT := 0.25
const REPEAT := 0.09
const SCROLL_RATE := 540.0
const PAD_DIRECTIONS := {
	JOY_BUTTON_DPAD_UP: &"ui_up", JOY_BUTTON_DPAD_DOWN: &"ui_down",
	JOY_BUTTON_DPAD_LEFT: &"ui_left", JOY_BUTTON_DPAD_RIGHT: &"ui_right",
}

var stick := Vector2.ZERO
var direction := StringName()
var repeat_in := 0.0
var device := -1
var held_pad := -1
var scroll_axis := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner()
	if event is InputEventJoypadButton:
		if not event.pressed:
			if event.button_index == held_pad and event.device == device:
				reset_stick()
			return
		reset_stick()
		if focused and PAD_DIRECTIONS.has(event.button_index):
			held_pad = event.button_index
			device = event.device
			direction = PAD_DIRECTIONS[held_pad]
			repeat_in = FIRST_REPEAT
			if navigate_scroll(focused, direction):
				get_tree().call_group(&"menu_pointer", &"observe_controller", event)
				viewport.set_input_as_handled()
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var region := scroll_region(focused) if focused else null
		scroll_axis[event.axis - JOY_AXIS_RIGHT_X] = event.axis_value if region else 0.0
		if region:
			get_tree().call_group(&"menu_pointer", &"observe_controller", event)
			viewport.set_input_as_handled()
		return
	if not event is InputEventJoypadMotion or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		return
	if not focused:
		reset_stick()
		return
	if held_pad >= 0:
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
	var focused := get_viewport().gui_get_focus_owner()
	if not focused:
		reset_stick()
		scroll_axis = Vector2.ZERO
		return
	if scroll_axis.length() > ENGAGE:
		var region := scroll_region(focused)
		if region:
			var axis := Vector2.AXIS_Y if absf(scroll_axis.y) >= absf(scroll_axis.x) else Vector2.AXIS_X
			var bar := region.get_h_scroll_bar() if region.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED else scroll_bar(region, axis)
			bar.value += scroll_axis[axis] * SCROLL_RATE * delta
	if direction.is_empty():
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
	var focused := viewport.gui_get_focus_owner()
	if not focused or navigate_scroll(focused, action):
		return
	var step := InputEventAction.new()
	step.action = action
	step.pressed = true
	viewport.push_input(step)

func navigate_scroll(focused: Control, action: StringName) -> bool:
	var region := scroll_ancestor(focused)
	if not region or focused is ScrollBar:
		return false
	var vertical := action in [&"ui_up", &"ui_down"]
	var axis := Vector2.AXIS_Y if vertical else Vector2.AXIS_X
	var sign_step := 1.0 if action in [&"ui_down", &"ui_right"] else -1.0
	if focused == region:
		var bar := scroll_bar(region, axis)
		var previous := bar.value
		bar.value += sign_step * 48.0
		return not is_equal_approx(bar.value, previous)
	if not vertical or focused is Slider or focused is LineEdit or focused is SpinBox or focused is TabBar:
		return false
	var side := SIDE_BOTTOM if sign_step > 0.0 else SIDE_TOP
	var explicit := focused.get_focus_neighbor(side)
	if not explicit.is_empty():
		var neighbor := focused.get_node_or_null(explicit) as Control
		if neighbor and can_focus(neighbor):
			return false
	var origin := focused.get_global_rect().get_center()
	var target: Control
	var best_score := INF
	for candidate: Control in region.find_children("*", "Control", true, false):
		if candidate == focused or candidate is ScrollBar or not can_focus(candidate):
			continue
		var offset := candidate.get_global_rect().get_center() - origin
		var along := offset.y * sign_step
		if along < 7.0:
			continue
		var score := along + absf(offset.x) * 2.0
		if score < best_score:
			best_score = score
			target = candidate
	if not target:
		return false
	target.grab_focus()
	region.ensure_control_visible(target)
	return true

func can_focus(control: Control) -> bool:
	return control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled)

func scroll_bar(region: ScrollContainer, axis: int) -> ScrollBar:
	return region.get_v_scroll_bar() if axis == Vector2.AXIS_Y else region.get_h_scroll_bar()

func scroll_ancestor(control: Control) -> ScrollContainer:
	var ancestor: Node = control
	while ancestor and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	return ancestor as ScrollContainer

func scroll_region(focused: Control) -> ScrollContainer:
	var own := scroll_ancestor(focused)
	if own:
		return own
	var ancestor := focused.get_parent()
	while ancestor is Control:
		for region: ScrollContainer in ancestor.find_children("*", "ScrollContainer", true, false):
			if region.is_visible_in_tree() and (region.get_v_scroll_bar().is_visible_in_tree() or region.get_h_scroll_bar().is_visible_in_tree()):
				return region
		ancestor = ancestor.get_parent()
	return null

func reset_stick() -> void:
	stick = Vector2.ZERO
	direction = &""
	held_pad = -1
	device = -1
