extends "res://tests/game_test_tree.gd"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	print("PASS " if condition else "FAIL ", description)
	failures += int(not condition)

func cast(stage: Node3D, origin: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	query.hit_from_inside = true
	return stage.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "user://foundry-envelope-profile.cfg"
	game.checkpoint_path = "user://foundry-envelope-run.cfg"
	root.add_child(game)
	game.profile.manual_only = true
	game.start_game(false, 1)
	var stage: Node3D = game.game_root
	await physics_frame
	await physics_frame
	for name in ["Furnace", "RunwayWest", "RunwayEast", "PumpIntake", "RepairTransition"]:
		var wall: StaticBody3D = stage.get_node("TERRAIN/" + name + "UpperBulkhead")
		var shape: CollisionShape3D = wall.get_node("Collider")
		var half: float = shape.shape.size.y * .5
		for y in [-half + .08, 0.0, half - .08]:
			var origin := wall.global_position + Vector3(-.72, y, .98)
			var hit := cast(stage, origin, origin + Vector3.RIGHT * 1.44)
			check(hit.get("collider") == wall or (hit.has("position") and absf(hit.position.x - wall.position.x) < .8), name + " solid above doorway")
		var head := wall.global_position + Vector3(-.72, -half - 2.3, .98)
		check(cast(stage, head, head + Vector3.RIGHT * 1.44).is_empty(), name + " opening stays clear")
	for name in ["Furnace", "Runway", "Pump", "Repair"]:
		var roof: StaticBody3D = stage.get_node("TERRAIN/" + name + "Roof")
		var shape: CollisionShape3D = roof.get_node("Collider")
		for x in [-shape.shape.size.x * .36, 0.0, shape.shape.size.x * .36]:
			var start := roof.global_position + Vector3(x, .9, 1.02)
			check(cast(stage, start, start + Vector3.DOWN * 1.8).get("collider") == roof, name + " ceiling across the room")
	check(is_equal_approx(stage.get_node("MARKERS/RoomExit").position.x - stage.get_node("MARKERS/PlayerSpawn").position.x, 333.4), "Act I keeps the original deployment-to-extraction distance")
	finish(failures)
