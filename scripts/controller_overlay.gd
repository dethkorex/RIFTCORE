extends Control

var back_action: Callable
var pause_action: Callable

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and pause_action.is_valid():
		get_viewport().set_input_as_handled()
		pause_action.call()
	elif event.is_action_pressed("ui_cancel") and back_action.is_valid():
		get_viewport().set_input_as_handled()
		back_action.call()
