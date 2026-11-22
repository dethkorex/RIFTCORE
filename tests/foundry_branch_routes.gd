extends "res://tests/game_test_tree.gd"

# Run each branch from its junction with the same controls and capsule as a fresh operator.
const STEP := 1.0 / 60.0
var player: Node3D
var game
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func result(ok: bool, label: String) -> bool:
	print("PASS " if ok else "FAIL ", label, " at ", Vector2(player.position.x, feet()))
	failures += int(not ok)
	return ok

func feet() -> float:
	return player.position.y - player.standing_capsule.height * 0.5

func tick(axis: float, jump := false, dash := false) -> void:
	await physics_frame
	player.remote_axis.x = axis
	player.remote_pressed = {}
	if jump:
		player.remote_pressed[&"jump"] = true
	if dash:
		player.remote_pressed[&"dash"] = true
	player.remote_held = {&"jump": true, &"dash": dash}
	player.simulate_movement(STEP)

func steer(x: float) -> float:
	return clampf((x - player.position.x) * 4.0 - player.velocity.x * .14, -1.0, 1.0)

func place(x: float, y: float) -> void:
	player.global_position = Vector3(x, y + player.standing_capsule.height * .5 + .04, 0)
	player.velocity = Vector3.ZERO
	player.hatch_floor = null
	for i in 10:
		await tick(0)

func walk(x: float, frames := 130) -> void:
	for i in frames:
		await tick(steer(x))
		if absf(x - player.position.x) < .2 and player.grounded():
			break

# Approach the takeoff edge, jump toward the near edge, then commit to the deck once clear.
func cross(takeoff: float, near_edge: float, landing: float, height: float) -> bool:
	await walk(takeoff)
	var direction := signf(landing - takeoff)
	await tick(direction, true)
	for i in 100:
		var target := near_edge - direction * .52 if feet() < height - .025 and player.velocity.y > 0 else landing
		await tick(steer(target))
		if i > 7 and player.grounded():
			break
	return result(absf(feet() - height) < .2 and absf(player.position.x - landing) < 2.0, "Jump to %.1f m at height %.2f" % [landing, height])

# Walk off the finished tread with the live solo pit/respawn handlers enabled.
func miss_gap(takeoff: float, height: float, middle: float) -> void:
	await place(takeoff, height)
	var initial_lives: int = player.lives
	player.set_physics_process(true)
	for frame in 100:
		player.remote_axis.x = steer(middle)
		await physics_frame
		if player.lives < initial_lives:
			break
	result(player.lives == initial_lives - 1, "Missing the inspection plinth costs one life")
	player.remote_axis = Vector2.ZERO
	for frame in 100:
		await physics_frame
		if player.health > 0 and player.lives < initial_lives:
			break
	result(player.health > 0 and player.lives == initial_lives - 1 and absf(player.position.x - middle) > 3, "The operator respawns clear of the slag")
	player.set_physics_process(false)

func shaft(gate: float, pier: float, height: float) -> void:
	await place(gate - 3, 0)
	for i in 35:
		await tick(1)
	if not result(player.position.x < gate - 1, "Door stops a standing operator"):
		return
	await tick(1, false, true)
	for i in 26:
		if player.position.x > gate + 1.65:
			break
		await tick(1)
	if not result(player.position.x > gate + 1.50, "A ground slide clears the pressure shutter from wall contact"):
		return
	await ascend(gate + 1.2, pier, height)

func ascend(left_face: float, pier: float, height: float, min_kicks := 2) -> void:
	await walk(pier - .88, 40)
	await tick(1, true)
	var toward := 1.0
	var kicks := 0
	for i in 300:
		if player.grounded() and absf(feet() - height) < .14:
			break
		if feet() > height - .04 and player.position.x > left_face + .7:
			await tick(steer(pier))
		elif player.is_on_wall() and player.velocity.y < 3 and player.get_wall_normal().x * toward < -.6:
			await tick(toward, true)
			toward *= -1.0
			kicks += 1
		else:
			await tick(toward)
	result(kicks >= min_kicks and player.grounded() and absf(feet() - height) < .14, "Alternating wall kicks land on the inspection pier")

func check_graph(act: int) -> void:
	var file := "neon_factory_test" if act == 1 else "neon_factory_act_2"
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://addons/riftcore_level_graph/maps/%s.json" % file))
	var visited := {}
	var pending := ["spawn" if act == 1 else "transfer_entry"]
	while not pending.is_empty():
		var key: String = pending.pop_back()
		if visited.has(key):
			continue
		visited[key] = true
		for edge in graph.routes:
			if edge[0] == key:
				pending.append(edge[1])
	var wing_rooms := ["lock", "loft", "upper", "lower", "apron"] if act == 1 else ["transfer_bridge", "transfer_drain", "transfer_lock", "survey_loft", "discharge"]
	for key in wing_rooms:
		result(visited.has(key) and game.game_root.has_node(graph.rooms[key].path), "Room graph leads to " + graph.rooms[key].title)
	result(visited.has("exit"), "Room graph connects deployment to extraction")

