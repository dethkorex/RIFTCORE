extends SceneTree

var directions: Array[Vector3] = []
var muzzles: Array[Vector3] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	current_scene = game
	game.sector = 1
	game.act = 2
	game.start_game(false)
	game.set_process(false)
	var actor = game.player
	actor.invulnerable_time = 999.0
	for enemy in get_nodes_in_group("level_enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
	await frames(5)
	var chosen: Node3D = get_first_node_in_group("factory_ladder")
	actor.global_position = chosen.global_position + Vector3.UP * 1.5
	actor.ladder = chosen
	actor.shot_fired.connect(func(shot):
		directions.append(shot.direction)
		muzzles.append(shot.global_position - actor.global_position)
	)
	var failures := 0
	for side in [-1.0, 1.0]:
		var aim := "move_left" if side < 0 else "move_right"
		Input.action_press(aim)
		Input.action_press("climb_up")
		var before: float = actor.global_position.y
		await frames(5)
		Input.action_press("shoot")
		await frames(2)
		Input.action_release("shoot")
		await frames(5)
		Input.action_release("climb_up")
		Input.action_release(aim)
		var correct: bool = actor.ladder == chosen and actor.global_position.y > before
		correct = correct and not directions.is_empty() and directions.back().is_equal_approx(Vector3(side, 0, 0))
		correct = correct and not muzzles.is_empty() and muzzles.back().x * side > 0.15
		print("PASS " if correct else "FAIL ", "Climbs and fires ", aim, " with muzzle on the aimed side. ", directions, " / ", muzzles)
		failures += int(not correct)
		await frames(20)
	quit(failures)
