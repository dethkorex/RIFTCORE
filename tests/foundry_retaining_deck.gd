extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, title: String) -> void:
	print("PASS " if ok else "FAIL ", title)
	failures += int(not ok)

func trace(stage: Node3D, origin: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	return stage.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "user://retaining-deck-profile.cfg"
	game.checkpoint_path = "user://retaining-deck-run.cfg"
	root.add_child(game)
	game.profile.manual_only = true
	game.start_game(false, 1)
	await physics_frame
	await physics_frame
	var stage: Node3D = game.game_root
	var pier := stage.get_node("TERRAIN/CoolingCaverns/PierFoundation1")
	for depth in [1.25, 5.0, 12.0, 18.5]:
		var centre := Vector3(89.55, -9.21 - depth, 0)
		var hit := trace(stage, centre + Vector3.FORWARD * -3.0, centre)
		check(hit.get("collider") == pier, "solid retaining face at %.2f metres below the tread" % depth)
	for x in [85.7, 93.3, 103.1]:
		check(trace(stage, Vector3(x, -9, 0), Vector3(x, -14.5, 0)).is_empty(), "open fissure at %.1f" % x)
	var lane := Vector3(90, -6.75, 0)
	check(trace(stage, lane, lane + Vector3.RIGHT * 4).is_empty(), "upper gallery supports leave the lower route clear")
	quit(failures)
