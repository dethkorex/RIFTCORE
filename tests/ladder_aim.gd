extends SceneTree

var directions: Array[Vector3] = []
var muzzles: Array[Vector3] = []
var charge_flags: Array[bool] = []

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
		charge_flags.append(shot.is_charged)
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
	var spawn: Node3D = game.game_root.get_node("MARKERS/PlayerSpawn")
	actor.reset_predicted_position(spawn.global_position, Vector3.ZERO, 1.0)
	await frames(10)
	for charged in [false, true]:
		var before := directions.size()
		Input.action_press("climb_up")
		Input.action_press("shoot")
		await frames(50 if charged else 3)
		Input.action_release("shoot")
		await frames(5)
		Input.action_release("climb_up")
		var fired_up: bool = directions.size() > before and directions.back().is_equal_approx(Vector3.UP) and muzzles.back().y > 0.5 and charge_flags.back() == charged
		print("PASS " if fired_up else "FAIL ", "Hold Up fires vertically with a raised muzzle, charged=", charged)
		failures += int(not fired_up)
		await frames(20)
	for sample in [
		["move_right", 1.0, 1.0, Vector3(1.0, 1.0, 0.0)],
		["move_right", 1.0, 0.4, Vector3(1.0, 0.4, 0.0)],
		["move_right", 1.0, 0.14, Vector3(1.0, 0.14, 0.0)],
		["move_right", 1.0, 0.19, Vector3(1.0, 0.19, 0.0)],
		["move_left", 0.35, 1.0, Vector3(-0.35, 1.0, 0.0)],
	]:
		actor.reset_predicted_position(spawn.global_position, Vector3.ZERO, 1.0)
		await frames(5)
		Input.action_press(sample[0], sample[1])
		Input.action_press("climb_up", sample[2])
		var before := directions.size()
		await fire()
		var correct: bool = directions.size() > before and directions.back().is_equal_approx(sample[3].normalized())
		print("PASS " if correct else "FAIL ", "Upper aiming follows the exact stick ratio ", sample[3])
		failures += int(not correct)
		Input.action_release(sample[0])
		Input.action_release("climb_up")
		await frames(20)

	actor.reset_predicted_position(spawn.global_position, Vector3.ZERO, 1.0)
	await frames(10)
	await fire()
	var standing_height: float = muzzles.back().y
	await frames(20)
	Input.action_press("climb_down")
	Input.action_press("crouch")
	Input.action_press("move_right")
	await frames(5)
	var before_crouch := directions.size()
	await fire()
	var crouch_shot: bool = (directions.size() > before_crouch and actor.crouching
		and directions.back().is_equal_approx(Vector3.RIGHT) and muzzles.back().y < standing_height - 0.15)
	print("PASS " if crouch_shot else "FAIL ", "Down plus Forward fires from the crouched muzzle")
	failures += int(not crouch_shot)
	Input.action_release("move_right")
	Input.action_release("climb_down")
	Input.action_release("crouch")
	await frames(20)

	for sideways in [false, true]:
		actor.reset_predicted_position(spawn.global_position + Vector3.UP * 4.0, Vector3.ZERO, 1.0)
		await frames(4)
		Input.action_press("climb_down")
		Input.action_press("crouch")
		if sideways:
			Input.action_press("move_left")
		var before := directions.size()
		await fire()
		var expected := Vector3(-1, -1, 0).normalized() if sideways else Vector3.DOWN
		var down_shot: bool = not actor.grounded() and directions.size() > before and directions.back().is_equal_approx(expected)
		print("PASS " if down_shot else "FAIL ", "Free fall allows downward aim, sideways=", sideways)
		failures += int(not down_shot)
		Input.action_release("move_left")
		Input.action_release("climb_down")
		Input.action_release("crouch")
		await frames(20)
	actor.reset_predicted_position(spawn.global_position + Vector3.UP * 4.0, Vector3.UP * 11.0, 1.0)
	Input.action_press("climb_down")
	await fire()
	Input.action_release("climb_down")
	var rising_level: bool = directions.back().is_equal_approx(Vector3.RIGHT)
	print("PASS " if rising_level else "FAIL ", "Rising with Down held fires horizontally")
	failures += int(not rising_level)
	quit(failures)

func fire() -> void:
	Input.action_press("shoot")
	await frames(3)
	Input.action_release("shoot")
	await frames(5)
