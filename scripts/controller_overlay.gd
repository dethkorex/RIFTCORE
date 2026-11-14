extends Control

var back_action: Callable
var pause_action: Callable
var sections: TabContainer

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
