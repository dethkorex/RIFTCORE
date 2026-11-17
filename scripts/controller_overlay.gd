extends Control

var back_action: Callable
var pause_action: Callable
var sections: TabContainer
var first_focus: Control
var last_focus: Control

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(remember_focus)
	get_window().focus_entered.connect(func(): restore_focus.call_deferred())

func remember_focus(control: Control) -> void:
	if is_instance_valid(control) and is_ancestor_of(control):
		last_focus = control

func restore_focus() -> void:
	if not is_visible_in_tree() or not can_process():
		return
	# A dialog layered over the pause screen may already own focus.
	if can_focus(get_viewport().gui_get_focus_owner()):
		return
	for control in [last_focus, first_focus]:
		if can_focus(control):
			control.grab_focus()
			return

func can_focus(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and control.can_process() and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled)

func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) > 0.28):
		restore_focus()

static func shoulder_step(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	return 0

static func cycle_tabs(tabs: TabContainer, step: int) -> void:
	tabs.current_tab = posmod(tabs.current_tab + step, tabs.get_tab_count())
	RiftAudio.play_effect(&"menu_move")

func _unhandled_input(event: InputEvent) -> void:
	var step := shoulder_step(event)
	if step != 0 and is_instance_valid(sections) and sections.is_visible_in_tree():
		get_viewport().set_input_as_handled()
		cycle_tabs(sections, step)
		return
	if not event is InputEventMouseButton and event.is_action_pressed("pause") and pause_action.is_valid():
		get_viewport().set_input_as_handled()
		pause_action.call()
	elif event.is_action_pressed("ui_cancel") and back_action.is_valid():
		get_viewport().set_input_as_handled()
		back_action.call()
