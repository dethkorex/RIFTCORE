extends SceneTree

func _initialize() -> void:
	call_deferred("inspect_model")

func inspect_model() -> void:
	var packed := load("res://assets/models/mecha_main/RiftcoreMecha.glb") as PackedScene
	if not packed:
		push_error("RiftcoreMecha.glb failed to load")
		quit(1)
		return
	var model := packed.instantiate()
	root.add_child(model)
	var player := find_animation_player(model)
	if player:
		var clips := player.get_animation_list()
		print("MECHA_ANIMATIONS=", clips)
		for required in [&"idle", &"walk", &"run", &"jump", &"shoot", &"slash", &"dash"]:
			if not player.has_animation(required):
				push_error("Missing animation: " + required)
				quit(3)
				return
		player.play(&"dash")
		player.advance(0.2)
		print("MECHA_DASH_VALID=true")
		quit(0)
	else:
		push_error("No AnimationPlayer found in RiftcoreMecha.glb")
		quit(2)

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := find_animation_player(child)
		if found: return found
	return null
