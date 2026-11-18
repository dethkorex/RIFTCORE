extends SceneTree

var errors := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	errors += int(not condition)

func run() -> void:
	var main = load("res://scripts/main.gd")
	var game = main.new()
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
	var platform := (load("res://assets/campaign/neon_factory/terrain/climb_platform_center.tscn") as PackedScene).instantiate() as Node3D
	game.game_root.add_child(platform)
	platform.global_position = Vector3(-20, 8, 0)
	await frames(5)
	var chosen := platform.get_node("Assembly/Climb") as Node3D
	actor.global_position = chosen.global_position + Vector3(-0.75, 1.13, 0)
	actor.velocity = Vector3(16.5, 0, 0)
	actor.dash_left = 0.22
	actor.dash_facing = 1
	actor.ground_dash = false
	Input.action_press("move_right")
	Input.action_press("climb_up")
	await frames(4)
	check(actor.ladder == chosen and actor.dash_left == 0.0, "Diagonal dash catches and cancels on the correct ladder")
	Input.action_release("move_right")
	await frames(ceili(chosen.rise / 2.85 * 60.0) + 38)
	Input.action_release("climb_up")
	await frames(24)
	check(not is_instance_valid(actor.ladder) and actor.is_on_floor(), "Climb clears the hatch and hands off to standing")
	var before: float = actor.global_position.y
	var down := InputEventJoypadMotion.new()
	down.device = 0
	down.axis = JOY_AXIS_LEFT_Y
	down.axis_value = 1.0
	Input.parse_input_event(down)
	var dash := InputEventJoypadButton.new()
	dash.device = 0
	dash.button_index = JOY_BUTTON_B
	dash.pressed = true
	Input.parse_input_event(dash)
	await frames(12)
	check(actor.global_position.y < before - 0.25 and actor.dash_left == 0.0 and not is_instance_valid(actor.ladder), "Left stick down and B drop through a one-way deck")
	down.axis_value = 0.0
	dash.pressed = false
	Input.parse_input_event(down)
	Input.parse_input_event(dash)
	await frames(2)
	var solid := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.6, 3)
	collider.shape = box
	solid.add_child(collider)
	game.game_root.add_child(solid)
	solid.global_position = Vector3(-25, 11, 0)
	actor.global_position = solid.global_position + Vector3(0, 1.4, 0)
	actor.velocity = Vector3.ZERO
	await frames(30)
	down.axis_value = 1.0
	dash.pressed = true
	Input.parse_input_event(down)
	Input.parse_input_event(dash)
	await frames(3)
	check(actor.is_on_floor() and actor.dash_left == 0.0 and actor.crouching, "Crouch and B keep the operator on a solid floor")
	down.axis_value = 0.0
	dash.pressed = false
	Input.parse_input_event(down)
	Input.parse_input_event(dash)
	await frames(2)
	dash.pressed = true
	Input.parse_input_event(dash)
	await frames(3)
	check(actor.dash_left > 0.0, "B dashes on a solid floor when standing")
	dash.pressed = false
	Input.parse_input_event(dash)
	quit(errors)