func start_act(act: int) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.manual_only = true
	root.add_child(game)
	game.act = act
	game.start_game(false, 1)
	player = game.player
	game.set_physics_process(false)
	for body in player.get_parent().get_children():
		body.set_physics_process(false)
		if body.is_in_group(&"level_enemies"):
			body.collision_layer = 0
	player.set_controls_suspended(false)
	player.remote_input = true
	player.invulnerable_time = 999
	await physics_frame
	await physics_frame
	result(absf(player.position.x - (-60.0 if act == 1 else -78.0)) < .05, "Fresh deployment starts inside the new wing")
	result(get_nodes_in_group(&"level_enemies").size() == (19 if act == 1 else 22), "Act %d enemy budget" % act)

func run() -> void:
	await start_act(1)
	check_graph(1)
	await shaft(-53, -47.9, 6)
	await place(-47.9, 6)
	if await cross(-48.05, -51.8, -52.9, 8):
		await cross(-53.55, -55.5, -57, 7.05)
	await place(-47.9, 6)
	if await cross(-47.7, -44.4, -42.8, 6.75):
		if await cross(-38.2, -35, -33.35, 7.6):
			if await cross(-26.95, -24, -22.4, 5.8):
				await walk(-12)
				result(absf(player.position.x + 12) < .4 and absf(feet()) < .15, "Inspection gallery rejoins the intake")
	await place(-40, -2)
	if await cross(-37.4, -34.8, -33.4, -2.8) and await cross(-31.85, -29.1, -27.95, -2.8):
		if await cross(-26.4, -23.4, -22.1, -1.55):
			await cross(-20.15, -17.5, -16.2, 0)
	await miss_gap(-32.1, -2.8, -30.3)
	await place(73.5, -16.4)
	result(game.gate_relays.interact(player, false), "Locker relay opens the deep drain")
	await walk(86.1)
	if result(absf(player.position.x - 86.1) < .5, "Pass through the opened drain and under the fissure"):
		await walk(89.9)
		if await cross(90.1, 92.45, 93.65, -19.55):
			await walk(97.6)
			result(absf(player.position.x - 97.6) < .5, "Drain rejoins at the deep well")
	await place(238.1, -19.45)
	result(game.gate_relays.interact(player, false), "Boiler relay opens the discharge passage")
	var seal = game.game_root.get_node("TERRAIN/BoilerSeal")
	seal.set_fractures(seal.HITS_TO_BREAK)
	await walk(247.0)
	var steps := [
		[247.2, 249.2, 250.4, -18.05],
		[252.35, 254.4, 255.5, -16.25],
		[254.9, 252.8, 251.55, -14.15],
		[252.5, 254.35, 255.6, -12.05],
	]
	for step in steps:
		if not await cross(step[0], step[1], step[2], step[3]):
			break
	await ascend(253.73, 257.15, -7.55, 1)
	if await cross(256.95, 253.73, 253.25, -5.21):
		await cross(253.5, 256.5, 257.65, -2.75)
	game.queue_free()
	await process_frame
	await physics_frame
	await start_act(2)
	check_graph(2)
	await place(-74, 0)
	if await cross(-71.6, -68.5, -66.8, 1):
		if await cross(-63.15, -59.9, -58.6, 2.25):
			await cross(-52.4, -49.2, -48, 1.1)
	await place(-66, -4.4)
	if await cross(-63.4, -60.4, -59.15, -5.1) and await cross(-58.45, -56.3, -55.15, -5.1):
		if await cross(-54.4, -51.9, -50.65, -3.6):
			if await cross(-48.6, -47, -45.65, -1.8):
				await cross(-44, -43.5, -42.4, 0)
	await miss_gap(-58.65, -5.1, -57.2)
	await shaft(-39, -33.8, 7.8)
	await place(-33.8, 7.8)
	if await cross(-33.6, -30.7, -29.2, 7.95):
		if await cross(-24.2, -20.8, -19.4, 9.3):
			await walk(-12)
			result(absf(player.position.x + 12) < .4 and absf(feet()) < .15, "Survey balcony rejoins the smelter")
	await place(487.65, -4.6)
	var grille: Node3D = game.game_root.get_node("TERRAIN/ValveDrainGrille")
	result(grille.is_visible_in_tree(), "The gallery grille covers the drain before the relay")
	result(game.gate_relays.interact(player, false) and not grille.is_visible_in_tree(), "Valve relay opens the drain")
	await walk(490.2)
	result(absf(feet() + 7.4) < .18, "Drain landing below the valve")
	await walk(499.55)
	result(absf(player.position.x - 499.55) < .4 and absf(feet() + 10.1) < .2, "Valve exit rejoins at the escape checkpoint")
	finish(failures)
