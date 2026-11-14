extends Control

signal advanced

var body: Label
var next: Button
var writing: Tween
var skipped := false
var waiting := false
var auto_advance := false

func show_line(text: String, automatic := false) -> void:
	if skipped:
		return
	auto_advance = automatic
	body.text = text
	body.visible_characters = 0
	next.disabled = true
	waiting = true
	writing = create_tween()
	var duration := float(text.length()) / 48.0
	writing.tween_property(body, "visible_characters", text.length(), duration)
	if automatic:
		next.hide()
		writing.tween_interval(maxf(0.75, 3.4 - duration))
		writing.tween_callback(finish_line)
	else:
		writing.tween_callback(func():
			next.disabled = false
			next.grab_focus()
		)
	await advanced

func advance() -> void:
	if not waiting or next.disabled or auto_advance:
		return
	finish_line()

func finish_line() -> void:
	waiting = false
	if writing and writing.is_running():
		writing.kill()
	advanced.emit()

func _input(event: InputEvent) -> void:
	if not waiting:
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		skipped = true
		finish_line()
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			advance()
