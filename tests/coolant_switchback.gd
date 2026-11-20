extends SceneTree

var player
var game
var failed := false

func _initialize() -> void:
	run.call_deferred()

func surface() -> String:
	for i in player.get_slide_collision_count():
		var contact = player.get_slide_collision(i)
		if contact.get_normal().y > 0.55:
			var body = contact.get_collider()
			return str(body.get_parent().name if body.name == &"DeckCollider" else body.name)
	return ""

func check(ok: bool, label: String) -> bool:
	print("PASS " if ok else "FAIL ", label, " at ", player.position, " on ", surface())
	if not ok:
		failed = true
	return ok

func drive(to_x: float, direction := 1.0) -> bool:
	player.remote_axis = Vector2(direction, 0)
	for i in 400:
		if (player.position.x - to_x) * direction >= 0:
			return true
		if i % 12 == 0:
			player.remote_pressed["shoot"] = true
		await physics_frame
	return check(false, "Approach %.2f" % to_x)

func jump(to_x: float, expected: String, dash_frame := -1, expect_miss := false) -> bool:
	var start: Vector3 = player.position
	var speed: float = player.velocity.x
	player.remote_pressed["jump"] = true
	player.remote_held["jump"] = true
	var airborne := false
	for frame in 120:
		var dx: float = to_x - player.position.x
		player.remote_axis = Vector2(clampf(dx * 2.2, -1, 1), 0)
		if frame == dash_frame and airborne:
			player.remote_pressed["dash"] = true
			player.remote_held["dash"] = true
		await physics_frame
		if not player.grounded():
			airborne = true
		elif airborne:
			break
	player.remote_held.erase("jump")
	player.remote_held.erase("dash")
	if expect_miss:
		return check(airborne and surface() != expected and player.position.y < start.y, "Unaided jump misses elevated runout")
	print("Jump from ", start, " at ", snappedf(speed, 0.1), " m/s")
	return check(airborne and surface() == expected, "Land on " + expected)

func attempt(route: String) -> bool:
	player.remote_axis = Vector2.ZERO
	player.remote_held.clear()
	player.reset_predicted_position(Vector3(289.9, 5.25, 0), Vector3.ZERO, 1)
	for i in 15:
		await physics_frame
	if not check(surface() == "FrostEntry" and player.environment_control().x < .3, "Icy shared entry"):
		return false
	if route in ["upper", "vault"]:
		await drive(299.45)
		var before: float = player.position.x
		player.remote_axis = Vector2.ZERO
		for i in 30:
			await physics_frame
		print("Brake distance ", snappedf(player.position.x - before, .01), " m")
		if not check(surface() == "BrakeStrip" and is_zero_approx(player.velocity.x) and player.environment_control().x > .9, "Stop on steel"):
			return false
		if not await jump(297.3,"ServicePerch"): return false
		if route == "vault":
			if not await jump(293.1, "ArchiveStep"): return false
			await drive(294.1)
			if not await jump(298.4, "ArchiveTurn"): return false
			await drive(303.0)
			return await jump(308, "UpperWestVault00")
		if not await jump(303.0,"ServiceLanding"): return false
		await drive(306.3)
		if not await jump(311.4,"InspectionDeck"): return false
		await drive(315.1)
		if not await jump(321,"ValveDeck"): return false
		await drive(325.15)
		if not await jump(330.5,"TransferDeck"): return false
		await drive(333.65)
		if not await jump(339.3,"Downstep"): return false
		# Walk off the end of the steelwork onto the common ice runout.
		await drive(346)
	elif route in ["lower", "no_dash"]:
		await drive(314.45)
		if not check(surface() == "LaunchIce" and player.velocity.x > 8.5, "Full-speed ice takeoff"): return false
		if not await jump(323.5,"SkatingStraight"): return false
		await drive(330.95)
		if route == "no_dash": return await jump(342,"Runout",-1,true)
		if not await jump(342,"Runout",24): return false
	else:
		await drive(314.45)
		player.remote_axis = Vector2.RIGHT
		for i in 60:
			await physics_frame
		return check(player.position.y < 3.0, "Running off the ice misses the landing")
	await drive(354)
	player.remote_axis = Vector2.ZERO
	for i in 20:
		await physics_frame
	return check(surface() == "DrainApron", route + " rejoins above the sump")

func start_act() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.profile.manual_only = true
	game.sector = 3
	game.act = 1
	game.start_game(false, 3)
	player = game.player
	player.remote_input = true
	var level = load("res://scripts/mission_difficulty.gd").recommended_level(3, 0)
	player.gain_experience(player.experience_threshold(level), false)

func run() -> void:
	for route in ["upper", "lower", "vault", "miss", "no_dash"]:
		start_act()
		print("ROUTE ", route)
		await attempt(route)
		game.queue_free()
		await process_frame
		await physics_frame
	quit(1 if failed else 0)
