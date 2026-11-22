extends SceneTree

func finish(exit_code := 0) -> void:
	root.get_node("RiftAudio").quit_after_audio(exit_code)
