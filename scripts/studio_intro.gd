extends Control

@onready var video: VideoStreamPlayer = $Video
var finished := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not video.stream:
		open_game.call_deferred()
		return
	video.finished.connect(open_game)
	# Recover if a video backend cannot start or signals no completion.
	get_tree().create_timer(5.0).timeout.connect(open_game)
	video.play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		open_game.call_deferred()

func open_game() -> void:
	if finished:
		return
	finished = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
