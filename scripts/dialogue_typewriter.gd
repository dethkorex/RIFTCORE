extends Control

signal advanced

const COMMS_CHIRP := preload("res://assets/audio/combat/comms_chirp.wav")
const CHARACTERS_PER_SECOND := 48.0
const CHIRP_SPACING := 5

var body: Label
var next: Button
var writing: Tween
var skipped := false
var waiting := false
var auto_advance := false
var voice_pitch := 1.14
var chirp: AudioStreamPlayer
var last_chirp_at := 0

func _ready() -> void:
	chirp = AudioStreamPlayer.new()
	chirp.stream = COMMS_CHIRP
	chirp.bus = &"SFX"
	chirp.volume_db = -21.0
	add_child(chirp)

static func automatic_seconds(text: String) -> float:
	var duration := float(text.length()) / CHARACTERS_PER_SECOND
	return maxf(3.4, duration + 0.75)

func show_line(text: String, automatic := false) -> void:
	if skipped:
		return
	auto_advance = automatic
	body.text = text
	body.visible_characters = 0
	last_chirp_at = -CHIRP_SPACING
	next.disabled = true
	waiting = true
	writing = create_tween()
	var duration := float(text.length()) / CHARACTERS_PER_SECOND
	writing.tween_method(reveal, 0, text.length(), duration)
	if automatic:
		next.hide()
		writing.tween_interval(automatic_seconds(text) - duration)
		writing.tween_callback(finish_line)
	else:
		writing.tween_callback(func():
			next.disabled = false
			next.grab_focus()
		)
	await advanced

func reveal(count: int) -> void:
	var previous := body.visible_characters
	body.visible_characters = count
	if count <= previous or count - last_chirp_at < CHIRP_SPACING:
		return
	for character in body.text.substr(previous, count - previous):
		var code := character.unicode_at(0)
		if code >= 192 or code in range(48, 58) or code in range(65, 91) or code in range(97, 123):
			last_chirp_at = count
			chirp.pitch_scale = voice_pitch * randf_range(0.95, 1.05)
			chirp.play()
			return

func advance() -> void:
	if not waiting or next.disabled or auto_advance:
		return
	finish_line()

func skip() -> void:
	skipped = true
	if waiting:
		finish_line()

func finish_line() -> void:
	waiting = false
	chirp.stop()
	if writing and writing.is_running():
		writing.kill()
	advanced.emit()

func _input(event: InputEvent) -> void:
	if not waiting:
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		skip()
	elif not auto_advance and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			advance()
